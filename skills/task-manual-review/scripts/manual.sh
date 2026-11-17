#!/usr/bin/env bash
# Adds a manual review section to findings.md of a task-run task.
# Usage: bash manual.sh <project> <TASK-ID> <command>
#   info     latest review round, next finding id, verdict, repo, warnings
#   append   reads finding blocks (### F-<n> ...) from stdin, validates them and
#            appends them as "## Manual review (round <n>)" for the latest round
# Run from the workspace root or below it.
# Exit codes: 0 ok, 1 fail, 2 usage error

set -u
PROJECT="${1:-}"; ID="${2:-}"; CMD="${3:-}"
if [ -z "$PROJECT" ] || [ -z "$ID" ] || [ -z "$CMD" ]; then sed -n '2,9p' "$0"; exit 2; fi

WS="$(pwd)"
while [ "$WS" != "/" ] && [ ! -d "$WS/.agents/tasks" ]; do WS="$(dirname "$WS")"; done
[ -d "$WS/.agents/tasks" ] || { echo "FAIL workspace with .agents/tasks not found above $(pwd)"; exit 1; }
DIR="$WS/.agents/tasks/$PROJECT/$ID"; ST="$DIR/status.md"; FD="$DIR/findings.md"
[ -d "$DIR" ] || { echo "FAIL no task folder $DIR"; exit 1; }
[ -s "$FD" ] || { echo "FAIL no findings.md in $DIR: run the automatic review first (task-run)"; exit 1; }

field() { [ -f "$ST" ] && grep -E "^$1:" "$ST" | head -1 | sed -E "s/^$1:[[:space:]]*//"; }
review_round() { r="$(grep -oE '^round:[[:space:]]*[0-9]+' "$FD" | tail -1 | grep -oE '[0-9]+')"; echo "${r:-0}"; }
impl_round() {
  [ -f "$ST" ] || { echo "?"; return; }
  r="$(awk 'index($0,"## Implementer report")==1{f=1;next} /^## /{f=0} f' "$ST" | grep -oE '^round:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')"
  echo "${r:-0}"
}
verdict() { grep -E '^verdict:[[:space:]]*(APPROVE|CHANGES_REQUESTED)[[:space:]]*$' "$FD" | tail -1 | awk '{print $2}'; }
max_id() { grep -oE '^### F-[0-9]+' "$FD" | grep -oE '[0-9]+' | sort -n | tail -1; }

R="$(review_round)"; I="$(impl_round)"; V="$(verdict)"; M="$(max_id)"; NEXT=$(( ${M:-0} + 1 ))
[ "$R" -gt 0 ] || { echo "FAIL findings.md has no review round yet"; exit 1; }
grep -qE "^## Round $R[[:space:]]*$" "$FD" || { echo "FAIL latest round $R has no '## Round $R' section from the automatic reviewer"; exit 1; }
if [ "$I" != "?" ] && [ "$I" != "$R" ]; then
  echo "FAIL implementation round $I is ahead of review round $R: add manual findings after review round $I is recorded"; exit 1
fi

case "$CMD" in

info)
  echo "round: $R"
  echo "next_id: F-$NEXT"
  echo "verdict: ${V:-none}"
  echo "repo: $(field repo)"
  echo "base_commit: $(field base_commit)"
  echo "manual_sections_in_round: $(grep -cE "^## Manual review \(round $R\)" "$FD")"
  D="$(grep -E "^nonblocking decision \(round $R\):" "$FD" | tail -1)"
  [ -n "$D" ] && echo "WARN '$D' already recorded: it also covers new non-blocking findings of round $R"
  exit 0 ;;

append)
  IN="$(cat)"
  [ -n "$IN" ] || { echo "FAIL nothing on stdin"; exit 1; }
  ERR="$(printf '%s\n' "$IN" | awk -v expect="$NEXT" '
    function e(m){ print "FAIL " m; bad=1 }
    function check(  k){
      if(id=="") return
      if(f["axis"] !~ /^(spec|standards|process)$/) e(id " axis must be spec, standards or process")
      if(f["severity"] !~ /^(blocking|non-blocking)$/) e(id " severity must be blocking or non-blocking")
      if(f["class"] !~ /^(one-off|pattern)$/) e(id " class must be one-off or pattern")
      if(f["source"] !~ /^(plan|implementation|tests)$/) e(id " source must be plan, implementation or tests")
      if(f["status"] != "open") e(id " status must be open")
      if(f["origin"] != "manual") e(id " origin must be manual")
      split("lesson location problem fix", req, " ")
      for(k in req) if(f[req[k]] == "") e(id " " req[k] " is missing or empty")
    }
    /^### F-[0-9]+[[:space:]]*$/ {
      check(); id=$2; n=substr(id,3)+0; split("", f)
      if(n != expect) e(id " should be F-" expect " (ids continue across rounds)")
      expect++; ids++; next
    }
    /^(## |verdict:|round:)/ { e("input must hold only finding blocks, found: " $0); next }
    id=="" && NF { e("text before the first finding: " $0); next }
    id!="" && match($0, /^[a-z_]+:/) {
      k=substr($0, 1, RLENGTH-1); v=substr($0, RLENGTH+1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); f[k]=v
    }
    END{ check(); if(ids==0) e("no finding blocks (### F-<n>) on stdin"); exit bad }')"
  [ $? -eq 0 ] || { echo "$ERR"; exit 1; }
  FLIP=""
  if [ "$V" = "APPROVE" ] && printf '%s\n' "$IN" | grep -qE '^severity:[[:space:]]*blocking[[:space:]]*$'; then
    FLIP="verdict: CHANGES_REQUESTED"
  fi
  { echo; echo "## Manual review (round $R)"; echo; echo "round: $R"; echo "reviewer: manual"
    [ -n "$FLIP" ] && echo "$FLIP"
    echo; printf '%s\n' "$IN"; } >> "$FD"
  N="$(printf '%s\n' "$IN" | grep -cE '^### F-')"
  echo "OK   $N manual finding(s) appended to round $R: F-$NEXT..F-$((NEXT+N-1))"
  [ -n "$FLIP" ] && echo "OK   verdict of round $R changed from APPROVE to CHANGES_REQUESTED (manual blocking findings)"
  exit 0 ;;

*) sed -n '2,9p' "$0"; exit 2 ;;
esac
