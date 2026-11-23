# Internal Antigravity setup, sourced by the top-level installer.
setup_antigravity() (
  command -v agy >/dev/null || { echo "skip: agy is not on PATH, no Antigravity workers"; exit 0; }
  for f in "$K"/antigravity/templates/*.md; do link "$f" "$HOME/.config/herdr-core/templates/$(basename "$f")"; done
)
