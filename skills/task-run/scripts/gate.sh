#!/usr/bin/env bash
# Deterministic checks and state updates for task-run.
# Usage: bash gate.sh <project> <TASK-ID> <command> [arg]
#   start                 task is ready to execute (MANUAL=1: missing agents are warnings)
#   next                  prints the next action: tests | impl <n> | review <n> | done | needs-user | limit
#   set <step> <state>    sets a row of the status table (pending|in-progress|done|blocked|n/a)
#   after-tests           acceptance tester finished correctly
#   after-impl <n>        implementer finished round n correctly
#   snapshot              records the repository state before a review
#   record-findings <n>   appends review round n, read from stdin, to findings.md
#   after-review <n>      reviewer finished round n correctly, prints the verdict
#   summary               short final summary
# Run from the workspace root or below it.
# Exit codes: 0 pass, 1 fail, 2 usage error, 3 needs the user (blocked, disputed finding)
# Env: MAX_ROUNDS (default 3)

set -u
PROJECT="${1:-}"; ID="${2:-}"; CMD="${3:-}"; ARG="${4:-}"; ARG2="${5:-}"
if [ -z "$PROJECT" ] || [ -z "$ID" ] || [ -z "$CMD" ]; then sed -n '2,15p' "$0"; exit 2; fi
MAX_ROUNDS="${MAX_ROUNDS:-3}"

WS="$(pwd)"
while [ "$WS" != "/" ] && [ ! -d "$WS/.agents/tasks" ]; do WS="$(dirname "$WS")"; done
[ -d "$WS/.agents/tasks" ] || { echo "FAIL workspace with .agents/tasks not found above $(pwd)"; exit 1; }
DIR="$WS/.agents/tasks/$PROJECT/$ID"; ST="$DIR/status.md"; FD="$DIR/findings.md"
[ -f "$ST" ] || { echo "FAIL no status.md in $DIR"; exit 1; }

FAILS=0; NEEDS=0
ok()   { echo "OK   $1"; }
bad()  { echo "FAIL $1"; FAILS=$((FAILS+1)); }
need() { echo "USER $1"; NEEDS=$((NEEDS+1)); }
warn() { echo "WARN $1"; }
finish() { if [ "$FAILS" -gt 0 ]; then echo "RESULT: FAIL"; exit 1; elif [ "$NEEDS" -gt 0 ]; then echo "RESULT: NEEDS_USER"; exit 3; else echo "RESULT: OK"; exit 0; fi; }

