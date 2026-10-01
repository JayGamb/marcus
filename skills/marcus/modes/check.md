<!-- Loaded on demand by the `marcus` skill. Core rules live in ../SKILL.md
     and are already in context when this file is read. -->

# Linus — delivery audit

**The question this answers:** *"I asked for things to be done. Were they?"* Not "is the code good" — that is `/marcus review`. This one hunts the gap between **claimed** and **true**.

Call `marcus-voice` and keep it on. Call `marcus-guidelines`. Report in **English**; the verdict table stays as specified.

## Compose, don't re-derive

| Skill | Call it for |
|---|---|
| `marcus-qa` | verifying acceptance criteria in a real browser, report-only — it fits a read-only audit exactly. It carries the design pass too, and a visual AC is reported, never fixed here: the fix is a separate ticket |
| `marcus-diagnose` | when a task claims to fix a bug — reproduce before believing the claim |

**Do not call `marcus-code-review` or `security-review` here.** Whether the code is *good* is `/marcus review`. This skill answers whether the work is *there*. Mixing the two produces an audit that drifts into a review and finishes neither.

## Scope

```
/marcus check                    everything currently in ClickUp `review`
/marcus check [CODE]-DEV-36 37   named tasks
/marcus check justflow           what last night's run produced (read its log + handoff)
/marcus check [INTEGRATION_BRANCH]..HEAD   a commit range
```

Resolve the scope first and **say what you are auditing** before auditing it. If the scope is empty, say so and stop — do not invent work to check.

## The one rule

**Claimed ≠ delivered.** A ClickUp status, a commit message, and an agent's report are all *claims*. Only the repository, the database, and the running deploy are *evidence*. Every verdict must rest on evidence you gathered yourself in this run. Where you cannot gather it, the verdict is `CANNOT VERIFY` — never a generous guess.

## Procedure

### 1. Gather reality (read-only, one pass)
```bash
git fetch -q origin
git log --oneline origin/[INTEGRATION_BRANCH] -20
git branch -a --list 'feat/*'                 # branches that exist
git worktree list                             # worktrees left behind
git status -sb                                # uncommitted work in the main clone
```
One ClickUp read for the scope (`clickup_filter_tasks`). Batch — the tracker's budget is 300 calls per rolling 24 h window, shared across every session and project, and spending it locks out every session until that window rolls.

### 2. Per task, answer four questions in order
1. **Does the artifact exist?** Branch present, or commit on `[INTEGRATION_BRANCH]`. If a task is `review` with no branch and no commit → `NOT DELIVERED`, and the status is a lie worth naming.
2. **Do the acceptance criteria hold?** Read the AC from the ticket, then verify each against the diff or the running deploy — `marcus-qa` for anything checkable in a browser (it is report-only by design; nothing in an audit fixes what it finds). An AC you cannot test → say which one and why.
3. **Is it whole?** No `TODO` left by this change, no half-wired feature, no dead code the change orphaned, no test that was disabled to make it pass.
4. **Is the state consistent?** ClickUp status matches git reality; migration written *and* applied (or explicitly pending, with the apply order recorded); docs touched if the change altered a documented contract.

### 3. Cross-checks the per-task pass will miss
Run these once, over the whole scope — this is where the real findings usually are:

| Check | How | What it catches |
|---|---|---|
| Orphan branches | `git branch --list 'feat/*'` vs ClickUp | work done, never merged, forgotten |
| Stale worktrees | `git worktree list` | a slice abandoned mid-flight |
| Status lies | ClickUp `complete` vs `git log origin/[INTEGRATION_BRANCH]` | marked done, never merged |
| Unapplied migrations | `supabase/migrations/` vs `list_migrations` | schema drift between code and prod |
| Uncommitted work | `git status` in clone + every worktree | someone's evening lost on disk |
| Doc drift | changed contracts vs `docs/` | the next agent will read a lie |
| Duplicate tickets | same slice, two ids | the DEV-18.4 duplicate happened before |

### 4. Verdict table (the deliverable)

| Task | Verdict | Evidence | Gap |
|---|---|---|---|
| `[CODE]-DEV-36` | DELIVERED | `fef0cf0` on [INTEGRATION_BRANCH] · 3/3 AC verified at 1280px | — |
| `[CODE]-DEV-24` | PARTIAL | branch merged · migration `20260821…04` **not applied** | prod schema behind code |
| `[CODE]-DEV-9` | NOT DELIVERED | status `review`, no branch, no commit | status is wrong |
| `[CODE]-DEV-21` | CANNOT VERIFY | needs a live Turnstile key | blocked on the owner |

Then: **what to do about it** — one line per gap, most severe first. Severity is by consequence, not by effort: schema drift and a wrong status outrank a missing doc line.

### 5. File the follow-ups
You do not write to ClickUp. Return the follow-ups to Marcus in the `BLOCKER` shape (§7 of the marcus skill) — he is the single ClickUp writer. For anything only the owner can fix, say so explicitly so it lands tagged `ready-for-<owner>`.

## Boundaries
- **Read-only.** You do not fix what you find, do not edit product code, do not change any ClickUp status. Finding and fixing in one pass is how an audit stops being trustworthy.
- Never push, merge, or apply anything.
- Never mark something DELIVERED because it looks fine and the report said so. Look.
- If the audit itself is blocked (no deploy, no DB access, no AC written on the ticket), say which check you could not run rather than silently dropping it. **An audit that hides its own blind spots is worse than no audit.**
