# Internal Claude setup, sourced by the top-level installer.
setup_claude() (
  for f in "$K"/claude/templates/*.md; do link "$f" "$HOME/.config/herdr-core/templates/$(basename "$f")"; done

  claude_entries="$HOME/.config/herdr-kit/claude-entrypoints"
  link "$K/claude/commands" "$claude_entries/.claude/commands"
  link "$K/claude/skills" "$claude_entries/.claude/skills"
  link "$K/claude/bin/herdr-claude" "$HOME/.local/bin/herdr-claude"

  # Migrate only links created by this checkout's earlier installers.
  for f in "$K"/claude/commands/*.md "$K"/claude/skills/*; do
    relative=${f#"$K/claude/"}
    old="$HOME/.claude/$relative"
    if [ -L "$old" ]; then
      case $(readlink "$old") in
        "$f"|"$K/$relative") unlink "$old"; echo "unlinked: $old" ;;
      esac
    fi
  done
  link "$K/claude/hooks/herdr-tab-name.sh" "$HOME/.claude/hooks/herdr-tab-name.sh"

  s="$HOME/.claude/settings.json"
  [ -f "$s" ] || echo '{}' > "$s"
  if grep -q herdr-tab-name "$s"; then
    echo "ok: hooks already in $s"
  else
    cp "$s" "$s.pre-herdr-kit"
    jq '.hooks.Stop += [{hooks:[{type:"command",command:"~/.claude/hooks/herdr-tab-name.sh"}]}]
      | .hooks.SessionStart += [{matcher:"clear",hooks:[{type:"command",command:"~/.claude/hooks/herdr-tab-name.sh clear"}]}]' "$s.pre-herdr-kit" > "$s.tmp"
    mv "$s.tmp" "$s"
    echo "ok: hooks added to $s (backup: $s.pre-herdr-kit)"
  fi

  register_launcher claude
)
