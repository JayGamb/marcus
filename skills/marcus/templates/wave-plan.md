# Wave plan — the template

> Installed with the `marcus` skill. `wave plan` (`../modes/wave.md`) fills this in and writes the result to `docs/waves/[CODE]-plan.md`, committed on the integration branch. **One file, for the life of the project**: a re-run rewrites it and bumps `Plan version:`; the history is `git log` on that path.
>
> **The plan file is the source of truth. The tracker is a view of it.** Two sessions can work two waves at once because this file — not a transcript, not a window, not one session's memory — says who holds what, which files each wave owns, and in what order the owner merges. Anything a wave needs that is only in a session is already lost.

## How to use it

1. Copy the skeleton below into `docs/waves/[CODE]-plan.md` — that exact path, every time.
2. Fill **every** field. A field that does not apply is `—`, never blank: a blank one reads as "unknown" to the session that claims the wave, and costs it exactly the reads this file exists to save. **`Tracker task:` is the one exception, and there is no other**: on that line **empty is a value** — "the batch degraded before this wave's task existed; look it up once at the close and write it back" — and `—` would tell that close there is nothing to find. See the skeleton's own note on that line.
3. Show the owner the wave table, the merge order, and **every wave's kickoff block** — not the file. Gate: granularity right, order right, prompts complete → « ok ? ».
4. After the ok and **before the commit**, in **one batch**: create the tracker's wave view — one wave task per wave, `label add wave-<n>` on each member (`../modes/wave.md` § *Tracker view of a wave*) — then write each wave task's url, or its id where the adapter has no url, into that wave's `Tracker task:` line. The batch runs first so the ids it returns are in the file the commit carries.
5. Commit — one commit, owner identity, no trailer. A `wave plan` commit (version 1, or a re-run's version bump) and the `Status: merged` write are the only orchestrator docs commits allowed on the integration branch during a wave run; everything else goes on a `wave/<n>` branch. **`wave plan` stops there.** It launches nothing: no agent, no branch, no worktree, no terminal. The owner opens one session per wave and pastes that wave's kickoff block.

---

## The skeleton

````markdown
# [CODE] — wave plan

Plan version: <n>          Supersedes: version <n-1>, or "none"
Integration branch: `<branch>`   Tracker adapter: `<clickup | github | local-html | none>`
Tracker state: <"synced" | "unreachable — this file is the queue">
Written by: <session id> on <machine> at <YYYY-MM-DDTHH:MM>

## Waves

### Wave <n> — <one line: what this wave delivers>

Status: `planned` | `claimed:<session id>` | `in review` | `merged`
Reverted: <sha of the commit that backed this wave out of the integration branch, or `—`. Owner-written, at revert time — never by a mode. §`wave status`'s revert test reads it (`../modes/wave.md` §`wave status` step 2)>
Branch: `wave/<n>`   Base: `<integration branch>`   *(always — a wave never stacks on a wave)*
Round: <r>   Runs in parallel with: <the other waves of round r, or "none — alone in its round">
Blocked by wave: <the waves of round r-1 holding this wave's blockers, or "none">
Tracker task: <url or id of `[CODE]-WAVE-<n>`, written at `wave plan` step 8 before the plan commit. `—` **only** on adapter `none`, which creates nothing ever. Left **empty** where the batch degraded before this wave's task was created — empty means "look it up once and write it back" at `wave close <n>` step 6; `—` would tell that close there is nothing to find>

| # | Ticket | Title | Slice branch | Base | File fence (predicted) | Blocked by |
|---|---|---|---|---|---|---|
| 1 | [CODE]-DEV-<num> | <title> | `feat/[CODE]-<slice>` | `wave/<n>` | `<path>` · `<path>` | — |
| 2 | … | … | … | … | … | … |

Merge order inside the wave: 1. `feat/…` 2. `feat/…`  *(stacked first, base before dependant)*
Migration order: `<timestamped filename>` then `<timestamped filename>` — or `none`

Claim
```
session:    <session id, or "unclaimed">
machine:    <hostname, or —>
claimed_at: <YYYY-MM-DDTHH:MM, or —>
checkpoint: <docs/handoffs/… path, or —>
```

Kickoff — paste this into a fresh session, nothing else
```
You are Marcus, orchestrator for <Name> ([CODE]). Repo: <REPO_PATH>.
Run /marcus wave <n>.

Wave <n> — <what this wave delivers>.  Base: `<integration branch>`.
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

End-of-wave summary — written at `wave close <n>` step 6, once the merge is real. Until then: `—`
```
Built:        <ticket — branch — sha>, one line each
Verified:     <integration check + gate · linus per slice · polo per slice, advisory outside ultraflow and binding inside · the owner's gate>
Blocks what:  <this wave's tickets still blocking other waves> / <the waves this one waited on>
Parked:       <ticket — status — why — what unparks it>, or "none"
Independence: <one line per other open wave: runs in parallel with / waits for>
```

### Wave <n+1> — …
<same block>

## Not waved

| Ticket | Title | Why it cannot be waved yet | Re-check when |
|---|---|---|---|
| [CODE]-DEV-<num> | <title> | <blocked outside this repo / no predictable fence / awaiting a decision> | <the event> |

## Disjointness proof

Each off-diagonal cell is the **intersection** of the two waves' fences.
`∅` on both axes **and** no blocking edge between them = those two waves may run at once, in two sessions.

|  | Wave 1 | Wave 2 | Wave 3 |
|---|---|---|---|
| **Wave 1** | — | <∅ or the shared paths> | … |
| **Wave 2** | … | — | … |
| **Wave 3** | … | … | — |

Verdict: <which pairs may run in parallel, or "serial — no parallel pair">

## Merge order — run this top to bottom

<numbered, absolute, copy-paste ready; nothing to read before it, nothing to decide in it>
````

---

## Field reference

**Plan version / Supersedes.** A re-run of `wave plan` rewrites **this same file** and bumps `Plan version:`; `Supersedes:` names the version it replaced, `none` at version 1. Waves at `planned` are superseded; waves at `claimed`, `in review` or `merged` keep their number and their table verbatim — but their `Status:` line and claim block are left exactly as the copy being edited has them, because the state lives on `wave/<k>` and the re-run writes on the trunk (`../modes/wave.md` § *Re-running it*). Numbers are never reused: a branch, a claim and a tracker view all carry them.

**Tracker state.** Whether the plan was built from a live tracker query or from what the owner named. With `tracker.adapter = none`, or with any adapter whose service was unreachable, this file is the queue — and it says so in its own header rather than in somebody's memory.

**Status.** Exactly four values, and they mean what they say: `planned` (nobody holds it), `claimed:<session id>` (one session is working it), `in review` (its slices are verified and reviewed, waiting on the owner), `merged` (the owner merged `wave/<n>` into the integration branch — never recorded on anything less than that).

**Reverted.** The sha of the commit that backed this wave out of the integration branch, written by the **owner** at revert time and by nobody else — `—` for as long as the wave stands. `git revert -m 1` adds a commit and removes none, so `merge-base --is-ancestor` keeps exiting 0 for a wave that was backed out: this line is how §`wave status` tells a reverted wave from one nobody wrote down (`../modes/wave.md` §`wave status` step 2). It is not a fifth `Status:` value — `Status:` keeps the four above, and this line qualifies it.

**Round / Runs in parallel with / Blocked by wave.** The partition is built in rounds (`../modes/wave.md` §`wave plan` step 3): round 1 is everything unblocked, round `r+1` everything whose blockers sit in rounds `≤ r`. Inside a round, tickets fill waves **to a cap of 3** — one session's 3 agents in flight (`../SKILL.md` §12) — and the overflow opens a **sibling** wave that runs in parallel, not a later one. `Runs in parallel with:` is written from the disjointness proof below, never from the round alone; `Blocked by wave:` is what §`wave <n>` step 1 refuses a claim on until those waves are `merged`.

**Kickoff.** The paste-ready block that makes a wave *launchable*: a fresh session that has read nothing runs `/marcus wave <n>` from it and nothing else. Ids and URLs go in literally — a session that has to look a ticket up has already spent the context this block exists to save. **Marcus never launches a wave**; the owner opens one session per wave and pastes this.

**End-of-wave summary.** Five sections, written at `wave close <n>` step 6 — *after* the merge is real, because "built" names a merge the owner has not taken until then. The same block is posted as one comment on the wave's tracker task. `—` until then, never a forecast.

**Base.** Always the integration branch. **A wave never has a wave for a base** — every `wave/<n>` is cut from the trunk, and stacking happens *inside* a wave, in the table's slice `Base` column. Two waves that cannot be independent are one wave with a stack in it, or two waves the plan orders serially.

**File fence (predicted).** What the planner expects each ticket to touch, derived from the ticket's scope text plus a `git grep` of the repo for every artifact it names. It is a claim, not a fact. A slice that returns having touched a file outside its fence means the plan was wrong: fix the plan, never widen a fence in flight.

**Merge order.** Inside a wave, stacked branches come first, base before dependant. Across waves, the order the owner merges `wave/<n>`. Migrations are listed by timestamped filename in apply order; production apply is the owner's, always.

**Claim.** Written when a session claims the wave, updated at every checkpoint. A claim older than **6 hours whose `checkpoint:` is still `—`** is reported **stale** by `wave status`. Six hours is a default, not a law. Nothing auto-releases a claim — a wrong wait costs an hour, a wrong release costs the work. Releasing one is the owner's call.

**Not waved.** The tickets that exist and cannot be planned: blocked on another repo, on a credential, on a decision. Naming them is the point — a plan that silently omits them looks finished when it is not.

---

## Worked example

A dry run of the procedure in `../modes/wave.md` against this repo's own open tickets, their real blocking edges and a real `git grep` of the tree, at the frontier that exists **the moment `MRCS-DEV-9.3` merges**. Nobody claimed this wave; it is what `/marcus wave plan` would print.

Three caveats first, because a worked example that hides them teaches the wrong thing.

**This frontier yields exactly one wave, and an honest plan says so.** Two tickets are unblocked and their fences are disjoint — which under the cap of 3 is **one wave of two**, not two waves of one. The cap opens a sibling wave on **overflow only**: a wave fills to 3, and the *fourth* unblocked disjoint ticket of that round starts the sibling. **A round that does not overflow has nothing to split** — two tickets, or three sitting exactly on the cap, are one wave either way, and only the fourth changes the answer. A plan that split them anyway would be inventing parallelism — two claims, two Gate 7s and two merges for work one session finishes inside its own wave.

**So this example does not demonstrate parallel waves.** The demonstration is the six-ticket scratch drill at the end of this section: six unblocked tickets on six disjoint files, the case where the cap actually bites and the partition returns two waves of three. Read that one for the parallel case; read this one for the shape a real, small frontier has.

**Ticket ids and URLs are elided below** (`<id>`) because this file ships as a template: the published tree carries placeholders where an install carries its own tracker's ids. A real plan carries them **literally** in the row and in the kickoff block — that is the whole point of that block, and eliding them in a real plan would cost the claiming session exactly the lookups the block exists to save.

````markdown
# MRCS — wave plan

Plan version: 1          Supersedes: none
Integration branch: `staging`   Tracker adapter: `clickup`
Tracker state: synced
Written by: session 4946b9bd on <hostname -s> at 2026-09-13T23:55

## Waves

### Wave 1 — the residuals the wave chain leaves, and the package that ships it

Status: `planned`
Reverted: —
Branch: `wave/1`   Base: `staging`
Round: 1   Runs in parallel with: none — alone in its round
Blocked by wave: none
Tracker task: <url>

| # | Ticket | Title | Slice branch | Base | File fence (predicted) | Blocked by |
|---|---|---|---|---|---|---|
| 1 | MRCS-DEV-9.1 | Post-wave residuals, incl. splitting `wave.md` | `feat/MRCS-DEV-9-1` | `wave/1` | `skills/marcus/modes/wave.md` (the split) · `skills/marcus/trackers/local-html.md` (the §6 example's duplicate id) · `docs/WORKFLOW.md` (§7, and the count lines) | — |
| 2 | MRCS-DEV-5 | Package and install-test on a clean machine | `feat/MRCS-DEV-5` | `wave/1` | `README.md` · `.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json` · `scripts/install.sh` · `scripts/diff.sh` | — |

**Why these two are one wave and not two.** 9.1 ∩ 5 = ∅: they share no file, so they run as two slices **inside** this wave — two agents, one session, one claim. Round 1 holds two tickets against a cap of 3, so there is no overflow and no sibling to open. `scripts/install.sh` discovers skills and agents by walking `skills/*/` and `agents/*.md` and names no file by hand, which is why 9.1 splitting `wave.md` into several files does not reach into DEV-5's fence — the one place these two could plausibly have collided.

**The one pair that could turn that `∅` non-empty,** named so nobody is surprised by it: `docs/WORKFLOW.md` carries, on two lines, a line count, a file count and the mode files' size range for the whole plugin. MRCS-DEV-9.1 moves all three by splitting `wave.md`; DEV-5's packaging work is the other ticket that plausibly wants to touch them. They stay out of DEV-5's fence because step 2's *neighbours* rule admits a citing file only when the ticket changes the cited artifact's **path, name or contract** — and DEV-5 validates the package, it does not rename it. If DEV-5 comes back having rewritten those lines anyway, that is a `Fence corrections:` line under this wave and a re-partition; inside one wave the repair is a **stack** — 9.1 first, DEV-5 based on it — and **never** a fence widened in flight.

Merge order inside the wave: 1. `feat/MRCS-DEV-9-1` 2. `feat/MRCS-DEV-5`  *(neither stacks — both cut from `wave/1`; this is the plan's order, not a dependency)*
Migration order: none

Claim
```
session:    unclaimed
machine:    —
claimed_at: —
checkpoint: —
```

Kickoff — paste this into a fresh session, nothing else
```
You are Marcus, orchestrator for Marcus (MRCS). Repo: <REPO_PATH>.
Run /marcus wave 1.

Wave 1 — the residuals the wave chain leaves, and the package that ships it.  Base: `staging`.
  Tickets, in merge order:
    1. MRCS-DEV-9.1 — Post-wave residuals, incl. splitting wave.md — id <id> — https://app.clickup.com/t/<id>
       fence: `skills/marcus/modes/wave.md` · `skills/marcus/trackers/local-html.md` · `docs/WORKFLOW.md`
       base: `wave/1`
    2. MRCS-DEV-5 — Package and install-test on a clean machine — id <id> — https://app.clickup.com/t/<id>
       fence: `README.md` · `.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json` · `scripts/install.sh` · `scripts/diff.sh`
       base: `wave/1`
  Merge order inside the wave: 1. `feat/MRCS-DEV-9-1` 2. `feat/MRCS-DEV-5`
  Migrations: none
  Runs in parallel with: none — this wave is alone in its round.
  Blocked by wave: none.
Do NOT re-read: the ticket bodies, docs/handoffs/.
Read instead: docs/waves/MRCS-plan.md — wave 1's block only — then the mode file /marcus wave 1 loads (~/.claude/skills/marcus/modes/wave.md).
```

End-of-wave summary — written at `wave close 1` step 6, once the merge is real: —

## Not waved

| Ticket | Title | Why it cannot be waved yet | Re-check when |
|---|---|---|---|
| MRCS-DEV-8 | Wire Marcus to the team's own UI kit | blocked on the first wave of a different repo (`<OTHER-CODE>`). No fence is predictable until the kit's shape exists — inventing one would put a lie in the plan | `<OTHER-CODE>`'s wave 1 is merged |
| MRCS-DEV-9 | Wave mode (parent) | not work: it is the parent of 9.1/9.2/9.3 and sits at `review`. It completes when its subtasks do, and a parent in a wave table double-counts its children's fences | MRCS-DEV-9.1 completes |

## Disjointness proof

|  | Wave 1 |
|---|---|
| **Wave 1** | — |

Verdict: **serial — no parallel pair.** One wave, one session, one Gate 7. The table is a single diagonal cell with no off-diagonal cell to compute, and that is the shape every honest one-wave plan has: **the absence of a `∅` here is the finding, not a step that was skipped.** What this frontier permits is two agents inside wave 1, not two windows.

## Merge order — run this top to bottom

```bash
cd <REPO_PATH>

# First: free every branch a worktree is holding, or the checkouts below refuse
git worktree remove --force .worktrees/wave-1
git worktree remove --force .worktrees/MRCS-DEV-9-1
git worktree remove --force .worktrees/MRCS-DEV-5

# Wave 1 — two disjoint slices, neither stacked. This order because the plan says so
git checkout wave/1
git merge --no-ff feat/MRCS-DEV-9-1 && git merge --no-ff feat/MRCS-DEV-5
git diff --check && <the path sweep>   # this repo's gate; a product repo runs build + tsc + eslint here
git checkout staging && git merge --no-ff wave/1
```

Migrations: none in this plan. Where a plan has them, they are listed per wave by timestamped filename in apply order, and the production apply is the owner's — never in this block.
````

**Where the partition rule was proved — and the parallel case the frontier above cannot show.** A throwaway repo of six unblocked tickets on six disjoint files, run through both rules: the old one returned **one wave of six** — a 1×1 proof table with no off-diagonal cell, which is why no plan built that way could ever mark two waves parallel. The rule above returned **two waves of three, both in round 1, each `Runs in parallel with` the other**, cell `∅`. Carried through to real branches — two claim commits, six slices — the cross product `S₁ × S₂` read **0 markers in all 16 pairs**, the modify/delete sweep 0, and both waves merged into the trunk in sequence with every claim block intact. **Two live waves both write the plan file**, so that drill's `wave/1 × wave/2` is a lane-B pair by construction; here their claim blocks sit in different sections and merged clean, and where they would not, lane B is *wait for the earlier Gate 7*, never a rebase onto a sibling.

---

**Why the gate line is not `scripts/diff.sh`.** That script compares the tree to the installed copy under `~/.claude/`, so every unshipped change reads as a difference: it is a sync report, and a gate that fails by design proves nothing. Run it before committing, as this repo's `CLAUDE.md` asks — never as a wave's integration check.

---

**A plan is good when** a session that has read no transcript can claim a wave from this file alone, and the owner can merge the whole thing from its last section without opening anything else.
