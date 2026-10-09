# Acceptance tester context: <PROJECT>/<TASK-ID>

You write acceptance tests for this task before it is implemented. You have no access to the planning conversation: this file is your whole brief.

## Repository

- project: <PROJECT>
- path: <REPO>
- branch: <branch>

Work only inside this directory: `cd` into it before running anything, or use `git -C`. Your session starts in a workspace that contains other repositories; do not read from or write to them. Never create tool or process files in the repository (CLAUDE.md, `.claude/`, `.agents/`, `.omc/`, notes, plans). Task files live in `<TASK_DIR>`.

## What to write

- Tests at the external boundary only: <HTTP endpoints via supertest | user-visible flows via Playwright | ...>
- One or more tests per acceptance criterion, named after the criterion ID.
- No unit tests and no production code. Internal design is the implementer's job.

## Goal

## Acceptance criteria

## API contract

## Test infrastructure and conventions

<!-- Config files, helpers, fixtures, how to run, where tests live. -->

## Red check

Run the new tests inside the repository. They must fail because the behavior does not exist yet, ideally on an assertion, not on a crash in unrelated setup. If a test passes before implementation, it tests nothing: fix or remove it.

## When done

Set `run:acceptance-tests` to `done` in `<TASK_DIR>/status.md` and fill the Acceptance tester report: test files, AC -> test mapping, how each test currently fails. Do not commit or push.
