#!/bin/bash
# Marcus — PreToolUse hook (Bash). Two tiers.
#
#   TIER 1 — always blocked, in every mode, for everyone. No arming file lifts these.
#   TIER 2 — blocked unless the run is ARMED for /marcus ultraflow.
#
# ARMING: the owner — and only the owner — creates the sentinel before an autonomous run:
#     touch .claude/.ultraflow
# and removes it when the run is over:
#     rm .claude/.ultraflow
#
# Marcus must NEVER create, touch, or delete that file himself. An agent that can
# arm its own push rights has no guardrail at all — see marcus skill §4f and §11.
# The sentinel is gitignored so it never travels to another clone.
#
# GOTCHA (kept from the original): patterns match the literal command string, so a
# blocked verb inside a heredoc or a comment is blocked too. Write docs that mention
# these commands with the Write tool, not a shell heredoc.

# Fail closed without any binary the hook depends on. Without cat INPUT is empty;
# without jq COMMAND is empty; without grep every test exits 127, which `if grep -qE`
# reads as a clean miss; without sed the production pattern is corrupt. Each one
# lets every command pass. `command -v` is a shell builtin, so the check itself
# needs none of them.
for t in jq grep sed cat; do
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "BLOCKED: $t is required by this guardrail and is not in PATH — every Bash command is refused until it is (restore PATH, or install $t with your package manager)." >&2
    exit 2
  fi
done
# Present is not working: a shim or an exported function named grep that always
# fails turns every `if grep -qE` below into a clean miss. Prove it matches.
printf 'x' | grep -qE 'x' || { echo "BLOCKED: grep is present but not functional — every Bash command is refused until it is (restore PATH, unset any grep function, or reinstall grep)." >&2; exit 2; }

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
# Fail closed on an empty or null command. Unreadable stdin, malformed JSON or a
# payload without tool_input.command would otherwise match nothing and pass.
if [ -z "$COMMAND" ] || [ "$COMMAND" = "null" ]; then
  echo "BLOCKED: no command could be read from the hook payload — refused rather than passed unchecked." >&2
  exit 2
fi
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Production branch. The main|master floor always applies. When marcus.config.json
# (branches.production) is readable and the value is a plain branch name, that value
# is APPENDED to the floor, never substituted for it; every failure path keeps the
# floor alone, so the hook is never weaker than before it learned to read the config.
prod_re='main|master'
CONFIG="$PROJECT_DIR/marcus.config.json"
if [ -r "$CONFIG" ]; then
  prod_branch=$(jq -r 'if (.branches.production | type) == "string" then .branches.production else empty end' "$CONFIG" 2>/dev/null)
  # Whole-value charset check — `case` matches the entire string, newline
  # included. A value carrying a newline or an unanticipated metacharacter must
  # never reach the pattern: a corrupt ERE makes grep error out and the tier
  # would pass silently. Anything unexpected keeps the default instead.
  case "$prod_branch" in
    ''|*[!A-Za-z0-9._/-]*) : ;;    # empty or unsafe — keep main|master
    *) # escape the ERE metacharacters a branch name may legitimately contain
       prod_re="main|master|$(printf '%s' "$prod_branch" | sed 's/[][(){}.^$*+?|\]/\\&/g')" ;;
  esac
  # A malformed ERE makes grep exit 2, which `if grep -qE` cannot tell from a
  # clean miss — the tier would fail open. Compile-test it; >1 means malformed.
  printf '' | grep -qE "($prod_re)" 2>/dev/null
  [ $? -gt 1 ] && prod_re='main|master'
fi

deny() {
  echo "BLOCKED: '$COMMAND' matches '$1'. $2" >&2
  exit 2
}

# ---------------------------------------------------------------- TIER 1
# Irreversible, history-destroying, or production-facing. Never allowed.
TIER1=(
  "push --force"
  "push -f"
  "force-with-lease"
  "git reset --hard"
  "reset --hard"
  "git clean -fd"
  "git clean -f"
  "git branch -D"
  "git checkout \."
  "git restore \."
  "filter-branch"
  "push --mirror"
  "push --delete"
  "push origin :"
  "git push[^|;&]*\b($prod_re)\b"
  "gh pr merge[^|;&]*--base[[:space:]]+($prod_re)"
  "supabase db push"
  "supabase db reset"
  # rm with recursive AND force, any order: -rf -fr -Rf, -r -f, --recursive --force (MRCS-DEV-68.4).
  # rm must be a word: confirm, ./rm-tool do not match; /bin/rm does.
  '(^|[^a-zA-Z0-9._-])rm[[:space:]]([^|;&]*[[:space:]])?(-[a-zA-Z]*([rR][a-zA-Z]*f|f[a-zA-Z]*[rR])[a-zA-Z]*|(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)[[:space:]]([^|;&]*[[:space:]])?(-[a-zA-Z]*f[a-zA-Z]*|--force)|(-[a-zA-Z]*f[a-zA-Z]*|--force)[[:space:]]([^|;&]*[[:space:]])?(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive))([[:space:]]|$)'
)
for p in "${TIER1[@]}"; do
  if echo "$COMMAND" | grep -qE "$p"; then
    deny "$p" "Irreversible or production-facing — owner only, in every mode."
  fi
done

# ---------------------------------------------------------------- TIER 2
# Remote write operations. Allowed only while the run is armed.
TIER2=(
  "git push"
  "gh pr create"
  "gh pr merge"
)
for p in "${TIER2[@]}"; do
  if echo "$COMMAND" | grep -qE "$p"; then
    if [ -f "$PROJECT_DIR/.claude/.ultraflow" ]; then
      break   # armed: allowed — and the run must report every push it made
    fi
    deny "$p" "Remote write is owner-only unless the run is armed for ultraflow. If the owner wants an autonomous run, THEY create .claude/.ultraflow — you never create it yourself."
  fi
done

exit 0
