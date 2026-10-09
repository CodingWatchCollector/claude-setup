# claude-setup

Skills and agents for the task-prep / task-run / task-retro workflow.

- `skills/`, `agents/`: linked into `~/.claude/`
- `VERSION`, `CHANGELOG.md`: bump both with every change

## Install or update (each machine)

    git pull && bash install.sh

Existing non-matching files are moved aside as `*.bak-<timestamp>`, not overwritten.
Override the Claude folder with `CLAUDE_DIR` (default `~/.claude`).

## Changing things

Edit through the symlinks or in the repo, then add a CHANGELOG entry, bump VERSION and commit.
When a change makes results worse, `git log -p skills/<name>` shows what moved; `git revert` undoes it.
Project-specific lessons, task folders and `skills/synced` are intentionally not tracked.
