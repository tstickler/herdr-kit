# herdr-kit

A Claude Code + Herdr setup where a lead agent breaks work into tasks and hands each one to a worker on the right
model for the job. A reviewer checks every diff, and nothing merges without your yes. This repo holds everything
generic. Each project adds short notes for the roles that need project detail.

## Writers: four tiers, staffed like a team

| Template | Model | Level | Use for |
|---|---|---|---|
| `writer-low` | Haiku, medium | Junior | One fully specified change: exact files, exact change, exact check. |
| `writer` | Sonnet, medium | Mid | A straightforward change across several files, nothing risky. The default. |
| `writer-high` | Opus, high | Senior | Many files in one or two modules, edits inside sensitive code, unknowns that can be reasoned through. |
| `writer-deep` | Fable, high | | Abstract work across modules, or changing how a sensitive flow behaves. |

**Pick by risk first, size second. When they disagree, risk wins.**

Sensitive by default: money and purchases, auth and account merges, migrations that change data, public or
shipped API contracts, and anything that can lose user data. A change to how one of these *behaves* goes to
`writer-deep`. An edit inside one that keeps its contract goes to `writer-high`. If a task can't be written
precisely enough for `writer-low`, it isn't a `writer-low` task.

## Reviewers and helpers

| Template | Model | Job |
|---|---|---|
| `reader` | Fable, medium | Reviews diffs from `writer-low`, `writer` and `writer-high`. Read-only, except for one findings file. |
| `reader-deep` | Fable, high | Reviews `writer-deep` diffs. |
| `critique` | Fable, high | Attacks a plan before it's built. Launched by `/critique`. |
| `design` | Fable, medium | Proposes one design through a given lens. `/design` runs three and compares them. |
| `research` | Sonnet, medium | Answers a codebase question with path:line evidence, in the background. `/research`. |
| `spike` | Sonnet, medium | Throwaway prototype in its own worktree. `/spike` runs one per approach. |

## Codex workers (optional)

On a machine with `codex` on PATH, `install.sh` adds a Codex twin for each writer and reader. Without Codex they
are skipped and nothing else changes.

| Template | Codex model | Claude twin |
|---|---|---|
| `writer-low-codex` | Luna, medium | `writer-low` |
| `writer-codex` | Terra, medium | `writer` |
| `writer-high-codex` | Sol, high | `writer-high` |
| `writer-deep-codex` | Astra, high | `writer-deep` |
| `reader-codex` | Astra, medium | `reader` |
| `reader-deep-codex` | Astra, high | `reader-deep` |

The bodies match their twins; only the launch differs. Each template runs `codex --no-daemon -p herdr-<role>`,
and the install writes those profiles to `~/.codex/herdr-<role>.config.toml` with the model, effort, sandbox,
and `CLAUDE.md` as a fallback for `AGENTS.md`. `/lead` stays a Claude session. It uses Claude writers by default
and, when both families are installed, sends each diff to the other family's reader.

Sandboxes: Codex readers run sandboxed with network on (`hc send` needs its socket). Codex writers run with no
sandbox, because Xcode's package resolution starts its own `sandbox-exec`, which macOS refuses inside Codex's.
Their template rules are what hold them, as with the Claude writers.

Machine-specific settings go in `~/.config/herdr-kit/local.env`, never in this repo. For example, when Codex goes
through a proxy that prefixes model ids:

```sh
CODEX_MODEL_PREFIX=global.openai.
```

## From ticket to merge

1. **`/epic`** writes the spec, then a plan that `/critique` attacks. It cuts the plan into tasks with one repo, one writer and an exact file list each. Every task gets a `worker:` line.
2. **`/lead`** plans and delegates, and never writes code. It starts each task's writer in its own git worktree.
3. **The writer** makes the change, runs the tests, and reports back with `hc send`.
4. **The reviewer** checks the diff for real bugs and for the repo's own rules.
5. **You** get one summary of the diff and its review from `/lead`. Nothing merges without your yes.
6. **`/epic` again** checks every acceptance criterion and shows a pass or fail table.

## Project notes

Every agent first runs `herdr-notes <role>`. It prints the nearest `.claude/herdr/<role>.md` above the agent's
folder: where tickets live, the repos, worktree location, risky areas, and anything that can't run side by side.
A missing file means generic behavior. Safety rules stay in the templates, so an agent that skips its notes is
still safe.

Roles that read notes: `lead`, `epic`, `writer` (all four tiers), `reader` (both), `critique`, `design`,
`research`, `spike`. Most projects only need `lead` (where tickets live and how their status moves, the repos,
what can't run side by side) and `epic` (the ticket format and any extra steps). Notes belong to the project,
never to this kit.

To keep your notes out of a shared repo, put the folder above it. The lookup searches upward, so it covers the
repo and every worktree beside it, and coworkers never see it:

```
~/Documents/GitHub/
  .claude/herdr/lead.md, epic.md     your notes, in no repo
  herdr-kit/
  <monorepo>/<app>/                  finds them two levels up
  <monorepo>-<task>/<app>/           /lead's worktrees find them too
```

## Install

1. Install Herdr and `jq`, and make sure `~/.local/bin` is on your PATH.
2. `git clone https://github.com/tstickler/herdr-kit`
3. Run `herdr-kit/install.sh`. It symlinks the templates, skills, commands and hook into place. A file already in the way is moved aside to `*.pre-herdr-kit`, never deleted.
4. Write your project's notes: `mkdir -p <parent>/.claude/herdr`, then add `lead.md` and `epic.md` there.
5. Check from your app folder: `herdr-notes lead | head -1` should name your notes file.
6. Open a Herdr tab in the repo, run `claude`, then `/lead`.

To update, run `git pull` in `herdr-kit`. The links pick up the change.

## What's in here

```
templates/        the 10 agents          → ~/.config/herdr-core/templates/
codex/            Codex twins + their profiles, only when codex is installed
skills/           /lead, /epic           → ~/.claude/skills/
commands/         /critique /design /research /spike → ~/.claude/commands/
bin/herdr-notes                          → ~/.local/bin/
hooks/            names each Herdr tab after the Claude session
statusline.sh
install.sh
```

Every template sets its own model and effort. If a tier's diffs keep coming back from review, move that kind of
task up a tier. Don't raise the effort instead.
