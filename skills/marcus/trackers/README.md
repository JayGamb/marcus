# Trackers — the adapter contract

Marcus never talks to a tracker directly. Every skill and agent goes through the seven operations below, and an **adapter** maps them onto whatever the user actually runs.

This is what makes the plugin portable. ClickUp, GitHub Issues, or a local HTML file with no dependencies at all — the workflow does not change, only the adapter does. **Four adapters are written; `clickup` is the only one exercised so far**, and each one below says where it stands. A tracker with no adapter yet — Linear, say — is one new file here (§ *Writing a new adapter*), not a blocker.

---

## The contract

Seven operations. An adapter that implements these works with every mode.

| Operation | Input | Returns | Used by |
|---|---|---|---|
| `create` | title · body · list/phase · parent · assignee · tags | task id + url | DISC (`marcus-slice` §Publish), blockers |
| `status` | id · state | — | every phase transition |
| `comment` | id · body — last line = the signature `— <Agent> · <mode> · session <id> · <YYYY-MM-DD>` (`../SKILL.md` §7) | — | the per-ticket handoff, blockers, decisions, wave summary |
| `query` | phase/list · status · assignee | list of {id, title, status, url, parent, blocked_by} | `status`, `resume`, the frontier |
| `link` | id | url | every agent prompt carries it |
| `milestone` | action (`create` \| `status` \| `close`) · name `[CODE]-WAVE-<n>` · ticket ids · state (on `status`) | milestone id + url | wave mode — one wave, one milestone |
| `label` | id · tag · action (`add` \| `remove`) | — | `bug`, `ready-for-<owner>`, `decision`, `wave-<n>` |

`milestone` groups the tickets of one wave under a single name, and its `status` action moves that group through the same ten states a ticket uses — the two moments a wave is mirrored while it runs, the claim and the `in review` mark (`../modes/wave.md` § *Tracker view of a wave*). An adapter whose wave object has fewer states than that says in its §8 what it does instead. `label` is the tag primitive every mode uses for cross-cutting marks — `bug`, `backend`, `frontend`, `design`, `devops`, `ready-for-<owner>`, `decision`, `wave-<n>`.

**The vocabulary is fixed, the mapping is not.** Marcus always thinks in these states:

```
to do → on hold → in progress → review → blocked → decision → accepted | declined → complete
cancelled                                                    from any state
```

Ten states. `decision` is where a ticket waits on the owner to choose; `accepted` and `declined` are the two ways out of it, and **only the owner sets those two** (§Handback). A decision carries the `decision` **status and the `decision` tag** — the status is the state machine, the tag is what puts his open calls in one filterable view beside his `ready-for-<owner>` actions. Both, on the same task; neither alone is the decision.

An adapter maps all ten onto whatever the tracker offers. GitHub Issues has only open/closed, so it carries state in labels. That is the adapter's problem, never the workflow's — and the mapping table in every adapter file runs **both directions**, because `query` has to read a state back out.

Same for the phase lists — `DISC · ARCH · DESI · DEV · QA · REV · HAND`. One ClickUp list each, one GitHub label each, one section each in the HTML tracker.

And the ids are always ours: `[CODE]-[PHASE]-[NUM]`, sub-work `[CODE]-[PHASE]-[NUM].[N]` as a real child of its parent. That convention does not bend per tracker.

---

## Adapters

### `clickup.md` — MCP connector

**The adapter in service, and the only one exercised:** every wave that ran through the Marcus repo itself ran on it. The richest option too: real subtasks (`parent` field), custom statuses matching our vocabulary one-to-one, native dependencies, native tags.

**Costs you should know before choosing it:** the MCP connector is interactively authenticated, so it may be **absent in headless or scheduled runs** — a cloud routine cannot rely on it. And its budget is **300 calls per rolling 24 h window**, shared across every session and project — spend it and every session is locked out until the budget returns. Every mode batches its writes at the checkpoint for that reason.

Milestones are a task type, not a separate object — see the file.

### `github.md` — Issues

