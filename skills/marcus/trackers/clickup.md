# `clickup` — ClickUp through the MCP connector

The richest adapter: real subtasks, custom statuses one-to-one with our vocabulary, native dependencies, native tags. Also the most fragile — interactively authenticated and hard rate-limited. Read §6 and §7 before choosing it.

Config keys read: `tracker.workspace` · `tracker.space` · `tracker.folder` · `tracker.lists.<PHASE>` · `tracker.ownerUserId` · `tracker.fallback`. Nothing else.

---

## 1. Auth

The MCP connector, authenticated interactively in the session. **No token ever lives in the repo.**

| Situation | What it looks like | What to do |
|---|---|---|
| Live | `clickup_*` tools resolve | Normal operation |
| Absent | the tools are not in the session at all | Degrade (§7). Do **not** prompt — a headless or scheduled run has nobody to prompt |
| Revoked mid-run | first call after a run of successes fails on auth | Degrade (§7). One retry, then stop |

**`workspace_id` is required on every call when the account has more than one workspace.** Omit it there and the call resolves against the wrong workspace or errors on ambiguity — neither of which reads as a failure in the response. Always pass `config.tracker.workspace`, even on a single-workspace account: the account grows, the calls do not.

**Task ids are the raw ClickUp ids, never the `[CODE]-[PHASE]-[NUM]` custom id.** A custom id passed as `task_id` comes back as *Team not authorized* — an authorization-shaped error for what is an id-format problem, which is why the rule sits here and not in §2. The raw id is the one in `https://app.clickup.com/t/<id>`, and it is what every ticket's tracker line already carries.

---

## 2. The seven operations

| Op | Call | Arguments |
|---|---|---|
| `create` | `clickup_create_task` | `list_id` = `config.tracker.lists.<PHASE>` · `name` = `[CODE]-[PHASE]-[NUM] — <title>` · `markdown_description` = body · `parent` = parent task id for sub-work · `status` · `tags` · `assignees` = `[config.tracker.ownerUserId]` on a blocker subtask (§5) or a handback task (§9) |
| `status` | `clickup_update_task` | `task_id` · `status` (the string from §3) |
| `comment` | `clickup_create_task_comment` | `task_id` · `comment_text` |
| `query` | `clickup_filter_tasks` | `list_ids` = every phase list · `statuses` · `assignees` · `subtasks: true` — **one call per audit**, never one per list. `blocked_by` is **not** in this response: dependencies come from `clickup_get_task` with `include: ["dependencies"]`, one call per ticket that has an edge — resolve them only for the tickets the frontier actually turns on |
| `link` | *(none)* | `https://app.clickup.com/t/<id>` — a pure string. `clickup_get_task` only when you need the task's fields, never just for its URL |
| `milestone` | `clickup_create_task` + `clickup_add_tag_to_task` | see below |
| `label` | `clickup_add_tag_to_task` / `clickup_remove_tag_from_task` | `task_id` · `tag_name` |

**Milestone.** ClickUp has no milestone object — it has a milestone *task type*.

- **create** — one `clickup_create_task` in the wave's phase list, `name` = `[CODE]-WAVE-<n>`, marked as a milestone where the Milestones ClickApp is enabled (a plain task where it is not — the grouping is carried by the tag either way). Then one `clickup_add_tag_to_task` per member ticket with `wave-<n>`. Cost: 1 + one per ticket.
- **close** — `clickup_update_task` on the milestone task, status `complete`. The member tags stay: they are how a later audit reconstructs which wave a ticket belonged to.
- Returns the milestone task's id and `https://app.clickup.com/t/<id>`.

**Dependencies.** A blocking edge between two tickets is `clickup_add_task_dependency` (`task_id` · `depends_on`), not a sentence in the body. `query` returns them; a body mention does not.

**`clickup_get_folder` does NOT return the folder's lists.** It returns the folder object only — a trap that reads as "the folder is empty". Resolve list ids with **`clickup_get_workspace_hierarchy`** (one call, the whole tree) or one `clickup_get_list` per phase (seven calls). Use the hierarchy call: seven calls against a 300-call window (§6) spends seven on something one call answers.

