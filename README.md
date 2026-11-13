# herdr-kit

Generic Herdr agent setup: worker templates, `/lead`, `/epic`, helper commands, the tab-name hook.
Run `./install.sh` on each machine; it symlinks everything, so `git pull` is the update.

## Agents

| Template | Model | Role |
|---|---|---|
| `writer-low` | Haiku, medium | One fully specified change. Junior. |
| `writer` | Sonnet, medium | Straightforward multi-file change, nothing risky. Mid. |
| `writer-high` | Opus, high | Many files in one or two modules, sensitive code, reasonable unknowns. Senior. |
| `writer-deep` | Fable, high | Abstract cross-module work, or changing how a risky flow behaves. |
| `reader` | Fable, medium | Reviews `writer-low`, `writer`, `writer-high` diffs. |
| `reader-deep` | Fable, high | Reviews `writer-deep` diffs. |
| `critique` | Fable, high | Attacks a plan (`/critique`). |
| `design` | Fable, medium | One design proposal per lens (`/design`). |
| `research` | Sonnet, medium | Answers a codebase question (`/research`). |
| `spike` | Sonnet, medium | Throwaway prototype in a worktree (`/spike`). |

Pick by risk first, size second.

## Project notes

Every agent first runs `herdr-notes <role>`, which prints the nearest `.claude/herdr/<role>.md` above its
folder. Roles: `lead`, `epic`, `writer` (all four writers), `reader` (both readers), `critique`, `design`,
`research`, `spike`. A missing file means the generic behavior. Notes hold project detail only; safety rules
stay in the templates. `overlays/jira/` holds lead and epic notes for a Jira project: copy them into its
`.claude/herdr/`.
