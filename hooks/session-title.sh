#!/usr/bin/env bash
# UserPromptSubmit hook: names the session after the first task-* command typed in it,
# keeping the command and its <project> <TASK-ID> arguments only:
# "/task-prep fitness-tracker mvp-a <task text...>" -> "/task-prep fitness-tracker mvp-a".
# Later prompts leave the name alone.
# Never blocks a prompt: any failure exits 0 without output.
set -uo pipefail

in="$(cat)" || exit 0
prompt="$(jq -r '.prompt // empty' <<<"$in" 2>/dev/null)" || exit 0
sid="$(jq -r '.session_id // empty' <<<"$in" 2>/dev/null)" || exit 0
[ -n "$sid" ] || exit 0

# Every task-* skill takes <project> <TASK-ID> first (task-retro: <project> --pending);
# flags, task text and comments that follow stay out of the name.
read -r -a words <<<"$(printf '%s' "$prompt" | tr '\n\t' '  ')"
[[ "${words[0]:-}" =~ ^/task-(prep|run|manual-review|retro)$ ]] || exit 0
title="$(printf '%s ' "${words[@]:0:3}" | sed 's/ $//' | cut -c1-100)"

state="${XDG_STATE_HOME:-$HOME/.local/state}/claude-session-title"
mkdir -p "$state" 2>/dev/null || exit 0
mark="$state/$sid"
[ -e "$mark" ] && exit 0
: >"$mark" 2>/dev/null || exit 0
find "$state" -type f -mtime +90 -delete 2>/dev/null

jq -nc --arg t "$title" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