**Specified, not yet exercised.** Free, always present where the code is, works headless through `gh`. No real subtasks and no custom statuses, so the adapter carries both in labels (`phase:DEV`, `state:review`) and parent links in the body. Sub-issues where the repo has them. Milestones are native.

The advantage nothing else has: **the tracker lives in the same place as the diff**, so a CI runner reaches it with no extra credential.

### `local-html.md` — zero dependency

**Specified, not yet exercised** — `local-html.md` §6 carries the whole render template, and no board has been generated anywhere yet. A single self-contained `docs/tracker.html` per project: the board, openable in a browser, no account, no network, no MCP. Backed by a plain `docs/tracker.json` that Marcus reads and writes.

Pick this when the project has no tracker yet, when you want the queue committed alongside the code, or when a run has to work with no connector at all. It is also the adapter `clickup` and `github` name as their `fallback` — which names an adapter and nothing more: a degraded `clickup` or `github` run writes no `docs/tracker.json`, present or not, and `clickup.md` §7 step 3 names what carries the state instead.

### `none.md`

No tracker. The frontier comes from the user each session, handoffs carry state. Honest for a prototype; unusable for `justflow` and `ultraflow`, which both need a queue to compute a frontier from — those two refuse to start, with the exact sentence in the file. `wave` still runs: its plan file is the queue.

---

## Wave view

`wave` mode writes the tracker at **four moments and no others** — the **plan**, the **claim**, the **`in review`** mark and the **close** (`../modes/wave.md` § *Tracker view of a wave*). The checkpoint writes nothing at all, and `wave status` only ever **reads**: one read of each wave's task status, reported against git and the plan, correcting neither.

| Moment | Ops | Cost |
|---|---|---|
| **Plan**, after the owner's ok | `milestone create` named `[CODE]-WAVE-<n>`, carrying the plan's path and that wave's ticket ids · `label add wave-<n>` on every member | `1 + N` **per wave**, one batch for the whole plan |
| **Re-plan**, a `wave plan` re-run | `milestone create` **only** where the wave's `Tracker task:` line is empty · `status → cancelled` on each superseded `planned` wave's task, **closed** where the adapter has no `cancelled` (`github` milestones, `local-html` `waves[].state`) · **no `label remove`** — a superseded wave's `wave-<n>` tags stay on its members | same batch as the plan — `1` per new wave, `1` per superseded one, `0` for the tags |
| **Claim**, `wave <n>` step 2.4 | `status → in progress` on the wave task · **one comment** carrying the claim's `session` · `machine` · `claimed_at`, signed per `../SKILL.md` §7 | `2`, once per wave — on the id the plan's `Tracker task:` line already holds, so no lookup |
| **`in review`**, `wave close <n>` step 4 | `status → review` on the wave task; it stays **open** — the close is the owner's merge | `1`, once |
| **Close**, once the wave is an ancestor of the integration branch | `milestone close` · **the end-of-wave summary, written once** · one `status → complete` per member | `2 + N`, one batch — `1 + N` on an adapter that carries the summary on the same call it closes with |

**Two adapters have no state to mirror into, and they do not invent one.** A `github` milestone and a `local-html` `waves[]` entry are open-or-closed objects, and a milestone takes no comments either. Neither closes early to fake a state: `github` rewrites the one field a milestone has — its description, where its summary already goes — in a single PATCH per moment, and `local-html` widens its own `waves[].state` vocabulary, which its renderer prints verbatim. Both are written in their §8, and `none` mirrors nothing at all — the one thing `none` now loses that the others keep (`none.md` §8).

**The cancelled task is the authority, not the tag.** A re-plan does not strip `wave-<n>` off the members it repartitions: that would cost `+N` calls per superseded wave against the very budget that keeps every wave write to four moments, and the close already leaves member tags standing on purpose, as the audit history of which wave a ticket belonged to. So a repartitioned ticket carries two `wave-` tags — the **open** wave task is the live one, the cancelled one is history, and the plan file settles it above both. And a superseded wave whose `Tracker task:` line is **empty** has no task to cancel at all: skip it, and do not pay a lookup hunting for one that was never created (`../modes/wave.md` §`wave plan` step 8).

