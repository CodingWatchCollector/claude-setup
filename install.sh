#!/usr/bin/env bash
# Link this repo's skills, agents and hooks into place and register the hooks
# in settings.json. Needs jq.
# Usage: bash install.sh
# Env:   CLAUDE_DIR (default ~/.claude)
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="${CLAUDE_DIR:-$HOME/.claude}"
stamp="$(date +%Y%m%d-%H%M%S)"

link() { # link <source in repo> <target>
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ ! -L "$dst" ] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
      rm -rf "$dst"
    else
      mv "$dst" "$dst.bak-$stamp"
      echo "backed up $dst -> $dst.bak-$stamp"
    fi
  fi
  ln -s "$src" "$dst"
  echo "linked $dst"
}

register_hook() { # register_hook <event> <command>: add to settings.json unless present
  local event="$1" cmd="$2" settings="$claude_dir/settings.json" new note=""
  if [ -f "$settings" ]; then
    if jq -e --arg e "$event" --arg c "$cmd" \
        '[.hooks[$e][]?.hooks[]?.command] | index($c)' "$settings" >/dev/null; then
      return
    fi
    cp "$settings" "$settings.bak-$stamp"
    note=" (backup: $settings.bak-$stamp)"
  else
    echo '{}' >"$settings"
  fi
  # Write in place so a symlinked settings.json and its permissions survive.
  new="$(jq --arg e "$event" --arg c "$cmd" \
    '.hooks[$e] += [{hooks: [{type: "command", command: $c}]}]' "$settings")"
  printf '%s\n' "$new" >"$settings"
  echo "registered $event hook in $settings$note"
}

command -v jq >/dev/null || { echo "install.sh needs jq: install it and rerun" >&2; exit 1; }

for d in "$repo"/skills/*/; do link "${d%/}" "$claude_dir/skills/$(basename "$d")"; done
for f in "$repo"/agents/*.md; do link "$f" "$claude_dir/agents/$(basename "$f")"; done
for f in "$repo"/hooks/*.sh; do link "$f" "$claude_dir/hooks/$(basename "$f")"; done
register_hook UserPromptSubmit "$claude_dir/hooks/session-title.sh"

echo "installed $(cat "$repo/VERSION")"
