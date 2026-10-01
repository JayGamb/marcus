<!-- Loaded on demand by the `marcus` skill. Core rules (§0–§4, §5–§11) live in
     ../SKILL.md and are already in context when this file is read.

     One file at this length, on purpose. Ten files outside it cite its sections by name
     — ../SKILL.md · ../../marcus-checkpoint/SKILL.md · ultraflow.md (a guardrail) ·
     justflow.md · relay.md · ../templates/wave-plan.md · ../trackers/{README,clickup,
     github,none}.md — and nothing here is in context until a `wave` sub-command runs.
     A split costs all ten a hop into a file they never named, and buys a reader nothing
     that loading on demand has not already bought. Length is not the cost here. -->

## 4g. Mode `wave` — one plan file, one branch per wave, several sessions at once

```
/marcus wave plan          partition the open tickets into waves, write the plan, owner gate
/marcus wave <n>           claim wave n and work it
/marcus wave status        every wave, its claim, its staleness, the cross-wave conflict check
/marcus wave close <n>     verify the wave, review it, hand the merge to the owner
```

| Sub-command | State |
|---|---|
| `plan` | implemented — the whole of this file below |
| `<n>` | implemented — §`wave <n>` below |
| `status` | implemented — §`wave status` below |
| `close <n>` | implemented — §`wave close <n>` below |

**The contract, in one line:** the plan file is the source of truth and the tracker is a view of it — so two sessions can work two waves at once without either one being the other's memory.

### The shape, before the procedure

| Thing | Where | Who writes it |
|---|---|---|
| The plan | `docs/waves/[CODE]-plan.md`, committed — **one file**, `Plan version: <n>` in its header, its history in git | `wave plan`, once per run |
| A wave's branch | `wave/<n>`, cut from `[INTEGRATION_BRANCH]` — **always**; waves never stack on each other | §`wave <n>` |
| The wave's worktree | `.worktrees/wave-<n>`, checked out on `wave/<n>` — the session works **there** for the whole wave | §`wave <n>` step 2.1 |
| A slice's branch | `feat/[CODE]-<slice>`, cut from **and targeting** `wave/<n>` | the agent |
| A claim | the claim block in the plan file | §`wave <n>` |
| Orchestrator docs commits **during** a wave | the wave branch — never `[INTEGRATION_BRANCH]` | you |
| `wave/<n>` → `[INTEGRATION_BRANCH]` | **the owner**, in the plan's order | the owner |

**Two** carve-outs to the last row, and only two. The **plan commit itself** lands on `[INTEGRATION_BRANCH]`, a re-run's version bump included, because it is written before any `wave/<n>` exists — `wave plan` is the only thing that makes it. And the **`Status: merged` write** lands there too, *after* the owner's merge: that merge carried the wave branch's plan commits into the trunk, so the trunk's copy is the one anyone reads from then on (§`wave close <n>` step 6). Those two docs commits are the whole of what the orchestrator ever writes to `[INTEGRATION_BRANCH]` during a wave.

Two waves run at once **only** when their fences are pairwise disjoint **and** neither blocks the other. The planner proves that. The merge is not where it gets discovered.

---

### `wave plan` — the procedure

Spawn **linus**. Read-only on code: it writes one document and nothing else — and it never commits it. **You** commit the plan, at step 8.

**Inputs**

| Input | Source |
|---|---|
| code, integration branch, adapter | `marcus.config.json` → `code`, `branches.integration`, `tracker.adapter` |
| the open tickets | **one** tracker `query` (`../trackers/README.md`): phase `DEV`, status not `complete` / `cancelled`. One call, not one per ticket |
| the repo | the working tree at `[INTEGRATION_BRANCH]` |
| the previous plan | `docs/waves/[CODE]-plan.md`, if it exists — plus each wave's **own** copy, read through `wave/<k>` (§`wave <n>`, *Where a claim actually lives*) |

**Adapter `none` has no query to make.** The owner names the open tickets, and from the moment the plan is written the plan file *is* the queue — which is exactly what `none` lacks otherwise. Every other adapter degrades to the same place when its service is unreachable: say so in the plan header, and carry on. A wave plan never stops for a tracker.

**1 — Dependency graph.** One node per ticket; one edge per *real* blocking edge — the tracker's dependencies plus any "blocked by" written in a body. A ticket blocked by something outside this repo (another project's wave, a credential, an unmade decision) cannot be waved: list it under **Not waved** with the reason and keep it out of the graph. Guessing a fence for work whose shape does not exist yet is how a plan starts lying.

**2 — File fence per ticket, predicted.** You cannot read a diff that does not exist. Predict it, and show the working:

| Source | How |
|---|---|
| The ticket's scope text | the artifacts it names — files, skills, modes, docs, scripts |
| The repo | `git grep -l '<name>'` from the repo root, once per name it mentions |
| The neighbours | a file that *cites* the artifact belongs in the fence when the ticket changes that artifact's **path, name or contract** — not when it only changes its content |

The third row is where overlaps actually hide: two tickets can name completely different artifacts and still collide inside one file that documents both.

A predicted fence is a claim, not a fact. When a slice comes back having touched a file outside it, **the plan was wrong** — fix the plan, never widen a fence in flight (§11: two agents never share a file).

**3 — Partition: rounds first, then the session cap.**

**A wave is what one session carries.** `../SKILL.md` §12 caps a session at **3 agents in flight**, so a wave holds **at most 3 tickets** — and a stack counts as the tickets in it, never as one. That cap is the whole of what makes a plan launchable in parallel. The rule it replaces ("the earliest wave whose fences are disjoint") packed every unblocked ticket into wave 1, which left step 4 with no off-diagonal cell to compute: a plan built that way could never emit two waves that passed its own parallel test, however independent the work actually was.

**Rounds.** Round 1 is every ticket none of whose blockers is still open in this plan. Round `r+1` is every ticket whose blockers all sit in rounds `≤ r`. **A round is the set of tickets that *may* run at once; the waves inside it are the sessions that will.**

**Inside a round, in this order:**

1. **Stack what overlaps.** Two tickets whose predicted fences intersect are never two slices in two waves. Re-slice them (`marcus-slice`), or **stack** them — the second cuts from the first and merges base-first — and a stack stays inside **one** wave. **Stacked before independent** in every merge order.
2. **Fill to the cap, never past it.** A ticket joins the earliest wave of its round that holds fewer than 3 tickets **and** whose fence it is disjoint from. When none fits, it **opens a new wave in the same round** — a sibling, not a successor. Every wave of a round carries `Runs in parallel with:` the others.
3. **A stack longer than the cap breaks across rounds, serially.** Three of it fill one wave; the fourth is blocked by the third, so by the definition above it is round `r+1` and its wave waits.

**Across rounds, serial.** A wave of round `r+1` carries `Blocked by wave:` every **earlier-round** wave holding one of its blockers — not only round `r`: a ticket can wait on something two rounds back. §`wave <n>` step 1 already refuses to claim it until those are `merged` — that refusal is the enforcement; the header field is what makes it readable before anyone tries.

**Emit every wave the work permits, not the number of sessions you guess the owner will open.** Six unblocked disjoint tickets are two waves whether or not two terminals ever exist; a wave nobody opens waits, and costs nothing. A planner that trims the count has taken the owner's decision for him and hidden the parallelism he asked to be shown.

- A wave nobody can start is not a wave. If round 1 is empty, the graph is wrong, not the repo.

**4 — Prove pairwise disjointness.** One table, wave × wave; each off-diagonal cell is the *intersection* of the two waves' fences:

```
|        | Wave 1 | Wave 2 | Wave 3 |
| Wave 1 |   —    |   ∅    |   ∅    |
| Wave 2 |   ∅    |   —    | SKILL.md |
| Wave 3 |   ∅    | SKILL.md |  —   |
```