field() { grep -E "^$1:" "$ST" | head -1 | sed -E "s/^$1:[[:space:]]*//"; }
state() { grep -E "^\|[[:space:]]*$1[[:space:]]*\|" "$ST" | head -1 | awk -F'|' '{gsub(/[[:space:]]/,"",$3); print $3}'; }
section() { awk -v h="$1" 'index($0,"## " h)==1{f=1;next} /^## /{f=0} f' "$ST"; }
impl_round() { r="$(section "Implementer report" | grep -oE '^round:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')"; echo "${r:-0}"; }
review_round() { r=""; [ -f "$FD" ] && r="$(grep -oE '^round:[[:space:]]*[0-9]+' "$FD" | tail -1 | grep -oE '[0-9]+')"; echo "${r:-0}"; }
verdict() { [ -f "$FD" ] && grep -E '^verdict:[[:space:]]*(APPROVE|CHANGES_REQUESTED)[[:space:]]*$' "$FD" | tail -1 | awk '{print $2}'; }
last_round_block() { awk '/^## Round /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$FD"; }
# Prints "<id> <severity> <status> <round>" for every finding.
findings() {
  [ -f "$FD" ] || return 0
  awk '
    function flush(){ if(id!="") print id, (sev==""?"-":sev), (st==""?"open":st), (r==""?"0":r); id="" }
    /^round:[[:space:]]*[0-9]+/{ flush(); match($0,/[0-9]+/); r=substr($0,RSTART,RLENGTH); next }
    /^### F-/{ flush(); id=$2; sev=""; st=""; next }
    /^## /{ flush(); next }
    /^severity:/{ sev=$2 }
    /^status:/{ st=$2 }
    END{ flush() }' "$FD"
}
# Writes the Notes cell of a status table row: set_notes <step> <text>
set_notes() {
  TMP="$(mktemp)"
  awk -F'|' -v OFS='|' -v s="$1" -v t="$2" '
    { k=$2; gsub(/[[:space:]]/,"",k) }
    k==s && NF>=4 { $4=" " t " " }
    { print }' "$ST" > "$TMP" && mv "$TMP" "$ST"
}
rules_value() { section "Implementer report" | grep -E '^rules decided:' | head -1 | sed -E 's/^rules decided:[[:space:]]*//'; }
rule_ids() { section "Implementer report" | grep -oE '^- R-[0-9]+' | sed 's/^- //'; }
# Rule IDs of the report not confirmed for round $1 in status.md
unconfirmed_rules() {
  RV="$(rules_value)"; [ -z "$RV" ] || [ "$RV" = "none" ] && return 0
  CONF="$(grep -E "^rules confirmed \(round $1\):" "$ST" | sed -E 's/^[^:]*\):[[:space:]]*//' | tr ',' ' ')"
  for r in $(rule_ids); do echo " $CONF " | grep -qE "(^|[[:space:]])$r([[:space:]]|$)" || echo "$r"; done
}
nb_decision() { [ -f "$FD" ] && grep -E "^nonblocking decision \(round $1\):[[:space:]]*(fix|leave)" "$FD" | tail -1 | awk '{print $NF}'; }
open_nb_in_round() { findings | awk -v r="$1" '$4==r && $2=="non-blocking" && $3=="open"{print $1}' | tr '\n' ' ' | sed 's/ $//'; }

repo_state_hash() {
  ( cd "$REPO" && { git diff "$BASE"; git ls-files --others --exclude-standard -z | xargs -0 -I{} sh -c 'echo "== {}"; cat "{}"'; } ) | git hash-object --stdin
}
tool_files() {
  for f in CLAUDE.md .claude .agents .omc; do
    if [ -e "$REPO/$f" ] && ! git -C "$REPO" ls-files --error-unmatch "$f" >/dev/null 2>&1; then echo "$f"; fi
  done
}
changed_files() { { git -C "$REPO" diff --name-only "$BASE" -- ; git -C "$REPO" ls-files --others --exclude-standard; } | sort -u; }

REPO="$(field repo)"; BASE="$(field base_commit)"

case "$CMD" in

start)
  grep -qE '^approved:[[:space:]]*yes' "$DIR/plan.md" 2>/dev/null && ok "plan approved" || bad "plan.md not approved"
  for f in context-impl.md context-review.md; do [ -s "$DIR/$f" ] && ok "$f present" || bad "$f missing"; done
  if grep -qiE '^needed:[[:space:]]*yes' "$DIR/plan.md" 2>/dev/null; then
    [ -s "$DIR/context-tests.md" ] && ok "context-tests.md present" || bad "tester needed but context-tests.md missing"
  fi
  [ "$(state prep:context-files)" = "done" ] && ok "task-prep finished" || bad "prep:context-files is not done, run task-prep first"
  if [ -n "$REPO" ] && git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then ok "repo $REPO"; else bad "repo not found: '$REPO'"; fi
  if [ -n "$BASE" ] && git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null; then ok "base_commit $BASE"; else bad "base_commit invalid"; fi
  LEFT="$(grep -lE '<TASK-ID>|<PROJECT>|<REPO>|<TASK_DIR>|<TDD_SKILL>|<REVIEW_SKILL>|<sha>' "$DIR"/context-*.md 2>/dev/null)"
  [ -z "$LEFT" ] && ok "no placeholders in context files" || bad "placeholders left in: $(echo $LEFT | xargs -n1 basename | tr '\n' ' ')"
  TF="$(tool_files)"; [ -z "$TF" ] && ok "no tool files in repo" || bad "tool files in repo: $(echo $TF)"
  N="$(changed_files | grep -c . || true)"; [ "$N" = "0" ] && ok "repo unchanged since base_commit" || warn "$N files changed since base_commit (fine when resuming)"
  USER_AG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents"; NEEDED="task-implementer task-reviewer"
  [ -s "$DIR/context-tests.md" ] && NEEDED="task-acceptance-tester $NEEDED"
  for a in $NEEDED; do
    f="$WS/.claude/agents/$a.md"; [ -f "$f" ] || f="$USER_AG/$a.md"
    if [ -f "$f" ]; then
      m="$(grep -E '^model:' "$f" | head -1 | sed -E 's/^model:[[:space:]]*//')"; k="$(grep -E '^skills:' "$f" | head -1 | sed -E 's/^skills:[[:space:]]*//')"
      ok "agent $a (model: ${m:-inherit}, skills: ${k:-none})"; MODELS="${MODELS:+$MODELS, }${a#task-}=${m:-inherit}"
    elif [ "${MANUAL:-0}" = "1" ]; then warn "agent $a missing (manual mode, not needed)"
    else bad "agent $a missing in $WS/.claude/agents and $USER_AG: install it or run task-run with --manual"; fi
  done
  [ "${MANUAL:-0}" = "1" ] && MODELS="manual"
  if [ -n "${MODELS:-}" ]; then
    TMP="$(mktemp)"
    if grep -qE '^models:' "$ST"; then sed -E "s/^models:.*/models: $MODELS/" "$ST" > "$TMP"
    else awk -v m="models: $MODELS" '{print} /^mode:/ && !d {print m; d=1}' "$ST" > "$TMP"; fi
    mv "$TMP" "$ST"
  fi
  finish ;;

