---
name: epic
description: Take a feature through spec, plan critique, task breakdown, Lead handoff, and acceptance checks.
---

# $epic

Read and follow `references/epic.md`, relative to this skill file. Use `$lead` in the handoff.

## Plan critique

Run this step inside Herdr with `hc` available and `$HC_TERMINAL_ID` set. If either is missing, ask the
user to resume inside Herdr before continuing with the review.

1. Check that `hc templates` lists `critique-codex`. If it is missing, report the blocker. Write a brief
   file with the absolute plan path and output path (`<plan dir>/critique.md`).
2. Launch `hc run --bg --name epic-critic --cwd <repo> critique-codex "$(cat <brief file>)"`.
   If `first_message.sent` is false, inspect `hc read epic-critic`. If Codex is waiting for workspace
   trust, ask the user to accept it. Once the terminal is ready, send the installed template body
   from `~/.config/herdr-core/templates/critique-codex.md` followed by the brief.
3. Wait with `hc wait epic-critic` for its report. Check findings against the code and present the
   confirmed issues and proposed edits. If the worker is blocked, surface the blocker. Once you have
   read its report, close the critic with `hc kill epic-critic` and `hc rm epic-critic`.
