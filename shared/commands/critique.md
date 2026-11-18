# Critique

Get an independent critique of a plan.

If `hc` is not on the PATH, or `$HC_TERMINAL_ID` is empty, say this needs to run inside Herdr and stop.

1. Use the supplied plan path. If no path was supplied, use the most recently modified plan in `docs/plans/`.
   Ask for a plan if there is none. Read it yourself so you can judge the critique.
2. Use the primary template, label, and report directory supplied by the entry point. If the entry
   point supplies a second critic, include it when `hc templates` lists its template. Use the calling
   Epic's slug, or derive a short kebab-case slug from the plan title. Name each critic `<slug>-critic-<label>`.
   Keep the prefix before `-critic-` at 18 characters or fewer. If a name is in use or a report already
   exists at its output path, add a run number before `-critic-` and shorten the slug as needed. Give
   each critic a brief file containing only the absolute plan and report paths. Write each report to
   `<report directory>/<critic name>.md` and keep the paths to read after the critics reply.
3. Start each critic before waiting with
   `hc run --json --bg --name <critic name> --cwd <repo> <template> "$(cat <brief file>)"`.
   Record the terminal ID from each successful launch and use it in later commands. If
   `first_message.sent` is false, inspect that terminal with `hc read` before sending anything.
4. Wait for each of those terminals with `hc wait <terminal-id>` until it reports. Never sleep or poll.
5. Check each finding against the code yourself. Drop false positives and say why. With two critics, merge duplicates and mark the issues both found.
6. Report: confirmed issues, most severe first (with two critics, say which found each); what you would change in the plan; what you dismissed. Ask before editing the plan.
7. Run `hc kill <terminal-id>` and `hc rm <terminal-id>` for each critic you started.