---

## 3. State mapping

ClickUp custom statuses are configured to match our vocabulary **one-to-one**, so both directions are the identity. That is the whole reason this adapter is the rich one.

| Marcus | ClickUp status | Type | ← read back as |
|---|---|---|---|
| `to do` | `to do` | Not started | `to do` |
| `on hold` | `on hold` | Active | `on hold` |
| `in progress` | `in progress` | Active | `in progress` |
| `review` | `review` | Active | `review` |
| `blocked` | `blocked` | Active | `blocked` |
| `decision` | `decision` | Active | `decision` |
| `accepted` | `accepted` | Active | `accepted` |
| `declined` | `declined` | Closed | `declined` |
| `complete` | `complete` | Done | `complete` |
| `cancelled` | `cancelled` | Closed | `cancelled` |

Status strings are lowercase and are matched by name, not by id.

**`decision` is a status *and* a tag, and a decision carries both.** The status is what the handshake turns on (`../SKILL.md` §7); the tag is what puts the owner's open calls in one filterable view beside his `ready-for-<owner>` actions. Set both on the same task, in the same batch as the `create` (§9). A task carrying one without the other is half-created, not a variant — add the missing half rather than reading it as historical.

**`accepted` and `declined` are the owner's to set.** They are in the table because `query` has to read them back, never because Marcus writes them: he opens the `decision` and closes it after the answer, and the status in between is the owner's signature (`../SKILL.md` §7 step 2).

**A list missing these statuses is an init failure, not a runtime workaround.** `/marcus init` §2 verifies the status set when it verifies the ids. Collapsing ten states onto ClickUp's three defaults loses `blocked`, `decision` and `declined` — exactly the three the owner needs to see. Say so and stop; do not improvise a lossy mapping mid-run.

---

## 4. Phase mapping

One list per phase, id in `config.tracker.lists.<PHASE>`, inside `config.tracker.folder`.

| Phase | List name |
|---|---|
| `DISC` | Phase 0 · Discovery — DISC |
| `ARCH` | Phase 1 · Architecture — ARCH |
| `DESI` | Phase 2 · Design Validation — DESI |
| `DEV` | Phase 3 · Implementation — DEV |
| `QA` | Phase 4 · QA & Verification — QA |
| `REV` | Phase 5 · Code Review — REV |
| `HAND` | Phase 6 · Handoff & Ship — HAND |

Ids are the authority; the names are what a human reads in the UI. A ticket never moves list — its phase is where it was created.

---

## 5. Hierarchy

`[CODE]-[PHASE]-[NUM].[N]` is a **real ClickUp subtask**: `clickup_create_task` with `parent` = the parent's task id. Never a flat task, never a checklist item — a checklist item has no id, no status and no URL, so three of the seven operations cannot reach it.

Blockers (`../SKILL.md` §7) are created exactly this way: subtask, status `blocked`, `assignees` the owner when only the owner can unblock.

Sibling ordering constraints are dependencies (§2), not hierarchy.

---

## 6. Limits

**300 calls per rolling 24 h window, then a lockout until the budget returns.** The budget is shared across every session and every project. This is the binding constraint on every ClickUp run and the reason every mode batches at the checkpoint.

**What is measured, and what is not.** Two named reopenings — ≈ 10:00 CEST (2026-09-28) and ≈ 17:35 CEST (2026-09-30), `docs/handoffs/2026-09-27-MRCS-orchestrator-queue.md` and `docs/handoffs/2026-09-30-MRCS-orchestrator-queue.md` — exclude every fixed daily boundary on the named times alone: a calendar-day reset would have named a midnight. The 2026-09-30 queue file names ≈ 17:35 CEST as the reopening; no call was made at that time — the next successful write was the 20:50 replay — so the named time is consistent with what followed and was never tested at it. One reading alone excludes only the *local* midnight — 17:35 CEST is 00:35 JST — so the pair is the argument and a single figure is not. **What no reading yet settles is whether the budget comes back whole when `retryAfter` elapses, or call by call as each spent call ages out.** `docs/handoffs/2026-09-15-*` holds seven readings from one day: four taken between ~10:00 and 12:15 converge on one instant that afternoon (≈ 13:20–13:25 across all four), and three taken that evening name three different next-day instants — ≈ 10:35, ≈ 13:55 and ≈ 13:26 on 2026-09-16. The ~18:50 reading named ≈ 10:35 the next morning, and then **fourteen writes landed at 20:35 that same evening**, before the reopening it had named. Budget returned before `retryAfter` elapsed, which no whole-window reset explains.

