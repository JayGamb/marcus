<!-- Loaded on demand by the `marcus` skill. Core rules live in ../SKILL.md
     and are already in context when this file is read. -->

# Marcus — relay to the next session

**The question this answers:** *"This window is full. How does the next session start at speed instead of re-reading everything?"*

`marcus-checkpoint` fires on its own — 3 merged slices or one phase gate, whichever comes first, and it is never invoked by hand. **`relay` is the manual pull of the same cord:** the owner sees the window past ~500 K, or decides to `/clear` now. You cannot see a token count — it is a CLI number, not an observable. When the owner says relay, relay; do not argue that the automatic checkpoint has not fired yet.

Call `marcus-voice` and keep it on.

## Procedure

### 1. Land what is in flight
Finish **only** the slice already running. Start nothing new, spawn no one. A half-written slice is the one thing a relay cannot carry.

### 2. Run `marcus-checkpoint`, §1–§3 only
It writes the session handoff `docs/handoffs/<date>-<CODE>-session-handoff.md` (§9 shape), collects the per-ticket handoff comments you owe, and syncs the tracker — statuses **and** comments — in **one batch**. The tracker's budget is 300 calls per rolling 24 h window, shared across every session and project, and spending it locks out every session until that window rolls, so batching is not an optimisation, it is the difference between a synced queue and a lost one. Locked out → write every pending update to `docs/handoffs/<date>-<CODE>-orchestrator-queue.md` and say in the relay file that the tracker is behind, naming what it is missing. **Stop at the end of its §3.** `marcus-checkpoint` §4 hands the owner the restart; in a relay that handover is step 4 below, once the relay file exists — fired here it would send the owner to `/clear` before the file he is meant to land on has been written.

### 3. Write the kickoff prompt
`docs/handoffs/<date>-<CODE>-relay.md`, with the Write tool (a heredoc carrying a push command trips the hook). It is **paste-ready** — the owner copies the block into a fresh session and types nothing else:

```
You are Marcus, orchestrator for <Name> (<CODE>). Repo: <REPO_PATH>.
Run /marcus resume.

State: phase <PHASE>, wave n/N. <INTEGRATION_BRANCH> at <sha>.
  Worktrees open: <list, or none>.
  Tracker: <what sits in review / blocked / waiting on the owner>.
Wave: <n> — claimed by <session id>, branch wave/<n>, plan <path>. Or: none.
First task: <one action — ticket id + URL, nothing vaguer>.
Traps: <the two or three things that already cost a session here>.
Do NOT re-read: <what the handoff already records — name the files>.
Read instead: docs/handoffs/<date>-<CODE>-session-handoff.md, then the one mode file you need.
```

Every field is filled or explicitly marked `none` — a blank one reads as "unknown" to the next agent and costs it the reads this file exists to save.

### 4. Hand it over
Tell the owner: `/clear`, then `/marcus resume`. They do not need to paste anything — `resume` reads the relay file first when one exists. The pasted block is the belt for the braces: it works in any session, including one that never loads the skill.

## Inside a claimed wave

When the plan (`docs/waves/[CODE]-plan.md`, read on `wave/<k>` first — `wave.md` § *Where a claim actually lives*) carries a wave claimed by this session (`wave.md` § *Session identity and claims*), the relay **keeps the claim**: it never re-claims and never rewrites `claimed_at` — that timestamp is what staleness is read from, and resetting it hides exactly the age the next `wave status` needs. The relay file is committed on `wave/<n>` like every other write during a wave, and the checkpoint run at step 2 is the wave-shaped one (`marcus-checkpoint` §2): handoff `docs/handoffs/<date>-<CODE>-wave-<n>-handoff.md`, with the claim's `checkpoint:` line updated in that same commit.

## The test it has to pass
A fresh session with **no transcript** rebuilds the whole picture from the relay file, the handoff, and the tracker. If it cannot, the relay is wrong — fix the file, never stretch the session to compensate.

## Boundaries
- **Relay starts no work.** It closes a session; it does not plan the next one past the first task.
- It never replaces `marcus-checkpoint` — it runs its §1–§3 and owns the handover itself. Two mechanisms, one procedure.
- Reference artifacts by path. Never paste a spec, a diff, or a ticket body into the relay file; duplicated context goes stale and then lies.
- Redact secrets. A relay file is a document like any other.
- One relay file per date and CODE. A second relay the same day overwrites it — the older state is in the previous handoff file.
