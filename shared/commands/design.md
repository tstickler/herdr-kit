# Design

Get independent proposals for the supplied design question or brief.

1. Apply [the worker instructions](workers.md) with role `design`. Pick a short kebab-case slug for
   the topic and create a fresh `docs/plans/<slug>/` directory for the run.
2. Run every selected harness on all three lenses. Use the same question and lens instructions in
   each matching brief. Each brief supplies its own absolute report path, such as
   `design-<harness>-simplicity.md` in the run directory.
   - **Open-ended** — propose a design without an extra lens.
   - **Simplicity** — favor the simplest thing that could work.
   - **Flexibility** — favor long-term flexibility.
3. Launch all proposals before waiting on their terminal IDs. Read each available report and
   identify any missing harness and lens.
4. Write `comparison.md` in the run directory. Group proposals by lens and compare the harnesses
   within each lens when there is more than one. Compare complexity, risk, testability, and fit
   with the code. Identify agreement, disagreements that affect the decision, and your
   recommendation. Record the harness and template that wrote each proposal.
5. Summarize the comparison, then ask which direction the user wants before implementation.
