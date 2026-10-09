# Status: <PROJECT>/<TASK-ID>

project: <PROJECT>
repo: <REPO>
main_repo: <MAIN_REPO>
branch: <branch>
base_commit: <sha>
mode: standard | strict
lessons_matched: <_shared/L-001, <PROJECT>/L-007 | none>

States: pending | in-progress | done | blocked | n/a

| Step | State | Notes |
|---|---|---|
| prep:context | pending | |
| prep:plan | pending | |
| prep:validation | pending | rounds: 0 |
| prep:approval | pending | |
| prep:context-files | pending | |
| run:acceptance-tests | n/a | |
| run:implementation | pending | |
| run:review | pending | rounds: 0 |
| retro | pending | |

## Log

<!-- One line per event: date, step, what happened. -->

## Acceptance tester report

## Implementer report

<!-- Rewritten from scratch by the implementer every round. The first three lines are parsed by scripts, keep their format:
  round: <n>
  skills invoked: <names>
  tests: total=<n> passed=<n> failed=<n>
  rules decided: none
Then: AC -> test mapping, changed files, changed existing tests with AC reference, definition-of-done results. -->

## Blockers
