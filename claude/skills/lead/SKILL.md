---
name: lead
description: Plan and delegate tasks in Herdr, select writers and reviewers, and present reviewed diffs for approval.
argument-hint: "<task or ticket> [writer=claude|codex] [reader=claude|codex]"
disable-model-invocation: true
---

# /lead

Read and follow `references/lead.md`, relative to this skill file. Start with the arguments supplied
to `/lead` in the user's message.

If the tab-naming hook is installed, name the tab for the current task with
`~/.claude/hooks/herdr-tab-name.sh set "<short task name>"`.
