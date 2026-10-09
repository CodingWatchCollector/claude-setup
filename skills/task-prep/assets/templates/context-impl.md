# Implementer context: <PROJECT>/<TASK-ID>

You implement this task. You have no access to the planning conversation: this file is your whole brief. Status and handoff go through `<TASK_DIR>/status.md`.

## Repository

- project: <PROJECT>
- path: <REPO>
- branch: <branch>

Work only inside this directory: `cd` into it before running anything, or use `git -C`. Your session starts in a workspace that contains other repositories; do not read from or write to them. Never create tool or process files in the repository (CLAUDE.md, `.claude/`, `.agents/`, `.omc/`, notes, plans). Task files live in `<TASK_DIR>`.

## Before you start

1. Follow the `<TDD_SKILL>` skill for the whole task. It is normally preloaded into your context; if its instructions are not there, invoke it.
2. Read the repository's AGENTS.md and, if present, CONTEXT.md and ADRs for the areas below.
3. Read the Blockers section of `<TASK_DIR>/status.md`. Resolved blockers contain decisions you must follow.
4. Check `<TASK_DIR>/findings.md`. This is a fix round if its latest verdict is `CHANGES_REQUESTED`, or if it ends with a `nonblocking decision (round <n>): fix` line for the latest round: see "Review rounds" below.

## Goal

## Scope

## Out of scope

Do not change anything here, even if it looks broken. Note it in the Implementer report instead.

## Acceptance criteria

## Seams, in implementation order

<!-- Work one vertical slice per row, red -> green, through the listed public interface. -->

| # | AC | Seam | Test file |
|---|---|---|---|

## API contract

## Lessons to respect

<!-- Full entries, not just IDs. -->

## Conventions and constraints

## Rules for tests

- Never delete or skip existing tests (`.skip`, `.only`, `xit`, `xdescribe`, `fit`, commenting out) and never weaken their assertions.
- If an acceptance criterion intentionally changes existing behavior, update the affected existing test and list it under "changed existing tests" with the AC reference.
- Acceptance tests listed below are read-only. If one looks wrong, stop and report a blocker.

Acceptance tests (read-only): <paths | none>

## Code rules

- Comment only a non-obvious decision: why, never what. Delete comments that restate the code, in production and spec files alike. A test name says what is tested; a comment does not repeat it.

## If blocked

When a business rule is unclear or a criterion contradicts the code, do not guess. Set `run:implementation` to `blocked` in status.md, write the question under Blockers, and stop.

A business rule is any behavior a user or another system can observe that neither the plan nor a recorded decision fixes: which input is accepted, which error is raised, which value wins. If you cannot avoid choosing one to finish, choose the most conservative option, mark it in the code or docs as provisional, and list it under `rules decided` in your report. The user confirms every such rule before the review starts. Never leave one only in notes for the reviewer.

## Review rounds

In a fix round after `CHANGES_REQUESTED`, handle every finding with `severity: blocking` and `status: open`. In a fix round after a `nonblocking decision ... fix` line, handle every finding of the latest review round with `status: open`, whatever its severity:

- Fix it and set `status: fixed`, adding `fix_note:` with one line on what changed.
- If you are convinced the finding is wrong, do not skip it silently: set `status: disputed` and add `reason:` with your argument. The user decides.

In a round after `CHANGES_REQUESTED`, non-blocking findings: fix them if cheap and inside scope, otherwise leave them open. Then finish with "When done" below. A fix round ends exactly like the first round.

## Definition of done

A definition-of-done command that exits with status 2 or higher, or prints to stderr, is an error: report it as an error, never as clean. A "no output expected" check passes only on exit status 1 (for grep: no match).

## When done (every round, including fix rounds)

1. Run every definition-of-done command again. Never reuse results from a previous round.
2. Rewrite the Implementer report in status.md from scratch, do not patch the old one. Its first four lines, in this exact format:
   ```
   round: <n>
   skills invoked: <exact names of the skills you used, preloaded or invoked>
   tests: total=<n> passed=<n> failed=<n>
   rules decided: none
   ```
   Round is 1 for the first implementation, otherwise the latest `round:` in findings.md plus 1. Test counts come from the output of the test command you just ran. If you decided a business rule (see "If blocked"), write `rules decided: see below` instead of `none`, followed by one line per rule: `- R-<k>: <rule> (where: <file:line>; why: <one line>)`, numbered from 1 in each round. Rules already confirmed by the user in the Blockers section do not count.
3. Then: AC -> test mapping, changed files, changed existing tests with AC reference, results of every definition-of-done command.
4. Set `run:implementation` to `done` in the status table. Do not commit or push.
