---
name: epic
description: Take a feature through spec, plan critique, task breakdown, Lead handoff, and acceptance checks.
argument-hint: "<feature or ticket>"
disable-model-invocation: true
---

# /epic

Read and follow `references/epic.md`, relative to this skill file. Use `/lead` in the handoff.

For plan critique, follow the installed `~/.claude/commands/critique.md` with the absolute plan path
as its argument and the feature slug as context. If critique cannot run, surface the blocker before
creating tasks.
