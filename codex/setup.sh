# Internal Codex setup, sourced by the top-level installer.
setup_codex() (
  command -v codex >/dev/null || { echo "skip: codex is not on PATH, no Codex workers"; exit 0; }

  CODEX_MODEL_PREFIX=
  env="$HOME/.config/herdr-kit/local.env"
  # shellcheck disable=SC1090
  [ -f "$env" ] && . "$env"
  home="${CODEX_HOME:-$HOME/.codex}"
  state="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-core"
  # Machine-specific model settings are read from ~/.config/herdr-kit/local.env.
  mark="# Written by herdr-kit. Edits are overwritten; change the kit or local.env."
  legacy_mark="# Written by herdr-kit codex/install.sh. Edits are overwritten; change the kit or local.env."

  mkdir -p "$home"
  "$K/codex/scope-skills.sh" "$K"/codex/skills/*/SKILL.md
  link "$K/codex/skills" "$HOME/.config/herdr-kit/codex-skills"
  link "$K/codex/bin/herdr-codex" "$HOME/.local/bin/herdr-codex"
  for d in "$K"/codex/skills/*; do
    name=$(basename "$d")
    old="$HOME/.agents/skills/$name"
    skill="$home/skills/herdr-kit-$name"
    # Keep the kit in Codex's own skill directory.
    if { [ -e "$skill" ] || [ -L "$skill" ]; } &&
        { [ ! -L "$skill" ] || [ "$(readlink "$skill")" != "$d" ]; }; then
      echo "A file already occupies the skill link at $skill." >&2
      exit 1
    fi
    link "$d" "$skill"
    if [ -L "$old" ] && [ "$(readlink "$old")" = "$d" ]; then
      unlink "$old"
      echo "unlinked: $old"
    fi
  done
  for f in "$K"/codex/templates/*.md; do link "$f" "$HOME/.config/herdr-core/templates/$(basename "$f")"; done

  # Writers and spikes run unsandboxed (full): Xcode's SPM resolution starts its own sandbox-exec, which macOS
  # refuses inside Codex's sandbox. Read-only roles keep a sandbox, with network on (hc's socket needs
  # it) and hc's state folder writable, plus the folder context handoffs are written to.
  handoff="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-kit/handoff"
  mkdir -p "$handoff"
  profile() { # <role> <model> <effort> <full|sandboxed>
    p="$home/herdr-$1.config.toml"
    if [ -f "$p" ] && ! grep -qF -e "$mark" -e "$legacy_mark" "$p"; then
      mv "$p" "$p.pre-herdr-kit"
      echo "moved aside: $p.pre-herdr-kit"
    fi
    {
      echo "$mark"
      echo "model = \"$CODEX_MODEL_PREFIX$2\""
      echo "model_reasoning_effort = \"$3\""
      echo 'approval_policy = "never"'
      echo 'project_doc_fallback_filenames = ["CLAUDE.md"]'
      if [ "$4" = full ]; then
        echo 'sandbox_mode = "danger-full-access"'
      else
        echo 'sandbox_mode = "workspace-write"'
        echo
        echo '[sandbox_workspace_write]'
        echo 'network_access = true'
        printf "writable_roots = ['%s', '%s']\n" "$state" "$handoff"   # TOML literal strings: no escapes
      fi
    } > "$p.tmp"
    mv "$p.tmp" "$p"
    echo "wrote: $p"
  }

  profile writer-low  gpt-6-luna    medium full
  profile writer      gpt-6.1-terra medium full
  profile writer-high gpt-6.2-sol   high   full
  profile writer-deep gpt-6.2-astra high   full
  profile reader      gpt-6.2-astra medium sandboxed
  profile reader-deep gpt-6.2-astra high   sandboxed
  profile critique    gpt-6.2-astra high   sandboxed
  profile design      gpt-6.2-astra medium sandboxed
  profile research    gpt-6.1-terra medium sandboxed
  profile spike       gpt-6.1-terra medium full

  # Context handoff hook (shared with Claude). Codex skips it until it is trusted once with /hooks.
  link "$K/shared/hooks/herdr-handoff.sh" "$home/hooks/herdr-handoff.sh"
  hooks="$home/hooks.json"
  [ -f "$hooks" ] || echo '{}' > "$hooks"
  if grep -q herdr-handoff "$hooks"; then
    echo "ok: handoff hook already in $hooks"
  else
    cp "$hooks" "$hooks.pre-herdr-handoff"
    jq --arg c "$home/hooks/herdr-handoff.sh" '.hooks.PostToolUse += [{hooks:[{type:"command",command:$c}]}]' \
      "$hooks.pre-herdr-handoff" > "$hooks.tmp"
    mv "$hooks.tmp" "$hooks"
    echo "ok: handoff hook added to $hooks (backup: $hooks.pre-herdr-handoff); trust it once with /hooks in Codex"
  fi

  register_launcher codex
)
