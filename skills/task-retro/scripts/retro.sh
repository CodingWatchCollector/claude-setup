#!/usr/bin/env bash
# Data extraction and small writes for task-retro.
# Usage: bash retro.sh <project> <TASK-ID> <command> [arg]
#   data             task facts and a normalized findings table (TSV)
#   lessons-index    existing lessons for <project> and _shared (TSV)
#   backlog-index    existing process backlog entries (TSV)
#   next-id <folder> next free lesson ID in .agents/lessons/<folder>/ (folder: <project> or _shared)
#   next-pid         next free process backlog ID
#   record-metrics   writes or replaces this task's line in .agents/metrics.csv
#   set-done         marks the retro row of the status table as done
#   pending          lists tasks of <project> with an APPROVE verdict and retro not done (TASK-ID: use -)
# Run from the workspace root or below it. Tolerates older findings formats.

set -u
PROJECT="${1:-}"; ID="${2:-}"; CMD="${3:-}"; ARG="${4:-}"
if [ -z "$PROJECT" ] || [ -z "$ID" ] || [ -z "$CMD" ]; then sed -n '2,13p' "$0"; exit 2; fi

WS="$(pwd)"
while [ "$WS" != "/" ] && [ ! -d "$WS/.agents/tasks" ]; do WS="$(dirname "$WS")"; done
[ -d "$WS/.agents/tasks" ] || { echo "FAIL workspace with .agents/tasks not found above $(pwd)"; exit 1; }
LESSONS="$WS/.agents/lessons"; BACKLOG="$WS/.agents/process-backlog.md"; METRICS="$WS/.agents/metrics.csv"
DIR="$WS/.agents/tasks/$PROJECT/$ID"; ST="$DIR/status.md"; FD="$DIR/findings.md"; PL="$DIR/plan.md"

state() { grep -E "^\|[[:space:]]*$2[[:space:]]*\|" "$1" 2>/dev/null | head -1 | awk -F'|' '{gsub(/[[:space:]]/,"",$3); print $3}'; }
verdict_of() { grep -E '^verdict:[[:space:]]*(APPROVE|CHANGES_REQUESTED)' "$1" 2>/dev/null | tail -1 | awk '{print $2}'; }

# Normalized findings: id round severity class source axis status location problem
findings_tsv() {
  [ -f "$FD" ] || return 0
  awk -v OFS='\t' '
    function flush(){
      if(id!=""){
        ax=axis; if(ax==""){ ax=(loc ~ /(^|\/)\.agents\//) ? "process*" : "-" }
        print id, (r==""?"-":r), (sev==""?"-":sev), (cls==""?"-":cls), (src==""?"-":src), ax, (st==""?"open":st), (loc==""?"-":loc), prob
      }
      id=""; sev=""; cls=""; src=""; axis=""; st=""; loc=""; prob=""; inprob=0
    }
    /^round:[[:space:]]*[0-9]+/ { flush(); match($0,/[0-9]+/); r=substr($0,RSTART,RLENGTH); next }
    /^### F-/ { flush(); id=$2; next }
    /^## / || /^---[[:space:]]*$/ || /^verdict:/ { flush(); next }
    id=="" { next }
    /^severity:/ { sev=$2; next }
    /^class:/ { cls=$2; next }
    /^source:/ { src=$2; next }
    /^axis:/ { axis=$2; next }
    /^location:/ { sub(/^location:[[:space:]]*/,""); loc=$0; next }
    /^status:/ { s=$2; sub(/[^a-zA-Z-].*$/,"",s); sub(/-$/,"",s); st=tolower(s); next }
    /^problem:/ { sub(/^problem:[[:space:]]*/,""); prob=substr($0,1,110); next }
    END { flush() }' "$FD"
}

case "$CMD" in

data)
  [ -f "$ST" ] || { echo "FAIL no status.md in $DIR"; exit 1; }
  echo "task: $PROJECT/$ID"
  echo "repo: $(grep -E '^repo:' "$ST" | head -1 | sed -E 's/^repo:[[:space:]]*//')"
  echo "base_commit: $(grep -E '^base_commit:' "$ST" | head -1 | awk '{print $2}')"
  echo "mode: $(grep -E '^mode:' "$PL" 2>/dev/null | head -1 | awk '{print $2}')"
  echo "tester: $(grep -iE '^needed:' "$PL" 2>/dev/null | head -1 | awk '{print $2}')"
  echo "models: $(grep -E '^models:' "$ST" | head -1 | sed -E 's/^models:[[:space:]]*//')"
  RR="$(grep -oE '^round:[[:space:]]*[0-9]+' "$FD" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)"
  echo "review_rounds: ${RR:-0}"
  echo "verdict: $(verdict_of "$FD")"
  echo "retro: $(state "$ST" retro)"
  C="$(sed -n '/^## API contract/,/^## /p' "$PL" 2>/dev/null | grep -vE '^## |^<!--|^[[:space:]]*$|^- [A-Za-z /]+:[[:space:]]*$' | grep -viE '^[[:space:]]*none[[:space:]]*$' | head -1)"
  [ -n "$C" ] && echo "api_contract: yes" || echo "api_contract: none"
  echo
  printf 'id\tround\tseverity\tclass\tsource\taxis\tstatus\tlocation\tproblem\n'
  findings_tsv ;;

lessons-index)
  printf 'lesson\tfile\toccurrences\ttitle\ttrigger\n'
  for folder in "$PROJECT" _shared; do
    for f in "$LESSONS/$folder"/*.md; do
      [ -f "$f" ] || continue
      awk -v OFS='\t' -v fo="$folder" -v fn="$(basename "$f")" '
        function flush(){ if(i!="") print fo "/" i, fn, (o==""?"-":o), t, tr; i="" }
        /^## L-[0-9]+/ { flush(); i=$2; sub(/:$/,"",i); t=$0; sub(/^## L-[0-9]+:[[:space:]]*/,"",t); tr=""; o=""; next }
        /^trigger:/ { sub(/^trigger:[[:space:]]*/,""); tr=$0; next }
        /^occurrences:/ { o=$2; next }
        END{ flush() }' "$f"
    done
  done ;;

