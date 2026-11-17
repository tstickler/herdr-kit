# Shared Herdr workflows

This design covers Lead, Epic, and how Lead selects a writer and reviewer. Critique, Design, Spike, and Research keep their current entry points and worker templates while we decide how to handle each of them.

## What belongs where

| Layer | Owns |
| --- | --- |
| Shared Lead workflow | Task sizing, worker selection, worktrees, briefs, review, and merge approval |
| Shared Epic workflow | Spec, plan, plan critique, task breakdown, handoff, and acceptance checks |
| Claude and Codex entry points | Explicit skill invocation, argument delivery, and any harness-specific hooks |
| Project notes | Ticket format and location, repository layout, worktree conventions, and shared resources |
| Herdr templates and worker profiles | Launch commands, model IDs, reasoning effort, and permissions |

Keep one canonical Markdown body for each workflow under `workflows/`. The installed Claude and Codex skills should each point to that body through a reference shipped with the skill. The reference must work from a project outside the kit checkout. The current session supplies the lead or epic model, effort, and permissions. The workflows still use Herdr to launch and communicate with workers.

## Lead invocation and routing

Accept optional `writer=claude|codex` and `reader=claude|codex` arguments with the task or ticket. Defaults are `writer=claude` and `reader=codex` in either harness. The selection lasts for the run. Show the selected templates before launching them so the user can catch a routing mistake.

```text
/lead TICKET-123
$lead TICKET-123 writer=codex
$lead TICKET-123 writer=codex reader=claude
```

The first invocation uses a Claude writer and a Codex reader. The second uses Codex for both. The third uses a Codex writer and a Claude reader. A user reaching the Claude limit can switch the writer without changing the ticket or restarting the lead session.

### Task levels

New tickets carry a single `level:` field. Epic uses risk first and size second to set it.

| Level | Use for | Claude writer | Codex writer |
| --- | --- | --- | --- |
| `low` | A fully specified change with an exact file list, edit, and check | `writer-low` | `writer-low-codex` |
| `medium` | Routine changes across several files | `writer` | `writer-codex` |
| `high` | Larger changes or work in sensitive code that preserves its contract | `writer-high` | `writer-high-codex` |
| `deep` | Cross-module design changes or changes to the behavior of a sensitive flow | `writer-deep` | `writer-deep-codex` |

Use the selected provider’s `reader-deep` variant for `deep` tasks and its `reader` variant for the other levels. Workflows refer to template names. Profiles continue to supply the current models and effort.

### Existing tickets and unavailable workers

- If both fields exist, `level:` controls routing. If only a known `worker:` name exists, translate it to its level. For example, both `writer-high` and `writer-high-codex` mean `high`; the invocation supplies the provider.
- If an ad hoc request or ticket has no level, Lead chooses one and explains the choice. Ask about an invalid level or unknown legacy worker name before launching.
- Check the resolved writer and reader in `hc templates` before creating the task worktree. If a template is missing, name it and let the user pick an available route. If a worker reports a quota failure, surface it and let the user decide whether to retry with a different provider.
- Keep the existing worktree, trust prompt, diff review, and merge approval rules. A reviewer checks the diff regardless of whether it shares a provider with the writer.

## Epic handoff

Epic writes the task goal, scope, acceptance check, and level. It hands back the task sequence, which tasks can run in parallel, and paste-ready instructions for Lead. Any writer or reader choice the user has already made belongs in the Lead invocation. The ticket stays usable when that choice changes.

Keep plan critique in the shared sequence. For the first pass, let the Claude entry point use the existing Claude critique workflow and the Codex entry point use the existing `critique-codex` template. Both produce findings for the same plan approval step. This preserves the current ways into critique while its routing is still open.

## Helper workflows to revisit

| Helper | Current behavior | Open question |
| --- | --- | --- |
| Critique | Attacks a plan before implementation. Claude can run both critic templates. The Codex Epic draft uses one Codex critic. | Is one independent critic enough by default, and when should a caller request two? |
| Design | Runs three design lenses and compares the proposals. Claude uses a Codex designer for one when available. | Should provider diversity be the default, or should the caller choose the panel? |
| Spike | Runs competing prototypes in separate throwaway worktrees. | Should each approach use the same provider for comparison, with an option to vary it? |
| Research | Sends one background worker to investigate a codebase question. | Should callers choose a provider independently, or inherit a project or session default? |

Lead’s `reader=` parameter controls diff review. Leave how it relates to plan critique for the helper design discussion.

## Implementation and verification

1. Extract the common bodies from the Claude skills and Codex drafts. Keep each harness’s explicit invocation and adapt how it loads the shared text.
2. Add the Lead argument and template mapping and teach Epic to emit `level:`. Keep legacy ticket parsing in Lead and update the install and README for both entry points.
3. Verify both installed skills load the shared bodies from an unrelated project checkout. Exercise the default route, each provider override, a deep review, an old `worker:` ticket, and a missing template.
4. Run a small Epic-to-Lead handoff inside Herdr. Check that the task levels survive the handoff, the selected workers receive their briefs, and reviewed diffs are presented before merge approval.
