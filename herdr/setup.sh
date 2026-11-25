# Herdr app setup, sourced by the top-level installer: the Changes panel that follows worktrees
# (`changes-worktrees`) and a layout that shows it (`main-worktrees`, Herdr's `main` with that panel).
setup_herdr() (
  app="$HOME/.config/herdr-app"
  [ -d "$app" ] || { echo "skip: no Herdr app home at $app (open Herdr once, then rerun)"; return 0; }

  # Mods are linked, so `git pull` updates them. Not link(): a folder moved aside inside mods/
  # would load as one more mod, so anything in the way goes to herdr-kit's backups instead.
  backups="$HOME/.config/herdr-kit/backups"
  for m in "$K"/herdr/mods/*/; do
    m=${m%/}; dest="$app/mods/$(basename "$m")"
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$m" ]; then echo "ok: $dest"; continue; fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      mkdir -p "$backups"
      mv "$dest" "$backups/$(basename "$m").$(date +%Y%m%d%H%M%S)"
      echo "moved aside: $dest (to $backups)"
    fi
    mkdir -p "$app/mods"
    ln -s "$m" "$dest"; echo "linked: $dest"
  done

  # Layouts are copied once and then yours: Herdr writes theme picks into the shown layout's file.
  for l in "$K"/herdr/layouts/*.json; do
    dest="$app/layouts/$(basename "$l")"
    if [ -e "$dest" ]; then echo "ok: $dest (kept)"; continue; fi
    mkdir -p "$app/layouts"
    cp "$l" "$dest"; echo "copied: $dest"
  done
  echo "To use the worktree-aware Changes panel, switch Herdr to the main-worktrees layout (ctrl-shift-l)."
)
