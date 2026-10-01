# `github` — Issues through `gh`

The queue lives where the diff lives. Works headless, needs no extra credential in CI, and has a rate budget two orders of magnitude above ClickUp's. Pays for it with no custom statuses and no native subtasks — both are carried in labels and in the body.

Config keys read: `tracker.adapter` · `tracker.fallback`. **Nothing else.** The repo comes from the checkout's `origin` remote (`gh` resolves it; `{owner}`/`{repo}` below are `gh api` placeholders, not values to substitute by hand), and the label prefixes `phase:` / `state:` are fixed constants of this adapter, not configuration. An adapter that invents a config key `/marcus init` never writes is an adapter that reads `undefined` on first use.

---

## 1. Auth

`gh`, authenticated on the machine or by `GH_TOKEN` in CI. No token in the repo.

```bash
gh auth status          # verify once, at init and at the start of a run
```

| Situation | What to do |
|---|---|
| Authenticated, `origin` is a GitHub remote | Normal operation |
| `gh auth status` fails | Degrade (§7). Do not prompt for a token, do not write one anywhere |
| `origin` is not GitHub, or absent | This adapter cannot be used. Say so and offer `local-html` |
| Scope too narrow (403 on write, 200 on read) | Degrade (§7) and name the missing scope — `repo` is what issues need |

Labels and milestones must exist before they are used. Create the fixed set once, at init:

```bash
for p in DISC ARCH DESI DEV QA REV HAND; do gh label create "phase:$p" --force; done
for s in to-do on-hold in-progress review blocked decision accepted declined complete cancelled; do gh label create "state:$s" --force; done
for t in bug backend frontend design devops decision "ready-for-<owner>"; do gh label create "$t" --force; done
```

`ready-for-<owner>` is the one label that is not literal: it is derived from `config.owner.name` — the **first name, lowercased** (an owner named `Firstname Lastname` gives `ready-for-firstname`, `../SKILL.md` §0). Substitute it before running that line. `decision` is the tag that rides beside `state:decision` — the state is the machine, the tag is what puts the owner's open calls in one filterable view (`README.md` §Handback).

---

## 2. The seven operations

| Op | Command |
|---|---|
| `create` | `gh issue create --title '[CODE]-[PHASE]-[NUM] — <title>' --body-file <f> --label 'phase:<PHASE>' --label 'state:to-do' [--label <tag>…]` |
| `status` | `gh issue edit <n> --remove-label 'state:<old>' --add-label 'state:<new>'` (+ close/reopen, §3) |
| `comment` | `gh issue comment <n> --body-file <f>` |
| `query` | `gh issue list --label 'phase:<PHASE>' --state all --limit 200 --json number,title,labels,state,url,body,milestone` |
| `link` | `https://github.com/<owner>/<repo>/issues/<n>` — built from the number, no call |
| `milestone` | `gh api repos/{owner}/{repo}/milestones -f title='[CODE]-WAVE-<n>'` · assign · close (below) |
| `label` | `gh issue edit <n> --add-label '<tag>'` / `--remove-label '<tag>'` |

`create` prints the issue URL on stdout; the number is its last path segment. Use `--body-file`, not `--body`: a body with backticks inside a shell string is command substitution under zsh.

**Milestone.**

```bash
# create  → returns JSON; keep .number and .html_url
gh api repos/{owner}/{repo}/milestones -f title='[CODE]-WAVE-<n>' -f description='<wave goal>'
# assign  → one call per member ticket
gh issue edit <n> --milestone '[CODE]-WAVE-<n>'
# close
gh api --method PATCH repos/{owner}/{repo}/milestones/<milestone_number> -f state=closed
```

Milestones are native here, so no `wave-<n>` label is needed — but write one anyway if the project also mirrors to `local-html`, because the JSON board carries waves as tags.

**Query is the one to watch.** `gh issue list` defaults to `--state open` and to 30 results. Both defaults are wrong for an audit: `complete` and `cancelled` tickets are closed, and a wave is more than 30 tickets by REV. Always pass `--state all --limit 200`, and keep `state` in `--json`: §3 reads a closed issue carrying no `state:` label as `complete`, which needs the open/closed bit.

