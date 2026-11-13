# Epic notes: Jira

The Jira ticket is the spec, and what it already decides stands. Jira holds all tracking and all state: keep no
ticket or status files in the repo. Use the Atlassian MCP tools if they are connected, otherwise `acli` (check
`acli jira workitem --help` for flags). If neither works, say so and stop.

- With no argument, list `assignee = currentUser() AND statusCategory != Done` and ask which ticket.
- Find the step by status category (To Do, In Progress, Done), since workflows name statuses differently: parent Done → finished; no child work items → Read; children with no `worker:` line → Tasks, filling only those gaps; any child To Do or In Progress → Hand off; every child Done → Verify.
- On a ticket someone else filed, a gap only product or design can answer is not the user's to decide. Say who owns it, and draft a Jira comment asking them. Post it only on the user's yes.
- Spec: if the project has its own acceptance criteria field, put them there. Keep any text already on the ticket. Update Jira only on the user's yes.
- Plan: `/tmp/epic-<KEY>/plan.md`. The ticket and subtasks are the lasting record.
- Tasks are Jira children, using the project's own type names: Sub-tasks under a Story, Task or Bug; child Tasks or Stories under an Epic. Give an https link to each. Never put secrets in Jira. If the ticket already has subtasks, keep them and add a brief only with the user's yes; never edit or delete anything else on someone's work item.
- Hand off text: "Build <KEY>. Subtasks in order: <list>. Each subtask's description is the worker's brief and names its worker on the first line. Move a subtask to In Progress when its worker starts and to Done once I have approved its merge."
- Verify: when everything passes, offer a draft summary comment for the parent ticket. Post it only on the user's yes.
- Never change the parent ticket's status, assignee or sprint.
