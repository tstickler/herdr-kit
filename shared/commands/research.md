# Research

Start one background worker on the supplied codebase question.

1. Apply [the worker instructions](workers.md) with role `research`. The resolver accepts one
   harness for this role. Pick a short slug and give the worker the question and a fresh absolute
   report path under `docs/research/<slug>.md`.
2. Launch the worker and resolve any delivery issue. Tell the user that research is running and
   carry on with their work.
3. When the worker reports, read and summarize the findings with the report path, then close its
   terminal. If the user asks for the result before it reports, wait on that terminal ID.
