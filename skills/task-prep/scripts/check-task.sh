#!/usr/bin/env bash
# Checks the artifacts produced by task-prep for one task.
# Usage: bash check-task.sh <project> <TASK-ID>   (run from the workspace root or below it)
# Exit code: 0 if no FAIL, 1 otherwise.

set -u
PROJECT="${1:-}"; ID="${2:-}"
if [ -z "$PROJECT" ] || [ -z "$ID" ]; then echo "usage: check-task.sh <project> <TASK-ID>"; exit 2; fi

# Workspace root: nearest ancestor containing .agents/tasks
WS="$(pwd)"
while [ "$WS" != "/" ] && [ ! -d "$WS/.agents/tasks" ]; do WS="$(dirname "$WS")"; done
[ -d "$WS/.agents/tasks" ] || { echo "FAIL workspace root with .agents/tasks not found above $(pwd)"; exit 1; }

DIR="$WS/.agents/tasks/$PROJECT/$ID"
FAILS=0
ok()   { echo "OK   $1"; }
bad()  { echo "FAIL $1"; FAILS=$((FAILS+1)); }
warn() { echo "WARN $1"; }

echo "workspace: $WS"
[ -d "$DIR" ] || { bad "task dir missing: .agents/tasks/$PROJECT/$ID"; exit 1; }

# Required files
for f in plan.md status.md context-impl.md context-review.md; do
  [ -s "$DIR/$f" ] && ok "$f present" || bad "$f missing or empty"
done

# Repository recorded and valid
REPO="$(grep -E '^repo:' "$DIR/status.md" 2>/dev/null | head -1 | sed -E 's/^repo:[[:space:]]*//')"
if [ -n "$REPO" ] && [ -d "$REPO" ] && git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  ok "repo $REPO"
else
  bad "repo missing in status.md or not a git repository: '$REPO'"; REPO=""
fi

# Repo belongs to the project
if [ -n "$REPO" ]; then
  C="$(cd "$REPO" && cd "$(git rev-parse --git-common-dir)" && pwd)"
  [ "$(basename "$C")" = ".git" ] && M="$(dirname "$C")" || M="$C"
  [ "$(basename "$M" .git)" = "$PROJECT" ] && ok "repo belongs to project $PROJECT" || bad "repo belongs to project $(basename "$M" .git), not $PROJECT"
fi

# Approval
grep -qE '^approved:[[:space:]]*yes' "$DIR/plan.md" 2>/dev/null && ok "plan approved" || bad "plan.md not marked approved: yes"

# Acceptance tester consistency
if grep -qiE '^needed:[[:space:]]*yes' "$DIR/plan.md" 2>/dev/null; then
  [ -s "$DIR/context-tests.md" ] && ok "tester needed and context-tests.md present" || bad "tester needed but context-tests.md missing"
else
  [ -e "$DIR/context-tests.md" ] && warn "context-tests.md exists but plan says tester not needed" || ok "no acceptance tester, as planned"
fi

# base_commit recorded and valid in that repo
BASE="$(grep -oE '^base_commit:[[:space:]]*[0-9a-f]{7,40}' "$DIR/status.md" 2>/dev/null | awk '{print $2}')"
if [ -n "$BASE" ] && [ -n "$REPO" ] && git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null; then
  ok "base_commit $BASE exists"
else
  bad "base_commit missing or not a commit in the repo"; BASE=""
fi

# Prep steps done
for s in prep:context prep:plan prep:validation prep:approval prep:context-files; do
  grep -qE "\|[[:space:]]*$s[[:space:]]*\|[[:space:]]*done[[:space:]]*\|" "$DIR/status.md" \
    && ok "status $s done" || bad "status $s not done"
done

# Leftover template placeholders
LEFT="$(grep -nE '<TASK-ID>|<PROJECT>|<REPO>|<MAIN_REPO>|<TASK_DIR>|<TDD_SKILL>|<REVIEW_SKILL>|<sha>|<branch>|<title>|<paths \| none>' "$DIR"/*.md 2>/dev/null)"
[ -z "$LEFT" ] && ok "no template placeholders left" || { bad "template placeholders left:"; echo "$LEFT" | sed 's/^/     /'; }

# Context files state the repository and the task dir
for f in "$DIR"/context-*.md; do
  [ -e "$f" ] || continue
  n="$(basename "$f")"
  if [ -n "$REPO" ]; then grep -qF "$REPO" "$f" && ok "$n states the repository path" || bad "$n does not state the repository path $REPO"; fi
  grep -qF "$DIR" "$f" && ok "$n states the task dir" || bad "$n does not state the task dir $DIR"
done

# Commands in briefs must not write to the repository
WRITE='git add|git stash|git checkout|git reset|git commit|git restore|git clean|npm install|npm i |yarn add|pnpm add'
RW="$(grep -nE "$WRITE" "$DIR/context-review.md" 2>/dev/null | grep -v 'no `git add`')"
[ -z "$RW" ] && ok "context-review.md has no repository-writing commands" || { bad "context-review.md contains repository-writing commands (the reviewer must stay read-only):"; echo "$RW" | sed 's/^/     /'; }
for f in context-impl.md context-tests.md; do
  [ -e "$DIR/$f" ] || continue
  RW="$(grep -nE "$WRITE" "$DIR/$f" | grep -v 'no `git add`')"
  [ -z "$RW" ] || { warn "$f contains repository-writing commands, check they are intended:"; echo "$RW" | sed 's/^/     /'; }
done

# Context files must be self-contained
REFS="$(grep -niE 'see above|as discussed|as mentioned earlier|discussed earlier|in (this|the) conversation|див\. вище|як обговорювали|voir ci-dessus|comme discut' "$DIR"/context-*.md 2>/dev/null)"
[ -z "$REFS" ] && ok "context files do not refer to the chat" || { bad "context files refer to the chat:"; echo "$REFS" | sed 's/^/     /'; }

# Acceptance criteria present in plan and carried into impl/review contexts
if grep -qE 'AC-1' "$DIR/plan.md" 2>/dev/null; then
  for f in context-impl.md context-review.md; do
    grep -q 'AC-1' "$DIR/$f" 2>/dev/null && ok "$f contains acceptance criteria" || bad "$f has no acceptance criteria (AC-1 not found)"
  done
else
  bad "plan.md has no acceptance criteria (AC-1 not found)"
fi

# Repository untouched by planning
if [ -n "$REPO" ]; then
  for f in CLAUDE.md .claude .agents .omc; do
    if [ -e "$REPO/$f" ] && ! git -C "$REPO" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      bad "untracked tool file inside repository: $f"
    fi
  done
  if [ -n "$BASE" ]; then
    OUT="$( { git -C "$REPO" diff --name-only "$BASE" -- ; git -C "$REPO" ls-files --others --exclude-standard; } | sort -u)"
    [ -z "$OUT" ] && ok "repository unchanged since base_commit" || { warn "repository changed since base_commit (task-prep must not write there; check whether these are yours):"; echo "$OUT" | sed 's/^/     /'; }
  fi
fi

# Workspace
[ -f "$WS/.agents/lessons/README.md" ] && ok "lessons base initialized" || warn ".agents/lessons/README.md missing"

echo
[ "$FAILS" -eq 0 ] && echo "RESULT: OK" || echo "RESULT: $FAILS FAIL(s)"
[ "$FAILS" -eq 0 ]
