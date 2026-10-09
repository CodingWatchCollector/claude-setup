#!/usr/bin/env bash
# Resolves a path (main checkout or worktree) to its project and repository facts.
# Usage: bash resolve-repo.sh <path>
# Works with normal clones, worktrees placed anywhere, and bare-repo worktree setups.

set -u
P="${1:-}"
[ -n "$P" ] || { echo "usage: resolve-repo.sh <path>"; exit 2; }
cd "$P" 2>/dev/null || { echo "error: no such directory: $P"; exit 1; }

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "error: not inside a git repository: $P"; exit 1; }
cd "$TOP"
COMMON_REL="$(git rev-parse --git-common-dir)"
COMMON="$(cd "$COMMON_REL" && pwd)"

# Main repository: parent of .git for normal clones, the bare dir itself for bare setups.
if [ "$(basename "$COMMON")" = ".git" ]; then
  MAIN="$(dirname "$COMMON")"
else
  MAIN="$COMMON"
fi
PROJECT="$(basename "$MAIN" .git)"
[ "$TOP" = "$MAIN" ] && WT="no" || WT="yes"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
HEAD="$(git rev-parse HEAD 2>/dev/null)"
DIRTY="$(git status --porcelain | wc -l | tr -d ' ')"

# Tool or process files inside the repository that git does not track.
TOOLS=""
for f in CLAUDE.md .claude .agents .omc; do
  if [ -e "$TOP/$f" ] && ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    TOOLS="$TOOLS $f"
  fi
done

echo "project: $PROJECT"
echo "repo: $TOP"
echo "main_repo: $MAIN"
echo "worktree: $WT"
echo "branch: $BRANCH"
echo "head: $HEAD"
echo "uncommitted: $DIRTY"
echo "tool_files_in_repo:${TOOLS:- none}"
