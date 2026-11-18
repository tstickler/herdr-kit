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

link "$K/shared/commands" "$HOME/.config/herdr-kit/commands"
link "$K/shared/bin/herdr-notes" "$HOME/.local/bin/herdr-notes"

# Your Herdr look. Anything already set on this machine wins.
h="$HOME/.config/herdr-app/settings.json"
mkdir -p "$(dirname "$h")"
[ -f "$h" ] || echo '{}' > "$h"
jq -s '.[0] * .[1]' "$K/shared/herdr-settings.json" "$h" > "$h.tmp" && mv "$h.tmp" "$h"
echo "ok: $h"

. "$K/claude/setup.sh"
. "$K/codex/setup.sh"
setup_claude
setup_codex

echo "Done. Project notes go in <project>/.claude/herdr/<role>.md; see README.md."