backlog-index)
  printf 'id\tstatus\tseen\ttitle\n'
  [ -f "$BACKLOG" ] && awk -v OFS='\t' '
    function flush(){ if(i!="") print i, (s==""?"open":s), (n==""?"1":n), t; i="" }
    /^## P-[0-9]+/ { flush(); i=$2; sub(/:$/,"",i); t=$0; sub(/^## P-[0-9]+:[[:space:]]*/,"",t); s=""; n=""; next }
    /^status:/ { s=$2; next } /^seen:/ { n=$2; next }
    END{ flush() }' "$BACKLOG" ;;

next-id)
  F="${ARG:-$PROJECT}"; M="$(cat "$LESSONS/$F"/*.md 2>/dev/null | grep -oE '^## L-[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1)"
  printf 'L-%03d\n' $(( 10#${M:-0} + 1 )) ;;

next-pid)
  M="$(grep -oE '^## P-[0-9]+' "$BACKLOG" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)"
  printf 'P-%03d\n' $(( 10#${M:-0} + 1 )) ;;

record-metrics)
  [ -f "$ST" ] || { echo "FAIL no status.md in $DIR"; exit 1; }
  T="$(findings_tsv)"
  cnt() { echo "$T" | awk -F'\t' "$1" | grep -c . || true; }
  RR="$(grep -oE '^round:[[:space:]]*[0-9]+' "$FD" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)"
  MOD="$(grep -E '^models:' "$ST" | head -1 | sed -E 's/^models:[[:space:]]*//' | tr ',' ';')"
  LINE="$(date +%F),$PROJECT,$ID,$(grep -E '^mode:' "$PL" 2>/dev/null | head -1 | awk '{print $2}'),${RR:-0},$(verdict_of "$FD"),$(cnt 'NF>1{print}'),$(cnt '$3=="blocking"'),$(cnt '$7=="open"'),$(cnt '$5=="plan"'),$(cnt '$5=="implementation"'),$(cnt '$5=="tests"'),$(cnt '$6 ~ /^process/'),$(cnt '$4=="pattern"'),$(grep -iE '^needed:' "$PL" 2>/dev/null | head -1 | awk '{print $2}'),${MOD:-unknown}"
  HDR="date,project,task,mode,review_rounds,verdict,findings,blocking,open_after_review,src_plan,src_implementation,src_tests,process,pattern,tester,models"
  [ -s "$METRICS" ] || echo "$HDR" > "$METRICS"
  TMP="$(mktemp)"; awk -F',' -v p="$PROJECT" -v t="$ID" '!($2==p && $3==t)' "$METRICS" > "$TMP" && mv "$TMP" "$METRICS"
  echo "$LINE" >> "$METRICS"; echo "OK   $LINE" ;;

set-done)
  grep -qE '^\|[[:space:]]*retro[[:space:]]*\|' "$ST" || { echo "FAIL no retro row in status table"; exit 1; }
  TMP="$(mktemp)"
  awk -F'|' -v OFS='|' '{ k=$2; gsub(/[[:space:]]/,"",k) } k=="retro" && NF>=4 { $3=" done " } { print }' "$ST" > "$TMP" && mv "$TMP" "$ST"
  echo "OK   retro -> done" ;;

pending)
  for d in "$WS/.agents/tasks/$PROJECT"/*/; do
    [ -f "$d/status.md" ] || continue
    [ "$(verdict_of "$d/findings.md")" = "APPROVE" ] || continue
    [ "$(state "$d/status.md" retro)" = "done" ] && continue
    basename "$d"
  done ;;

*) sed -n '2,13p' "$0"; exit 2 ;;
esac
