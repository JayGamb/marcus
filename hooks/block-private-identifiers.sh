#!/bin/bash
# Marcus — PreToolUse hook: block any OUTBOUND tool call that carries one of the owner's private identifiers.
#
# Why: incident 2026-10-24 (docs/incidents/2026-10-24-owner-email-user-agent.md). A Dieter subagent
# downloaded a public-domain image from Wikimedia with curl and put the owner's personal email in the
# User-Agent header. The email reaches every subagent through the injected `userEmail` context; no rule
# and no hook stopped it from leaving the machine.
#
# What it does: reads the identifier list, decides whether the call can reach the network, and
# blocks (exit 2) when the call's input contains any identifier, raw or URL-encoded.
#
# Identifier sources (all optional, merged):
#   1. ~/.claude/hooks/private-identifiers.txt — one identifier per line, `#` comments allowed.
#      This file is private: never commit it.
#   2. marcus.config.json → owner.email in the project dir.
#   3. `git config user.email` in the project dir.
#
# Fails CLOSED if jq is missing: an outbound privacy guard that silently does nothing is worse than none.
#
# Declared in .claude/settings.json under hooks.PreToolUse, matcher `Bash|WebFetch|WebSearch|mcp__.*`
# (skills/marcus/modes/init.md §4, guardrail 5). Self-test: hooks/test-block-private-identifiers.sh.
#
# Known limits, stated rather than hidden:
#   - It matches the literal call input. An identifier read at runtime (from a file, an env var or
#     `git log`) and sent from inside a script is NOT seen.
#   - The Bash network check is a keyword prefilter (curl, wget, ssh, python requests, fetch…).
#     A call that reaches the network some other way, with the identifier written literally in the
#     command, is missed.
#   - It blocks; it does not redact. The agent must rewrite the call.
#   - It fails OPEN on empty or non-JSON stdin (no tool name, so nothing is judged outbound) and
#     on a hook timeout (the harness lets the call through). Only a missing jq fails closed.
#   - Case folding is ASCII only (BSD `tr`): an identifier with accented capitals can miss.
#   - Matching is a case-folded substring: a short token or a numeric id in the list blocks every
#     outbound call that happens to contain it. Put emails, phone numbers and full names there.

set -u

INPUT=$(cat) || exit 2
if ! command -v jq >/dev/null 2>&1; then
  echo "BLOCKED: jq is missing, so the private-identifier hook fails closed. Install jq (brew install jq)." >&2
  exit 2
fi

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
PAYLOAD=$(printf '%s' "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# ---- identifiers ----------------------------------------------------------------------------------
IDS=()
LIST="$HOME/.claude/hooks/private-identifiers.txt"
if [ -r "$LIST" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"   # trim leading whitespace
    line="${line%"${line##*[![:space:]]}"}"   # trim trailing whitespace and \r; inner spaces stay
    [ -n "$line" ] && IDS+=("$line")
  done < "$LIST"
fi
CFG="$PROJECT_DIR/marcus.config.json"
if [ -r "$CFG" ]; then
  e=$(jq -r '.owner.email // empty' "$CFG" 2>/dev/null)
  [ -n "$e" ] && IDS+=("$e")
fi
e=$(git -C "$PROJECT_DIR" config user.email 2>/dev/null)
[ -n "$e" ] && IDS+=("$e")

[ ${#IDS[@]} -eq 0 ] && exit 0

# ---- is this call outbound? ------------------------------------------------------------------------
outbound=0
case "$TOOL" in
  WebFetch|WebSearch) outbound=1 ;;
  mcp__*) outbound=1 ;;   # every MCP call leaves the process: browsers, trackers, mail, chat, docs
  Bash)
    cmd=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    # CLI names count only as a command word: a / . _ - before it or no whitespace after it is a
    # path segment or a file name (supabase/seed.sql, netlify.toml, gh-pages, ~/.ssh), not a call.
    if printf '%s' "$cmd" | grep -Eiq '(curl|wget|https?://|ftp://|(^|[^a-z/._-])(nc|ncat|ssh|scp|sftp|rsync|telnet|mail|gh|netlify|supabase|vercel|dig|nslookup|http)([[:space:]]|$)|(^|[^a-z/._-])deno +(run|eval)([[:space:]]|$)|requests\.|urllib|http\.client|fetch\(|axios|got\(|sendmail|osascript)'; then
      outbound=1
    fi
    ;;
esac
[ "$outbound" -eq 0 ] && exit 0

# ---- match ------------------------------------------------------------------------------------------
lc=$(printf '%s' "$PAYLOAD" | tr '[:upper:]' '[:lower:]')
for id in "${IDS[@]}"; do
  idl=$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')
  enc=$(printf '%s' "$idl" | sed -e 's/%/%25/g' -e 's/@/%40/g' -e 's/+/%2b/g' -e 's/ /%20/g')
  enc2=$(printf '%s' "$enc" | sed -e 's/\./%2e/g')
  enc3=$(printf '%s' "$idl" | sed -e 's/%/%25/g' -e 's/@/%40/g' -e 's/+/%2b/g' -e 's/ /+/g')   # form encoding
  if printf '%s' "$lc" | grep -Fq -- "$idl" || printf '%s' "$lc" | grep -Fq -- "$enc" \
     || printf '%s' "$lc" | grep -Fq -- "$enc2" || printf '%s' "$lc" | grep -Fq -- "$enc3"; then
    echo "BLOCKED: this $TOOL call would send a private owner identifier off this machine (header, URL, query or body). Rewrite it without the identifier. If a service asks for a contact in the User-Agent, use a generic one built from marcus.config.json: '<company>Bot/1.0 (+<site>)' — no site, no contact at all, never an email. Incident 2026-10-24." >&2
    exit 2
  fi
done
exit 0
