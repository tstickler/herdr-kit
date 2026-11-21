#!/bin/sh
# PostToolUse hook for Claude Code and Codex: a Herdr worker whose context grows past
# HERDR_HANDOFF_SOFT tokens is asked once to hand off at its next stopping point; past
# HERDR_HANDOFF_HARD it is told once to hand off now. When the session records its window (Codex
# does), the limits are capped at 60% and 80% of it. The worker writes a handoff file and sends
# "HANDOFF <path>" to the terminal that started it; the lead then starts a fresh worker from the
# same brief plus the handoff. Only terminals with a parent (workers) are affected.
[ -n "$HC_TERMINAL_ID" ] || exit 0
soft=${HERDR_HANDOFF_SOFT:-250000}
hard=${HERDR_HANDOFF_HARD:-350000}
input=$(cat)
transcript=$(printf %s "$input" | jq -r '.transcript_path // empty')
session=$(printf %s "$input" | jq -r '.session_id // empty')
[ -f "$transcript" ] && [ -n "$session" ] || exit 0

# "<context tokens> <window or 0>" from the last usage record: Codex logs token_count events
# (input_tokens includes cached); Claude logs usage on each main-thread reply. Neither has it on
# disk during a session's first turn, so the check starts from the second turn.
read -r tokens window <<EOF
$(tail -n 200 "$transcript" | jq -r '
  if .type=="event_msg" and .payload.type=="token_count" and .payload.info != null then
    "\(.payload.info.last_token_usage.input_tokens // 0) \(.payload.info.model_context_window // 0)"
  elif .type=="assistant" and .isSidechain != true and .message.usage != null then
    .message.usage | "\((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)) 0"
  else empty end' 2>/dev/null | tail -n 1)
EOF
[ -n "$tokens" ] || exit 0
if [ "${window:-0}" -gt 0 ]; then
  [ $((window * 60 / 100)) -lt "$soft" ] && soft=$((window * 60 / 100))
  [ $((window * 80 / 100)) -lt "$hard" ] && hard=$((window * 80 / 100))
fi
[ "$tokens" -ge "$soft" ] || exit 0

lead=$(hc get "$HC_TERMINAL_ID" 2>/dev/null | jq -r '.parent // empty')
[ -n "$lead" ] || exit 0

state="$HOME/.local/state/herdr-kit/handoff"
mkdir -p "$state"
file="$state/$HC_TERMINAL_ID-$session.md"
if [ "$tokens" -ge "$hard" ]; then
  [ -e "$state/$session.hard" ] && exit 0
  : > "$state/$session.hard"; : > "$state/$session.soft"
  when="Stop what you are doing and hand off now, before any other step."
else
  [ -e "$state/$session.soft" ] && exit 0
  : > "$state/$session.soft"
  when="Keep working until your next stopping point (a step finished and its tests green, or you are about to wait on the lead), then hand off. Do not start a new step first."
fi

msg="Context handoff: this session is at $tokens tokens (soft limit $soft, hard limit $hard). $when
To hand off, write $file with: what is done; what is left, in order; the state of the worktree (uncommitted files, whether the build and tests pass); decisions made and why; gotchas and dead ends; the exact files and line ranges the next worker should read first. Do not repeat the brief or paste code: the next worker gets the brief and the worktree as you leave them.
Then run: hc send $lead \"HANDOFF $file\"
Then stop and wait. The lead ends this session and starts a fresh worker from your handoff."
jq -nc --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}'