**A second line of evidence, recorded-not-total:** between the ≈ 13:21 reopening and the 18:50 refusal that day the handoffs record ≈ **45** calls, not 300 (`docs/handoffs/2026-09-15-MRCS-session-11-handoff.md` 22 + 1 · `-session-12-handoff.md` 20 · `-wave-8-justflow-log.md` 2 at 18:32); a whole reset would have left ≈ 255. This leans call-by-call **unless ~255 calls went unrecorded, which the handoffs cannot exclude**. And `retryAfter` fits neither model: the evening's named reopenings run 10:35 → 13:55 → 13:26, non-monotonic, which oldest-call-ages-out cannot produce. So read `retryAfter` as the service's own figure, not a schedule — measured once naming a time fourteen hours later than calls actually landed (2026-09-15); record it, never compute one, never fire a long batch on it, and do not write either model into a procedure.

**The measurement that would settle it, and nobody has taken it.** At the next lockout: record `retryAfter`, then fire calls **one at a time, one per minute, counting them** — starting at the refusal, not after `retryAfter` elapses: the interesting signal (first landing vs named time) lives before the named time, and the count after it still answers whole-vs-trickle. A budget that returns whole gives ≈ 300 before the next refusal; a budget that returns call by call gives roughly as many as were spent in the first minute of the exhausted window, then refuses again. **One counted minute is the whole experiment** — until someone runs it, this section says unmeasured rather than naming the likelier model.

**Three dated measurements, each one killing its predecessor's phrasing.** **2026-09-15** — `retryAfter` **12 301 s**, recorded at the time as a lockout of fixed length; it has no fixed length. **2026-09-27** — `retryAfter` **62 179 s**, recorded at the time as running to the next calendar-day boundary; closer, and still wrong. **2026-09-30 00:39 CEST** — `retryAfter` **60 972 s** on a `300/300` body, whose reopening ≈ 17:35 CEST is one half of the pair above — which is what kills the calendar-day boundary, neither reading alone. **Read `retryAfter` for the retry time; never compute one from a clock.** The raw session records behind these three are not published.

What a lockout looks like: `429 Too Many Requests`, surfaced by the connector as a tool error whose body names **`RATE_LIMIT_EXCEEDED`**, reads literally **`Daily MCP limit reached (300/300 calls used)`** as `docs/handoffs/2026-09-15-MRCS-orchestrator-queue.md` records it, and carries **`retryAfter`** in seconds, and then subsequent writes failing the same way (one read answered mid-lockout on 2026-09-15 12:15; do not spend calls finding out). **`Daily` in that string is the service's own label for the limit and says nothing about when the window rolls** — reading it as a rule is the likeliest source of the calendar-day phrasing this section already retired (above). **Read that body on the first refusal** — it is the signal, and **`retryAfter` is the only figure the response gives for the retry** — record it (§7 step 1); it is not a schedule (above). Waiting for a run of six to confirm it spends five more calls on a question the first refusal already answered. A burst of writes followed by a run of consecutive failures is a lockout even if the text differs.

Budget, per operation: `query` 1 · `create` 1 per ticket · `status` 1 · `comment` 1 · `label` 1 · `milestone` 1 + 1 per member ticket.

