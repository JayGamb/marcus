#!/usr/bin/env bash
# scripts/snapshot.sh — build the publishable public snapshot of this repo, or refuse to.
#
# WHY IT EXISTS. This repo's history carries real operational values: tracker workspace and
# list ids, internal product codes, absolute home paths. Scrubbing the working tree leaves
# `git log -p` fully exposed, and cleaning history needs filter-branch — TIER 1 in
# hooks/block-dangerous-git.sh, forbidden in every mode. So the only publishable artifact is
# a tree with ONE commit behind it: an orphan branch, rebuilt from scratch every time.
#
# USAGE (works from any cwd inside the repo):
#   scripts/snapshot.sh           build refs/heads/public/snapshot from the integration branch
#   scripts/snapshot.sh --check   run the leak gate against the current checkout, build nothing
#
# --check is what the wave's integration check calls, so the gate runs on the merged result
# before anything lands. It needs marcus.config.json to resolve the owner identity it is
# gating; inside a clone that has no config it refuses loudly rather than quietly gating one
# pattern fewer. That includes the published snapshot itself — by design.
#
# WHAT IT NEVER DOES. No remote operation and no destructive one: it does not push, open or
# merge a PR, reset --hard, clean, delete a branch, or rewrite history with filter-branch.
# Not because the PreToolUse hook would stop it — because those verbs are not in it. The two
# commands that actually publish are printed at the end for the owner to run.
set -euo pipefail

# ---------------------------------------------------------------- data: what stays out
# The exclusion list. Data, in one place, each entry saying why it is out. A trailing slash
# marks a directory; entries are matched as literal path prefixes (glob `case`), never as a
# regex, so nothing here needs escaping.
EXCLUDE=(
  'docs/handoffs/'       # per-session state: live ticket ids, owner decisions, client names
  'docs/waves/'          # wave plans: live ticket ids and per-slice owner instructions
  'docs/evaluations/'    # pre-project research on ideas that are not public yet
  'docs/PARKING-LOT.md'  # a third party's paid-course critique, an unlaunched business line and its kill
                         #   criteria, the owner's company name, internal mail aliases, CH tax admin scope
  'docs/VISION.md'       # the owner's product portfolio codes, personal operating system, cash-per-product
  'marcus.config.json'   # the owner's own identity + tracker ids; the published tree ships the example
)

# ---------------------------------------------------------------- data: what must not leak
# Each entry: <id>|<ERE>. Two more (owner-name, owner-email) are appended at run time from
# marcus.config.json, so no identity value is ever written into this file.
#
# NOTE, and do not "tidy" it away: this script ships INSIDE the snapshot, so each pattern is
# written so its own source text does not match it — a bracketed single character ([r] in
# /Use[r]s/, [C] in B[C]M) matches exactly the same input while breaking the literal
# substring. Word boundaries are spelled out instead of \b, which is not portable ERE.
#
# backend-project-ref is the one pattern here that is a SHAPE, not a known string: a Supabase
# project ref is a bare 20-character lowercase alphanumeric token with no suffix and no
# punctuation to key off. It was added after an audit found a live ref that all the other
# patterns missed, sitting in the very table that documents what needs scrubbing.
#   CHOSEN: the unanchored shape, matched as a standalone token.
#   NOT CHOSEN: anchoring to `supabase` / `project.?ref` / a `url =` line. It would have caught
#     that one ref, but a ref pasted into prose, a code fence or a filename has no anchor, and
#     the anchored form gives a false sense of coverage.
#   COST, measured over the whole shippable tree on 2026-09-30: exactly one match, the real
#     ref. Zero false positives, so there is no word allowlist here to rot.
#   WHAT IT MISSES, knowingly: a ref glued into a longer token with no boundary (21+ chars, a
#     base64 blob, a concatenated identifier); a ref split across two lines; any ref that is
#     not exactly 20 chars. It is also not a secret scanner — API keys, JWTs and connection
#     strings have other shapes and are not gated here.
#   If a future doc legitimately contains a 20-character token, reword the doc or add a
#   by-file-and-field allowlist entry. Never widen or drop this pattern to make a file pass.
PATTERNS=(
  'clickup-id-numeric|9015[0-9]{6,}'
  'clickup-id-task|12472j[a-z0-9]{4,}'
  'home-path|/Use[r]s/'
  'product-code|(^|[^A-Za-z0-9_])(B[C]M|D[C]AK|I[U]IK|L[R]N|A[R]K|K[I]LK)([^A-Za-z0-9_]|$)'
  'backend-project-ref|(^|[^A-Za-z0-9_])[a-z0-9]{20}([^A-Za-z0-9_]|$)'
)

