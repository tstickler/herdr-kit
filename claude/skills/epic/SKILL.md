---
name: epic
description: Take a feature through spec, plan critique, task breakdown, Lead handoff, and acceptance checks.
argument-hint: "<feature or ticket> [harness=claude|codex|antigravity|<comma list>]"
disable-model-invocation: true
---

# /epic

Read and follow `references/epic.md`, relative to this skill file. Use `/lead` in the handoff.
Take an optional trailing `harness=` selection from the Epic invocation for plan critique.

At plan review, follow `~/.config/herdr-kit/commands/critique.md` with `claude` as the calling harness,
the absolute plan path, the feature slug, and the optional harness selection.
