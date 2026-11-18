---
name: epic
description: Take a feature through spec, plan critique, task breakdown, Lead handoff, and acceptance checks.
---

# $epic

Read and follow `references/epic.md`, relative to this skill file. Use `$lead` in the handoff.

## Plan critique

Run this step inside Herdr with `hc` available and `$HC_TERMINAL_ID` set. If either is missing, ask the
user to resume inside Herdr before continuing with the review.

1. Check that `hc templates` lists `critique-codex`. If it is missing, report the blocker. Name the
   terminal `<slug>-critic-codex` using the feature slug. Keep the prefix at 18 characters or fewer.
   If the name is in use or its report already exists, add a run number before `-critic-` and shorten
   the slug as needed. Write a brief with the absolute plan path and the output path
   `<plan dir>/<critic-name>.md`.
2. Launch `hc run --json --bg --name <critic-name> --cwd <repo> critique-codex "$(cat <brief file>)"`.
   Record the terminal ID from the successful launch. If `first_message.sent` is false, inspect
   `hc read <terminal-id>`. If Codex is waiting for workspace
   trust, ask the user to accept it. Once the terminal is ready, send the installed template body
   from `~/.config/herdr-core/templates/critique-codex.md` followed by the brief.
3. Wait with `hc wait <terminal-id>` for its report. Check findings against the code and present the
   confirmed issues and proposed edits. If the worker is blocked, surface the blocker. Once you have
   read its report, close the critic with `hc kill <terminal-id>` and `hc rm <terminal-id>`.
