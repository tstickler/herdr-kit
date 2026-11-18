# herdr-kit

A Herdr setup for Claude Code and Codex where a lead agent breaks work into tasks and hands each one to a worker on the right
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

On a machine with `codex` on PATH, `install.sh` adds Codex writers, readers, a critic, and a designer.

| Template | Codex model |
|---|---|
| `writer-low-codex` | Luna, medium |
| `writer-codex` | Terra, medium |
| `writer-high-codex` | Sol, high |
| `writer-deep-codex` | Astra, high |
| `reader-codex` | Astra, medium |
| `reader-deep-codex` | Astra, high |
| `critique-codex` | Astra, high |
| `design-codex` | Astra, medium |

Each template runs `codex --no-daemon -p herdr-<role>`,
and the install writes those profiles to `~/.codex/herdr-<role>.config.toml` with the model, effort, sandbox,
and `CLAUDE.md` as a fallback for `AGENTS.md`. When the Codex templates are installed, `/critique`
runs both critics side by side and `/design` has one of its three designers on Codex.

Sandboxes: Codex readers, the critic and the designer run sandboxed with network on (`hc send` needs its
socket). Codex writers run with no sandbox, because Xcode's package resolution starts its own `sandbox-exec`,
which macOS refuses inside Codex's. Their template rules are what hold them, as with the Claude writers.

Machine-specific settings go in `~/.config/herdr-kit/local.env`, never in this repo. For example, when Codex goes
through a proxy that prefixes model ids:

```sh
CODEX_MODEL_PREFIX=global.openai.
```

## Lead and Epic in either harness

If this kit is already installed, run `./codex/install.sh` from this checkout to add the two
Codex skills. Otherwise run `./install.sh` for the initial setup, including the shared `herdr-notes` helper.
Run `codex login` if needed and choose **Sign in with ChatGPT** to use your subscription.

From a Herdr tab in your project, open Claude Code and use `/lead` or `/epic`. In a normal Codex
session, use `$lead` or `$epic`. Both harnesses load the same workflows from `shared/workflows/` and use
your current session's model, reasoning effort, and permissions. Workers use their own templates.

Lead defaults to Claude writing and Codex reviewing. Set `writer=` and `reader=` independently
for a run. A missing template or exhausted quota prompts you to choose another provider.

```text
/lead TICKET-123
$lead TICKET-123 writer=codex
$lead TICKET-123 writer=codex reader=claude
```

Epic writes `level: low|medium|high|deep` on new tasks. Lead uses the level to pick a writer
template and uses the deep reviewer for deep tasks. Legacy `worker:` labels, including `-codex`
labels, supply the task level. The Lead invocation supplies the provider.

Plan critique uses `/critique` in Claude Code and the existing `critique-codex` template in Codex.

## From ticket to merge

1. **Epic** writes the spec and a plan, gets a critique, then defines tasks with one repo, one writer, an exact file list, and a `level:` each.
2. **Lead** plans and delegates. It selects the writer and reviewer using the level and provider options, then starts the writer in its own git worktree.
3. **The writer** makes the change, runs the tests, and reports back with `hc send`.
4. **The reviewer** checks the diff for real bugs and for the repo's own rules.
5. **You** get one summary of the diff and its review from Lead. Nothing merges without your yes.
6. **Epic again** checks every acceptance criterion and shows a pass or fail table.

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

To update, run `git pull` in `herdr-kit`. If you installed the kit before the `claude/` and `shared/`
layout, rerun `./install.sh` once to relink the moved files.

## What's in here

```
claude/
  skills/             Lead and Epic entry points → ~/.claude/skills/
  commands/           critique, design, research, spike → ~/.claude/commands/
  templates/          Claude workers → ~/.config/herdr-core/templates/
  hooks/              Claude session tab naming
  statusline.sh       Claude session status line
codex/
  skills/             Lead and Epic entry points → ~/.agents/skills/
  templates/          Codex workers → ~/.config/herdr-core/templates/
  install.sh          Codex skills, templates, and worker profiles
shared/
  workflows/          Lead and Epic instructions and task levels
  bin/herdr-notes     Project notes lookup → ~/.local/bin/
  herdr-settings.json Herdr app defaults
install.sh            Installs the kit
```

Every template sets its own model and effort. If a tier's diffs keep coming back from review, move that kind of
task up a tier. Don't raise the effort instead.
