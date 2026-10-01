#!/usr/bin/env bash
# ~/.claude -> repo. Run before committing, to capture live edits.
# Only pulls what the repo already tracks; never wipes the repo's skills directory.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
L="$HOME/.claude"
for f in "$R"/agents/*.md; do
  a="$(basename "$f")"
  if [ -f "$L/agents/$a" ]; then cp "$L/agents/$a" "$R/agents/"; else echo "  missing live: agents/$a"; fi
done
for d in "$R"/skills/*/; do
  s="$(basename "$d")"
  if [ -d "$L/skills/$s" ]; then rm -rf "${R:?}/skills/${s:?}"; cp -R "$L/skills/$s" "$R/skills/$s"
  else echo "  missing live: skills/$s (kept repo copy)"; fi
done
echo "pulled. Review with: git -C '$R' diff"