`∅` on both axes **and** no blocking edge between them = those two waves may run in parallel, in two sessions. Anything else = they are serial, and the plan says so in one line. A cell with a filename in it is not a failure of the plan; a cell nobody computed is.

**This table is the authority, not step 3's packing.** Step 3 proposes the rounds; each wave's `Runs in parallel with:` line is written from **here**. Two round siblings whose cell comes back non-`∅` were mis-stacked at step 3.1 — the fence they share arrived through the *neighbours* row of step 2, not through the artifacts either ticket names — and they go back to step 3: stacked into one wave, or re-sliced. Never written as parallel with a caveat attached.

Across rounds a non-`∅` cell is ordinary and needs no fix: the later wave merges after the earlier one, so the two never hold the file at the same time.

**On a re-run, compute this table over every wave the new version carries** — claimed and `in review` ones included, because you need their fences to place the new waves. Then write the result only into the waves you are allowed to rewrite: a claimed or in-review wave's whole block, `Runs in parallel with:` included, is copied forward **verbatim** (§ *Re-running it*), and it is the **new** wave that states the truth about the pair. Recomputing that line on a wave somebody is holding puts a second author on a file that branch is still writing, which is the conflict § *Re-running it* exists to prevent.

**Two live waves both write the plan file** — their claim blocks, their checkpoints — so `wave/<i>` × `wave/<j>` is a lane-B pair by construction, not a fence error (§ *Conflict handling*). Parallel planning makes that the normal case rather than a rarity: the blocks sit in different sections of the file and merge clean, and where they do not, lane B is waiting for the earlier wave's Gate 7, never a rebase onto a sibling.

**5 — Merge order and migration order.** Per wave: the slice branches in the order the owner merges them (stacked first, base before dependant), then the migrations by timestamped filename in apply order, or `none`. Across waves: the order the owner merges `wave/<n>` into `[INTEGRATION_BRANCH]` — round by round. **Inside a round there is no order**, and the plan says so instead of inventing one: two siblings that had to merge in a particular order were never parallel.

**6 — One kickoff prompt per wave, written into the wave's own block.** A wave is *launchable* when a session that has read nothing can claim it from the plan alone. This block is that guarantee. Shape it like `relay.md` §3 — paste-ready, the owner copies it into a fresh session and types nothing else:

```
You are Marcus, orchestrator for <Name> ([CODE]). Repo: <REPO_PATH>.
Run /marcus wave <n>.

Wave <n> — <what this wave delivers>.  Base: `[INTEGRATION_BRANCH]`.
  Tickets, in merge order:
    1. [CODE]-[PHASE]-[NUM] — <title> — id <id> — <url>
       fence: `<path>` · `<path>`        base: `wave/<n>`
    2. …
  Merge order inside the wave: 1. `feat/…` 2. `feat/…`    Migrations: <…, or none>
  Runs in parallel with: wave <k> — its fence is not yours, do not touch it.
  Blocked by wave: <m> — claim refused until it is merged. Or: none.
Do NOT re-read: the ticket bodies, the other waves' tickets, docs/handoffs/.
Read instead: docs/waves/[CODE]-plan.md — wave <n>'s block only — then the mode file /marcus wave <n> loads (~/.claude/skills/marcus/modes/wave.md).
```

Every field filled or explicitly `none`; a blank one reads as "unknown" to the session that pastes it and costs exactly the reads this block exists to save. **The fence is copied verbatim from the row** (§`wave <n>` step 3 says the same of the agent prompt) — re-deriving it is how the disjointness proof stops covering the work it was computed for.

**Ids and URLs go in.** A session that has to look a ticket up has already spent the context the prompt was written to save. Adapter `none` has no URL: write `—`, and the plan's row is the whole of the ticket.

**7 — Write it.** `docs/waves/[CODE]-plan.md`, from `../templates/wave-plan.md` — the same path every time, `Plan version:` bumped, `Supersedes: version <n-1>`. Every field filled or explicitly `—`, the kickoff block of every wave included; a blank field reads as "unknown" to the session that claims the wave and costs it the reads this file exists to save.

**One field is exempt, and only one: `Tracker task:`.** There, **empty is a value** — "the batch below degraded before this wave's task existed; look it up once at §`wave close <n>` step 6 and write it back" — and `—` would tell that close there is nothing to find. `—` is right on that line for adapter `none` alone, which creates nothing ever (`../templates/wave-plan.md`, the skeleton's own note on it). Everywhere else in the file the rule stands unbent.

**8 — Owner gate, then the tracker.** Show the owner **three things, and not the file**: the wave table, the merge order, and **every wave's kickoff prompt**. Ask: granularity right, order right, prompts complete → « ok ? ». Iterate. **You commit it, never linus, and only after the ok** — on `[INTEGRATION_BRANCH]`, one commit, owner identity, no trailer, and **after the tracker batch below**, so the ids it returns are in the file that commit carries. A refused plan leaves no commit behind, and its tracker batch never runs.

**The tracker batch runs before that commit.** Once and in **one batch**: the tracker's wave view, **created here at plan time** — one wave task per wave, named `[CODE]-WAVE-<n>`, carrying the plan's path and its ticket ids, plus `label add wave-<n>` on every member (§ *Tracker view of a wave*; what each adapter renders is `../trackers/README.md` § *Wave view*). The owner sees every wave in the tracker **before** he opens a single session.

**On a re-run, that batch creates less and it also closes.** Create a wave task **only for a wave whose `Tracker task:` line is empty** — a wave carried forward verbatim (§ *Re-running it*) already has one, and a second `[CODE]-WAVE-<n>` gives the close two tasks to pick between and the owner two rows for one wave. And every `planned` wave the new version superseded loses its view: **`status → cancelled` on its task — closed where the adapter has no such state — one call each, in the same batch** — read off the previous version's `Tracker task:` lines *before* the rewrite overwrites them (`git show [INTEGRATION_BRANCH]:docs/waves/[CODE]-plan.md` where it already did). A superseded wave left open in the tracker is a wave the owner can still see and no session will ever claim.

**A superseded wave whose `Tracker task:` line is empty has nothing to cancel.** Empty means the creating batch degraded before that wave's task existed (step 7's carve-out above), so there is no task to close and no id to read: **skip it**, and do **not** spend `../trackers/<adapter>.md` §8's lookup hunting for one — a task that was never created cannot be found, and the call is gone either way. Name the waves you skipped, in one line, rather than leaving the owner to wonder which rows the re-plan left behind.

**The `wave-<n>` tags on a superseded wave's members stay — the cancelled task is the authority, never the tag.** Stripping them would cost `+N` calls per superseded wave against the very budget that took the claim off the tracker entirely (§ *Tracker view of a wave*), and the close already leaves member tags standing on purpose, as the audit history of which wave a ticket belonged to (`../trackers/clickup.md` §8 · `../trackers/local-html.md` §8). So a ticket repartitioned into a new wave carries two `wave-` tags, and that is read the way everything else here is read: the **open** wave task is the live one, the cancelled one is history, and the plan file settles it above both.

**Then write each wave task's url — or its id where the adapter has no url — into that wave's `Tracker task:` line in the plan**, and commit. The task is created in this session and closed in another (§`wave close <n>` step 6), so the plan is where its id is kept: a line in the committed file costs nothing to read, and a close that has to search for the task pays a call for something it was already told. Adapter `none` creates nothing — write `—`.