| Rule | Why |
|---|---|
| **One `clickup_filter_tasks` per audit**, all phase lists in `list_ids` | Seven calls for one answer, against 300 shared by every session in the window |
| Batch statuses and comments at the checkpoint, never per slice | 12 slices × (status + comment) = 24 calls, and every other session in the window draws on the same 300 |
| **A wave is four writes, never a stream** — `1 + N` at the plan, `2` at the claim, `1` at the `in review` mark, `2 + N` at the close (§8) | a three-wave plan is 11 calls before a single slice runs; a mirror that fired per slice or per `wave status` would multiply that by every slice and every read, for state the plan file already holds |
| `clickup_get_workspace_hierarchy` once, cache the ids into the config | `clickup_get_folder` does not return lists (§2) |
| Never poll | There is no operation that needs polling |

Pagination: `clickup_filter_tasks` pages. Ask for the phase lists you need, not the space.

---

## 7. Degradation

**Triggers:** connector absent · **the first 429 whose body names `RATE_LIMIT_EXCEEDED` / `300/300`** (§6 — do not fire a second to confirm it) · any write failing twice.

Then, in order:

1. **Stop writing to ClickUp for the rest of the session.** Retrying into a lockout spends nothing but calls. Record `retryAfter` at the top of the queue file in step 2, in seconds and as the wall-clock time those seconds name: it is the only figure the refusal gives and it is not a schedule (§6) — the next session treats it as the service's own figure, replays the first owed row as its one probe (step 5), waits for no named time and fires no batch on it.
2. **Write every pending write to `docs/handoffs/<date>-<CODE>-orchestrator-queue.md`** — one line per operation, tracker-agnostic, replayable by hand or by the next session:
   ```
   retryAfter 60972 s — retryAfter names ≈ 2026-09-30 17:35 CEST (seconds from the refusal body; the time is that many seconds after it, not a reopening)

   - [ ] status  MRCS-DEV-4        → review
   - [ ] comment MRCS-DEV-4        → handoff (docs/handoffs/<date>-<CODE>-session-handoff.md)
   - [ ] label   MRCS-DEV-4 add    → wave-1
   - [ ] create  MRCS-DEV-4.1      → blocker, parent MRCS-DEV-4, status blocked, assignee owner
   ```
3. **Do not initialise `docs/tracker.json` to hold a mirror at the moment of failure.** Ruled 2026-10-01: two consecutive lockouts — 2026-09-27 and 2026-09-30 — skipped this step and neither lost state, and the step cannot be obeyed honestly anyway. A lockout is exactly the moment the full board **cannot be read without spending calls into the lockout** (§6), so a board written during one is this session's slice of the queue with every untouched ticket missing — and step 4 then hands the owner that file as *the state*, which is worse than handing him none, because he believes it. **What replaces it:** step 2's queue file is the replay log, and the readable state is **`docs/waves/[CODE]-plan.md`** inside a wave — wave state, the claim block, the end-of-wave summary — and **`docs/handoffs/<date>-<CODE>-session-handoff.md`** outside one, because `new` at DISC-3, `justflow` and `resume` outside a wave have no *current* plan file, and DISC-3 is a large publish burst. Both are committed to git and neither needs a tracker read to be written. **A project whose `tracker.adapter` is `local-html` keeps its own board by its own procedure (`local-html.md` §5). A degraded `clickup` run writes no `docs/tracker.json`, present or not.**
4. **Say it out loud in the session's next message to the owner**, naming the trigger and both files:
   > ClickUp is locked out (`RATE_LIMIT_EXCEEDED`, `300/300`, `retryAfter` <n> s — `retryAfter` names ≈ <time>). State is in `docs/waves/<CODE>-plan.md` inside a wave, `docs/handoffs/<date>-<CODE>-session-handoff.md` outside one; pending writes queued in `docs/handoffs/<date>-<CODE>-orchestrator-queue.md`. The tracker is behind by <n> writes.

   A degraded run that reads like a normal run is the failure this section exists to stop.