# ---------------------------------------------------------------- data: the three exceptions
# Allowlisted exceptions — exactly three, and every one of them is the owner's NAME, the one
# identity value a published MIT plugin has to carry. Allowlisting is BY FILE AND FIELD: a
# hit is forgiven only when it lands in this exact file, on the field named here, and that
# value occurs on exactly one line of the file. No pattern is ever switched off — that is how
# a gate quietly stops gating.
#   <file>|<pattern id>|line:<ERE the matching line must satisfy>
#   <file>|<pattern id>|jq:<path to the field, whose value must equal the owner name>
ALLOWLIST=(
  # 1. MIT is not a licence without a named copyright holder.
  'LICENSE|owner-name|line:^Copyright \(c\) [0-9]{4} '
  # 2. Claude Code plugin manifest: author.name is the publisher the marketplace displays.
  '.claude-plugin/plugin.json|owner-name|jq:.author.name'
  # 3. Marketplace manifest: the field here is owner.name, NOT author.name — verified against
  #    the file on 2026-09-30. Naming the wrong path would void the exception, not widen it.
  '.claude-plugin/marketplace.json|owner-name|jq:.owner.name'
)

SNAP_BRANCH='public/snapshot'
SNAP_REF="refs/heads/$SNAP_BRANCH"
MARKER='Marcus-Snapshot'          # trailer that identifies a tip this script made

# ---------------------------------------------------------------- plumbing
# Global, not local to build(): an EXIT trap expands its body when it fires, by which point a
# function-local would be gone and the cleanup would silently target nothing.
TMP=''
trap 'if [ -n "$TMP" ]; then rm -rf "$TMP"; fi' EXIT

die() { printf '%s\n' "snapshot: $*" >&2; exit 1; }

R="$(git rev-parse --show-toplevel 2>/dev/null)" || die 'not inside a git repository.'
cd "$R"
CONFIG="$R/marcus.config.json"

command -v jq >/dev/null 2>&1 || die 'jq is required (owner identity and the two JSON fields).'

# ERE-escape a literal, same escape set as hooks/block-dangerous-git.sh.
ere_quote() { printf '%s' "$1" | sed 's/[][(){}.^$*+?|\]/\\&/g'; }

# Owner identity comes from the config, never from git config: a clone with an unset or
# different user.email would silently gate one value fewer, and this gate fails closed.
[ -r "$CONFIG" ] || die "marcus.config.json is not readable at $CONFIG — the gate cannot
  resolve the owner identity it is supposed to catch, and a gate that skips a pattern is not
  a gate. Run this inside the private repo."
OWNER_NAME="$(jq -r 'if (.owner.name  | type) == "string" then .owner.name  else empty end' "$CONFIG")"
OWNER_EMAIL="$(jq -r 'if (.owner.email | type) == "string" then .owner.email else empty end' "$CONFIG")"
[ -n "$OWNER_NAME" ]  || die 'marcus.config.json: owner.name is missing or not a string.'
[ -n "$OWNER_EMAIL" ] || die 'marcus.config.json: owner.email is missing or not a string.'
PATTERNS+=("owner-name|$(ere_quote "$OWNER_NAME")")
PATTERNS+=("owner-email|$(ere_quote "$OWNER_EMAIL")")