**`wave plan` ends here.** It spawns **no worker**, cuts no branch, creates no worktree and opens no terminal — **in this mode or any other. Marcus launches nothing.** linus, its planner, is the one agent it ever spawns, and it is read-only on code with no branch and no worktree of its own (the head of this section). The owner opens one session per wave and pastes that wave's prompt; that session runs §`wave <n>` and claims it, unchanged. Two reasons it is drawn here and not one: starting the work takes the one decision this gate exists to leave with the owner, and sessions started from this window would share this window's context — which is step 3's cap being observed in the table and broken in fact.

### Re-running it

`wave plan` is re-runnable and expected to be re-run — the frontier moves.

**Read every wave's status where it actually lives, before applying the table below.** The trunk's copy shows every wave `planned` forever (§`wave <n>`, *Where a claim actually lives*), so run that `git show wave/<k>:…` read once per wave the current version carries. A wave at `claimed:*` or `in review` **on its own branch** keeps its number and its table verbatim, however the copy in front of you reads. A re-run that trusts the trunk copy supersedes a wave somebody is holding.

**Its `Status:` line and its claim block are the exception: leave both exactly as the copy you are editing already has them** — `planned`, unclaimed. The re-run commits on `[INTEGRATION_BRANCH]` and the state lives on the wave branch (§ *Where a claim actually lives*), so copying `claimed:<session>` onto the trunk puts a second author on the two lines that branch is still writing: it goes on to write `checkpoint:` and then `in review` over them, both sides have changed, `S_k × [INTEGRATION_BRANCH]` goes non-zero, `wave close` refuses and the owner's Gate 7 merge conflicts on the plan file. The trunk copy carries the partition; the wave branch stays the authority on the state.

| Wave status | What a new plan does |
|---|---|
| `planned` | superseded: renumbered, repartitioned, rewritten |
| `claimed:<session>` | table and number **untouched**, copied forward verbatim — `Status:` and the claim block left as the copy being edited has them |
| `in review` | the same: table and number verbatim, `Status:` and claim block left as the copy being edited has them |
| `merged` | untouched, copied forward as history |

New waves number after the highest number in the previous version — numbers are never reused, because a branch, a claim and a tracker view all carry them. The rewrite lands in **the same file**: `Plan version:` goes up by one and `Supersedes: version <n-1>` records what it replaced (`none` at version 1). The previous version is `git log` on that path — not a second file anyone has to pick between.

### What `wave plan` refuses

| Condition | Why | What you do |
|---|---|---|
| Dirty working tree | fences are predicted against a known tree, and the plan commit would sweep up unrelated work | stop, name the files, ask the owner |
| A claimed wave whose `wave/<n>` branch is missing | the claim and the repo disagree; the branch was deleted, or the claim came from a clone this machine does not have | stop, report both, **never** clear the claim yourself |
| No open tickets, or none plannable | there is nothing to partition | say so, list the *Not waved* reasons, write nothing |

### Session identity and claims

A claim lives in the plan file, one block per wave, written by §`wave <n>` and read by everyone:

```
session:    <session id>              # the orchestrator session holding the wave
machine:    <hostname -s>
claimed_at: <YYYY-MM-DDTHH:MM local>
checkpoint: <docs/handoffs/… path>    # the last checkpoint this claim wrote, or —
```

A claim older than **6 hours with `checkpoint:` still `—`** is **stale**. `wave status` reports it; nothing ever auto-releases it. Six hours is a default, not a law — a long slice on a slow model is not an abandoned session, and releasing someone else's claim from a guess destroys work that a wrong wait merely delays. Releasing a claim is the owner's call, always.

### `wave <n>` — the procedure

`wave plan` partitions and the owner gates it. **`wave <n>` is the only thing that writes a claim** — and from the claim on, this session owns exactly one wave and touches nothing else in the repo.

#### Where a claim actually lives

`wave plan` commits the plan on `[INTEGRATION_BRANCH]`, but every write after it — the claim included — lands on `wave/<n>` (the shape table above). So the copy on `[INTEGRATION_BRANCH]` shows every wave `planned` forever, and **the authoritative status of wave `k` is the plan file on `wave/<k>`**:

```bash
git show wave/<k>:docs/waves/[CODE]-plan.md 2>/dev/null \
  || git show [INTEGRATION_BRANCH]:docs/waves/[CODE]-plan.md
```

Read every wave that way before the checks below. A session that reads only the integration copy will claim a wave another session is already holding, and the first anyone hears of it is a conflict.

**Session id — one definition, used by the claim, the plan header and the handoff names.** The Claude session URL (`https://claude.ai/code/session_<id>`) sits in your own context, not on disk: the id is its **last 8 characters**. Headless, no URL: `printf '%08x' "$(date +%s)"`. Never derive it from the hostname, the branch or the ticket — two sessions on one machine would collide, which is the one thing a claim exists to prevent. The worked example in `../templates/wave-plan.md` uses `4946b9bd`.

#### 1 — What `wave <n>` refuses *(main tree)*

| Condition | Why | What you do |
|---|---|---|
| No plan file in `docs/waves/` | a wave with no committed plan is one session's memory wearing a branch name | stop; `/marcus wave plan` first |
| Wave `<n>` absent from the plan | the number came from a superseded version, or from nowhere | stop; list the waves the current version does have |
| `claimed:<another session>`, fresh | one wave, one session — that is the whole of this mode's safety | refuse. Report `session`, `machine`, `claimed_at`, `checkpoint:` |
| `claimed:<another session>`, **stale** (> 6 h, `checkpoint:` still `—`) | stale is a symptom, not a verdict: a long slice on a slow model looks identical from outside | report it as stale **and refuse anyway**. Releasing a claim is the owner's call, always (*Session identity and claims* above) |
| Status `in review` or `merged` | the wave is closed; a new slice on it lands after the review that cleared it | refuse, name the status |
| Dirty working tree **in the main checkout** | the wave worktree and every slice worktree are cut from it, and they all inherit the mess | refuse, name the files, ask the owner |
| `claimed:<this session>` | **not a refusal** | you already hold it → step 4, resume in place. **Evaluated before the two rows below**, which are claim-time checks and say nothing about a wave already in flight |
| `wave/<n>` exists but does not contain `[INTEGRATION_BRANCH]`'s head (`git merge-base --is-ancestor [INTEGRATION_BRANCH] wave/<n>`) | **at claim time** the branch predates work already in the trunk, so every slice you are about to cut is written against a tree the owner has already moved past | refuse, report both shas. Never reset or move someone else's branch. Once a wave is claimed the trunk moves under it as a matter of course — §`wave status` reports that as information, never as a fault |
| One of wave `<n>`'s tickets is `Blocked by` a ticket in wave `<m>`, and `<m>` is not `merged` | you would be cutting slices from work that is not in the trunk yet, and paying for it at the merge | refuse, name `<m>` and its current status. The owner merges `<m>`, or `wave plan` runs again. A wave never has a wave for a base (*The shape* above): stacking happens **inside** a wave, in the table's slice `Base` column |

#### 2 — Claim it *(main tree, then the wave worktree it creates)*

One commit on `wave/<n>`, before any slice worktree exists and before any agent is spawned.