next)
  if [ -s "$DIR/context-tests.md" ]; then
    case "$(state run:acceptance-tests)" in done|n/a) ;; blocked) echo "next: needs-user tests-blocked"; exit 0 ;; *) echo "next: tests"; exit 0 ;; esac
  fi
  [ "$(state run:implementation)" = "blocked" ] && { echo "next: needs-user impl-blocked"; exit 0; }
  if findings | awk '$3=="disputed"{f=1} END{exit !f}'; then echo "next: needs-user disputed"; exit 0; fi
  I="$(impl_round)"; R="$(review_round)"; V="$(verdict)"; IS="$(state run:implementation)"
  if [ "$I" -eq "$R" ]; then
    if [ "$R" -gt 0 ] && [ "$V" = "APPROVE" ]; then
      NB="$(open_nb_in_round "$R")"; D="$(nb_decision "$R")"
      if [ -z "$NB" ] || [ "$D" = "leave" ]; then echo "next: done"
      elif [ -z "$D" ]; then echo "next: needs-user nonblocking $NB"
      elif [ "$R" -ge "$MAX_ROUNDS" ]; then echo "next: limit $R"
      else echo "next: impl $((R+1))"; fi
    elif [ "$R" -ge "$MAX_ROUNDS" ]; then echo "next: limit $R"
    else echo "next: impl $((R+1))"; fi
  elif [ "$I" -eq $((R+1)) ]; then
    if [ "$IS" = "done" ]; then
      UR="$(unconfirmed_rules "$I" | tr '\n' ' ' | sed 's/ $//')"
      if [ -n "$UR" ]; then echo "next: needs-user rules $UR"; else echo "next: review $I"; fi
    else echo "next: impl $I"; fi
  else
    echo "next: needs-user inconsistent (implementer round $I, review round $R)"
  fi
  exit 0 ;;

set)
  STEP="$ARG"; NEW="$ARG2"
  case "$NEW" in pending|in-progress|done|blocked|n/a) ;; *) echo "FAIL invalid state '$NEW'"; exit 2 ;; esac
  grep -qE "^\|[[:space:]]*$STEP[[:space:]]*\|" "$ST" || { echo "FAIL no row '$STEP' in status table"; exit 1; }
  TMP="$(mktemp)"
  awk -F'|' -v OFS='|' -v s="$STEP" -v n="$NEW" '
    { k=$2; gsub(/[[:space:]]/,"",k) }
    k==s && NF>=4 { $3=" " n " " }
    { print }' "$ST" > "$TMP" && mv "$TMP" "$ST"
  echo "OK   $STEP -> $NEW"; exit 0 ;;

