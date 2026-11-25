#!/bin/sh
# Tells Herdr where this Claude Code session works, for the Changes panel. Claude Code's own
# process folder never moves, so Herdr alone only ever sees the folder the session started in.
#   workdir    the session's current folder (after `cd`, or entering a worktree)
#   worktrees  linked git worktrees the session has edited files in or worked from, most recent
#              first, separated by ":". They stay after the shell goes back to the main checkout:
#              a session often edits a worktree by absolute path from main.
[ -n "$HC_TERMINAL_ID" ] || exit 0          # not running in Herdr
input=$(cat)
cwd=$(printf %s "$input" | jq -r '.cwd // empty' 2>/dev/null)
file=$(printf %s "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
labels=$(hc get "$HC_TERMINAL_ID" 2>/dev/null | jq -r '.labels') || exit 0
old_workdir=$(printf %s "$labels" | jq -r '.workdir // empty')
old_worktrees=$(printf %s "$labels" | jq -r '.worktrees // empty')

# The root of the linked worktree holding $1 (a folder), or nothing for a main checkout.
linked() {
  [ -d "$1" ] || return 0
  dir=$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null) || return 0
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  [ "$dir" = "$common" ] || git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

worktrees=$old_worktrees
for top in "$(linked "$cwd")" "$([ -n "$file" ] && linked "$(dirname "$file")")"; do
  [ -n "$top" ] || continue
  rest=$(printf %s "$worktrees" | tr ':' '\n' | grep -vxF "$top" | head -n 4 | paste -sd: -)
  worktrees=$top${rest:+:$rest}
done
# Forget worktrees that have been removed.
worktrees=$(printf '%s\n' "$worktrees" | tr ':' '\n' | while read -r w; do [ -d "$w" ] && echo "$w"; done | paste -sd: -)

# Labels re-render every panel: only write what changed.
set --
[ -n "$cwd" ] && [ "$cwd" != "$old_workdir" ] && set -- "$@" "workdir=$cwd"
[ "$worktrees" != "$old_worktrees" ] && set -- "$@" "worktrees=$worktrees"
[ $# -gt 0 ] && hc label "$HC_TERMINAL_ID" "$@" >/dev/null 2>&1
exit 0
