# Process backlog

Improvements to the workflow itself: the task-prep, task-run and task-retro skills, their templates, the agents, the gate scripts. Fed by findings about the process, not about product code. Lives at `<workspace>/.agents/process-backlog.md`. Never mixed into lessons: task-prep injects lessons into plans, and workflow notes there would be noise in every task.

## Entry format

```
## P-001: <short title>
status: open | done | rejected
seen: <number of tasks where it showed up>
sources: <project/TASK-ID F-n, ...>
observed: <what happened, concretely>
proposal: <which skill, template, agent or script to change, and how>
```

## Rules

- IDs are never reused.
- Same problem in another task: increment `seen` and add the source, do not add a duplicate entry.
- `done` when the change is shipped in the skills; `rejected` with one line on why.
