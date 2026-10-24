#!/bin/bash
# Self-test for block-private-identifiers.sh. Uses a FAKE identifier, never a real one.
# Run: bash hooks/test-block-private-identifiers.sh  → 14 PASS lines, then "14/14 PASS", exit 0.
# Exits 1 if any case FAILs. scripts/diff.sh runs it on every call (exit bit 4).
HOOK="$(cd "$(dirname "$0")" && pwd)/block-private-identifiers.sh"
# HOME points at a temp dir for every case, so the real ~/.claude list and the real GLOBAL git
# config (whose user.email the hook would otherwise read, even outside a repo) are both masked.
TMPH=$(mktemp -d)
EMPTYDIR=$(mktemp -d)   # no git, no marcus.config.json
trap 'rm -rf "$TMPH" "$EMPTYDIR"' EXIT
mkdir -p "$TMPH/.claude/hooks"
# the name line carries edge spaces and a CRLF on purpose: edges are trimmed, the inner space is kept
printf 'fake.owner@example.test\n# comment\n  Fake Owner \r\n' > "$TMPH/.claude/hooks/private-identifiers.txt"

pass=0; total=0
run() { # expected_exit  json  label
  total=$((total + 1))
  printf '%s' "$2" | HOME="$TMPH" CLAUDE_PROJECT_DIR="$EMPTYDIR" bash "$HOOK" >/dev/null 2>&1; code=$?
  if [ "$code" -eq "$1" ]; then pass=$((pass + 1)); echo "PASS  $3"; else echo "FAIL  $3 (got $code, want $1)"; fi
}

run 2 '{"tool_name":"Bash","tool_input":{"command":"curl -A \"Bot/1.0 (fake.owner@example.test)\" https://upload.wikimedia.org/x.jpg -o x.jpg"}}' "curl with identifier in User-Agent is blocked"
run 2 '{"tool_name":"Bash","tool_input":{"command":"wget --header=\"From: Fake.Owner@Example.test\" https://example.org/a"}}' "wget with identifier, mixed case, is blocked"
run 2 '{"tool_name":"WebFetch","tool_input":{"url":"https://example.org/?q=fake.owner%40example.test","prompt":"x"}}' "WebFetch with URL-encoded identifier is blocked"
run 2 '{"tool_name":"WebSearch","tool_input":{"query":"fake.owner@example.test"}}' "WebSearch query with identifier is blocked"
run 2 '{"tool_name":"mcp__claude-in-chrome__navigate","tool_input":{"url":"https://x.test/?e=fake.owner@example.test"}}' "browser navigate with identifier is blocked"
run 0 '{"tool_name":"Bash","tool_input":{"command":"curl -A \"ExampleBot/1.0 (+https://example.com)\" https://upload.wikimedia.org/x.jpg -o x.jpg"}}' "curl with generic User-Agent passes"
run 0 '{"tool_name":"Bash","tool_input":{"command":"git log -1 --format=%ae"}}' "local git command passes"
run 0 '{"tool_name":"Bash","tool_input":{"command":"echo fake.owner@example.test > notes.txt"}}' "local write with identifier passes (not outbound)"
run 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x","content":"fake.owner@example.test"}}' "Write tool passes (not outbound)"
run 2 '{"tool_name":"WebSearch","tool_input":{"query":"who is fake owner"}}' "full name with an inner space is blocked"
run 0 '{"tool_name":"Bash","tool_input":{"command":"echo \"email fake.owner@example.test\" > notes.txt"}}' "the word email is not the mail command (not outbound)"
run 2 '{"tool_name":"Bash","tool_input":{"command":"supabase secrets set CONTACT=fake.owner@example.test"}}' "infra CLI (supabase) with identifier is blocked"
run 0 '{"tool_name":"Bash","tool_input":{"command":"cat supabase/seed.sql | grep fake.owner@example.test"}}' "CLI name as a path segment is not a call (not outbound)"
run 0 '{"tool_name":"Bash","tool_input":{"command":"cat > supabase/migrations/x.sql <<EOF\ninsert into t values (\u0027fake.owner@example.test\u0027);\nEOF"}}' "heredoc into a CLI-named directory is not a call (not outbound)"

echo "$pass/$total PASS"
[ "$pass" -eq "$total" ] || exit 1
exit 0
