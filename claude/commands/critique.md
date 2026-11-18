---
description: Have a fresh helper agent attack a plan before implementation starts
argument-hint: [path to plan — defaults to the newest file in docs/plans/]
---

Read and follow `~/.config/herdr-kit/commands/critique.md`. Use `critique` as the primary
template with the label `claude` and write its report next to the plan. Use `critique-codex`
as the optional second template with the label `codex`. Give it a fresh report directory
created with `mktemp -d /tmp/herdr-critique.XXXXXX` so the worker can write there.

Plan path (optional):

$ARGUMENTS