**`blocked_by` costs no extra call.** It is parsed out of the `body` this query already returns — the `Blocked by: #<n>` lines (§5) — plus the native sub-issue links where the repo has them.

---

## 3. State mapping

GitHub has two states: open and closed. Ours are carried in a `state:` label; the open/closed bit is derived so the issue list looks right to a human who never reads labels.

| Marcus | Label | Issue state | Close reason | ← read back |
|---|---|---|---|---|
| `to do` | `state:to-do` | open | — | `to do` |
| `on hold` | `state:on-hold` | open | — | `on hold` |
| `in progress` | `state:in-progress` | open | — | `in progress` |
| `review` | `state:review` | open | — | `review` |
| `blocked` | `state:blocked` | open | — | `blocked` |
| `decision` | `state:decision` | open | — | `decision` |
| `accepted` | `state:accepted` | open | — | `accepted` |
| `declined` | `state:declined` | closed | `not planned` | `declined` |
| `complete` | `state:complete` | closed | `completed` | `complete` |
| `cancelled` | `state:cancelled` | closed | `not planned` | `cancelled` |

**Reading back: the label is the authority, the open/closed bit is not.** A closed issue with no `state:` label reads as `complete`; an open one with none reads as `to do`. Never infer `declined` vs `cancelled` vs `complete` from the close reason alone — three of ours collapse onto two of theirs.

`status` is therefore up to three calls at a boundary:

```bash
gh issue edit <n> --remove-label 'state:review' --add-label 'state:complete'
gh issue close <n> --reason completed          # only when crossing into a closed state
gh issue reopen <n>                            # only when crossing back out
```

Exactly one `state:` label at a time. Two is a corrupt ticket — `query` must report it rather than pick one.

---

## 4. Phase mapping

One label per phase: `phase:DISC` · `phase:ARCH` · `phase:DESI` · `phase:DEV` · `phase:QA` · `phase:REV` · `phase:HAND`. Set at creation, never changed — a ticket's phase is where it was created.

There is no list to move between, so the frontier query is a label filter. One `gh issue list` per phase, or one over the whole repo filtered locally on the returned `labels` array — prefer the latter when auditing more than two phases.

---

## 5. Hierarchy

`[CODE]-[PHASE]-[NUM].[N]` is a child of `[CODE]-[PHASE]-[NUM]`. Two mechanisms, and **both are always written**:

1. **Body line, always.** The first line of every child's body:
   ```
   Parent: #<parent number>  ([CODE]-[PHASE]-[NUM])
   ```
   This is what lets `query` rebuild the tree from the `body` field it already fetched — no extra call, works on every repo, survives an org that has sub-issues disabled.

2. **Native sub-issue, where the repo has them.** The API takes the child's **database id**, not its issue number — passing the number silently links the wrong issue or 404s:
   ```bash
   child_id=$(gh api repos/{owner}/{repo}/issues/<child_number> --jq .id)
   gh api --method POST repos/{owner}/{repo}/issues/<parent_number>/sub_issues -F sub_issue_id="$child_id"
   ```
   A 404 or 422 here means sub-issues are unavailable on this repo. That is not an error — the body line already carries the relationship. Note it once, move on, do not retry per ticket.

Blockers (`../SKILL.md` §7) are created as children this way: `state:blocked`, assigned to the owner when only the owner can unblock (`gh issue edit <n> --add-assignee <login>`).

Sibling blocking edges have no native form. Write them in the body as `Blocked by: #<n>` and let `query` parse them.

---

## 6. Limits

Generous, but not unlimited, and the secondary limits bite on exactly the pattern a wave produces — a burst of writes.

| Limit | Value | What hits it |
|---|---|---|
| Primary, authenticated | 5 000 requests / hour | Nothing we do |
| Secondary, content-creating | ~80 / minute, ~500 / hour | A 20-ticket wave: create + label + milestone in a tight loop |
| Search API | 30 / minute | `gh issue list --search` |
| Page size | 30 by default | Every `query` that forgets `--limit` |

Rules: **sleep briefly between creates in a loop** rather than firing twenty at once; batch the checkpoint's status and comment writes as one pass; never poll. A 403 whose body names a secondary rate limit is a back-off signal, not a permission failure — wait, do not re-auth.

