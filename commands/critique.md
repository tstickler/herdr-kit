---
description: Have a fresh helper agent attack a plan before implementation starts
argument-hint: [path to plan — defaults to the newest file in docs/plans/]
---
Get an independent critique of a plan.

If `hc` is not on the PATH, or `$HC_TERMINAL_ID` is empty, say this needs to run inside Herdr and stop.

1. Plan: $ARGUMENTS. If blank, use the most recently modified plan in `docs/plans/`, and ask if there is none. Read it yourself so you can judge the critique.
2. Write the brief to a file: the plan's path, and the output path `<plan dir>/critique.md`. Nothing else: not your opinion of the plan or the conversation that produced it.
3. `hc run --bg --name critic --cwd <repo> critique "$(cat <brief file>)"`. If `first_message.sent` is false, `hc read critic` before sending anything.
4. `hc wait critic`. Never sleep or poll.
5. Check each finding against the code yourself. Drop false positives and say why.
6. Report: confirmed issues, most severe first; what you would change in the plan; what you dismissed. Ask before editing the plan.
7. `hc kill critic; hc rm critic`.
