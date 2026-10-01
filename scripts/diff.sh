#!/usr/bin/env bash
# What differs between this repo's agents/ and skills/ and the live ~/.claude — read-only.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
L="$HOME/.claude"
out=$(mktemp)

check(){
  if   [ ! -e "$2" ];                       then echo "  ONLY IN REPO : ${1#$R/}" >>"$out"
  elif ! diff -q "$1" "$2" >/dev/null 2>&1; then echo "  DIFFERS      : ${1#$R/}" >>"$out"; fi
}

for f in "$R"/agents/*.md; do check "$f" "$L/agents/$(basename "$f")"; done
while IFS= read -r f; do check "$f" "$L/skills/${f#$R/skills/}"; done < <(find "$R/skills" -name '*.md')

if [ -s "$out" ]; then cat "$out"; rm -f "$out"; exit 1; fi
echo "  in sync"; rm -f "$out"

# --- triad check (MRCS-DEV-10.D3): one key per agent, and an announced cut must exist in the frontmatter
fail=0
for f in "$R"/agents/*.md; do
  fm=$(awk '/^---$/{c++; next} c==1' "$f")
  t=$(printf '%s\n' "$fm" | grep -c '^tools:'); d=$(printf '%s\n' "$fm" | grep -c '^disallowedTools:')
  [ "$t" -eq 1 ] && [ "$d" -eq 1 ] && { echo "triad: $f sets both tools: and disallowedTools: (the second is ignored)"; fail=1; }
  grep -qiE 'denied in your frontmatter|disallowedTools' "$f" && [ "$t$d" = "00" ] && { echo "triad: $f body announces a cut, frontmatter has none"; fail=1; }
done
[ "$fail" -eq 0 ] && echo "triad: ok ($(ls "$R"/agents/*.md | wc -l | tr -d ' ') agents, one tools/disallowedTools key each)" || exit 1
