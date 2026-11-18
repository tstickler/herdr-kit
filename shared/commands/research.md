# Research

Start background codebase research on the supplied question.

If `hc` is not on the PATH, or `$HC_TERMINAL_ID` is empty, say this needs to run inside Herdr and stop.

1. Pick a short slug. Write the brief to a file: the question, and the output path `docs/research/<slug>.md`.
2. Use the template selected by the entry point. Run `hc run --bg --name research-<slug> --cwd <repo> <template> "$(cat <brief file>)"`. If `first_message.sent` is false, `hc read research-<slug>` before sending anything.
3. Don't block on it. Tell me in one line that it's running, then carry on with whatever we were doing.
4. When its report arrives (or I ask first, then `hc wait research-<slug>`; never sleep or poll), read the file and summarize it in a few lines with its path, without waiting to be asked. Then `hc kill research-<slug>; hc rm research-<slug>`.