EMPTY_TREE="$(git hash-object -t tree /dev/null)"

# A malformed ERE makes grep exit >1, which reads exactly like a clean miss — that is how a
# gate fails open. Compile every pattern under both engines that will run it before scanning.
compile_or_die() {
  local id="$1" pat="$2" rc
  rc=0; printf '' | grep -qE -- "$pat" || rc=$?
  if [ "$rc" -gt 1 ]; then die "pattern '$id' does not compile under grep -E."; fi
  rc=0; git grep -qE -e "$pat" "$EMPTY_TREE" -- . >/dev/null 2>&1 || rc=$?
  if [ "$rc" -gt 1 ]; then die "pattern '$id' does not compile under git grep -E."; fi
}

is_excluded() {                     # is_excluded <path>
  local p="$1" x
  for x in "${EXCLUDE[@]}"; do
    case "$p" in "$x"*) return 0 ;; esac
  done
  return 1
}

# SRC_TREE empty => the gate is reading the working tree; set => it is reading that tree object.
SRC_TREE=''
snap_cat() {                        # snap_cat <path> — the file as the scanned source has it
  if [ -n "$SRC_TREE" ]; then git show "$SRC_TREE:$1"; else cat "$1"; fi
}

# forgiven <pattern id> <ERE> <path> <matched line>
forgiven() {
  local id="$1" pat="$2" file="$3" text="$4"
  local e apath rest aid rule kind arg n
  for e in "${ALLOWLIST[@]}"; do
    apath="${e%%|*}"; rest="${e#*|}"; aid="${rest%%|*}"; rule="${rest#*|}"
    [ "$apath" = "$file" ] || continue
    [ "$aid" = "$id" ] || continue
    # The exception covers exactly ONE line of that file. A second occurrence is something
    # new that crept in under cover of the exception, so it is a leak, not an exception.
    n="$(snap_cat "$file" 2>/dev/null | grep -cE -- "$pat" || true)"
    [ "${n:-0}" -eq 1 ] || return 1
    kind="${rule%%:*}"; arg="${rule#*:}"
    case "$kind" in
      line) printf '%s\n' "$text" | grep -qE -- "$arg" && return 0 ;;
      jq)   [ "$(snap_cat "$file" 2>/dev/null | jq -r "$arg" 2>/dev/null)" = "$OWNER_NAME" ] && return 0 ;;
    esac
    return 1
  done
  return 1
}

