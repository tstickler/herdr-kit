# Critique

Get an independent critique of a plan.

1. Use the supplied plan path. If omitted, use the most recently modified plan in `docs/plans/`.
   Ask for a plan if there is none. Read it yourself so you can judge the critique.
2. Apply [the worker instructions](workers.md) with role `critique`. The resolver prefers the
   configured peer and falls back to the calling harness when needed. An explicit list runs every
   selected reviewer. All reviewers get the same plan independently.
3. Use Epic's slug if supplied, or derive a short kebab-case slug from the plan title. Start one
   worker per selected harness. Use a fresh directory from `mktemp -d /tmp/herdr-critique.XXXXXX`
   for the reports. Each brief contains only the absolute plan path and that worker's absolute
   report path. Start all reviewers before waiting on their terminal IDs.
4. Check each finding against the code. Merge duplicates, credit the reviewer or reviewers who
   found each issue, and explain dismissed findings. Report confirmed issues by severity and
   proposed edits, with links to the report files. Ask before editing the plan. If a requested review failed, identify it and
   preserve successful findings for a retry against the same plan revision.
