#!/usr/bin/env bash
# repo -> ~/.claude. Backs up anything it replaces.
# Skills and agents are discovered from the repo tree, never listed by hand — a list here is what broke the last install.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
L="$HOME/.claude"
B="$L/backups/marcus-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$B/agents" "$B/skills" "$L/agents" "$L/skills"
for f in "$R"/agents/*.md; do
  a="$(basename "$f")"
  [ -f "$L/agents/$a" ] && cp "$L/agents/$a" "$B/agents/"
  cp "$f" "$L/agents/"
done
for d in "$R"/skills/*/; do
  s="$(basename "$d")"
  [ -d "$L/skills/$s" ] && cp -R "$L/skills/$s" "$B/skills/"
  rm -rf "${L:?}/skills/${s:?}"; cp -R "$d" "$L/skills/$s"
done
S=""
for s in linus-check linus-review dieter-audit ui-research; do
  if [ -d "$L/skills/$s" ]; then S="$S $L/skills/$s"; fi
done
if [ -n "$S" ]; then echo "stale skill dirs — these are /marcus modes now, not skills. Delete when you are ready:"; echo "  rm -r$S"; fi
echo "installed. Backup: $B"
echo "Standing rules template: skills/marcus/templates/standing-rules.md (now at $L/skills/marcus/templates/) — append to the CLAUDE.md in $L with /marcus init, or by hand."
