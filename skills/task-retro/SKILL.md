---
name: task-retro
description: Post-task retrospective for tasks executed with task-prep and task-run in a multi-repository workspace. Reads the review findings of one or more approved tasks, records metrics, turns recurring code mistakes into lessons for future planning, routes workflow problems to a process backlog, surfaces findings left open after approval, and checks API contract follow-through. Proposes every change and writes only what the user confirms. Use when the user runs /task-retro or asks for a retro on finished tasks. Never touches repositories.
---

# task-retro

Last stage of the workflow:

1. **task-prep**: plan, validate, approve, write context files.
2. **task-run**: implementer and reviewer rounds.
3. **task-retro** (this skill): learn from the findings.

The goal is that the next plan knows about this task's mistakes. Lessons are only worth something if they are few, precise and triggered by concrete files or situations: prefer no lesson to a vague one.

## Rules

- Propose first, write after explicit confirmation. The only write without confirmation is the metrics line, since it is factual.
- Never write inside a repository. Everything goes under `<workspace>/.agents/`. An ADR proposal is a draft in the task folder; the user decides whether it goes into the repository through a PR.
- Run every script call in full with an absolute path; never store commands in shell variables (the shell may be zsh).
- Plain ASCII punctuation in everything you write.
- Write lessons and backlog entries in English, whatever the language of the findings, so matching works across tasks. Keep project terms as they are.

## Input

- `/task-retro <project> <TASK-ID>`
- `/task-retro <project> --pending`: every task of the project with an APPROVE verdict and retro not done. Process them in one pass with one combined proposal table, so the same pattern seen in two tasks becomes one lesson with two sources.

## Script

`bash <this skill's folder>/scripts/retro.sh <project> <TASK-ID> <command> [arg]`, from the workspace root:

- `data`: task facts and a normalized findings table (id, round, severity, class, source, axis, status, location, problem). Tolerates older findings formats.
- `lessons-index`, `backlog-index`: existing entries, for matching.
- `next-id <folder>`, `next-pid`: free IDs.
- `record-metrics`, `set-done`: the two writes the script does itself.
- `pending` (with `-` as TASK-ID): tasks waiting for a retro.

Lesson format: `<workspace>/.agents/lessons/README.md`. Backlog format: `references/process-backlog-format.md`.

## Step 1 - Load

1. For each task: `retro.sh ... data`. If the verdict is not APPROVE, say so and ask whether to continue (an abandoned task can still teach something).
2. If `models:` is empty (tasks run before this was recorded), ask the user once which models ran, or accept "unknown".
3. `retro.sh ... record-metrics` for each task.
4. Load `lessons-index` and `backlog-index`.

Read `plan.md` and the full text of a finding only when a decision below needs it. Do not read the code or the diff, except for the contract check in Step 3.

## Step 2 - Classify every finding

Apply the rules in order. A finding can land in two buckets (an open pattern finding is both a leftover and a lesson candidate).

1. **Process.** Axis `process` or `process*` (the script marks findings located under `.agents/` with `process*`, whatever their other labels), or the problem is about how an agent followed the workflow (stale report, rule added without asking, brief ignored). -> process backlog candidate. Never a project lesson.
2. **Leftover.** Status `open` after the final APPROVE, any severity. -> leftover list.
3. **Declined or waived with a plan source.** Not a code lesson, but ask why the plan allowed the gap: if the plan promised something (in its Goal, for example) that no acceptance criterion covered, that is a process candidate for the validation checklist.
4. **Lesson candidate.** `class: pattern`, or a one-off that clearly matches an existing lesson. Check the reviewer's label: a pattern is something likely to happen again in another task of this project. A mistake tied to one specific file's content is a one-off whatever the label says.
5. **Skip.** Everything else. One-offs that were fixed teach nothing new.

## Step 3 - Build proposals

**Lessons.** For each candidate, compare with `lessons-index`:
- Same mistake already recorded: propose `occurrences + 1`, `last_seen`, new source.
- New: propose a full entry. `trigger` names files, globs or situations (`plan touches src/migration/**`, `tests that call TypeORM migrations directly`), never topics. `correct` is an instruction an agent can follow. `detect` names a test or check.
- `source: plan` lessons are the most valuable: phrase the trigger as a planning situation, since task-prep matches lessons while planning.
- Folder: the project's folder. Propose `_shared` only if an equivalent lesson already exists in another project's folder; then propose moving it there with both sources.

**Process backlog.** Match against `backlog-index`: increment `seen` or propose a new entry with a concrete proposal (which file of which skill, what to change).

**Leftovers.** List each open finding with one line and a recommended action:
- `fix`: worth doing now. Suggest a small follow-up task through task-prep, with the findings as its input.
- `ticket`: real but out of this task's scope; the user creates the ticket.
- `accept`: not worth the effort.

**Contract check.** If `data` says `api_contract: yes`, list the files changed since `base_commit` (`git -C <repo> diff --name-only <base_commit>` plus the branch head if committed) and report whether DTOs, shared types, Swagger decorators and known frontend consumers were touched as the plan's contract section says. Report only; missing items become leftovers.

**ADR drafts.** Only when a lesson is really a project decision (a rule the team should follow everywhere, not a mistake to avoid). Propose a short draft; it will be written to `<task dir>/adr-draft-<slug>.md`.

## Step 4 - Confirm

Show one numbered table for all tasks:

| # | Task | Finding | Bucket | Proposal |
|---|---|---|---|---|

Then the full text of each proposed new lesson and backlog entry below the table. The user approves all, or approves, edits or rejects by number. Nothing is written before that answer.

## Step 5 - Write

1. Lessons: edit existing entries or append new ones to the right file of the folder (create the file by area, for example `tests.md`, `migrations.md`, if none fits). Use `next-id` for new IDs.
2. Process backlog: append or update `<workspace>/.agents/process-backlog.md`, creating it with a one-line header if missing. Use `next-pid`.
3. Leftovers: under each finding in `findings.md`, add `decision (retro, <date>): fix | ticket | accept - <one line>`. Do not change its `status`.
4. ADR drafts, if approved, in the task folder.
5. `retro.sh ... set-done` for each task, and one line in the status Log.

## Step 6 - Report

Short summary: lessons added or updated (with IDs), backlog entries, leftovers by decision, and the metrics lines recorded. If leftovers are marked `fix`, give the exact `/task-prep` command for the follow-up task. If the backlog now has entries with `seen` of 2 or more, point them out: those are the workflow changes worth making first.
