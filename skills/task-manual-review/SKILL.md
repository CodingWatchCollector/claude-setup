---
name: task-manual-review
description: Adds the user's own review comments, short or detailed, to findings.md of a task run by task-run, in the same finding format the task-reviewer uses. Writes them as a "Manual review (round <n>)" section on the latest review round, continues finding numbers, and flips an APPROVE verdict to CHANGES_REQUESTED when a comment is blocking, so the next task-run continues with a fix round. Use when the user runs /task-manual-review or wants to add their review notes or comments to a task's findings. Never edits code.
---

# task-manual-review

Turns the user's review comments into findings for a task from the task-prep / task-run workflow. The findings then go through the normal loop: `/task-run` fixes them in the next implementation round, the reviewer checks the fixes, and task-retro learns from them.

## Rules

- Never edit code, tests or task files by hand. The only write is `manual.sh append`.
- Read the repository only with read-only commands (`git -C <repo> diff`, `grep`, reading files).
- Keep the user's intent. Add detail from the code (location, concrete fix), but never add problems the user did not raise and never drop or soften one they did.
- Plain ASCII punctuation in findings.

## Input

`/task-manual-review <project> <TASK-ID> [comments]`

Comments come in any form: one-liners, a pasted list, prose, with or without file paths. If none are given, ask for them.

## Script

`bash <this skill's folder>/scripts/manual.sh <project> <TASK-ID> <info|append>`, run from the workspace root, with the absolute path to `manual.sh`.

## Steps

1. Run `manual.sh info`. On FAIL, show the output and stop. It gives the round to write into, the next finding id, the current verdict, `repo` and `base_commit`. Show WARN lines to the user.
2. Read `findings.md` (existing findings, to avoid duplicates) and the acceptance criteria and scope in `plan.md`. For each comment, read the code it refers to in the diff since `base_commit`, enough to pin the location and a concrete fix.
3. Write one finding per issue. Split a comment that raises unrelated issues; merge comments that describe the same issue. If a comment repeats an existing finding marked `fixed`, add `reopens: F-<n>`. If it repeats an open one, tell the user instead of duplicating it.
4. Show the drafted blocks and ask the user to confirm or correct them. Apply corrections and show again until confirmed.
5. Append, then show the script output:

   ```
   bash <abs path>/manual.sh <project> <TASK-ID> append << 'FINDINGS_EOF'
   <finding blocks only, no headers>
   FINDINGS_EOF
   ```

6. Tell the user what happens next:
   - Any blocking finding: `/task-run <project> <TASK-ID>` starts implementation round <n+1> to fix them. If round <n> already hit the round limit, add `--max-rounds <n+1>`.
   - Only non-blocking findings after APPROVE: `/task-run` asks whether to fix or leave them.
   - Only non-blocking findings after CHANGES_REQUESTED: they ride along with the blocking ones in the next round.

## Finding format

The script writes the section header. Pass only blocks like this, numbered from `next_id` on, each field on one line:

```
### F-<n>
axis: spec | standards | process
severity: blocking | non-blocking
class: one-off | pattern
source: plan | implementation | tests
lesson: <folder/L-xxx | none>
location: <path:line>
origin: manual
problem: <what is wrong and why it matters, specific to the code>
fix: <concrete change>
status: open
```

How to fill the fields from a comment:

- **severity**: the user's words decide ("must", "blocking", "nit", "optional", "consider"). With no signal: `blocking` for wrong behaviour, a spec or acceptance criterion mismatch, a missing or weak test, a security or data issue; `non-blocking` for naming, style and suggestions.
- **axis**: `spec` when it is about what the plan asked for, `standards` for code quality and conventions, `process` for workflow issues.
- **source**: `plan` when the plan itself was wrong or silent, `tests` when the problem is in tests, `implementation` otherwise.
- **class**: `pattern` if the same mistake is likely in other tasks, else `one-off`. task-retro builds lessons from it.
- **lesson**: an id from the plan's lessons checklist if the comment matches one, else `none`.
- **location**: the most specific `path:line` in the repository. For an issue spanning files, the main one; list the others in `problem`.
