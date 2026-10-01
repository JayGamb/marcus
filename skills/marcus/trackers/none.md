# `none` — no tracker

The honest option for a throwaway. There is no queue: the frontier comes from the owner each session, and `docs/handoffs/` carries the state between them.

Choose it for a prototype or a one-evening spike. Do not choose it for anything that will still exist in a month — the cost is not felt on day one, it is felt the first time a session has to reconstruct what is left.

Config keys read: `tracker.adapter`. No `fallback` — there is nothing below this.

---

## 1. Auth

None, because there is nothing to authenticate against.

---

## 2. The seven operations

All seven are **no-ops that record instead of write**. The record is the session handoff, `docs/handoffs/<date>-<CODE>-session-handoff.md` (`../SKILL.md` §9) — the plan file, and the only file. Nothing new is invented for this adapter.

| Op | What happens |
|---|---|
| `create` | A line under **Prochaines étapes** in the handoff. The id `[CODE]-[PHASE]-[NUM]` is still minted and still used in the commit message and the agent prompt — the convention does not bend, only its storage does |
| `status` | A line under **Livré** (done) or **Prochaines étapes** (not). No state machine, no transition record |
| `comment` | The per-ticket handoff paragraph goes into **Livré** under that id, inline. There is nowhere else for it |
| `query` | **Read the handoff.** That is the whole implementation. It returns what a human last wrote, not what the system last did — treat it as a report, never as truth about the repo |
| `link` | There is no URL. Agent prompts carry the id alone, and the prompt says the tracker is `none` so no agent goes looking for a link that does not exist |
| `milestone` | No-op. A wave is a heading in the handoff and nothing more. Nothing groups the tickets, nothing closes |
| `label` | No-op. `bug`, `decision`, `ready-for-<owner>`, `wave-<n>` are written as words in the handoff line, where nothing can filter on them |

**The asymmetry is the point.** `create`, `status`, `comment` and `label` are lossy but survivable — a human reads the prose. `query` is the one that is genuinely gone, and `query` is what every autonomous mode is built on.

---

## 3. State mapping

| Marcus | Stored as | ← read back |
|---|---|---|
| `complete` | a line under **Livré** | `complete` |
| everything else (`to do` · `on hold` · `in progress` · `review` · `blocked` · `decision` · `accepted` · `declined` · `cancelled`) | prose under **Prochaines étapes** or **Décisions du propriétaire en attente** | **not recoverable** — the reader infers it, and may infer wrong |

Ten states in, two out. That is the deal, and it is the reason the modes in §6 refuse.

---

## 4. Phase mapping

None. Ids still carry their phase (`[CODE]-DEV-4`), so the phase is readable from the id — but there is no list, label or section to group by, and no way to ask "what is open in QA".

---

## 5. Hierarchy

None. `[CODE]-[PHASE]-[NUM].[N]` is still the id for sub-work, written as an indented line under its parent in the handoff. It is a typographic parent, not a queryable one.

Blockers (`../SKILL.md` §7) have no subtask to live in, so they go **at the top of the handoff**, under **Décisions du propriétaire en attente**, with what is needed and the proposed resolution. A blocker buried mid-file is a blocker the next session misses.

---

## 6. Limits — what works, and what refuses

**Works:**

| Mode | Why |
|---|---|
| `prototype` (`rapid`) | Designed with no tracker: one wave, contract-first, the owner is in the room |
| `resume` | Reads `docs/handoffs/` — the one thing that still exists. It says plainly that it is reading a handoff, not auditing a queue |
| `status` | Reports the last handoff and labels it as such. Never presents it as the live frontier |
| `wave` | The plan file is the queue — `wave plan` writes `docs/waves/[CODE]-plan.md` from the tickets the owner names, and every later sub-command reads that file instead of a tracker (`../modes/wave.md`) |
| A named slice | The owner names the next task; Marcus spawns one agent, verifies, reports. The loop still works with a human supplying the frontier |

**Refuses to start:** `justflow` · `ultraflow`. Both compute an unblocked frontier from the queue and then work it without the owner. With no queue there is no frontier, and a mode that guesses one works on whatever it happened to remember — which is exactly the overnight run nobody can review in the morning.

The exact sentence, verbatim, with the mode name substituted:

