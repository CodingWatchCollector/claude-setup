# Lessons base

Recurring mistakes and wrong decisions, recorded so agents do not repeat them. Read by task-prep when planning, written by task-retro after a task, with human confirmation. Lives in the workspace, never inside a repository.

## Layout

```
.agents/lessons/
  _shared/        lessons valid for every project (same stack, same conventions)
  <project>/      lessons specific to one project; <project> = main checkout directory name
```

Inside a folder, one file per area, for example `nest-api.md`, `frontend.md`, `contract.md`, `shared-components.md`. Split further only when a file gets hard to scan.

Put a lesson in `_shared/` only if it would be true in every project you work on. When unsure, keep it in the project folder; move it once it shows up in a second project.

## Entry format

```
## L-001: <short title>
trigger: <files, globs, modules, fields, conditions that make this relevant>
kind: business-logic | types | a11y | api-contract | test-gap | security | performance | tooling
problem: <what went wrong, concretely>
correct: <what to do instead>
detect: <test, lint rule or review check that catches it>
source: <project/TASK-ID list>
occurrences: <number>
last_seen: <YYYY-MM-DD>
```

## Rules

- IDs are unique within a folder and never reused. Refer to a lesson as `<folder>/L-<n>`, for example `_shared/L-003`.
- `trigger` is what matching uses, so write it in terms of files and concrete conditions, not general topics.
- A repeated mistake increments `occurrences` and updates `last_seen` and `source`; do not add a duplicate entry.
- If a lesson is really an architectural decision for one project, it belongs in that project's ADRs; keep a one-line pointer here.
- Entries not seen for a long time get reviewed and removed if obsolete. A stale base misleads more than an empty one.
