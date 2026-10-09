# Changelog

One entry per change to a skill, agent or process file. Newest first. Bump `VERSION` with each entry.
Roll back a bad change with `git revert <commit>` and rerun `bash install.sh`.

## 0.2.0

- Process backlog P-001: `gate.sh after-review` writes `rounds: <n>` into the run:review row; task-prep records validation rounds in prep:validation.
- Process backlog P-002: validation checklist check 15 and a plan template note: commands outside the repo root use absolute tool paths, baseline step aborts on runner errors.
- Process backlog P-003: validation checklist check 8 requires dry-running DoD commands, `grep -r` on directories and exit status 1 for "no output" checks; impl and review templates say exit >= 2 or stderr is an error.

## 0.1.2

- Drop the workspace files (lessons, process-backlog.md, metrics.csv) and the workspace argument from install.sh. The repo holds skills and agents only.

## 0.1.1

- install.sh: workspace folder is a required `<WORKSPACE_DIR>` argument, remembered in `.install.conf`, instead of a hardcoded default.

## 0.1.0

- Initial import of task-prep, task-retro, task-run, unslop, wiki, the four task-* agents,
  and the workspace files (lessons, process-backlog.md, metrics.csv).