1. **Cut or verify the branch, then take a worktree on it.** Absent → `git branch wave/<n> [INTEGRATION_BRANCH]`. Present → the ancestor check above, then use it as it stands. Either way, anchor on the main worktree once — `ROOT=$(git worktree list --porcelain | sed -n '1s/^worktree //p')` — then `git -C "$ROOT" worktree add .worktrees/wave-<n> wave/<n>`. **From here this session is that worktree** — the claim commit, the checkpoint handoffs, the justflow queue and log, the `in review` commit, all of them there, on `wave/<n>`. The main checkout stays on `[INTEGRATION_BRANCH]` and untouched, which is what lets a second session claim another wave in the same clone. **`$ROOT` is carried for the rest of the wave** — a session resuming it re-runs that one line — because the cwd is now `.worktrees/wave-<n>` and every worktree path below is relative to the *main* tree: a root-relative `git worktree add` run from here nests the slice worktree inside the wave worktree, dangles the `node_modules` symlink it is given, and leaves the Gate 7 removals pointing at a path that is not there. Slice worktrees stay under the **root's** `.worktrees/`: they are cut from `wave/<n>` by ref and need no checkout of it.
2. **Fill the claim block** of wave `<n>` in the plan: `session:` (the id defined above), `machine:` = `hostname -s`, `claimed_at:` = local `YYYY-MM-DDTHH:MM`, `checkpoint:` = `—` — there is no checkpoint yet, and a guessed one is worse than none. Set that wave's `Status:` to `claimed:<session id>`.
3. **Commit the plan file on `wave/<n>`** — one commit, owner identity, no trailer, `docs(wave): claim wave <n> [CODE]-WAVE-<n>` (the milestone name § *Tracker view of a wave* publishes), nothing else in it.
4. **Tracker — mirror the claim.** The wave's task and its member tags were created at `wave plan`; the claim is what moves it. On the task **this wave's `Tracker task:` line names**, read straight off the plan, no lookup: `status → in progress`, then **one comment** carrying the three claim lines — `session`, `machine`, `claimed_at` — and ending with the `../SKILL.md` §7 signature line, `— Marcus · wave · session <id> · <YYYY-MM-DD>`. **`+2` calls, once** (§ *Tracker view of a wave*; an adapter whose wave object has no `in progress` says what it does instead, in its §8). **The claim is still the commit, and the mirror is still only a view** — a lockout, a degraded service, or a `Tracker task:` line that is absent or empty: queue both writes by `../trackers/<adapter>.md` §7, say the tracker is behind, and carry on. The wave is claimed just as hard. With `none`, nothing at all.

#### 3 — Work it *(wave worktree)*

**Per ticket, in the plan table's order** — that table *is* the frontier; you never recompute one inside a wave. The cwd is `.worktrees/wave-<n>`, so both commands are `$ROOT`-anchored (step 2.1):

```bash
git -C "$ROOT" worktree add .worktrees/[CODE]-<slice> -b feat/[CODE]-<slice> wave/<n>   # or the row's Base, when stacked
ln -sfn "$ROOT/node_modules" "$ROOT/.worktrees/[CODE]-<slice>/node_modules"
```

