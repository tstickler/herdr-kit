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
| `reader` | Opus, medium | Reviews diffs from `writer-low` and `writer`. Read-only, except for one findings file. |
| `reader-high` | Fable, medium | Reviews `writer-high` diffs. |
| `reader-deep` | Fable, high | Reviews `writer-deep` diffs. |
| `critique` | Fable, high | Attacks a plan before it's built. Launched by `/critique`. |
| `design` | Fable, medium | Proposes one design through a given lens. The design command compares the results. |
| `research` | Sonnet, medium | Answers a codebase question with path:line evidence, in the background. `/research`. |
| `spike` | Sonnet, medium | Throwaway prototype in its own worktree. `/spike` runs one per approach. |

## Codex workers (optional)

On a machine with `codex` on PATH, `install.sh` adds Codex writers, readers, and helper workers.

| Template | Codex model |
|---|---|
| `writer-low-codex` | Luna, medium |
| `writer-codex` | Terra, medium |
| `writer-high-codex` | Sol, high |
| `writer-deep-codex` | Astra, high |
| `reader-codex` | Sol, medium |
| `reader-high-codex` | Astra, medium |
| `reader-deep-codex` | Astra, high |
| `critique-codex` | Astra, high |
| `design-codex` | Astra, medium |
| `research-codex` | Terra, medium |
| `spike-codex` | Terra, medium |

Each template runs `codex --no-daemon -p herdr-<role>`,
and the install writes those profiles to `~/.codex/herdr-<role>.config.toml` with the model, effort, sandbox,
and `CLAUDE.md` as a fallback for `AGENTS.md`.

Codex readers, critics, designers, and researchers run sandboxed with network access for
`hc send`. Codex writers and Spike workers run without a sandbox so projects can build with Xcode and
SwiftPM, which start their own `sandbox-exec` process on macOS. Spike workers are instructed to work
in their assigned worktrees.

Machine-specific settings go in `~/.config/herdr-kit/local.env`, never in this repo. For example, when Codex goes
through a proxy that prefixes model ids:

```sh
CODEX_MODEL_PREFIX=global.openai.
```

## Lead and Epic in either harness

Run `./install.sh` for a first install or upgrade. It installs the shared commands and worker
resolver, configures each harness, and registers its Herdr menu entry. If you add Codex later,
rerun the same installer to pick up the Codex workers and menu entry.
Backups of Codex skills displaced by older installs remain under `~/.config/herdr-kit/skill-backups/`.
Run `codex login` if needed and choose **Sign in with ChatGPT** to use your subscription.

From a Herdr tab in your project, launch Claude for `/lead` and `/epic`, or Codex for `$lead` and
`$epic`. Both harnesses load the same workflows from `shared/workflows/` and use your
current session's model, reasoning effort, and permissions. Workers use their own templates.

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

Epic in either harness uses the shared Critique command. Pass `harness=` to Epic to choose the plan
reviewer. Epic keeps the plan and pauses before task creation if critique is blocked. Retry with
another harness to continue from the same plan. Lead's `writer=` and `reader=` choices are separate.

## Helper commands

Use Herdr's Claude and Codex menu entries, or type `claude` or `codex` in a new zsh or Bash terminal
inside Herdr. The installer connects those launches to the kit's session-specific entry points.
Ordinary agent launches use their usual command and skill lists. Existing custom menu launch
commands, shell functions, and aliases keep their precedence.

The first time you start Claude from Herdr's menu or run plain `claude` in a Herdr terminal, the
launcher opens the kit's entry-point directory if it still needs trust. Choose **Yes, I trust this
folder**, then exit that setup session. Claude saves your approval and the launcher opens your project.
Future launches go straight to the project.

Use `/critique`, `/design`, `/research`, and `/spike` in Claude, or `$critique`, `$design`,
`$research`, and `$spike` in Codex. They use the same instructions from `shared/commands/`.
Append `harness=claude`, `harness=codex`, or `harness=claude,codex` to select the worker harnesses.

| Command | Default | When both harnesses are selected |
|---|---|---|
| Critique | One reviewer from the opposite harness if available, otherwise one from the calling harness | Two independent reviews of the same plan |
| Design | The calling harness runs all three lenses | Each harness runs all three lenses, for six proposals |
| Research | One background worker from the calling harness | Choose one harness |
| Spike | The calling harness prototypes every approach | Each harness prototypes every approach in separate worktrees |

The worker resolver checks the executable and Herdr template immediately before launch. Explicit
selections must all be available. If a worker fails during the run, including when it hits a usage
cap, completed reports are retained and the failure is reported. Critique reports are written to a
fresh temporary directory so both reviewers can write them. The worker mappings live in
`harnesses.json` and can grow as more harnesses are added.

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

Roles that read notes: `lead`, `epic`, `writer` (all four tiers), `reader` (all three), `critique`, `design`,
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
3. Run `herdr-kit/install.sh` to install the templates, launchers, and session-scoped entry points.
4. Write your project's notes: `mkdir -p <parent>/.claude/herdr`, then add `lead.md` and `epic.md` there.
5. Check from your app folder: `herdr-notes lead | head -1` should name your notes file.
6. Open a Herdr tab in the repo, start Claude, then run `/lead`.

To update, run `git pull` in `herdr-kit`. Rerun `./install.sh` once to migrate the old global links,
install the launch integration and worker resolver, and update the Codex profiles. Open a new Herdr
terminal to pick up the shell integration.

## What's in here

```
claude/
  bin/herdr-claude    Claude session launcher → ~/.local/bin/
  skills/             Lead and Epic entry points loaded by the launcher
  commands/           Helper slash commands loaded by the launcher
  templates/          Claude workers → ~/.config/herdr-core/templates/
  hooks/              Claude session tab naming
  setup.sh            Claude setup called by the top-level installer
codex/
  bin/herdr-codex     Codex session launcher → ~/.local/bin/
  skills/             Lead, Epic, and helper entry points enabled by the launcher
  templates/          Codex workers → ~/.config/herdr-core/templates/
  setup.sh            Codex setup called by the top-level installer
shared/
  commands/           Critique, Design, Research, and Spike instructions → ~/.config/herdr-kit/commands/
  workflows/          Lead and Epic instructions and task levels
  bin/                Project notes lookup and worker resolver → ~/.local/bin/
  herdr-settings.json Herdr app defaults
harnesses.json        Worker executables and template mappings
install.sh            Installs the kit
```

Every template sets its own model and effort. If a tier's diffs keep coming back from review, move that kind of
task up a tier. Don't raise the effort instead.
