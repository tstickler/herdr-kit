#!/bin/bash
input=$(cat)

RAW_MODEL=$(echo "$input" | jq -r '.model.display_name')

# Map long model IDs to friendly names
case "$RAW_MODEL" in
  *sonnet-4-5*|*claude-sonnet-4-5*) MODEL="Sonnet 4.5" ;;
  *opus-4-8*|*claude-opus-4-8*|*"Opus 4.8"*) MODEL="Opus 4.8" ;;
  *opus-4-6*|*claude-opus-4-6*)     MODEL="Opus 4.6" ;;
  *haiku-4-5*|*claude-haiku-4-5*)   MODEL="Haiku 4.5" ;;
  *)                                 MODEL="$RAW_MODEL" ;;
esac
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
# Rate-limit usage (absent for non-subscribers / before first API response)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
# Reset timestamps (Unix epoch seconds) for each rate-limit window
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' | cut -d. -f1)
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' | cut -d. -f1)
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'; DIM='\033[2m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '█')$(printf "%${EMPTY}s" | tr ' ' '░')

BRANCH=""
GIT_DIFF=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=" | $(git branch --show-current 2>/dev/null)"

  # Find merge base with main branch
  MERGE_BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null)

  if [ -n "$MERGE_BASE" ]; then
    # Get total diff stats since branch diverged from main
    DIFF_STAT=$(git -c core.fileMode=false diff --shortstat "$MERGE_BASE" 2>/dev/null)
    if [ -n "$DIFF_STAT" ]; then
      # Parse the diff output
      INSERTIONS=$(echo "$DIFF_STAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
      DELETIONS=$(echo "$DIFF_STAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')

      # Build git diff display
      GIT_DIFF=" ["
      [ -n "$INSERTIONS" ] && GIT_DIFF="${GIT_DIFF}${GREEN}+${INSERTIONS}${RESET} "
      [ -n "$DELETIONS" ] && GIT_DIFF="${GIT_DIFF}${RED}-${DELETIONS}${RESET} "
      GIT_DIFF="${GIT_DIFF%?}]"  # Remove trailing space
    fi
  fi

  # Upstream main ahead of local main (routines push tickets while you're away).
  # Fetch in the background at most every 5 minutes, so the line never waits on the network.
  # --no-write-fetch-head: never touch FETCH_HEAD, which a concurrent `git pull` reads.
  STAMP="$(git rev-parse --git-dir 2>/dev/null)/statusline-fetch"
  LAST=$(stat -f %m "$STAMP" 2>/dev/null || echo 0)
  if [ $(( $(date +%s) - LAST )) -gt 300 ]; then
    touch "$STAMP" 2>/dev/null
    (GIT_TERMINAL_PROMPT=0 git fetch -q --no-write-fetch-head origin main >/dev/null 2>&1 &)
  fi
  BEHIND=$(git rev-list --count main..origin/main 2>/dev/null)
  [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ] && GIT_DIFF="${GIT_DIFF} ${YELLOW}↓${BEHIND} pull main${RESET}"
fi

# Color a usage percentage by how close it is to the limit
usage_color() {
  if [ "$1" -ge 90 ]; then echo "$RED"
  elif [ "$1" -ge 70 ]; then echo "$YELLOW"
  else echo "$GREEN"; fi
}

# At/above this usage %, surface the window's reset countdown ("approaching")
RESET_AT_PCT=70

# Given a reset epoch (seconds), print a dim "↻2h13m" countdown until reset.
# Prints nothing if the epoch is missing; "↻now" if the window has already reset.
reset_hint() {
  [ -z "$1" ] && return
  local delta=$(( $1 - $(date +%s) ))
  [ "$delta" -le 0 ] && { printf '↻now'; return; }
  local d=$((delta / 86400)) h=$(((delta % 86400) / 3600)) m=$(((delta % 3600) / 60))
  if [ "$d" -gt 0 ]; then printf '↻%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '↻%dh%dm' "$h" "$m"
  else printf '↻%dm' "$m"; fi
}

# Visible width of a string: expand escapes, strip ANSI colors, count characters
vislen() { printf '%b' "$1" | sed $'s/\033\\[[0-9;]*m//g' | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }

# Right column: 5h on row 1, week on row 2, as three aligned columns:
# label, percentage (right-aligned, 4 wide), reset countdown (left-aligned, padded to the longer one)
T1=$(reset_hint "$FIVE_H_RESET"); T2=$(reset_hint "$WEEK_RESET")
TW=$(vislen "$T1"); TW2=$(vislen "$T2"); [ "$TW2" -gt "$TW" ] && TW=$TW2
usage_cell() {  # label, percentage (may be empty), reset text
  local color="" pct="--"
  [ -n "$2" ] && { color=$(usage_color "$2"); pct=$2; }
  printf '%s %s%4s%s %s%s%s%*s' "$1" "$color" "${pct}%" "$RESET" "$DIM" "$3" "$RESET" $(( TW - $(vislen "$3") )) ""
}
R1=$(usage_cell 5h "$FIVE_H" "$T1")
R2=$(usage_cell wk "$WEEK" "$T2")

L1="${CYAN}$MODEL${RESET} | ${BAR_COLOR}${BAR}${RESET} ${PCT}%"
L2="${DIR##*/}$BRANCH$GIT_DIFF"

# Terminal width: stdout is a pipe, so ask the controlling tty
COLS=$(stty size 2>/dev/null </dev/tty | cut -d' ' -f2)
COLS=${COLS:-${COLUMNS:-80}}
RIGHT_MARGIN=4  # Claude Code pads the status line; tune if the right edge wraps or sits short


row() {
  local pad=$(( COLS - RIGHT_MARGIN - $(vislen "$1") - $(vislen "$2") ))
  [ "$pad" -lt 1 ] && pad=1
  echo -e "$1$(printf "%${pad}s")$2"
}

row "$L1" "$R1"
row "$L2" "$R2"
