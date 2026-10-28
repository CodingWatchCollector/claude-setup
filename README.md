# claude-setup

My Claude Code workflow for working on real tasks with AI agents, in three steps:

- **task-prep**: turns a task into a plan with testable acceptance criteria, has it checked by a separate plan-reviewer agent, and waits for my approval before any code is written
- **task-run**: runs fresh agents to write acceptance tests, implement and review, loops through fix and review rounds, and checks every handoff with a deterministic gate script
- **task-retro**: turns review findings into lessons for future planning and into process fixes, and records metrics, so the next task goes better

It also includes `unslop` (removes AI writing patterns from prose) and `wiki` (a markdown knowledge base that grows across sessions).

## What's inside

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
