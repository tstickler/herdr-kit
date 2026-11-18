#!/bin/sh
# Links this kit into place, so a `git pull` here updates every machine. Safe to re-run.
# A real file already in the way is moved aside to <file>.pre-herdr-kit, never deleted.
set -eu
K=$(cd "$(dirname "$0")" && pwd -P)

command -v jq >/dev/null || { echo "Install jq first: brew install jq"; exit 1; }
command -v hc >/dev/null || echo "Warning: hc is not on PATH. Add ~/.local/bin to PATH in ~/.zshrc."

link() {
  mkdir -p "$(dirname "$2")"
  if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then echo "ok: $2"; return; fi
  if [ -e "$2" ] || [ -L "$2" ]; then mv "$2" "$2.pre-herdr-kit"; echo "moved aside: $2.pre-herdr-kit"; fi
  ln -s "$1" "$2"; echo "linked: $2"
}

for f in "$K"/claude/templates/*.md; do link "$f" "$HOME/.config/herdr-core/templates/$(basename "$f")"; done
link "$K/shared/commands" "$HOME/.config/herdr-kit/commands"
link "$K/harnesses.json" "$HOME/.config/herdr-kit/harnesses.json"
claude_entries="$HOME/.config/herdr-kit/claude-entrypoints/.claude"
link "$K/claude/commands" "$claude_entries/commands"
link "$K/claude/skills" "$claude_entries/skills"
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
link "$K/shared/bin/herdr-notes" "$HOME/.local/bin/herdr-notes"
link "$K/shared/bin/herdr-resolve-workers" "$HOME/.local/bin/herdr-resolve-workers"

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

# Your Herdr look. Anything already set on this machine wins.
h="$HOME/.config/herdr-app/settings.json"
mkdir -p "$(dirname "$h")"
[ -f "$h" ] || echo '{}' > "$h"
jq -s '.[0] * .[1]' "$K/shared/herdr-settings.json" "$h" > "$h.tmp" && mv "$h.tmp" "$h"
echo "ok: $h"

# Codex workers, only on machines with codex installed.
"$K/codex/install.sh"

# Keep the usual agent names in Herdr's app menu and honor customized launches.
claude_launcher=
codex_launcher=
if command -v claude >/dev/null 2>&1; then claude_launcher="$HOME/.local/bin/herdr-claude"; fi
if command -v codex >/dev/null 2>&1; then codex_launcher="$HOME/.local/bin/herdr-codex"; fi
if [ -n "$claude_launcher$codex_launcher" ]; then
  programs="$HOME/.config/herdr-app/programs.json"
  [ -f "$programs" ] || echo '{}' > "$programs"
  jq --arg claude "$claude_launcher" --arg codex "$codex_launcher" '
    (if $claude != "" then .programs.claude.run //= [$claude] else . end)
    | (if $codex != "" then .programs.codex.run //= [$codex] else . end)
  ' "$programs" > "$programs.tmp"
  mv "$programs.tmp" "$programs"
fi

# Use the same names when typing into Herdr's interactive shells.
link "$K/shell-launchers.sh" "$HOME/.config/herdr-kit/shell-launchers.sh"
configure_shell() {
  if [ -f "$1" ] && grep -qF '# Herdr Kit launchers' "$1"; then return; fi
  mkdir -p "$(dirname "$1")"
  cat >> "$1" <<'EOF'

# Herdr Kit launchers
if [ -n "${BASH_VERSION:-}${ZSH_VERSION:-}" ] && [ -n "${HC_TERMINAL_ID:-}" ] &&
    [ -r "$HOME/.config/herdr-kit/shell-launchers.sh" ]; then
  . "$HOME/.config/herdr-kit/shell-launchers.sh"
fi
EOF
  echo "ok: $1"
}
login_shell=${SHELL:-}
case ${login_shell##*/} in
  zsh) configure_shell "${ZDOTDIR:-$HOME}/.zshrc" ;;
  bash)
    configure_shell "$HOME/.bashrc"
    login_profile="$HOME/.bash_profile"
    if [ ! -e "$login_profile" ]; then
      if [ -e "$HOME/.bash_login" ]; then login_profile="$HOME/.bash_login"
      elif [ -e "$HOME/.profile" ]; then login_profile="$HOME/.profile"
      fi
    fi
    configure_shell "$login_profile"
    ;;
esac

echo "Done. Project notes go in <project>/.claude/herdr/<role>.md; see README.md."