after-tests)
  S="$(state run:acceptance-tests)"
  [ "$S" = "blocked" ] && { need "acceptance tester is blocked, see Blockers in status.md"; finish; }
  [ "$S" = "done" ] && ok "run:acceptance-tests done" || bad "run:acceptance-tests is '$S', expected done"
  [ -n "$(section "Acceptance tester report" | grep -vE '^[[:space:]]*$|^<!--')" ] && ok "tester report written" || bad "Acceptance tester report is empty"
  NONTEST="$(changed_files | grep -vE '(\.(spec|test|e2e-spec)\.[cm]?[jt]sx?$)|(^|/)(test|tests|e2e|__tests__)/' || true)"
  [ -z "$NONTEST" ] && ok "tester changed only test files" || bad "tester changed non-test files: $(echo $NONTEST)"
  finish ;;

after-impl)
  N="$ARG"; [ -n "$N" ] || { echo "FAIL after-impl needs a round number"; exit 2; }
  S="$(state run:implementation)"
  if [ "$S" = "blocked" ]; then need "implementer is blocked, see Blockers in status.md"; finish
  elif [ "$S" = "done" ]; then ok "run:implementation done"
  else bad "run:implementation is '$S', expected done (implementer did not finish its 'When done' steps)"; fi
  I="$(impl_round)"; [ "$I" = "$N" ] && ok "report round $I" || bad "Implementer report says round $I, expected $N (stale report)"
  REP="$(section "Implementer report")"
  SK="$(echo "$REP" | grep -E '^skills invoked:' | head -1)"
  echo "$SK" | grep -qi 'tdd' && ok "tdd skill reported" || bad "report does not list a tdd skill in 'skills invoked:'"
  T="$(echo "$REP" | grep -oE '^tests:[[:space:]]*total=[0-9]+[[:space:]]+passed=[0-9]+[[:space:]]+failed=[0-9]+' | head -1)"
  if [ -z "$T" ]; then bad "report has no 'tests: total=N passed=N failed=N' line"
  else
    TOT="$(echo "$T" | sed -E 's/.*total=([0-9]+).*/\1/')"; FL="$(echo "$T" | sed -E 's/.*failed=([0-9]+).*/\1/')"
    [ "$TOT" -gt 0 ] && [ "$FL" -eq 0 ] && ok "tests: total=$TOT failed=0" || bad "tests line reports total=$TOT failed=$FL"
  fi
  RV="$(rules_value)"
  if [ -z "$RV" ]; then bad "report has no 'rules decided:' line"
  elif [ "$RV" = "none" ]; then ok "rules decided: none"
  elif [ -z "$(rule_ids)" ]; then bad "rules decided is '$RV' but no '- R-<k>:' lines follow"
  else
    UR="$(unconfirmed_rules "$N" | tr '\n' ' ' | sed 's/ $//')"
    [ -z "$UR" ] && ok "rules decided, all confirmed by the user" || need "rules decided without a plan decision, the user must confirm or reject: $UR"
  fi
  [ -n "$(changed_files)" ] && ok "repo has changes since base_commit" || bad "no changes in repo since base_commit"
  TF="$(tool_files)"; [ -z "$TF" ] && ok "no tool files in repo" || bad "tool files in repo: $(echo $TF)"
  PAT='(\b(it|test|describe)\.(skip|only)\(|\b(xit|xdescribe|xtest|fit|fdescribe)\()'
  FOCUS="$( { git -C "$REPO" diff "$BASE" | grep -E "^\+.*$PAT"; git -C "$REPO" ls-files --others --exclude-standard | while read -r f; do grep -HnE "$PAT" "$REPO/$f" 2>/dev/null; done; } || true)"
  [ -z "$FOCUS" ] && ok "no skipped or focused tests added" || { bad "skipped or focused tests added:"; echo "$FOCUS" | head -5 | sed 's/^/     /'; }
  if [ "$N" -gt 1 ]; then
    OPEN="$(findings | awk '$2=="blocking" && $3=="open"{print $1}' | tr '\n' ' ')"
    if [ "$(nb_decision $((N-1)))" = "fix" ]; then OPEN="$OPEN $(open_nb_in_round $((N-1)))"; OPEN="$(echo $OPEN)"; fi
    DISP="$(findings | awk '$3=="disputed"{print $1}' | tr '\n' ' ')"
    [ -z "$OPEN" ] && ok "no open findings left to fix" || bad "findings still open: $OPEN"
    [ -n "$DISP" ] && need "disputed findings need a decision: $DISP"
  fi
  finish ;;