Pagination: `--limit N` on `gh issue list`; `--paginate` on `gh api`. A truncated audit that looks complete is worse than a failed one.

---

## 7. Degradation

**Triggers:** `gh auth status` failing · no network · 403 on write (scope or secondary limit) · any write failing twice.

Then, in order:

1. **Stop writing to GitHub for the rest of the session.**
2. **Write every pending write to `docs/handoffs/<date>-<CODE>-orchestrator-queue.md`**, one replayable line per operation — same format as `clickup.md` §7.
3. **Do not initialise `docs/tracker.json` to hold a mirror at the moment of failure.** `clickup.md` §7 step 3 rules on that: a board written while the service is unreachable is this session's slice of the queue with every untouched issue missing, and step 4 then hands the owner that file as *the state*. **A project whose `tracker.adapter` is `local-html` keeps its own board by its own procedure (`local-html.md` §5). A degraded `github` run writes no `docs/tracker.json`, present or not.** Step 2's queue file is the replay log, and the readable state is **`docs/waves/[CODE]-plan.md`** inside a wave and **`docs/handoffs/<date>-<CODE>-session-handoff.md`** outside one — `new` at DISC-3, `justflow` and `resume` outside a wave have no *current* plan file — both committed to git and neither needing a tracker read to be written.
4. **Say it out loud in the session's next message to the owner**, naming the trigger and both files:
   > GitHub Issues is unreachable (`gh auth status` fails). State is in `docs/waves/<CODE>-plan.md` inside a wave, `docs/handoffs/<date>-<CODE>-session-handoff.md` outside one; pending writes queued in `docs/handoffs/<date>-<CODE>-orchestrator-queue.md`. The tracker is behind by <n> writes.
5. **Never drop a write silently.** Replay the queue file at the start of the next session, then audit.

The one case that is not degradation: `origin` is not a GitHub remote. That is a wrong adapter choice, and the answer is `/marcus init`, not a fallback.

---

## 8. Wave view

Milestones are native, so one wave = one milestone, assigned issue by issue. Written at **four moments** — the **plan**, the **claim**, the **`in review`** mark and the **close** (`../modes/wave.md` § *Tracker view of a wave*). **A milestone is open-or-closed and takes no comments**, so the two middle moments land in the one field it has: see *The mirror* below.

```bash
# plan — after the owner's ok, BEFORE the plan commit. The description carries the plan's path;
# keep .number and .html_url and write them into that wave's "Tracker task:" line in the plan —
# that is where the close reads them from, in another session (../modes/wave.md, wave plan step 8)
gh api repos/{owner}/{repo}/milestones -f title='[CODE]-WAVE-<n>' \
  -f description='Plan: docs/waves/[CODE]-plan.md'
gh issue edit <n> --milestone '[CODE]-WAVE-<n>' --add-label 'wave-<n>'    # one call per member ticket

# re-plan — SAME batch as the plan: create only where that wave's "Tracker task:" line is empty,
# and close each superseded planned wave's milestone. GitHub has no "cancelled" state for one.
# The members keep their wave-<n> label: the closed milestone is the authority (README.md §Wave view)
gh api --method PATCH repos/{owner}/{repo}/milestones/<number> -f state=closed

# claim — wave <n> step 2.4, on the number off that wave's "Tracker task:" line. ONE call: the
# milestone stays open, and the Status: line plus the claim block are rewritten in the description
gh api --method PATCH repos/{owner}/{repo}/milestones/<number> -f description="$(cat <claim file>)"

# in review — wave close step 4. Same field, the Status: line rewritten to "review". The milestone
# does NOT close here: closed is the owner's merge, and step 6 is what writes it
gh api --method PATCH repos/{owner}/{repo}/milestones/<number> -f description="$(cat <review file>)"

# wave status step 0 — ONE read for every wave of the plan, not one per wave. Writes nothing
gh api --paginate 'repos/{owner}/{repo}/milestones?state=all' \
  --jq '.[] | {number, title, state, description}'

# close, where the plan's "Tracker task:" line came back EMPTY — one lookup by title, once,
# and the Status: merged commit — wave close step 6, sub-step 1 — writes it back (../modes/wave.md)
gh api --paginate 'repos/{owner}/{repo}/milestones?state=all' \
  --jq '.[] | select(.title=="[CODE]-WAVE-<n>") | .number'

# close — state and the end-of-wave summary in ONE PATCH, once the wave is an ancestor of the trunk
gh api --method PATCH repos/{owner}/{repo}/milestones/<number> \
  -f state=closed -f description="$(cat <summary file>)"
gh issue edit <n> --remove-label 'state:review' --add-label 'state:complete'            # one per member ticket
```

