# Spike

Run time-boxed prototypes for the supplied question and approaches.

1. Identify the question, approaches, time box, and what would count as evidence. If the question
   or approaches are unclear, ask before starting.
2. Apply [the worker instructions](workers.md) with role `spike`. Run `herdr-notes lead` and follow
   its worktree rules. Capture the current commit. For each combination of selected harness and
   approach, create a throwaway worktree from that commit. Include the run slug, harness and
   approach in the branch and worktree names. Put worktrees where the notes say, or next to the
   repo by default.
3. Start one worker in each worktree with the question, approach, agreed time box, and success
   check. Keep the conditions the same across workers. Start them all before waiting on their
   terminal IDs.
4. Read each `spike-report.md`. Compare approaches within each harness and check whether the
   results agree across harnesses. Summarize the verdicts, evidence, failures, and recommendation.
5. Close the worker terminals and leave the branches and worktrees for inspection. List the
   cleanup commands (`git worktree remove …` and `git branch -D …`). Keep spike branches out of
   the merge workflow.
