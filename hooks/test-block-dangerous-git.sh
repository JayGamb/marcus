#!/bin/bash
# Self-test for block-dangerous-git.sh. Feeds command STRINGS to the hook — nothing is executed.
# Run: bash hooks/test-block-dangerous-git.sh  → one PASS line per case, then "N/N PASS", exit 0.
# Exits 1 if any case FAILs. scripts/diff.sh runs it on every call (exit bit 8).
# HOOK=<path> overrides the hook under test (red-green against an older copy).
HOOK="${HOOK:-$(cd "$(dirname "$0")" && pwd)/block-dangerous-git.sh}"
# CLAUDE_PROJECT_DIR points at an empty temp dir for every case: no .claude/.ultraflow (unarmed),
# no marcus.config.json (production floor main|master only).
EMPTYDIR=$(mktemp -d)
trap 'rm -r "$EMPTYDIR"' EXIT

pass=0; total=0
run() { # expected_exit  command  label
  total=$((total + 1))
  jq -nc --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}' \
    | CLAUDE_PROJECT_DIR="$EMPTYDIR" bash "$HOOK" >/dev/null 2>&1; code=$?
  if [ "$code" -eq "$1" ]; then pass=$((pass + 1)); echo "PASS  $3"; else echo "FAIL  $3 (got $code, want $1)"; fi
}

# --- blocked: remote writes (TIER 2, unarmed) and history/production (TIER 1)
run 2 "git push origin feat/x"              "push is blocked (unarmed)"
run 2 "git push --force origin feat/x"      "force-push is blocked"
run 2 "git push -f origin feat/x"           "push -f is blocked"
run 2 "git push origin main"                "push to production is blocked"
run 2 "gh pr create --base staging"         "gh pr create is blocked (unarmed)"
run 2 "gh pr merge 12"                      "gh pr merge is blocked (unarmed)"
run 2 "gh pr merge 12 --base main"          "gh pr merge into production is blocked"
run 2 "git reset --hard HEAD~1"             "reset --hard is blocked"
run 2 "git clean -fd"                       "clean -fd is blocked"
run 2 "git branch -D feat/x"                "branch -D is blocked"
run 2 "supabase db push"                    "supabase db push (prod apply) is blocked"
run 2 "supabase db reset"                   "supabase db reset is blocked"
# --- blocked: rm recursive + force, every flag order
run 2 "rm -rf build"                        "rm -rf is blocked"
run 2 "rm -fr build"                        "rm -fr is blocked"
run 2 "rm -r -f build"                      "rm -r -f is blocked"
run 2 "rm -f -r build"                      "rm -f -r is blocked"
run 2 "rm --recursive --force build"        "rm --recursive --force is blocked"
run 2 "rm -Rf build"                        "rm -Rf is blocked"
run 2 "rm -r build -f"                      "rm -r <path> -f (flag after operand) is blocked"
run 2 "/bin/rm -rf build"                   "rm by absolute path is blocked"
run 2 "cd /tmp/x && rm -rf build"           "rm -rf after && is blocked"
# --- allowed
run 0 "git status"                          "git status passes"
run 0 "git commit -m 'x'"                   "git commit passes"
run 0 "git commit -m 'mention push here'"   "commit message containing the word push passes"
run 0 "rm file.txt"                         "rm file passes"
run 0 "rm -r dir"                           "rm -r without -f passes"
run 0 "rm -f file"                          "rm -f without -r passes"
run 0 "confirm -rf"                         "confirm is not rm"
run 0 "./rm-tool -rf"                       "./rm-tool is not rm"
run 0 "npm run rm"                          "npm run rm passes"

echo "$pass/$total PASS"
[ "$pass" -eq "$total" ] || exit 1
exit 0