**`state=all` is load-bearing in that lookup.** `gh api` returns `state=open` milestones by default, so a wave whose milestone a re-plan already closed — or one closed by a `wave close` whose plan write never landed — comes back as nothing at all, and the close concludes there is no task where there is one. `--paginate` for the reason §6 gives: 30 per page, and a long-lived repo outruns that. A line that is `—` and not empty is adapter `none`'s, never this adapter's: do not run the lookup on it.

**A GitHub milestone takes no comments**, so the end-of-wave summary goes in its **description**: keep `Plan: docs/waves/[CODE]-plan.md` as the first line and append the five sections under it, in the same PATCH that closes the milestone. One object, one call, and the summary sits where the wave does — a comment sprayed across N member issues would cost N calls to say one thing N times.

**The mirror, and why it is the description here too.** A milestone has **two** states — there is no `in progress` and no `review` to set — and §3's `state:` label trick does not reach it: labels go on issues, not on milestones. So the claim and the `in review` mark are written where the summary is, and the description carries a fixed shape the whole way:

```
Plan: docs/waves/[CODE]-plan.md          # first line, never rewritten
Status: in progress | review             # rewritten at each moment — this is the mirrored status
Claim: session <id> · <machine> · <claimed_at>
— Marcus · wave · session <id> · <YYYY-MM-DD>       # ../SKILL.md §7, the claim's signature
```

**The milestone stays `open` through both**, and `state=closed` keeps meaning exactly one thing: the wave is in the trunk. Closing it at `in review` to signal "done" would make every read of `state` a lie for as long as the owner takes to merge, and §8's own `state=all` lookup depends on that bit meaning what it says. `wave status` step 0 reads `state` **and** the `Status:` line, and reports the plan against them on that step's equivalence — the plan's `in review` is this line's `review`, because the mirror carries the contract's ten-state word (`README.md` § *The contract*) and never the plan's. The cost is `1` per moment rather than `2`: one object, one field, one PATCH — read the current description first only if you are appending rather than rewriting the block.

The `wave-<n>` label rides along on the same `gh issue edit` — one call, not two — and is what keeps the wave readable after a mirror to `local-html`, whose board carries waves as tags (§2). Cost against ~80/minute (§6): `1 + N` at the plan, **per wave**, one batch for the whole plan; `1` at the claim and `1` at the `in review` mark — one PATCH each, not two calls, because the milestone has nowhere else to put them; `1` **read** for all waves at `wave status`; `1 + N` at the close (the one PATCH plus a `state:` swap per member). On a wave past ten tickets, sleep briefly between them rather than firing them at once. Unreachable → §7; the plan and the claim are commits either way.


---

## 9. Handback — the owner's actions and decisions

The shape is `README.md` §Handback. §5 has no real subtasks, so a decision links its parent in the body and the **labels** carry the split.

- **ACTION** — `gh issue create … --label 'state:to-do' --label 'ready-for-<owner>' --assignee <owner login>`. He executes it and closes it.
- **DECISION** — title `[CODE]-[PHASE]-[NUM].D<n> — Décision : <the question>`, `--label 'state:decision' --label 'decision' --assignee <owner login>`, the parent ticket linked in the body. **He** swaps to `state:accepted` or `state:declined` and comments; Marcus never runs that edit, in any mode.
- **The sweep**, on `resume` — `gh issue list --label 'state:accepted'`, then again for `state:declined` (`--label` ANDs, so two calls). The **comment is the answer**, not the label; comment what you executed on the decision, then move the **parent** off `state:blocked`. The decision keeps the label the owner gave it.
