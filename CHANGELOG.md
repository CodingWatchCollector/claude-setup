# Changelog

One entry per change to a skill, agent or process file. Newest first. Bump `VERSION` with each entry.
Roll back a bad change with `git revert <commit>` and rerun `bash install.sh`.

## 0.10.0

- Process backlog P-014 (follow-up): the "Long commands" rule in `context-impl.md` and `context-review.md` now says what waiting looks like: after starting the background command, end the turn with one line naming it and make no other tool call (no echo, sleep, Monitor or ToolSearch) until its notice arrives.
- Process backlog P-021: in `context-review.md`, a `fix:` that moves, extracts or merges code names the rules (R-n) and decisions that apply to that code and how the suggested shape keeps them, or says it cannot and marks the fix optional. A `fix:` that adds a public export tells the implementer to add a `contract note:` line.
- Process backlog P-022: `gate.sh after-impl` collects the names on added `export` lines under `src/` since `base_commit` (tracked diff and untracked files, test-utils included), drops names already exported under `src/` at `base_commit` and names the brief gives (any word in its API contract section, or as inline code elsewhere in `context-impl.md`), and fails unless every remaining name appears in a `contract note` line of the Implementer report. Re-exports and type-only exports are checked and labelled; `export *` and multi-line `export { ... }` lists print a WARN to check by hand. The contract-note rule moves from per-task briefs into the `context-impl.md` template's "When done" step 3.

## 0.9.0

- task-run at `next: done` proposes a commit as two code blocks: the commit message (for an editor's source control panel) and a ready-to-paste `git -C <repo> add -A && git -C <repo> commit -F -` command carrying the same message. The message is written from plan.md, the Implementer report and `gate summary`, in the repository's commit style, without reading the diff. task-run still never commits.

## 0.8.0

- Process backlog P-015: the implementer's "When done" checks that every handled finding has `status: fixed` with a `fix_note:`, or `status: disputed` with a `reason:`, before setting run:implementation done (`context-impl.md`). When every gate FAIL line names a status.md or findings.md field, the task-run retry prompt says the code is not at fault: fix only those fields, confirm the tree with `git status --porcelain` and keep the previous attempt's definition-of-done results.
- Process backlog P-014: the plan template marks definition-of-done commands expected to run over 2 minutes as `(long, ~N min)`. `context-impl.md` and `context-review.md` get a "Long commands" rule: run each one as its own background Bash call and wait for the completion notice, never sleep, poll the output or arm a Monitor. The implementer calls SubagentHandback exactly once and ignores late background notices.
- Process backlog P-016: an unused test binding is either asserted for the behavior it was created for or deleted, never kept alive with an existence check or a restatement of setup data. Rule added to `context-impl.md`.
- Process backlog P-017: for a sub-task whose plan.md is shared, task-prep reads the previous sub-task's Implementer report and review notes for "contract note" lines and adds them to the API contract section of every context file.

## 0.7.0

- Process backlog P-008: the implementer never picks a weaker product implementation because the test environment cannot exercise the right one (jsdom lacking an API, for example). It adapts the tests or reports a blocker with the options. Rule added to `agents/task-implementer.md` and `context-impl.md`.
- Process backlog P-009: the definition-of-done stderr rule ignores the package manager's echo of the script line (pnpm's `$ <command>`), which pnpm always writes to stderr. Reworded in `context-impl.md`, `context-review.md` and check 8 of `validation-checklist.md`.
- Process backlog P-010: tests must assert every value the AC text names, use exact equality where the AC says equal or exactly, and build fixtures from the AC's own values. Rule added to `context-tests.md` and `context-impl.md`.
- Process backlog P-011: `transcripts.py` no longer counts a tool_use twice when a subagent transcript logs the same id twice, so tool counts, search streaks and repeated-call counts are correct.

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
