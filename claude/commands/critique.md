---
description: Have a fresh helper agent attack a plan before implementation starts
argument-hint: [path to plan — defaults to the newest file in docs/plans/]
---
Get an independent critique of a plan.

If `hc` is not on the PATH, or `$HC_TERMINAL_ID` is empty, say this needs to run inside Herdr and stop.

1. Plan: $ARGUMENTS. If blank, use the most recently modified plan in `docs/plans/`, and ask if there is none. Read it yourself so you can judge the critique.
2. Use the calling Epic's slug, or derive a short kebab-case slug from the plan title. Name the critics
   `<slug>-critic-claude` and `<slug>-critic-codex`. Keep the prefix at 18 characters or fewer. If a name
   is already in use or its report already exists, add a run number before `-critic-` and shorten the
   slug as needed. Give each critic a brief file containing only the absolute plan path and its own
   output path, `<plan dir>/<critic-name>.md`.
3. Launch `hc run --json --bg --name <claude-name> --cwd <repo> critique "$(cat <claude brief file>)"`.
   If `hc templates` lists `critique-codex`, also launch
   `hc run --json --bg --name <codex-name> --cwd <repo> critique-codex "$(cat <codex brief file>)"`. Start both
   before waiting. Record the terminal ID from each successful launch and use it in later commands.
   If `first_message.sent` is false, inspect that terminal with `hc read` before sending anything.
4. Wait for each of those terminals with `hc wait <terminal-id>` until it reports. Never sleep or poll.
5. Check each finding against the code yourself. Drop false positives and say why. With two critics, merge duplicates and mark the issues both found.
6. Report: confirmed issues, most severe first (with two critics, say which found each); what you would change in the plan; what you dismissed. Ask before editing the plan.
7. Run `hc kill <terminal-id>` and `hc rm <terminal-id>` for each critic you started.