> `tracker.adapter` is `none`, so there is no queue to compute a frontier from — `<mode>` cannot start. Run `/marcus init` and pick `local-html` (zero dependency, no account, the queue commits with the code), or name the next task and I will work it as a single slice.

Say it once and stop. Do not offer to reconstruct a queue from the handoff, do not run a reduced version of the mode, and do not start and stop at the first ambiguity — a half-run of `justflow` leaves branches nobody asked for.

`new` and `reset` do run, but their `marcus-slice` §Publish writes the plan into the handoff instead of a queue, and the moment either reaches a phase gate it is in the same position as the two above. Say that at the start, not at the gate.

Everything else is unlimited, which is the one genuine advantage: no rate limit, no lockout, no connector to lose mid-run.

---

## 7. Degradation

There is nothing to degrade to and nothing to be unreachable — the failure mode is not technical.

It is this: **a project outgrows `none` without anybody deciding that it did.** Three sessions in, the handoff is carrying twenty open items in prose and the owner is the index. Watch for the tell — a handoff whose **Prochaines étapes** runs past about ten lines, or a second session that has to re-derive what is left — and when you see it, say so:

> This is past what `none` holds. `/marcus init` and switch to `local-html` — I can write the current handoff into `docs/tracker.json` in one pass, and nothing else about the workflow changes.

Migration is one-way and cheap: every id already exists, the phase is in the id, and `complete` is whatever sits under **Livré**. The states that were never recorded (§3) come from the owner, once, and are correct from then on.

---

## 8. Wave view

No-op, like `milestone` and `label` in §2 — there is nothing here to render a wave into, at any of the four moments the other adapters write (`../modes/wave.md` § *Tracker view of a wave*): not the plan, not the claim, not the `in review` mark, not the close. `wave` itself still runs (§6): the plan file `docs/waves/[CODE]-plan.md` is the queue, and every sub-command reads it. **The close costs nothing here** — no wave task to shut, no statuses to push, no comment to post; the plan's `Status: merged` line and the end-of-wave summary block written beside it are the whole of it. **The claim and the `in review` mark cost nothing either, and `wave status` makes no call** — there is no task to move to `in progress` or to `review`, and none to read back: the claim block and the `Status:` line in the plan on `wave/<n>` are the whole of those too.

What a reader looks at instead:

| Question | Where the answer is |
|---|---|
| What is in wave `<n>`, and in what order | that wave's table in the plan file |
| How do I start wave `<n>` | that wave's **kickoff block** — paste it into a fresh session and type nothing else |
| Who holds it, since when, how far along | `/marcus wave status` — git and the plan. On every other adapter it also **reads** that wave's task status first and reports any mismatch (`../modes/wave.md` §`wave status` step 0); here there is no task, so it makes no call and the plan is the whole answer |
| Was it merged | the plan's `Status:`, checked against `git merge-base --is-ancestor wave/<n> [INTEGRATION_BRANCH]` |
| What did it deliver, and what is still blocked | the **end-of-wave summary** block under that wave — built · verified · blocks what · parked · independence |

**This used to be the one place `none` lost nothing the other adapters keep. It is not any more.** The *record* is still the plan file and `none` loses none of it — but the claim and the `in review` mark are now mirrored onto the wave task everywhere else (`../modes/wave.md` § *Tracker view of a wave*), and **`none` loses that mirror**: who holds wave `<n>` and since when, and that a wave is sitting waiting on the owner's merge, are legible only by reading `wave/<n>`'s copy of the plan. On one machine, with one person, that costs nothing real. The moment a second session or a second person is involved, it is exactly the thing they cannot see — and §7 is when to stop paying for it.


---

## 9. Handback — the owner's actions and decisions

`label` and `parent` are both no-ops here (§2, §5), so the handback is **words in the handoff** — and the split is carried by two headings, never one list of "owner stuff" (`README.md` §Handback).

- **ACTION** — a line under **Prochaines étapes**, prefixed `[ready-for-<owner>]`: the id, the verb, the object.
- **DECISION** — a line under **Décisions du propriétaire en attente**, id `[CODE]-[PHASE]-[NUM].D<n>`, naming the ticket it unblocks, the options and the recommendation.
- **The answer** — his, in that line or in session. Nothing filters on either heading and **nothing sweeps**: the next session reads the handoff and asks him which decisions are still open. That is the cost of `none`, and §7 is when to stop paying it.
