# Herdr workers for helper commands

Run inside Herdr with `hc` on PATH and `HC_TERMINAL_ID` set. If either is missing, ask the user to
resume inside Herdr. Extract the optional trailing
`harness=<name>[,<name>...]` argument from the command input. From the target repository run
`herdr-resolve-workers <role> <calling-harness>`, adding the comma-separated value as a third shell
argument only if the option was supplied. The entry point supplies the calling harness. Use the
returned tab-separated harness and template pairs. On a resolver error, report it before creating
worktrees or launching workers. Tell the user which harnesses and templates were selected.

Start each job with `hc run --json --bg --name <name> --cwd <directory> <template> "$(cat <brief file>)"`.
Use unique names of at most 32 characters and fresh output paths so reports from earlier runs
cannot count as results. Record each successful terminal ID and its expected report. If
`first_message.sent` is false, inspect `hc read <terminal-id>`. If there is a trust prompt, let the
user handle it. Once ready, send the body of the installed template from
`~/.config/herdr-core/templates/<template>.md` followed by the brief in one `hc send`.

Wait with `hc wait <terminal-id>` on the workers from this run, using the individual command's
timing. If a wait checks in before a result, continue waiting for that worker while it is still
working. Treat launch errors, reported blockers, and terminal completion without a report as
failed jobs. Keep completed reports and identify failures by harness and job. Let the user
choose whether to retry the failed jobs or switch harnesses. Use `hc kill` and `hc rm` on the recorded terminal
IDs when finished with them.
