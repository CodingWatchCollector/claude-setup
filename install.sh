#!/usr/bin/env bash
# Link this repo's skills and agents into place.
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

for d in "$repo"/skills/*/; do link "${d%/}" "$claude_dir/skills/$(basename "$d")"; done
for f in "$repo"/agents/*.md; do link "$f" "$claude_dir/agents/$(basename "$f")"; done

echo "installed $(cat "$repo/VERSION")"