# ---------------------------------------------------------------- the gate (AC 3 / AC 7)
# gate <label> — scans SRC_TREE when set, otherwise the tracked files of this checkout as
# they are on disk (so uncommitted edits are seen). Returns 1 and reports every hit.
gate() {
  local label="$1"
  local entry id pat raw rest hit file lineno text match hits=0 scanned
  local -a pathspec=()
  local x

  if [ -z "$SRC_TREE" ]; then
    # one positive pathspec, then the exclusions — a list of nothing but :(exclude) magic is
    # not portable across git versions.
    pathspec=('.')
    for x in "${EXCLUDE[@]}"; do pathspec+=(":(exclude)${x%/}"); done
    scanned="$(git ls-files -- "${pathspec[@]}" | wc -l | tr -d ' ')"
  else
    scanned="$(git ls-tree -r --name-only "$SRC_TREE" | wc -l | tr -d ' ')"
  fi

  for entry in "${PATTERNS[@]}"; do
    id="${entry%%|*}"; pat="${entry#*|}"
    compile_or_die "$id" "$pat"

    # content
    if [ -n "$SRC_TREE" ]; then
      raw="$(git grep -n -I -E -e "$pat" "$SRC_TREE" -- . || true)"
      raw="${raw//$SRC_TREE:/}"
    else
      raw="$(git grep -n -I -E -e "$pat" -- "${pathspec[@]}" || true)"
    fi
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      file="${hit%%:*}"; rest="${hit#*:}"; lineno="${rest%%:*}"; text="${rest#*:}"
      if forgiven "$id" "$pat" "$file" "$text"; then continue; fi
      match="$(printf '%s\n' "$text" | grep -oE -- "$pat" | head -1)"
      printf '  LEAK  %-18s %s:%s\n        match: %s\n' "$id" "$file" "$lineno" "$match" >&2
      hits=$((hits + 1))
    done <<< "$raw"

    # paths — a filename leaks as loudly as a line of content
    if [ -n "$SRC_TREE" ]; then
      raw="$(git ls-tree -r --name-only "$SRC_TREE" | grep -E -- "$pat" || true)"
    else
      raw="$(git ls-files -- "${pathspec[@]}" | grep -E -- "$pat" || true)"
    fi
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      match="$(printf '%s\n' "$hit" | grep -oE -- "$pat" | head -1)"
      printf '  LEAK  %-18s %s (in the path itself)\n        match: %s\n' "$id" "$hit" "$match" >&2
      hits=$((hits + 1))
    done <<< "$raw"
  done

  if [ "$hits" -gt 0 ]; then
    printf '\n  %s: %s leak(s) in %s file(s), %s patterns. Nothing was built.\n' \
      "$label" "$hits" "$scanned" "${#PATTERNS[@]}" >&2
    return 1
  fi
  printf '  %s: clean — %s files, %s patterns, %s allowlisted exceptions.\n' \
    "$label" "$scanned" "${#PATTERNS[@]}" "${#ALLOWLIST[@]}"
  return 0
}

# ---------------------------------------------------------------- build (AC 1 / AC 4)
build() {
  local src src_sha src_date line path tree tip parents commit n
  src="$(jq -r 'if (.branches.integration | type) == "string" then .branches.integration else empty end' "$CONFIG")"
  [ -n "$src" ] || die 'marcus.config.json: branches.integration is missing or not a string.'
  git rev-parse --verify --quiet "refs/heads/$src" >/dev/null \
    || die "the integration branch 'refs/heads/$src' does not exist in this repo."
  src_sha="$(git rev-parse --short "refs/heads/$src")"
  src_date="$(git log -1 --format=%cI "refs/heads/$src")"

  # Filtered tree via a TEMP INDEX: this checkout, its index and its files are never touched.
  TMP="$(mktemp -d)"
  git ls-tree -r --full-name "refs/heads/$src" | {
    while IFS= read -r line; do
      path="${line#*$'\t'}"
      is_excluded "$path" || printf '%s\n' "$line"
    done
  } | GIT_INDEX_FILE="$TMP/index" git update-index --index-info
  tree="$(GIT_INDEX_FILE="$TMP/index" git write-tree)"

  # Prove the filter actually filtered, rather than trusting the pipe above.
  while IFS= read -r path; do
    if is_excluded "$path"; then die "internal: '$path' survived the exclusion list."; fi
  done < <(git ls-tree -r --name-only "$tree")
  n="$(git ls-tree -r --name-only "$tree" | wc -l | tr -d ' ')"
  [ "$n" -gt 0 ] || die 'the filtered tree is empty — refusing to build a snapshot of nothing.'

  printf '\n  source : %s at %s\n  tree   : %s (%s files)\n\n' "$src" "$src_sha" "$tree" "$n"

  SRC_TREE="$tree"
  gate 'gate' || die 'refusing to build a leaking snapshot. Fix the files above, then re-run.'
  SRC_TREE=''

  # Refuse to clobber a tip this script did not make. No branch is ever deleted: update-ref
  # moves the ref, and the previous orphan tip is simply left unreferenced.
  if git rev-parse --verify --quiet "$SNAP_REF" >/dev/null; then
    tip="$(git rev-parse "$SNAP_REF")"
    parents="$(git rev-list --parents -n 1 "$tip" | wc -w | tr -d ' ')"
    if [ "$parents" -ne 1 ] || ! git log -1 --format='%B' "$tip" | grep -q "^$MARKER:"; then
      die "$SNAP_BRANCH already exists at $tip and its tip is not a snapshot this script
  made (no '$MARKER:' trailer, or it has a parent). Refusing to overwrite someone's work.
  Inspect it, then move or rename it yourself if you want this ref back."
    fi
  fi

  # No -p => a true orphan. Dates pinned to the source commit so an unchanged source
  # reproduces an identical commit, not merely an identical tree.
  commit="$(
    printf '%s\n' \
      'Marcus — public snapshot' \
      '' \
      'The Marcus multi-agent delivery framework for Claude Code, published as a single' \
      'commit. The absence of history is deliberate: this framework was developed in a' \
      'private repo whose commits carry operational values that are not publishable.' \
      '' \
      "Built by scripts/snapshot.sh from $src at $src_sha." \
      "$MARKER: 1" \
    | GIT_AUTHOR_NAME="$OWNER_NAME"     GIT_AUTHOR_EMAIL="$OWNER_EMAIL"    \
      GIT_COMMITTER_NAME="$OWNER_NAME"  GIT_COMMITTER_EMAIL="$OWNER_EMAIL" \
      GIT_AUTHOR_DATE="$src_date"       GIT_COMMITTER_DATE="$src_date"     \
      git commit-tree "$tree" -F -
  )"
  git update-ref "$SNAP_REF" "$commit"

  printf '  built  : %s -> %s\n' "$SNAP_BRANCH" "$(git rev-parse --short "$SNAP_REF")"
  printf '  commits: %s (orphan, no parent)\n' "$(git rev-list --count "$SNAP_REF")"
  handoff
}

