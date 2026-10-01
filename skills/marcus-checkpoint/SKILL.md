---
name: marcus-checkpoint
description: "The session checkpoint: finish the in-flight slice, write the session handoff file, batch the per-ticket tracker comments, hand the owner the restart line. AUTOMATIC — the orchestrator runs it on its own trigger (3 merged slices or 1 phase gate, whichever comes first); it is not something a human invokes. Load it when that trigger fires, or when `/marcus relay` calls it as a manual override."
---

# Marcus checkpoint

> Replaces **context-save** and **context-restore** by the gstack authors (MIT, Garry Tan), whose core insight this keeps: a session's real state is git plus the decisions made plus the work left, and if it is not written down before the window fills, it is gone. Rewritten here — one skill instead of two, because restoring is `/marcus resume` reading the tracker and the handoff, not a second saved blob. Credit for the idea is theirs.

## This is not invoked by hand

The orchestrator fires it. The trigger and the reasoning behind it live in **`~/.claude/CLAUDE.md` → "Context budget"**, loaded in every session; the orchestrator's own share is **`skills/marcus/SKILL.md` §12**. Read them there — they are not restated here.

What matters at this end: when the trigger fires, **stop planning new work**. A checkpoint deferred because the next slice looked small is how sessions die with three tickets un-commented and no handoff.

**Manual override:** `/marcus relay` (`skills/marcus/modes/relay.md`) runs this checkpoint on demand, then writes a paste-ready kickoff prompt for the next session. Same procedure, human timing.

---

## Procedure

### 1. Land, do not start

Finish **only** the slice in flight: its commit, its verification, its status. Nothing new is spawned, no wave is opened, no "quick" follow-up. A slice that cannot land cleanly is left uncommitted and named in the handoff as exactly that.

### 2. Write the session handoff

`docs/handoffs/<date>-<CODE>-session-handoff.md`. Sections are fixed by `skills/marcus/SKILL.md` §9 — the skeleton below is that list. Write it with the Write tool: a heredoc carrying remote-git verbs trips the PreToolUse hook.

```markdown
# <CODE> — session handoff <YYYY-MM-DD>

## Rôle attendu du prochain agent
<one paragraph: which mode, which phase, what it owns>

## État
repo · branches · worktrees (and which are stale) · prod DB · tracker ids + statuses

## Livré
| ticket | commit | branch | verified | tokens |

## Décisions du propriétaire en attente
<each open question, with a recommendation — never a bare problem>

## Conventions apprises
<what this session learned that is not yet written in a doc>

## Prompt de reprise
`/marcus resume` — paste-ready, with the code and the entry point

## Prochaines étapes
<ordered, each one a tracker ticket that exists>

## Suggested skills
<skills the next session should load first>
```

The headings are literal — the same shape the orchestrator's §9 prescribes. Reference every artifact **by path or URL** — ADRs, specs, `DESIGN.md`, the previous handoff. Never paste their contents: a handoff that duplicates a doc is a handoff that will contradict it next week. **Redact secrets.** Prose, not compressed voice — a human reads this without you there to explain it.

**Inside a claimed wave** — the plan (`docs/waves/[CODE]-plan.md`, read on `wave/<k>` first — `skills/marcus/modes/wave.md` § *Where a claim actually lives*) carries a wave whose claim `session:` is this session's id (`skills/marcus/modes/wave.md` § *Session identity and claims*) — three things change, and nothing else does:

- The handoff is `docs/handoffs/<date>-<CODE>-wave-<n>-handoff.md`, and it is committed on `wave/<n>`, never on the integration branch.
- **The claim's `checkpoint:` line is updated in the same commit as the handoff file.** The rule and its reason are `skills/marcus/modes/wave.md` § `wave <n>` step 4 — read them there.
- Run the cross-wave conflict check first (same file, § `wave status` step 3) and paste its block into the handoff's **État**. A checkpoint is the cheapest place to learn that two waves stopped being disjoint.

### 3. Batch the per-ticket comments — one batch, not one call per slice

Each delivered ticket gets a handoff comment on its tracker task carrying four things:

- **what was built** — end to end, understandable by someone who read no transcript
- **commit SHA + branch**
- **what was verified** — the checks actually run (build, typecheck, lint, the browser pass), with what they printed. Never a check you predicted.
- **what is left, or what waits on the owner**
- **cost — subagent tokens for the slice**, as the `Agent` tool result reported them (`<subagent_tokens>`), plus the attempts it took (`2/3`) and whether it hit the ceiling. One number per slice, copied, never estimated: it is the only measurement the team has, and it is what makes the open roster questions in `docs/WORKFLOW.md` §10 decidable instead of arguable. A retry is a second number, not a replacement for the first — record both.
- **signature** — the last line: `— <Agent> · <mode> · session <id> · <YYYY-MM-DD>` (`skills/marcus/SKILL.md` §7). Unsigned = unwritten.

Status moves to `review` (or `complete` where the mode merged it) in the same batch. **Send them together.** ClickUp's budget is 300 calls per rolling 24 h window, shared across every session and project, and spending it locks out every session until that window rolls; a session that comments per slice buys a lockout in the middle of the next one.

The per-ticket comment and the session handoff are different jobs. The comment travels with the ticket; the file is the map of the session. Both are required.

**Totals go in the handoff, not only on the tickets.** The **Livré** table's `tokens` column carries the per-slice number and the section ends with the session total — tokens, slices, and **every ceiling hit, named by ticket**. A ticket that burned its ceiling twice is a slice cut wrong: say so in **Conventions apprises** so the next cut does not repeat it.

### 4. Hand the owner his tasks, then the restart

**Skipped when called from `/marcus relay`**, which owns the handover and fires it only once the relay file exists.

**First, the owner's task block** — the one in `skills/marcus/SKILL.md` §10, used as written and not as a variant: every action and every decision this session left with him, as clickable task links. A checkpoint is the last thing he reads before `/clear`, so a task missing from this block is a task he will not see tonight — and by tomorrow the session that knew about it is gone.

Then two lines, exactly:

```
/clear
/marcus resume
```

Nothing else. No summary of the session — it is in the handoff — and no offer to keep going.

---

## The resume test

A fresh session that has read **no transcript** must rebuild the whole picture from **disk + the tracker alone**. Before you hand over, read your own handoff as if you were that session and ask: do I know which branch, which worktree, which ticket, which decision is pending, and what to do first?

If it cannot be rebuilt, **the handoff was bad — fix the handoff, never stretch the session.** That failure mode has a record: 43 worktrees across two projects with zero handoffs between them, and not one of those runs could ever have resumed.

## Failure modes

| What it looks like | What it means |
|---|---|
| "I'll checkpoint after this next slice" | the trigger already fired; two slices of state are now unwritten |
| A handoff that pastes the spec | it will drift from the spec, and the next session will believe the wrong one |
| A comment saying "implemented and working" | no check was named, so nothing was verified |
| One tracker call per slice, all session | the lockout lands mid-run in the next session |
| A handoff naming a ticket that does not exist | if it is not a task, it does not exist |