5. **Never drop a write silently, and never guess it succeeded.** On the next session, replay the queue file first, then audit. **A long replay can re-lock part-way**, because the budget may be returning call by call rather than whole (§6): a 16-call batch on 2026-09-15 landed 14 and was refused on 2 (rows 7 and 16 of a burst fired at once) (`docs/handoffs/2026-09-15-MRCS-wave-8-justflow-queue.md`), while the 13 rows owed on 2026-09-30 replayed in full about three hours **after** the reopening `retryAfter` had named (`docs/handoffs/2026-09-30-MRCS-orchestrator-queue.md`). So fire the owner-facing rows — the DECISION and ACTION creates — **first**, tick each row as its call returns, and rewrite the queue to the rows still owed if it re-locks. Do not race the reopening with a long batch.

---

## 8. Wave view

One wave = **one task of type `Wave`** + one tag per member. Written at **four moments** — the **plan**, the **claim**, the **`in review`** mark and the **close** (`../modes/wave.md` § *Tracker view of a wave*). Two of them are one batch each; the claim and the `in review` mark are the mirror, `2` calls and `1`.

| Piece | Call | Arguments |
|---|---|---|
| The wave task | `clickup_create_task` | `list_id` = `config.tracker.lists.DEV` · `name` = `[CODE]-WAVE-<n>` · `task_type` = `Wave` (the fallback chain below) · `markdown_description` = the plan's path (`docs/waves/[CODE]-plan.md`), then the member ids one per line |
| The id, recorded | *(no call)* | the created task's `url` goes into that wave's `Tracker task:` line in `docs/waves/[CODE]-plan.md`, **before** the plan commit. `wave close <n>` runs in another session and reads it there instead of searching for the task (`../modes/wave.md` §`wave plan` step 8) |
| The members | `clickup_add_tag_to_task` | `task_id` · `tag_name` = `wave-<n>`, one call per member ticket. **Not** the `tags` array on `clickup_create_task`: that one requires the tag to already exist in the space (§2) |
| The claim, status | `clickup_update_task` | `task_id` = the wave task, **off the plan's `Tracker task:` line** · `status` = `in progress` (`../modes/wave.md` §`wave <n>` step 2.4) |
| The claim, comment | `clickup_create_task_comment` | `task_id` = the wave task · `comment_text` = the three claim lines — `session`, `machine`, `claimed_at` — ending with the `../SKILL.md` §7 signature line. **One comment, and the wave's only one until the close** |
| `in review` | `clickup_update_task` | `task_id` = the wave task · `status` = `review` (§`wave close <n>` step 4). **Not `complete`** — the wave is not merged yet, and `complete` is step 6's |
| The status, read | `clickup_get_task` | `task_id` = the wave task — `wave status` step 0 only, one per wave carrying a `Tracker task:` line, and it writes nothing back |
| Close | `clickup_update_task` | `task_id` = the wave task · `status` = `complete` |
| The summary | `clickup_create_task_comment` | `task_id` = the wave task · `comment_text` = the five-section end-of-wave summary (`../modes/wave.md` §`wave close <n>` step 6). **One comment, never one per ticket** |
| The members, closing | `clickup_update_task` | one per member ticket to `complete` — the member tags **stay**: they are how a later audit reconstructs which wave a ticket belonged to |

**The `Wave` task type, and its fallback chain.** `clickup_create_task` takes `task_type` **by name**, and the name must already exist in the workspace (§2). Try them in this order, one call, and never stop a plan on a missing type:

1. `task_type: "Wave"` — the type this mode wants.
2. Refused → `task_type: "Milestone"`, where the Milestones ClickApp is enabled.
3. Refused → **omit `task_type` entirely**: a plain task in the DEV list.

**The `wave-<n>` tag carries the grouping in all three cases**, which is why the chain is safe to fall down. Creating a custom task type is a workspace setting, not an operation this connector exposes — so **it is the owner's one-time action**, and the honest thing to do when it is missing is to fall through, say which rung you landed on, and put it on the owner's list. A plan that halts because a task type does not exist has traded the whole run for a label.