# ---------------------------------------------------------------- owner hand-off (AC 6)
handoff() {
  local repo slug url desc
  repo="$(jq -r '.repository // empty' "$R/.claude-plugin/plugin.json" 2>/dev/null || true)"
  desc="$(jq -r '.description // empty' "$R/.claude-plugin/plugin.json" 2>/dev/null || true)"
  slug="${repo#https://github.com/}"; slug="${slug%.git}"
  [ -n "$slug" ] && [ "$slug" != "$repo" ] || slug='<github-owner>/<repo>'
  url="${repo:-<repo-url>}"
  [ -n "$desc" ] || desc='<one-line description>'

  cat <<EOF

  Publishing is yours, not this script's. Two commands, and it ran NEITHER of them:

    1)  gh repo create $slug --public --description '$desc'
    2)  git push $url $SNAP_BRANCH:refs/heads/main

  Both are owner-only in every mode, including this one: creating the repo and the first
  push are the two steps that make this tree public, and they are irreversible in practice
  (a published leak is published). Read the gate output above before you run either.

  Two things to know before you do:
    - The orphan commit is authored under owner.email from marcus.config.json. That is the
      GitHub noreply address this repo's history already carries, so nothing new is exposed
      — but the gate cannot see commit metadata, only the tree, so this one is on you.
    - Re-running this script rebuilds $SNAP_BRANCH from scratch. Do that after every
      scrub, and never hand-edit the snapshot branch: the next run would refuse it.
EOF
}

# ---------------------------------------------------------------- entry
usage() {
  cat <<EOF
usage: scripts/snapshot.sh [--check]

  (no flag)   build $SNAP_BRANCH as a one-commit orphan from the integration branch,
              refusing to build if the leak gate finds anything.
  --check     run the leak gate against this checkout and exit. Builds nothing.
EOF
}

case "${1-}" in
  '')            build ;;
  --check)       [ $# -eq 1 ] || { usage >&2; exit 2; }
                 gate 'check' ;;
  -h|--help)     usage ;;
  *)             printf '%s\n' "snapshot: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
esac
