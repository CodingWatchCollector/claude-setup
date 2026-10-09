# Changelog

One entry per change to a skill, agent or process file. Newest first. Bump `VERSION` with each entry.
Roll back a bad change with `git revert <commit>` and rerun `bash install.sh`.

## 0.1.2

- Drop the workspace files (lessons, process-backlog.md, metrics.csv) and the workspace argument from install.sh. The repo holds skills and agents only.

## 0.1.1

- install.sh: workspace folder is a required `<WORKSPACE_DIR>` argument, remembered in `.install.conf`, instead of a hardcoded default.

## 0.1.0

- Initial import of task-prep, task-retro, task-run, unslop, wiki, the four task-* agents,
  and the workspace files (lessons, process-backlog.md, metrics.csv).
