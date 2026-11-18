#!/bin/sh
# Names this Herdr tab after Claude Code's session title, and keeps it current while the tab still
# shows the name this hook set (remembered in the terminal's `autotab` label). A name set by hand
# (F2) is never touched. `clear` (SessionStart on /clear) puts the tab's number back.
# `set "<name>"` is for an agent naming its own tab when the title no longer fits (e.g. /lead).
[ -n "$HC_TERMINAL_ID" ] || exit 0          # not running in Herdr
info=$(hc get "$HC_TERMINAL_ID" 2>/dev/null) || exit 0
get() { printf %s "$info" | jq -r "$1 // empty"; }
tab=$(get '.labels["herdr.tab"]'); title=$(get .title)
mine=$(get .labels.autotab); stale=$(get .labels.autotab_stale)
[ -n "$tab" ] || exit 0
name=$(herdr-app ls 2>/dev/null | jq -r --arg t "$tab" '.spaces[].tabs[] | select(.id==$t) | .name')
[ -n "$name" ] || exit 0
case "$name" in *[!0-9]*) [ "$name" = "$mine" ] || exit 0;; esac   # named by hand
rename() { herdr-app do tab.rename "$(jq -nc --arg id "$tab" --arg n "$1" '{id:$id,name:$n}')" >/dev/null 2>&1; }
if [ "$1" = set ]; then
  # An agent naming its own tab: the hook owns the name (so /clear frees it), and the session
  # title at this moment counts as stale, so the next reply doesn't put it back.
  [ -n "$2" ] && rename "$2" && hc label "$HC_TERMINAL_ID" "autotab=$2" "autotab_stale=$title" >/dev/null 2>&1
  exit 0
fi
if [ "$1" = clear ]; then
  # Until Claude Code retitles the new session, the old title is stale: don't put it back.
  rename "" && hc label "$HC_TERMINAL_ID" autotab= "autotab_stale=$title" >/dev/null 2>&1
  exit 0
fi
[ -n "$title" ] && [ "$title" != "$name" ] && [ "$title" != "$stale" ] || exit 0
rename "$title" && hc label "$HC_TERMINAL_ID" "autotab=$title" autotab_stale= >/dev/null 2>&1
exit 0
