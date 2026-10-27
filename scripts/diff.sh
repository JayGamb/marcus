#!/usr/bin/env bash
# What differs between this repo's agents/ and skills/ and the live ~/.claude — read-only.
# All four checks always run, from any cwd (every path is anchored on the repo root R).
# Exit code is a bitmask; the bits combine (3 = 1+2, 5 = 1+4, 15 = all four):
#   0  in sync with ~/.claude, triad ok, privacy hook test ok, git hook test ok
#   1  repo differs from ~/.claude (ONLY IN REPO / DIFFERS / ONLY IN LIVE list printed).
#      Also fires on a fresh machine: nothing installed yet = every file ONLY IN REPO.
#   2  structure check failed (reason printed): triad, no agent files, or no skill files
#      (skills/ missing or empty — the comparison is not run, so "in sync" is never claimed)
#   4  privacy hook self-test failed: hooks/test-block-private-identifiers.sh exited non-zero
#      (failing cases printed)
#   8  git hook self-test failed: hooks/test-block-dangerous-git.sh exited non-zero
#      (failing cases printed)
# ONLY IN LIVE covers *.md inside the live copy of each skill dir the repo ships
# (a file left in ~/.claude/skills/<name>/ with no repo source). It does NOT cover
# ~/.claude/agents/: that directory is shared with agents this repo does not ship,
# so a live-only agent file is not reported.
set -uo pipefail
shopt -s nullglob
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
L="$HOME/.claude"
out=$(mktemp)
rc=0

check(){
  if   [ ! -e "$2" ];                       then echo "  ONLY IN REPO : ${1#$R/}" >>"$out"
  elif ! diff -q "$1" "$2" >/dev/null 2>&1; then echo "  DIFFERS      : ${1#$R/}" >>"$out"; fi
}

agents=("$R"/agents/*.md)
for f in ${agents[@]+"${agents[@]}"}; do check "$f" "$L/agents/$(basename "$f")"; done
# skills/ guarded like agents/: a missing or empty tree fails loud instead of reading as in sync.
nskills=0; skills_fail=0
if [ -d "$R/skills" ]; then
  while IFS= read -r f; do
    nskills=$((nskills + 1)); check "$f" "$L/skills/${f#$R/skills/}"
  done < <(find "$R/skills" -name '*.md')
fi
if [ "$nskills" -eq 0 ]; then skills_fail=1; fi
# live-only: *.md under the live copy of each skill dir the repo ships.
for d in "$R"/skills/*/; do
  s=$(basename "$d")
  [ -d "$L/skills/$s" ] || continue
  while IFS= read -r f; do
    rel=${f#$L/skills/}
    [ -e "$R/skills/$rel" ] || echo "  ONLY IN LIVE : skills/$rel" >>"$out"
  done < <(find "$L/skills/$s" -name '*.md')
done

if [ "$skills_fail" -eq 1 ]; then
  echo "skills: FAIL — no skill files under $R/skills/ (comparison incomplete)"
  [ -s "$out" ] && { cat "$out"; rc=1; }
elif [ -s "$out" ]; then cat "$out"; rc=1; else echo "  in sync"; fi
rm -f "$out"

# --- triad check (MRCS-DEV-10.D3): exactly one of tools:/disallowedTools: per agent frontmatter,
# and a body that announces a cut must have a key. Fails loud on zero agent files.
fail=0
if [ "${#agents[@]}" -eq 0 ]; then
  echo "triad: FAIL — no agent files under $R/agents/"; fail=1
fi
for f in ${agents[@]+"${agents[@]}"}; do
  fm=$(awk '/^---$/{c++; next} c==1' "$f")
  t=$(printf '%s\n' "$fm" | grep -c '^tools:'); d=$(printf '%s\n' "$fm" | grep -c '^disallowedTools:')
  n=${f#$R/}
  if   [ "$t" -ge 1 ] && [ "$d" -ge 1 ]; then echo "triad: $n sets both tools: and disallowedTools: (the second is ignored)"; fail=1
  elif [ "$t" -gt 1 ] || [ "$d" -gt 1 ]; then echo "triad: $n repeats a key (tools:=$t disallowedTools:=$d)"; fail=1
  elif [ "$t$d" = "00" ]; then
    if grep -qiE 'denied in your frontmatter|disallowedTools' "$f"
    then echo "triad: $n body announces a cut, frontmatter has none"
    else echo "triad: $n frontmatter has neither tools: nor disallowedTools:"; fi
    fail=1
  fi
done
if [ "$fail" -eq 0 ]; then
  echo "triad: ok (${#agents[@]} agents, exactly one tools:/disallowedTools: key each)"
else
  rc=$((rc | 2))
fi
if [ "$skills_fail" -eq 1 ]; then rc=$((rc | 2)); fi

# --- privacy hook self-test (MRCS-DEV-66): the outbound-identifier hook must pass its own cases.
ph_out=$(bash "$R/hooks/test-block-private-identifiers.sh" 2>&1); ph_rc=$?
ph_sum=$(printf '%s\n' "$ph_out" | tail -n 1)
if [ "$ph_rc" -eq 0 ]; then
  echo "privacy hook: ok (${ph_sum% PASS})"
else
  echo "privacy hook: FAIL — exit $ph_rc, ${ph_sum:-no output}"
  printf '%s\n' "$ph_out" | grep '^FAIL' || true
  rc=$((rc | 4))
fi

# --- git hook self-test (MRCS-DEV-68.4): the dangerous-command hook must pass its own cases.
gh_out=$(bash "$R/hooks/test-block-dangerous-git.sh" 2>&1); gh_rc=$?
gh_sum=$(printf '%s\n' "$gh_out" | tail -n 1)
if [ "$gh_rc" -eq 0 ]; then
  echo "git hook: ok (${gh_sum% PASS})"
else
  echo "git hook: FAIL — exit $gh_rc, ${gh_sum:-no output}"
  printf '%s\n' "$gh_out" | grep '^FAIL' || true
  rc=$((rc | 8))
fi
exit "$rc"