record-findings)
  N="$ARG"; [ -n "$N" ] || { echo "FAIL record-findings needs a round number"; exit 2; }
  IN="$(cat)"
  [ -n "$IN" ] || { echo "FAIL nothing on stdin"; exit 1; }
  echo "$IN" | grep -qE "^## Round $N[[:space:]]*$" || { echo "FAIL input has no '## Round $N' header"; exit 1; }
  echo "$IN" | grep -qE "^round:[[:space:]]*$N[[:space:]]*$" || { echo "FAIL input has no 'round: $N' line"; exit 1; }
  if [ -f "$FD" ] && grep -qE "^## Round $N[[:space:]]*$" "$FD"; then echo "FAIL findings.md already contains round $N"; exit 1; fi
  { [ -s "$FD" ] && echo; echo "$IN"; } >> "$FD"
  echo "OK   round $N appended to findings.md"; exit 0 ;;

snapshot)
  repo_state_hash > "$DIR/.review-snapshot" && echo "OK   snapshot saved"; exit 0 ;;

after-review)
  N="$ARG"; [ -n "$N" ] || { echo "FAIL after-review needs a round number"; exit 2; }
  [ -f "$FD" ] || { bad "findings.md missing"; finish; }
  R="$(review_round)"; [ "$R" = "$N" ] && ok "findings round $R" || bad "findings latest round is $R, expected $N"
  [ "$R" = "$N" ] && set_notes run:review "rounds: $N"
  BLK="$(last_round_block)"
  VC="$(echo "$BLK" | grep -cE '^verdict:[[:space:]]*(APPROVE|CHANGES_REQUESTED)[[:space:]]*$' || true)"
  [ "$VC" = "1" ] && ok "one verdict in round $N" || bad "round $N must have exactly one verdict line (APPROVE or CHANGES_REQUESTED), found $VC"
  V="$(verdict)"
  echo "$BLK" | grep -E '^skills invoked:' | grep -qi 'review' && ok "review skill reported" || bad "round $N does not list a review skill in 'skills invoked:'"
  OPEN="$(findings | awk '$2=="blocking" && $3=="open"{print $1}' | tr '\n' ' ')"
  if [ "$V" = "CHANGES_REQUESTED" ]; then [ -n "$OPEN" ] && ok "open blocking findings: $OPEN" || bad "CHANGES_REQUESTED without open blocking findings"; fi
  if [ "$V" = "APPROVE" ]; then [ -z "$OPEN" ] && ok "no open blocking findings" || bad "APPROVE with open blocking findings: $OPEN"; fi
  if [ -f "$DIR/.review-snapshot" ]; then
    [ "$(repo_state_hash)" = "$(cat "$DIR/.review-snapshot")" ] && ok "reviewer did not change the repo" || bad "repository changed during review"
  else warn "no snapshot, cannot verify the reviewer left the code untouched"; fi
  echo "verdict: ${V:-none}"
  finish ;;

summary)
  echo "task: $PROJECT/$ID"
  echo "rounds: implementation $(impl_round), review $(review_round), verdict $(verdict)"
  if [ -f "$FD" ]; then
    awk '/^### F-/{n++} /^severity:/{s[$2]++} /^class:/{c[$2]++} /^source:/{o[$2]++}
      END{ printf "findings: %d", n; for(k in s) printf ", %s=%d", k, s[k]; print "";
           printf "class:"; for(k in c) printf " %s=%d", k, c[k]; print "";
           printf "source:"; for(k in o) printf " %s=%d", k, o[k]; print "" }' "$FD"
  fi
  echo "diff:"; git -C "$REPO" diff --stat "$BASE" | tail -1 | sed 's/^/  /'
  U="$(git -C "$REPO" ls-files --others --exclude-standard | grep -c . || true)"; echo "  untracked files: $U"
  exit 0 ;;

*) sed -n '2,15p' "$0"; exit 2 ;;
esac
