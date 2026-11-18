# Internal Claude setup, sourced by the top-level installer.
setup_claude() (
  for f in "$K"/claude/templates/*.md; do link "$f" "$HOME/.config/herdr-core/templates/$(basename "$f")"; done
  for f in "$K"/claude/commands/*.md; do link "$f" "$HOME/.claude/commands/$(basename "$f")"; done
  link "$K/claude/skills/lead" "$HOME/.claude/skills/lead"
  link "$K/claude/skills/epic" "$HOME/.claude/skills/epic"
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
)
