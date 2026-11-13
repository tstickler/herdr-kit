---
description: Get 3 independent design proposals from helper agents, then compare them
argument-hint: <design question or brief>
---
Get independent design proposals for:

$ARGUMENTS

If `hc` is not on the PATH, or `$HC_TERMINAL_ID` is empty, say this needs to run inside Herdr and stop.

1. Pick a short kebab-case slug for the topic and create `docs/plans/<slug>/`.
2. Write three brief files. Each holds the design question and its output path, `docs/plans/<slug>/<name>.md`, plus one lens so they diverge: `design-a` gets none, `design-b` gets "favor the simplest thing that could work", `design-c` gets "favor long-term flexibility".
3. Start each: `hc run --bg --name <name> --cwd <repo> design "$(cat <brief file>)"`. If `first_message.sent` is false, `hc read <name>` before sending anything.
4. `hc wait --children all`. Never sleep or poll.
5. Read the three proposals and write `docs/plans/<slug>/comparison.md`: a table comparing them on complexity, risk, testability and fit with the existing code; where they agree; the real disagreements; and your recommendation with reasoning.
6. Give me a short summary and ask which direction I want. Don't start implementing.
7. `hc kill` and `hc rm` all three.