**Creating the view at plan time is the point:** the owner sees every wave in his tracker *before* he opens a session — and Marcus opens none of them. That same batch writes each wave task's url — its id where the adapter has none, `—` on `none` — into that wave's `Tracker task:` line in the plan, so the close reads it there instead of searching for the task (`../modes/wave.md` §`wave plan` step 8). The plan file is the record; this is the view, and an adapter that cannot reach its service loses only the view.

| Adapter | What a wave looks like | Where the summary goes | Detail |
|---|---|---|---|
| `clickup` | a task of type `Wave` — falling back to `Milestone`, then a plain task — named `[CODE]-WAVE-<n>` in the DEV list, + tag `wave-<n>` on every member | a comment on that task | `clickup.md` §8 |
| `github` | native milestone `[CODE]-WAVE-<n>` + label `wave-<n>` on every issue | the milestone's description — milestones take no comments | `github.md` §8 |
| `local-html` | an entry in `waves[]`, rendered as a block above the phase sections | the plan file the entry's `plan` field points at — a `waves[]` entry is not a task and takes no comment | `local-html.md` §8 |
| `none` | nothing — the plan file alone, read with `/marcus wave status` | the summary block under the wave in the plan | `none.md` §8 |

---

## Handback

Everything the owner is expected to do is a task assigned to him (`../SKILL.md` §7). In adapter terms it is the seven operations in a fixed order — no adapter needs an eighth.

| Step | Who | Ops |
|---|---|---|
| **ACTION**, opened | Marcus | `create` (assignee = the owner, status `to do`) · `label add ready-for-<owner>` |
| **DECISION**, opened | Marcus | `create` (parent = the ticket it unblocks, id `….D<n>`, assignee = the owner, status `decision`) · `label add decision` |
| **DECISION**, answered | **the owner** | `status → accepted \| declined` · `comment`. Marcus never runs this row, in any mode |
| **DECISION**, closed | Marcus, on the next `resume` | `query` (statuses `accepted`, `declined`) → `comment` on each → `status` on the **parent** only. The decision keeps the status the owner gave it |

The owner's assignee id is `config.tracker.ownerUserId` (`../modes/init.md` §5). An adapter with no assignee concept still owes the other three columns and says in its own file how it writes the owner instead.

**An adapter carries the handback in whatever it has** — `github` already keeps state in labels, `local-html` in the ticket's own fields, `none` writes the words into the handoff line where nothing can filter on them, and **each says how, in its own §9** (`clickup.md` §9 · `github.md` §9 · `local-html.md` §9 · `none.md` §9). What no adapter may do is **collapse the two shapes into one list of "owner stuff"**: an action is executed and a decision is answered, they close differently, and a queue that cannot tell them apart is not an implementation of this section.

---

## Choosing one

`/marcus init` runs the choice interactively and writes `marcus.config.json`. It does not guess: it looks at what the repo and the session already have — a `gh` remote, a live ClickUp connector, an existing `docs/tracker.json` — presents what it found, and lets the user confirm or override.

**The user's answer is the source of truth, not our detection.** If they say they track in Linear and no Linear adapter exists yet, the honest answer is to say so and offer `local-html` or `github` rather than pretend.

---

## Writing a new adapter

One markdown file here. It must specify:

1. **Auth** — what credential, where it comes from, and what happens when it is missing.
2. **The seven operations** — the exact calls, with the tool or CLI named.
3. **State mapping** — our ten states onto theirs, in a table, both directions.
4. **Phase mapping** — our seven phases onto lists, labels, or sections.
5. **Hierarchy** — how sub-work attaches to its parent.
6. **Limits** — rate limits, pagination, what to batch, what a lockout looks like.
7. **Degradation** — what the adapter does when the service is unreachable: queue the writes, name the readable state, say so out loud. **Never initialise a board at the failure** (`clickup.md` §7 step 3); silently dropping writes is not an answer either.

**An adapter may only read config keys that `../modes/init.md` §5 declares.** Needing a new one is a change to the schema and to the init conversation, not something an adapter file invents on its own — a key nothing writes reads as `undefined` on first use.

Then add it to the `/marcus init` menu (`../modes/init.md` §2).
