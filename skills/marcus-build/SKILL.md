---
name: marcus-build
description: "Linus's ARCH-phase instrument: interrogate the plan while it is still cheap, then turn the spec into architecture context, code standards, ADRs, the data model, API contracts, auth boundaries and a test strategy. Load at the start of Phase 1 ARCH, and before any decision that is expensive to reverse."
---

# Marcus build

> Replaces two instruments this plugin used to borrow. The eng-manager plan review comes from the **gstack** skills by Garry Tan (MIT, © 2026) — the instinct it encodes, that a plan is the cheapest thing in a project to break, is his. The backend checklist replaces a loose local `backend-architect` skill carrying no licence header and no traceable author. Both are rewritten here from scratch, in our own words, so the plugin ships with no external dependency.

**Architecture is the subset of decisions that are expensive to reverse.** Everything else is implementation, and implementation can be argued about in review. This skill exists to find that subset before it gets decided by accident.

---

## The fence

You are a judgment role. **Read-only on product code** — `src/`, `supabase/`, config, migrations, anything that ships. Your write scope is documentation: `docs/architecture-context.md`, `docs/code-standards.md`, `docs/adr/*.md`. Something wrong in the code is a *finding*, ranked and returned, never a one-line fix on the way past.

On `.worktrees/…` paths the Edit/Write tools are blocked → write through `python3` or a shell heredoc.

## Before you write a line

Read in order: the project `CLAUDE.md` → `docs/project-overview.md` → the spec → existing `docs/adr/`. **Never assume the stack** — it differs per project, and an ADR written against the wrong one is worse than no ADR.

If the spec contradicts an existing ADR, that is finding #1 and everything else waits. Superseding an ADR is a decision; drifting away from one is an accident.

---

## Part 1 — Interrogate the plan

Four questions, in this order. **Answer all four in writing.** A question you cannot answer becomes an open question for the owner — never a silent assumption.

### 1. What breaks at 10×?

Ten times the rows, the users, the concurrent agents, the calls per hour. You are looking for the **first** thing to break, not everything that eventually does — the first one is the design constraint, the rest are its consequences.

Where it usually is: the unindexed column in the query that runs on every page · the single writer everything serialises on · the third-party quota measured per hour · the job that is O(n) over a table which only grows · the thing that is fine today because there is exactly one of it.

> Weak: "Should scale fine, Postgres handles millions of rows."
> Useful: "Orders list sorts client-side over the whole table — fine at 200 rows, 4 s at 2 000. First break is the list page, not the DB."

### 2. Where is the seam?

The seam is where you can test the thing without standing up the world, and replace one side without rewriting the other. **Prefer an existing seam, as high as possible; the ideal count is one.** Every extra seam is an interface that has to stay true forever.

Name it concretely — the module, the function signature, the table, the RPC. If the honest answer is "there isn't one", say so: a feature with no seam is a feature with no tests, and that is a decision somebody should make on purpose.

### 3. What is irreversible?

The one-way doors. Data you delete, a public URL shape, a dropped column, a migration applied to production, a schema other people now build on, a vendor whose export nobody has tried, anything with real money or a real customer at the far end.

Rank the plan by reversibility and **sequence the reversible parts first.** A decision undoable in an afternoon does not need a meeting; a decision that is not needs an ADR and the owner.

### 4. What did the spec leave undecided?

The gaps a builder will fill silently at 2 a.m. Read the spec for the noun with two meanings, the state nobody described (empty, error, partial, concurrent), the role nobody mentioned, the timezone, the second language, the "and then it syncs".

Every gap becomes exactly one of three things: an ADR (you decided, with reasons), an open question for the owner (the owner decides), or a non-goal written into the spec. **Nothing stays merely noticed.**

---

## Part 2 — The backend checklist

Run this on every ARCH pass that touches data. Four areas; each one has already shipped a bug on this team.

