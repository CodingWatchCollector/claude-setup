# Changelog

One entry per change to a skill, agent or process file. Newest first. Bump `VERSION` with each entry.
Roll back a bad change with `git revert <commit>` and rerun `bash install.sh`.

## 0.6.0

- Tool files in the repository (`CLAUDE.md`, `.claude`, `.agents`, `.omc`) that git ignores, through `.gitignore` or the global excludes, no longer fail `gate.sh` (start, after-review) or `check-task.sh`: they print a warning instead. Untracked tool files that git can see still fail. `resolve-repo.sh` reports them separately as `ignored_tool_files_in_repo`.
- install.sh adds `.omc/` to git's global excludes file (`core.excludesFile`, default `~/.config/git/ignore`) once, so `.omc/` folders that OMC skills create inside repositories stay out of git and out of the gates.

## 0.5.0

- New hook `hooks/session-title.sh` (UserPromptSubmit): names the session after the first task-* command typed in it, keeping only the command and its `<project> <TASK-ID>` arguments: `/task-prep fitness-tracker mvp-a <task text> --strict` becomes `/task-prep fitness-tracker mvp-a`. Later prompts keep that name. Per-session markers live in `${XDG_STATE_HOME:-~/.local/state}/claude-session-title/`.
- install.sh links `hooks/*.sh` into `~/.claude/hooks/` and registers the hook in `settings.json` with jq, once, after a `.bak-<timestamp>` backup. install.sh now needs jq.

## 0.4.0

- New skill task-manual-review: turns the user's review comments into findings in the task-reviewer format and appends them to `findings.md` as `## Manual review (round <n>)` on the latest round, through `scripts/manual.sh` (validates fields, continues F-ids, refuses when an implementation round is ahead of the review). A blocking manual finding after APPROVE adds `verdict: CHANGES_REQUESTED`, so `gate next` starts a fix round. Findings carry `origin: manual`.
- task-run points to task-manual-review at `next: done`.

## 0.3.0

- task-retro reads a digest of the subagent transcripts (`retro.sh transcripts`, backed by `scripts/transcripts.py`) and looks for friction the reviewer never sees: long search streaks, failed commands, missing information, repeated calls. Candidates go to the process backlog, to a new `env` bucket (environment drafts in the task folder for the user to take to the repo), or to lessons.
- task-retro proposes an automated check (linter rule, pre-commit hook, CI job) instead of a lesson when a mistake is mechanical.

## 0.2.1

- Process backlog P-005: `retro.sh data` reports no API contract when the plan's contract section starts with "none", even if a reason follows on the same or the next lines.

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