| Piece | In a wave |
|---|---|
| Agent prompt | §5 template, **unchanged** but for `Base:` = `wave/<n>` (or the row's `Base`), and the scope fence copied **verbatim** from the row's fence column — not re-derived, or the disjointness proof stops covering it |
| Verification | §6, **unchanged**, with one substitution: every `origin/<base>` is the local `wave/<n>`. Wave branches are never pushed, so there is no `origin/` ref to compare against |
| The round | justflow's loop, scoped: `justflow.md` § *The night loop* steps 2–6 as written — 3 agents max, disjoint files, §6 then **linus on every slice diff**, one retry, one log line per event. Step 1 is the only difference: the frontier is this wave's table, already computed and already gated. Its queue and log are wave-keyed — `docs/handoffs/<date>-[CODE]-wave-<n>-justflow-queue.md` and `…-wave-<n>-justflow-log.md`, on `wave/<n>` — or two waves running at once write one another's file |
| Eligibility | `justflow.md` § *Eligibility* still binds. A red item does not turn green by being in a wave |
| Stopping | `justflow.md` § *Stop conditions* binds, with the cutoff read as the wave's last ticket. Anything destructive still stops the whole run, not just the slice |

**A fence that was wrong.** A slice returning a file outside its fence means **the plan lied** — and the plan is what two sessions trust about each other. Stop that slice where it stands, do not mark it `review`, and record it under the wave:

```
Fence corrections: [CODE]-[PHASE]-[NUM] also touched `<path>` — <ticket it collides with, or "no collision"> — <re-slice | stack | re-run wave plan>
```

**Never widen a fence in flight** (§11: two agents never share a file). If the extra file sits in another ticket's fence *in this wave*, those two tickets are a stack and not two slices — the second does not start until the plan says so. A fence corrected in the file is a plan that stays true; a fence corrected in your head is the next session's conflict.

**Every orchestrator docs commit during the wave goes on `wave/<n>`** — the queue file, the handoffs, the plan updates above. `[INTEGRATION_BRANCH]` takes nothing from you between the plan commit and the owner's merge. When the table is exhausted and every slice is at `review`, the wave is not yours to close by hand — §`wave close <n>` is the procedure, and it ends at the owner.

#### 4 — Checkpoint, and resuming a wave you already hold *(wave worktree)*

The `marcus-checkpoint` trigger is **unchanged** — 3 merged slices or one gate, whichever comes first (`../SKILL.md` §12). Two things about it are wave-shaped:

- The handoff is `docs/handoffs/<date>-[CODE]-wave-<n>-handoff.md` — one wave, one file, found by wave number rather than by date alone.
- **The claim's `checkpoint:` line is updated to that path in the same commit that adds the file**, on `wave/<n>`. Two commits is one too many: a written checkpoint whose claim still reads `—` is a claim `wave status` reports stale six hours later.

**Resuming.** `/marcus resume` stays inside the wave when the plan carries a wave whose claim `session:` is this session's id — or when the owner names the wave, which is the normal case after a `/clear`, since a fresh session has a fresh id. It picks up from that wave's `checkpoint:` file, on `wave/<n>`, never on `[INTEGRATION_BRANCH]`. It does **not** re-claim: the block is already right, and rewriting it resets `claimed_at` and hides exactly the age staleness is read from.

### `wave status` — the procedure

**Read-only — on the repo and on the tracker both.** It edits no claim, releases nothing, rebases nothing and commits nothing; it **writes** no tracker call either, and it *reads* one — first, in step 0 below — so that the report can say when the view and the record disagree. It corrects neither side. It is a report; the only thing it changes is what you know.

#### 0 — The tracker, read first

**One read per wave, before git and before the plan**, so that a disagreement has two sides to name. Per wave `k` whose `Tracker task:` line carries an id: read that task's status off the line — no lookup, no hunt — with the call in `../trackers/<adapter>.md` §8, and take the whole set in one call on an adapter that can (`github`'s milestone list, `local-html`'s `docs/tracker.json`). Three rows never cost a call: a line that is **absent, empty or `—`** reads `tracker: not recorded`; adapter `none` reads `tracker: n/a` and the plan is the whole answer (`../trackers/none.md` §8); unreachable or locked out reads **`tracker: unreachable, plan only`**. The report degrades, it never stalls.

**Line the two vocabularies up before comparing them.** The plan's `Status:` and the tracker's state are different words for the same four positions, and a comparison that skips this step reports a mismatch on every wave: `planned` ≡ `to do` (github: the milestone `open`, no `Status:` line written yet · local-html: `waves[].state: "open"`) · `claimed:<session id>` ≡ `in progress` · `in review` ≡ `review` · `merged` ≡ `complete` (github: the milestone `closed` · local-html: `"closed"`). The right-hand column is the ten-state vocabulary of `../trackers/README.md` § *The contract* and never the plan's wording — `in review` is the plan's word for the position the tracker calls `review`. **Only a pair that is not on that list is a mismatch.**

**Then report the mismatch and correct nothing.** The status goes in step 2's table as its own cell, beside the plan's `Status:`, and a disagreement is one line under the table — `wave 2 — tracker: in progress · plan: planned`. **This sub-command writes neither side.** A view that drifted from the record is a fact the owner needs; a drift this report quietly repaired is one nobody ever sees. The fix belongs to the moment that owns that write — §`wave <n>` step 2.4, §`wave close <n>` step 4, or §`wave close <n>` step 6 — run by the session holding the wave.

**And a queued write is not a drift.** Read `docs/handoffs/<date>-[CODE]-orchestrator-queue.md` before naming one — it is the replay log a degraded adapter writes into (`../trackers/<adapter>.md` §7), and a claim or an `in review` mark still sitting in it **unreplayed** is a tracker that was unreachable when the write came due, not a view that drifted. That gets its own row — `wave 2 — tracker: queued, not replayed · plan: claimed:<session id>` — naming the queue file, and the replay stays with the session that owns the write. Reported as drift it sends the owner hunting a divergence nobody created.

#### 1 — Read every wave where its claim actually lives

One file: `docs/waves/[CODE]-plan.md`. Absent — or no `docs/waves/` directory at all — is "no waves planned": say it in one line and stop; it is not an error. Then, per wave `k` in it, the read from §`wave <n>`:

```bash
git show wave/<k>:docs/waves/[CODE]-plan.md 2>/dev/null \
  || git show [INTEGRATION_BRANCH]:docs/waves/[CODE]-plan.md
```

The integration copy shows every wave `planned` forever. A status report built from it is a report about nothing.

#### 2 — One table, one row per wave

| Column | Where it comes from |
|---|---|
| wave · status · session · machine · claimed_at · `checkpoint:` | the claim block in that wave's **own** copy (step 1) |
| tracker | that wave's task status from step 0 — or `not recorded` · `unreachable` · `n/a` |
| age | now − `claimed_at` |
| stale? | *Session identity and claims* above: > 6 h **and** `checkpoint:` still `—`. Nothing else is stale, and stale is a report, never a permission |
| `wave/<k>` present | `git rev-parse --verify -q wave/<k>` |
| commits ahead | `git rev-list --count [INTEGRATION_BRANCH]..wave/<k>` |
| slices seen | `git branch --list 'feat/[CODE]-*'`, matched to that wave's table rows |

Every cell filled or `—`. Under the table, the anomalies — one line each, and the reason this report exists at all:

- **Tracker ≠ plan** — step 0's status and this wave's `Status:` disagree (`in progress` against `planned`, `open` against `in review`). Report both sides on one line and **stop there**: the write belongs to the moment that owns it, never to this report.
- **Claim without branch** — status `claimed:*`, `git rev-parse` fails. Report both; **never** clear the claim.
- **Branch without claim** — `wave/<k>` exists, its own copy still says `planned`.
- **`merged` that did not merge** — the plan says `merged` and `git merge-base --is-ancestor wave/<k> [INTEGRATION_BRANCH]` fails.
- **merged, unrecorded** — the mirror image: status is **not** `merged` and `git merge-base --is-ancestor wave/<k> [INTEGRATION_BRANCH]` exits 0. The owner merged it and nobody wrote it down. Fix: §`wave close <n>` step 6, run by whichever session sees this — **after the revert test below, never before it**.

  **`is-ancestor` cannot tell a merge from a merge that was backed out.** `git revert -m 1` *adds* a commit; it removes none, so the wave's commits stay ancestors of the trunk forever and a reverted wave reads here exactly like a forgotten one. Test before you recommend anything:

```bash
W=$(git rev-parse wave/<k>)   # the wave tip — the merge that brought it in carries this as a direct parent
B=$(git rev-list --merges --topo-order --parents --ancestry-path wave/<k>..[INTEGRATION_BRANCH] | grep -w "$W")
[ -n "$B" ] && echo "$B" | wc -l          # bottom merges: 1 is the ordinary case, >1 is the report
M=$(echo "$B" | tail -1 | cut -d' ' -f1)  # the merge that brought the wave in
[ -n "$M" ] || echo "no bottom merge — cannot tell"
C=$M; N=0                                 # walk the chain: the revert, the revert of the revert, …
while [ -n "$C" ] && C=$(git log [INTEGRATION_BRANCH] --grep="This reverts commit ${C}" \
      --format=%H | head -1) && [ -n "$C" ]; do N=$((N+1)); done
#  N odd → reverted  ·  N even, 0 included → the trunk carries the work
```

  **Read `N`, not the first hit — a revert can itself be reverted, and so can that.** `N` **even, 0 included**, and no `Reverted:` line **carrying a sha (not `—`)** already written under that wave in the plan: the trunk carries the work and the reading stands as *merged, unrecorded*. `N` **odd**, or a `Reverted:` line carrying a sha — report it as **reverted**, recommend **nothing**, and leave it with the owner: marking `merged` a wave whose work the trunk no longer carries is precisely what § *Hard rules this mode does not touch* forbids, and step 6 would also close the tracker view and complete every member ticket on the strength of it. **Parity is the whole of it** — each revert on the chain flips the trunk's answer, so depth 2 is back in and depth 3 is out again, and a test that stops at the first hit calls depth 3 *merged*. **`--parents` is what makes `$M` right:** `--ancestry-path wave/<k>..[INTEGRATION_BRANCH]` holds **every** later `--no-ff` merge on the trunk — every wave merged after this one — so the merges on the path are not candidates; only the **bottom merges**, the ones carrying `wave/<k>`'s tip as a direct parent, are, and one of those is the ordinary case. **Two or more of them is the report:** the wave reached the trunk by two routes, `--topo-order` alone decides which one `tail -1` names, and which of them brought it in is a question for the owner and not for this test. An empty `$B` — no merge on the path carries that tip — means a fast-forward, which the Gate 7 block's `--no-ff` does not produce; and the chain sees neither a hand-written revert message nor a re-apply done by anything other than reverting the revert (a cherry-pick, a fresh merge): in every one of those cases say which states you could not tell apart, and stop there.
- **Trunk ahead of a wave** — *informational, and it carries no verdict.* Report `git rev-list --count wave/<k>..[INTEGRATION_BRANCH]` and stop there. A trunk that moved under a live wave is the ordinary case: another wave merged, or `wave plan` committed a new version of the plan there. It is a refusal only at claim time, on a branch nobody holds yet (§`wave <n>` step 1). **Ahead is not conflicting**, and the two are read by different commands: if one of those trunk commits touched a file this wave's branches also touch — the plan file, at every checkpoint — step 3's `S_k × [INTEGRATION_BRANCH]` count is what says so, and a non-zero there is a rebase (*Conflict handling*, lane B), never "the plan lied".

#### 3 — The cross-wave conflict check

**A wave branch is not the wave.** While a wave is in flight `wave/<k>` carries the claim and the orchestrator's docs commits and nothing else — the work sits on the `feat/` branches cut from it, and it reaches `wave/<k>` at the owner's Gate 7, not before. Comparing two wave branches therefore compares two claim commits and finds nothing. The operand set of an in-flight wave `k` is

```
S_k = { wave/<k> } ∪ { every feat/[CODE]-<slice> branch named in wave k's table that exists }
```

and the check runs the **cross product** `S_i × S_j` for every pair of in-flight waves — `claimed:*` or `in review` — plus every member of every `S_k` against `[INTEGRATION_BRANCH]`'s head. `merge-tree` reads refs, so none of it needs a worktree. §6's form, with one correction:

```bash
A=<a branch in S_i>; B=<a branch in S_j>                                 # or B=[INTEGRATION_BRANCH]
git merge-tree $(git merge-base $A $B) $A $B | grep -c '^+<<<<<<<' ; true   # the marker count
git merge-tree $(git merge-base $A $B) $A $B \
  | awk '/^changed in both/{getline; f=$NF} /^\+<<<<<<</{print f}' | sort -u   # the files
```

**`; true` is load-bearing:** `grep -c` exits 1 when the count is zero, so the *good* case is the one that aborts an `&&` chain or kills a `set -e` script. Swallow it, and read the number.

**The `+` is load-bearing, and `changed in both` is not the answer.** Three-argument `merge-tree` prints the markers inside a diff against the first branch, so every marker line arrives prefixed: `'^<<<<<<<'` counts zero on a repo that genuinely conflicts — a check that always passes (git 2.36.1, drill below). And `changed in both` lists every file both sides touched, the ones that merged clean included — the plan file itself, at every checkpoint. Key off the markers.

**One blind spot, named so nobody trusts the count blindly.** A file one branch deleted or renamed and the other edited is a modify/delete conflict, and the marker count reads **0** — there is no text to put markers in. One command per pair catches it, run **both ways** (swap `$A` and `$B`, it is directional):

```bash
git diff --name-status $(git merge-base $A $B) $A | grep -E '^[ADR]' | cut -f2 \
  | grep -Fxf - <(git diff --name-only $(git merge-base $A $B) $B)   # any line = modify/delete
```

Report **per wave pair the sum over its cross product**, and, when the sum is non-zero, the `(a, b, files)` triples. **Zero everywhere = the plan's disjointness proof still holds.** Non-zero on a **slice pair** = **the plan lied**: name the pair and the files. Non-zero only where a wave branch meets `[INTEGRATION_BRANCH]` or another wave branch is the trunk moving under a live wave — ordinary, and not a lie. Either way, *Conflict handling*: it sorts the two. **This check runs at every wave checkpoint too** (`../../marcus-checkpoint/SKILL.md` §2), and its block goes into the handoff's État — a conflict first met at the merge has already cost both waves the independence the plan claimed for them.

#### Conflict handling

Cross-wave conflicts are **prevented by the fences**, not resolved at merge time. The owner meeting one in a merge is the failure itself, never the fix. **Which branches the non-zero count came from decides the lane — and only one of the two lanes rebases.**

**Lane A — a slice pair.** `feat/<a>` × `feat/<b>`, or `feat/<a>` × the other wave's `wave/<j>`: one file sits in two waves' *work*, so a fence lied. **No rebase, and no cross-wave stack.** Rebasing `wave/<later>` onto the earlier wave replays that branch's own commits — the claim, the docs — and the slice pair conflicts afterwards exactly as it did before, because neither slice branch moved; and a wave never gets a wave for a base (§ *The shape, before the procedure*). linus diagnoses which fence lied — read-only, on the two diffs; the file was in neither fence, or quietly in both — and then it is one of three, recorded under the later wave in §`wave <n>` step 3's format: re-slice (`marcus-slice`), stack the two tickets inside **one** wave, or re-run `wave plan`.

```
Fence corrections: [CODE]-[PHASE]-[NUM] also touched `<path>` — <the ticket it collides with> — <re-slice | stack | re-run wave plan>
```

A conflict fixed in a branch and not in the plan is a conflict the next `wave plan` recreates — and an unresolved line there refuses the close (§`wave close <n>` step 1).

**Lane B — the wave branch's own commits.** `wave/<k>` × `[INTEGRATION_BRANCH]`, or `wave/<i>` × `wave/<j>`, colliding on what the orchestrator wrote there and nowhere else: the plan file, the justflow queue and log, the handoffs. **Not a fence error and not a lie** — a trunk that moved under a live wave is the ordinary case (§`wave status` step 2, *Trunk ahead of a wave*). Rebase onto the trunk — or, against another wave, wait. Three steps:

1. **Which branch rebases, if any.** Against `[INTEGRATION_BRANCH]`: `wave/<k>` rebases onto the trunk, never the reverse — the trunk is nobody's to rewrite. Against another wave: **no rebase** — wait for the earlier wave's Gate 7; once it is in the trunk the collision is `wave/<k>` × `[INTEGRATION_BRANCH]` and rebases onto the trunk like any other.
2. **In that wave's own worktree (`.worktrees/wave-<k>`), on `wave/<k>` only — and prove the branch is local first:** `git branch -r --contains wave/<k>` must print **nothing**. Anything it prints means a remote ref already carries those commits: **refuse, and hand it to the owner** — a rebase would rewrite history someone else may hold. Empty, and the branch is this session's alone (the shape table above, §11). **This is the one place in this mode where a local rebase is allowed**, and it stays fenced to that branch: `reset --hard`, `clean` and force-pushing stay forbidden here exactly as everywhere else, and neither the trunk nor the earlier wave is touched at all.
3. **linus re-reviews the rebased wave.** A rebase is a new diff; the review that cleared the old one cleared something else.

#### Worked example

A throwaway repo built to this mode's own shape: two claimed waves, each holding nothing on its wave branch but a claim commit, each with one slice on a `feat/` branch cut from it. The overlap is planted between the two **slices** — both rewrite one line of `docs/WORKFLOW.md`, which sits in wave 2's predicted fence and not in wave 1's. Real output, hostname substituted.

| wave | status | session | machine | claimed_at | age | `checkpoint:` | stale? | branch | ahead | slices seen |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `claimed:4946b9bd` | 4946b9bd | `<hostname -s>` | 2026-09-12T19:57 | 2 h 51 | — | no | `wave/1` | 1 | `feat/DRIL-1` |
| 2 | `claimed:7c31aa02` | 7c31aa02 | `<hostname -s>` | 2026-09-12T09:05 | 13 h 43 | — | **stale** | `wave/2` | 1 | `feat/DRIL-2` |

- Wave 2 is **stale** — > 6 h, `checkpoint:` still `—`. Reported, refused, left for the owner.

```
wave 1 × wave 2  (S_1 × S_2, 4 pairs)
  wave/1      x wave/2       0
  wave/1      x feat/DRIL-2  0
  feat/DRIL-1 x wave/2       0
  feat/DRIL-1 x feat/DRIL-2  1  docs/WORKFLOW.md
  sum over S_1 x S_2 = 1
  vs main: wave/1 0 · feat/DRIL-1 0 · wave/2 0 · feat/DRIL-2 0
```

**The wave-branch pair reads 0 and the plan lied anyway.** `wave/1 × wave/2` compares two claim commits; the conflict is one cell down, on the slice pair — and a check that stopped at the first row hands it to the owner at Gate 7, which is exactly where the same drill's `git merge --no-ff` fails. That cell is lane A, so nothing rebases: rebasing `wave/2` onto `wave/1` replays one claim commit and leaves `feat/DRIL-1 × feat/DRIL-2` at 1, unchanged. What moves is the plan — the `Fence corrections:` line under wave 2, then those two tickets re-sliced, stacked inside one wave, or re-partitioned by a new `wave plan`. The same drill with wave 2's slice moved to a file nobody else holds reads **0 in all four cells** and the claim rows do not move.

### `wave close <n>` — the procedure

The table is exhausted and every slice sits at `review`. Close **verifies the wave as one thing**, has it **reviewed**, and hands the merge to the owner. You never run that merge (§11), and the wave is not `merged` until you have seen it merged.

#### 1 — What `wave close <n>` refuses *(wave worktree)*

| Condition | Why | What you do |
|---|---|---|
| This session does not hold the claim — `session:` ≠ this id, and the owner has not named the wave | closing another session's wave marks their work reviewed on your word | refuse, print the claim block. Never edit it |
| A ticket in the wave's table is not at `review` | the wave is not finished, and an unverified slice inside an octopus is an unverified merge | refuse, **name the ticket and its status** |
| An unresolved `Fence corrections:` line under this wave (§`wave <n>` step 3) | the plan lied and the correction is still a note; closing freezes that lie into the merge order | refuse, quote the line, send it back to `marcus-slice` or `wave plan` |
| Dirty working tree in `.worktrees/wave-<n>` | the `in review` commit is made there and would sweep up unrelated work | refuse, name the files |
| `wave/<n>` missing | there is nothing to close: the claim and the repo disagree | refuse, report both. Never re-cut it |

#### 2 — The integration check *(throwaway worktree)*

`../SKILL.md` §4 step 4, wave-shaped. In a **throwaway worktree**, detached — so nothing that survives has been merged into anything, and `.worktrees/wave-<n>` stays on `wave/<n>` for step 4's commit:

```bash
git -C "$ROOT" worktree add --detach .worktrees/_wave-<n>-int wave/<n>
cd "$ROOT/.worktrees/_wave-<n>-int"
git merge --no-ff <the plan's merge order>   # stacked → the tip only; its base is already contained
OCT=$(git rev-parse HEAD)                    # the octopus, for the checks below
git update-ref refs/marcus/wave-<n>-oct "$OCT"   # pin it — the removal below leaves it unreferenced
<the repo's build gate>
```

**The gate is the repo's own**, run once over the whole wave instead of once per slice: a docs-only repo → `git diff --check` plus the path-resolution sweep; a product repo → build + `tsc --noEmit` + `eslint src` (`../SKILL.md` §4 step 4). **A `git merge` that fails here *is* the conflict signal** — same handling, no second check needed: report what `git diff --name-only --diff-filter=U` names, `git merge --abort`, § *Conflict handling*, close refused.

Then the conflict check in the corrected form at §`wave status` step 3 — the `'^+<<<<<<<'` count and the modify/delete sweep, cited from there and never re-typed from §6. Three sets, all required: **every pair of this wave's slice branches**, **`$OCT` against every member of every other in-flight wave's `S`**, and **`$OCT` against `[INTEGRATION_BRANCH]`'s head** — the trunk may have moved since the claim, and the other waves' slices certainly have. Then `cd "$ROOT/.worktrees/wave-<n>"` and `git -C "$ROOT" worktree remove --force .worktrees/_wave-<n>-int` — run from *inside* the throwaway, the removal deletes its own cwd and every command after it fails to resolve a path. Non-zero anywhere → § *Conflict handling* above, and **the close is refused**.

**`$OCT` survives that removal only because of the ref.** A detached octopus is nobody's branch: the moment the throwaway worktree goes, nothing points at that commit, `gc` may drop it, and the shell variable dies with the shell — a close resumed after a `/clear` has neither. `refs/marcus/wave-<n>-oct` is what step 3 reviews, and `OCT=$(git rev-parse refs/marcus/wave-<n>-oct)` is how a later session gets the sha back. It is our own ref under `refs/marcus/`, not a branch and not a tag: step 6 drops it once the merge is real.

#### 3 — Review, Stage 1 then Stage 2 *(no tree of its own)*

**linus, always**, on the octopus diff against `[INTEGRATION_BRANCH]` — `git diff [INTEGRATION_BRANCH]...refs/marcus/wave-<n>-oct`, step 2's pinned ref, because the worktree that built that commit is already gone (`../SKILL.md` §4 step 5): never hand the owner a wave no agent reviewed. §6 is a compliance check, not a code review — passing it says nothing about whether the code is right.

- 🔴 → **one fix slice**, cut from the last branch in the merge order and worked like any other slice, then re-review. Never a hand edit on `wave/<n>`.
- 🟡 → follow-up tickets. **🟡 does not hold the merge** — that ladder is `marcus-code-review`'s, and its wording is owned there.

**Stage 2 is polo, always** — every wave, in every mode. Stage 1 clear (zero 🔴) → spawn `polo` on the same octopus diff, fresh context, carrying linus's verdict: one Stage 2 verdict per slice. **Both verdicts ride into Gate 7** (step 5), and both are what step 6's *Verified* section reports.

In plain `wave` his verdict is **advice to the owner**: a `NO-GO` is handed over with Polo's reasons and a recommended fix slice, and the owner decides at Gate 7 — merge anyway, fix first, or drop. You merge nothing either way, and the wave stays `in review` until he does. Inside `ultraflow` the same verdict binds and blocks the merge (`ultraflow.md` §11).

#### 4 — Mark it `in review` *(wave worktree)*

Set that wave's `Status:` to `in review` in the plan. **The claim block is kept exactly as it stands** — never reset: the wave is still this session's until the owner merges, and a cleared claim is a wave anyone may re-cut. One commit on `wave/<n>`, owner identity, no trailer, nothing else in it:

```
docs(wave): wave <n> in review [CODE]-WAVE-<n>
```

Tracker: **the wave task → `review`, and nothing else.** One call, on the task this wave's `Tracker task:` line names. The member tickets are already at `review`, and the wave task stays **open** — `review` is precisely the state this step creates: the work is done and the owner has not merged it (§ *Tracker view of a wave*; an adapter whose wave object has no `review` state says what it does instead, in its §8). Degraded or locked out → `../trackers/<adapter>.md` §7, queue it, say so; the mark is the commit above. **A `Tracker task:` line that is absent or empty takes that same road** — queue the mark as a §7 line naming the wave, and say so out loud. Never a lookup: the adapters place the one search at §`wave close <n>` step 6, run once and after the merge (`../trackers/<adapter>.md` §8), and hunting for the task here would spend a call mid-wave to write a mark the commit above already carries. **The end-of-wave summary is not written here either**: two of its five sections are not true yet — "built" names a merge the owner has not taken, and the independence check reads the other waves as of that merge. Step 6 is where it goes.

#### 5 — Gate 7, the handoff *(main tree — the owner runs it)*

`../SKILL.md` §8's gate, written out. **You hand the owner this block and run none of it** (§11 — discipline, not the hook: the hook gates remote verbs, and every line here is local). Above it go **linus's and polo's verdicts per slice**; inside it, the slice order is the plan's § *Merge order* **verbatim**, from the repo root:

```bash
git worktree remove --force .worktrees/wave-<n>        # a branch a worktree holds cannot be checked out here
git worktree remove --force .worktrees/[CODE]-<slice>  # one per slice in the wave. --force because a `node_modules/`
                                                       # line in .gitignore does not match the symlink step 3 made,
                                                       # so the tree reads dirty and a plain remove refuses

git checkout wave/<n>
git merge --no-ff feat/[CODE]-<slice>            # one line per slice, in the plan's order
<the repo's gate>                                # docs-only: git diff --check + the path sweep
                                                 # product:   npm run build && tsc --noEmit && eslint src

git checkout [INTEGRATION_BRANCH]
git merge --no-ff wave/<n>
```

Then the migrations, by timestamped filename in apply order — or `none`. **Nothing remote is in this block**: wave branches are local, and if the owner's repo has a remote, sending the trunk there afterwards is their command and their business, not part of this gate. The tracker batch is step 6's, and it runs only once the merge is real.

#### 6 — After the merge is real *(main tree)*

The only step that runs later, and by whichever session sees it — the one resuming the wave, or a `wave status` that catches it. **One condition, and nothing else counts:**

```bash
git merge-base --is-ancestor wave/<n> [INTEGRATION_BRANCH]   # exit 0 = merged
```

That command is the *seeing* in « never mark a wave `merged` you did not see merged » (§ *Hard rules this mode does not touch*). The owner's word, your own memory of handing it over, a green terminal in a screenshot — none of them are it. Then, in order:

1. **`Status: merged` in the plan — and that write lands on `[INTEGRATION_BRANCH]`, in the main checkout.** `.worktrees/wave-<n>` is gone by then; the Gate 7 block removed it before checking the branch out. The merge carried `wave/<n>`'s plan commits into the trunk with it, so the trunk's copy is the one read from now on and it currently says `in review`; writing `merged` on the wave branch would write it where nobody looks again. One docs commit there, `docs(wave): wave <n> merged [CODE]-WAVE-<n>` — the second and last this mode allows on the trunk (§ *The shape, before the procedure*).
2. **Tracker, one batch:** `milestone close` on the wave task — **the one this wave's `Tracker task:` line in the plan names**, read straight off it, no lookup (§`wave plan` step 8) · **the end-of-wave summary, as one comment on it** · one `status → complete` per member ticket — `2 + N` calls (§ *Tracker view of a wave*). A plan whose `Tracker task:` line is **absent or empty** — written before the line existed, or left empty by a degraded batch (`../templates/wave-plan.md`) — costs **one** extra call — a **keyword search** for the task named `[CODE]-WAVE-<n>`, never a field filter (`../trackers/<adapter>.md` §8 carries the exact call) — and step 1's commit writes the line back.

   **The end-of-wave summary — five sections**, and **the same block goes into the plan under this wave, in step 1's commit**. It is what somebody who ran none of this wave reads instead of its branches:

   | Section | What goes in it |
   |---|---|
   | **Built** | one line per ticket in the wave's table: id, title, **the slice branch and the commit sha** the owner merged. Not a description of the work — the ticket body is already that |
   | **Verified** | what actually ran and what it returned: the integration check and the gate it ran (step 2), **linus's verdict per slice** (step 3), **polo's verdict per slice** (step 3 — advisory outside `ultraflow`, binding inside), and the gate the owner cleared |
   | **Blocks what** | the edges that outlive the wave, both directions: which of this wave's tickets still block tickets in **other** waves — named, with the wave number — and which waves this one waited on. Read off the plan's `Blocked by` columns, never off memory |
   | **Parked** | every ticket that left this wave at anything but `complete` — `on hold`, `decision`, `blocked`, or carrying a `Fence corrections:` line — with the reason and what unparks it. A wave that quietly drops a ticket is a wave lying about being closed |
   | **Independence** | one line **per other open wave**: `runs in parallel with wave <n>` or `waits for wave <n>`, **recomputed** from the current plan and §`wave status` — never copied from what step 8 wrote. This wave merging moved the frontier, and this line is what the other sessions read next |

   Adapter `none` posts nothing: the block in the plan file is the whole of it (`../trackers/none.md` §8).
3. Worktrees: the Gate 7 block removed them. `git worktree list` — anything of this wave's still standing (the owner merged some other way), remove now, `.worktrees/wave-<n>` included. Then drop step 2's pin — `git update-ref -d refs/marcus/wave-<n>-oct` — our own ref, not a branch. **That commit itself never reaches the trunk:** Gate 7 re-merged the slice branches into `wave/<n>` and built its own merge commits, so the octopus stays the throwaway that proved they merge clean. What is in the trunk is the work it pinned, and that is what makes the ref droppable.
4. The slice branches and `wave/<n>` are **the owner's to delete, never yours** (§11).

Until step 1 lands, `wave status` already reports that wave — as **merged, unrecorded** (step 2's anomalies): `wave/<n>` is an ancestor of the trunk and the plan does not say so. That anomaly exists for exactly this gap, and step 6 is its fix.

---

### Interactions

**Every row below is today's behaviour.**

| Mode | Relation to `wave` |
|---|---|
| `justflow` (`justflow.md`) | the round `wave <n>` runs: the wave supplies the frontier and the branch, justflow supplies the loop — eligibility, 3 agents, linus per slice, stop conditions (§`wave <n>` step 3). Called on its own it has no plan and recomputes the frontier each round, on `[INTEGRATION_BRANCH]` |
| `ultraflow` (`ultraflow.md`) | claims a wave and merges it itself, on an armed repo — `ultraflow.md` § *Inside a wave*. The only mode where `wave/<n>` reaches `[INTEGRATION_BRANCH]` without the owner |
| `relay` (`relay.md`) | a relay inside a claimed wave keeps the claim and updates its `checkpoint:` line — the next session resumes the same wave, it does not re-claim it (`relay.md` § *Inside a claimed wave*) |
| `marcus-slice` | cuts the tickets the planner partitions. A wave that cannot be made disjoint is a cut to send back there, not a fence to widen |
| `marcus-checkpoint` | unchanged trigger — 3 merged slices or one gate. Its handoff path is what a claim's `checkpoint:` line points at, and it runs §`wave status` step 3 before writing, pasting the conflict block into the handoff's État |

### Tracker view of a wave

**The plan file is the truth and the tracker is a view of it.** Every adapter degrades to the plan file — an unreachable service costs the view, never the record — and `wave status` **reads** the view without ever writing it: one read per wave, reported beside git and the plan, correcting neither (§`wave status` step 0).

Four writing moments. **The view is written at the plan, at the claim, at the `in review` mark and at the close; the checkpoint alone writes nothing.**

| Moment | Ops | Cost |
|---|---|---|
| **Plan** (§`wave plan` step 8, after the owner's ok) | `milestone create` per wave, named `[CODE]-WAVE-<n>`, carrying the plan's path and that wave's ticket ids · then `label add wave-<n>` on each member | `1 + N` **per wave**, **one batch for the whole plan**, once |
| **Re-plan** (§`wave plan` step 8, a re-run) | `milestone create` **only** for a wave whose `Tracker task:` line is empty · `status → cancelled` on each superseded `planned` wave's task — **closed**, on an adapter whose states are open/closed | folded into the plan's one batch — `1` per new wave, `1` per superseded one |
| **Claim** (§`wave <n>` step 2.4) | `status → in progress` on the wave task · **one comment** carrying `session` · `machine` · `claimed_at`, signed per `../SKILL.md` §7 | `2`, **once per wave**. The claim itself is still the commit on `wave/<n>`; this is the view of it |
| **Checkpoint** | none | the claim's `checkpoint:` line is the record, already committed on `wave/<n>` (§`wave <n>` step 4) |
| **`in review`** (§`wave close <n>` step 4) | `status → review` on the wave task — it does **not** close: the close is the owner's merge, and it has not happened | `1`, once |
| **Close** (§`wave close <n>` step 6) | `milestone close` · **one end-of-wave summary comment on the wave task** · one `status → complete` per member ticket — only once the wave is an ancestor of `[INTEGRATION_BRANCH]` | `2 + N`, **one batch**, once |

**Why creation moved to the plan.** The owner has to see the waves before he decides which sessions to open — a view that appears only when somebody claims a wave shows him the waves he has already launched. And it buys back the budget: one batch for the whole plan instead of one per claim.

**Why it is one batch and not a call per event.** ClickUp's budget is 300 calls per rolling 24 h window, shared across every session and project (`../trackers/clickup.md` §6): a three-wave plan over eight tickets is eleven calls, paid in one batch, and the reason the plan is one batch rather than one call per wave. **The mirror is priced the same way:** `2` at the claim and `1` at the `in review` mark, each paid once for the whole wave and never inside a loop — a view that fired per slice, per checkpoint or per status read would multiply that by every slice and every read, for state the plan file already holds. Write them together or not at all, and when the service refuses, degrade by `../trackers/<adapter>.md` §7 — queue the writes, say so out loud, carry on. **A wave whose tracker write never landed is planned, claimable and closeable exactly as hard as one whose did.**

What each adapter actually renders is `../trackers/README.md` § *Wave view* and each adapter file's §8 — written there, not here.

### Hard rules this mode does not touch

§11 binds unchanged. Restated only because a parallel-sessions mode is where they get bent:

- **You never merge `wave/<n>`.** You never push it. The owner does, in the plan's order — the one exception is `ultraflow` on an armed repo, and it is that mode's exception, not this one's.
- **Never edit another session's claim.** Stale is a report, not a permission.
- **Never mark a wave `merged` you did not see merged.** The plan file is the source of truth; a source of truth that records a merge that did not happen is worse than no plan.
- One agent per file, one slice per agent, one local commit, owner identity, no trailer. A wave does not raise the concurrency by lowering the bar; it raises it by proving the fences first.

---