**Cost, against the 300-call window (§6).** Plan: `1 + N` **per wave**, one batch for the whole plan — a three-wave plan over eight tickets is **11 calls**, paid in one batch, and the reason nothing here is written per event. Claim: `2`, once — the status and the signed comment, on the id off the `Tracker task:` line, so **no lookup**. `in review`: `1`, once. `wave status`: `1` **read** per wave carrying that line, and zero writes. Close: `2 + N` per wave (close + the summary comment + one status per member) — **and no lookup**, because the wave task's id came off the plan's `Tracker task:` line. A plan whose `Tracker task:` line is absent or empty costs one `clickup_search` — `keywords` = `[CODE]-WAVE-<n>`, `filters.asset_types: ["task"]`, `workspace_id` = `config.tracker.workspace`: one extra call, once, and the close writes the line back. **Not `clickup_filter_tasks`**: that call filters by structured field values and takes no `name` argument at all — a lookup by task name is a keyword search, and asking `filter_tasks` for one silently returns the wrong set. Locked out or absent → §7 as written: queue the lines, leave the readable state in the plan file, say it out loud in the next message. Both the plan commit and the claim commit are git, so a missing wave task costs the view and never the wave.

---

## 9. Handback — the owner's actions and decisions

The protocol is `../SKILL.md` §7; the adapter-neutral shape is `README.md` §Handback. These are the exact calls.

**The assignee is `config.tracker.ownerUserId`**, passed as `assignees: [<id>]`. Missing from the config → **one** `clickup_find_member_by_name` on `config.owner.name`, reuse that id for the rest of the session, and open one ACTION task asking the owner to record it (`../modes/init.md` §5). Never look it up twice: against §6 a lookup costs exactly what a write costs.

| Piece | Call | Arguments |
|---|---|---|
| **ACTION** | `clickup_create_task` | `list_id` = the phase list · `name` = `[CODE]-[PHASE]-[NUM].[N] — <verb + object>` · `parent` where it belongs to a ticket · `status: "to do"` · `assignees` · `markdown_description` = the five-section body (`../modes/justflow.md` §The handback) |
| ACTION, the tag | `clickup_add_tag_to_task` | `task_id` · `tag_name` = `ready-for-<owner>`. **Not** the `tags` array on `create`: that one needs the tag to exist in the space already (§2) |
| **DECISION** | `clickup_create_task` | `list_id` = **the parent ticket's phase list** (a subtask still needs one, and it belongs where its parent lives) · `parent` = **the ticket it unblocks** · `name` = `[CODE]-[PHASE]-[NUM].D<n> — Décision : <the question>` · `status: "decision"` · `assignees` · `markdown_description` = the five-section body |
| DECISION, the tag | `clickup_add_tag_to_task` | `task_id` · `tag_name` = `decision` |
| **The answer** | *(none — his)* | He sets `accepted` or `declined` and comments. You do not call `clickup_update_task` with either status, in any mode |
| The sweep, on `resume` | `clickup_filter_tasks` | `list_ids` = every phase list · `statuses: ["accepted","declined"]` · `subtasks: true` — **one call for the sweep**, never one per list |
| The answer, read | `clickup_get_task_comments` | `task_id`, one per task the sweep returned. **The comment is the answer**; the status says only that he answered, not what he chose — and on a two-option decision the status alone will read as an answer to the wrong question |
| The close | `clickup_create_task_comment` + `clickup_update_task` | the comment goes on the **decision** (what you executed); the `status` call goes on its **parent** only, off `blocked` / `on hold`. The decision keeps `accepted` / `declined` |

Cost: opening a decision is 2 calls; a sweep is `1 + two per answered task` (read the comments, write the close) `+ one status per parent`. Batch the closes with the checkpoint's other writes (§6). Six decisions is **12 calls** to open (2 each) and **19** to close — the sweep, 6 comment reads, 6 close comments, 6 parent statuses — **31 in all**. What separates the opens from the closes is not the budget but the owner's night — **the answers arrive in the morning** — so **the morning close is its own batch**: the night's 12 ride the night's checkpoint batch, the morning's 19 ride the morning's, and nothing in this file polls for an answer in between. Locked out → §7: queue the lines, and say the tracker is behind. **A handback that was queued and not written is a handback the owner cannot see** — name it in the message rather than letting the block of links go out with tasks that do not exist yet.
