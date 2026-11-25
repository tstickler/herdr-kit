# Herdr app setup, sourced by the top-level installer: the Changes panel that follows worktrees
# (`changes-worktrees`) and a layout that shows it (`main-worktrees`, Herdr's `main` with that panel).
setup_herdr() (
  app="$HOME/.config/herdr-app"
  [ -d "$app" ] || { echo "skip: no Herdr app home at $app (open Herdr once, then rerun)"; return 0; }

  # Mods are copied, not linked: Herdr only reloads a mod when files change under its own
  # folder, so a linked mod keeps running old code. Rerun the installer after `git pull`.
  # A copy edited in place since the last install (its checksum isn't the one recorded) goes
  # to herdr-kit's backups first, not into mods/, where it would load as one more mod.
  backups="$HOME/.config/herdr-kit/backups" installed="$HOME/.config/herdr-kit/installed"
  # Checksum of a mod's files, leaving out what the Herdr app writes into them.
  sum() { (cd "$1" && find . -type f ! -name gpui-kit.d.ts ! -name jsconfig.json ! -name .DS_Store | LC_ALL=C sort | xargs cksum | cksum); }
  for m in "$K"/herdr/mods/*/; do
    m=${m%/}; name=$(basename "$m"); dest="$app/mods/$name"
    if [ -d "$dest" ] && [ ! -L "$dest" ] && [ "$(sum "$dest")" = "$(sum "$m")" ]; then
      mkdir -p "$installed"; sum "$dest" > "$installed/$name"; echo "ok: $dest"; continue
    fi
    if [ -L "$dest" ]; then
      rm "$dest"
    elif [ -d "$dest" ] && [ "$(sum "$dest")" = "$(cat "$installed/$name" 2>/dev/null)" ]; then
      rm -rf "$dest"
    elif [ -e "$dest" ]; then
      mkdir -p "$backups"
      mv "$dest" "$backups/$name.$(date +%Y%m%d%H%M%S)"
      echo "moved aside: $dest (to $backups)"
    fi
    mkdir -p "$dest"
    for f in "$m"/*; do case $(basename "$f") in gpui-kit.d.ts|jsconfig.json) ;; *) cp -R "$f" "$dest/" ;; esac; done
    mkdir -p "$installed"; sum "$dest" > "$installed/$name"
    echo "copied: $dest"
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