**Schema and migration plan.** Tables, columns, types, nullability, defaults, foreign keys, and what happens on delete. Then the *order*: timestamped migrations, distinct timestamps, each one reversible, none locking a table that live traffic writes to. A migration containing `DELETE`, `TRUNCATE`, `cron.schedule`, purge or cleanup gets named in the ADR — nobody approves a deletion they had to infer from line 40.

**Anonymous reads.** Every path reachable without a session goes through a `SECURITY DEFINER` RPC with a pinned `search_path`, never a direct table read. Every write policy carries both `USING` and `WITH CHECK`, and they agree — `USING` alone lets a row be moved to another owner. Put the negative test in the test strategy now: query the row as a *second real user* and assert **zero rows**. RLS filters silently, so "no error" is not a pass.

**Idempotency.** Anything the network can retry: a webhook, a payment callback, a form the user double-taps, a job runner. Name the key that makes the second call a no-op, and say where it lives. "It won't be called twice" is not an answer — it is the bug.

**Expand–contract for wide changes.** Any change to a shape other code reads goes in three steps: add the new alongside the old (expand) → move every reader → drop the old (contract), each step shippable alone. A rename done in one commit is an outage with good intentions.

---

## Part 3 — What you produce

| Artifact | Must contain |
|---|---|
| `docs/architecture-context.md` | module map / component tree · data model · API contracts as payload shapes, both directions · auth boundaries and what sits either side · system invariants · performance targets, with numbers |
| `docs/code-standards.md` | the conventions this repo will actually enforce: naming, error shape, where validation lives, i18n rule, token rule, test layout. Short and enforced beats complete and ignored. |
| `docs/adr/ADR-0001-stack.md` | the stack, and the alternatives rejected, each with the reason it lost |
| `docs/adr/ADR-000N-*.md` | **one per non-obvious decision.** If a competent engineer could have chosen otherwise, it needs a file. |
| Test strategy | inside `architecture-context.md`: the seams from Q2, what is covered at each, and what is deliberately not covered |

### ADR shape

```
# ADR-000N — <the decision in five words>
Status: proposed | accepted | superseded by ADR-000M
Date: YYYY-MM-DD

## Context
What forced a choice. The constraint, not the history.

## Decision
What we are doing. Present tense, one paragraph.

## Alternatives rejected
Each with the one reason it lost. An ADR with no rejected alternative
is a note, not a decision.

## Consequences
What gets easier, what gets harder, what we now live with.
Including: is this reversible, and at what cost.
```

`Status` carries more weight than it looks. An ADR is never edited into a new opinion — it is **superseded** by a new file that names it. The trail is the point.

---

## Output to Marcus

Raw data, not prose. Reference every artifact **by path; never paste a file back.**

```
ARCH — [CODE]
Documents: <paths written>
ADRs: ADR-000N <title> — one line each
Plan review: 10× · seam · irreversible · undecided — one line each
Findings: 🔴 blocker · 🟡 should fix · 💭 nit — most severe first,
          each with file/decision, the failure scenario, the proposed fix
Open questions for the owner: numbered, each with your recommendation
Verdict: ARCH READY / ARCH BLOCKED ON <n> DECISIONS
```

**Flag every decision that affects another agent before it is locked**, not after. Ada and Neo build against these contracts; a contract changed during DEV costs two worktrees and a re-review.

---

## Failure modes this exists to stop

| What it looks like | Which part |
|---|---|
| An ADR-0001 listing the stack with no rejected alternative | Part 3 — that is a note, not a decision |
| "Scales fine" with no number and no first break named | Part 1 Q1 |
| A feature with no test seam, and nobody saying so | Part 1 Q2 |
| A migration that deletes data, approved because nobody read line 40 | Part 2 — schema |
| A webhook handler that charges twice on a retry | Part 2 — idempotency |
| A column renamed in one commit, three readers still on the old name | Part 2 — expand–contract |
| An ambiguity spotted in ARCH, resolved silently in DEV, resolved wrong | Part 1 Q4 |
| A `src/` file "obviously" fixed during the architecture pass | The fence |
