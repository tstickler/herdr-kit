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
`research`, `spike`. Most projects only need `lead` and `epic`. `overlays/jira/` has starter notes for a Jira
project.

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
4. For a Jira project, copy the starter notes: `mkdir -p <parent>/.claude/herdr && cp herdr-kit/overlays/jira/*.md <parent>/.claude/herdr/`
5. Check from your app folder: `herdr-notes lead | head -1` should name your notes file.
6. Open a Herdr tab in the repo, run `claude`, then `/lead`.

To update, run `git pull` in `herdr-kit`. The links pick up the change.

## What's in here

```
templates/        the 10 agents          → ~/.config/herdr-core/templates/
skills/           /lead, /epic           → ~/.claude/skills/
commands/         /critique /design /research /spike → ~/.claude/commands/
bin/herdr-notes                          → ~/.local/bin/
hooks/            names each Herdr tab after the Claude session
statusline.sh
overlays/jira/    starter project notes for a Jira project
install.sh
```

Every template sets its own model and effort. If a tier's diffs keep coming back from review, move that kind of
task up a tier. Don't raise the effort instead.
