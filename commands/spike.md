---
description: Prototype competing approaches in throwaway worktrees and report what was learned
argument-hint: <question>; A: <approach>; B: <approach>
---
Run time-boxed spikes for:

$ARGUMENTS

If `hc` is not on the PATH, or `$HC_TERMINAL_ID` is empty, say this needs to run inside Herdr and stop.

1. Identify the question and the options (usually two). If either is unclear, ask me before starting anything.
2. Run `herdr-notes lead` and follow its worktree rules. For each option, create a throwaway worktree from the current HEAD, where those notes say, or by default:
   `git -C <repo> worktree add ../<repo>-spike-<x> -b spike/<slug>-<x>`
3. Write one brief file per option: the question and that option's approach. Start one helper per worktree: `hc run --bg --name spike-<x> --cwd <worktree> spike "$(cat <brief file>)"`. If `first_message.sent` is false, `hc read spike-<x>` before sending anything.
4. `hc wait --children all`. Never sleep or poll.
5. Read each `spike-report.md` and give me a side-by-side: verdicts, the evidence behind them, and your recommendation.
6. Never merge spike branches. `hc kill` and `hc rm` the helpers, but leave the worktrees so I can inspect them, and list the cleanup commands (`git worktree remove …`, `git branch -D …`).
