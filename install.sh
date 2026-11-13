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

for f in "$K"/templates/*.md; do link "$f" "$HOME/.config/herdr-core/templates/$(basename "$f")"; done
for f in "$K"/commands/*.md; do link "$f" "$HOME/.claude/commands/$(basename "$f")"; done
link "$K/skills/lead" "$HOME/.claude/skills/lead"
link "$K/skills/epic" "$HOME/.claude/skills/epic"
link "$K/hooks/herdr-tab-name.sh" "$HOME/.claude/hooks/herdr-tab-name.sh"
link "$K/statusline.sh" "$HOME/.claude/statusline.sh"
link "$K/bin/herdr-notes" "$HOME/.local/bin/herdr-notes"

s="$HOME/.claude/settings.json"
[ -f "$s" ] || echo '{}' > "$s"
if grep -q herdr-tab-name "$s"; then
  echo "ok: hooks already in $s"
else
  cp "$s" "$s.pre-herdr-kit"
  jq '.hooks.Stop += [{hooks:[{type:"command",command:"~/.claude/hooks/herdr-tab-name.sh"}]}]
    | .hooks.SessionStart += [{matcher:"clear",hooks:[{type:"command",command:"~/.claude/hooks/herdr-tab-name.sh clear"}]}]
    | .statusLine //= {type:"command",command:"~/.claude/statusline.sh"}' "$s.pre-herdr-kit" > "$s.tmp"
  mv "$s.tmp" "$s"
  echo "ok: hooks added to $s (backup: $s.pre-herdr-kit)"
fi

# Your Herdr look. Anything already set on this machine wins.
h="$HOME/.config/herdr-app/settings.json"
mkdir -p "$(dirname "$h")"
[ -f "$h" ] || echo '{}' > "$h"
jq -s '.[0] * .[1]' "$K/herdr-settings.json" "$h" > "$h.tmp" && mv "$h.tmp" "$h"
echo "ok: $h"

echo "Done. Project notes go in <project>/.claude/herdr/<role>.md; see README.md."
