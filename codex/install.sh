#!/bin/sh
# Adds the Codex workers and skills when `codex` is on PATH; does nothing otherwise. Safe to re-run.
# Links Herdr templates and Codex skills, and writes one Codex profile per worker template.
# Machine-specific settings go in ~/.config/herdr-kit/local.env, never in this repo:
#   CODEX_MODEL_PREFIX=global.openai.   prepended to every model id (e.g. for a proxy)
set -eu
K=$(cd "$(dirname "$0")/.." && pwd -P)

command -v codex >/dev/null || { echo "skip: codex is not on PATH, no Codex workers"; exit 0; }

CODEX_MODEL_PREFIX=
env="$HOME/.config/herdr-kit/local.env"
# shellcheck disable=SC1090
[ -f "$env" ] && . "$env"
home="${CODEX_HOME:-$HOME/.codex}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-core"
mark="# Written by herdr-kit codex/install.sh. Edits are overwritten; change the kit or local.env."

link() {
  mkdir -p "$(dirname "$2")"
  if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then echo "ok: $2"; return; fi
  if [ -e "$2" ] || [ -L "$2" ]; then mv "$2" "$2.pre-herdr-kit"; echo "moved aside: $2.pre-herdr-kit"; fi
  ln -s "$1" "$2"; echo "linked: $2"
}

backup_skill() {
  backup_root="$HOME/.config/herdr-kit/skill-backups"
  mkdir -p "$backup_root"
  backup_dir=$(mktemp -d "$backup_root/$(basename "$1").XXXXXX")
  mv "$1" "$backup_dir/"
  echo "moved aside: $backup_dir/$(basename "$1")"
}

link_skill() {
  skill="$HOME/.agents/skills/$(basename "$1")"
  # Earlier installs kept this backup next to the active skill.
  if [ -e "$skill.pre-herdr-kit" ] || [ -L "$skill.pre-herdr-kit" ]; then
    backup_skill "$skill.pre-herdr-kit"
  fi
  if [ -L "$skill" ] && [ "$(readlink "$skill")" = "$1" ]; then
    echo "ok: $skill"
    return
  fi
  if [ -e "$skill" ] || [ -L "$skill" ]; then
    backup_skill "$skill"
  fi
  link "$1" "$skill"
}

for f in "$K"/codex/templates/*.md; do link "$f" "$HOME/.config/herdr-core/templates/$(basename "$f")"; done
for d in "$K"/codex/skills/*; do link_skill "$d"; done

# Writers run unsandboxed (full): Xcode's SPM resolution starts its own sandbox-exec, which macOS
# refuses inside Codex's sandbox. Read-only roles keep a sandbox, with network on (hc's socket needs
# it) and hc's state folder writable.
profile() { # <role> <model> <effort> <full|sandboxed>
  p="$home/herdr-$1.config.toml"
  if [ -f "$p" ] && ! grep -qF "$mark" "$p"; then mv "$p" "$p.pre-herdr-kit"; echo "moved aside: $p.pre-herdr-kit"; fi
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
      printf "writable_roots = ['%s']\n" "$state"   # TOML literal string: no escapes
    fi
  } > "$p.tmp"
  mv "$p.tmp" "$p"
  echo "wrote: $p"
}

mkdir -p "$home"
profile writer-low  gpt-6-luna    medium full
profile writer      gpt-6.1-terra medium full
profile writer-high gpt-6.1-sol   high   full
profile writer-deep gpt-6-astra   high   full
profile reader      gpt-6-astra   medium sandboxed
profile reader-deep gpt-6-astra   high   sandboxed
profile critique    gpt-6-astra   high   sandboxed
profile design      gpt-6-astra   medium sandboxed
