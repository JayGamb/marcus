# `<your company>` — standing rules

> Loaded in every session on this machine. **Scope: any repository that carries a `marcus.config.json` at its root.** Outside that, ignore everything below.
>
> **This file is the single source for the rules that apply everywhere.** A project `CLAUDE.md` adds what is specific to that project — stack, tokens, paths, deploy — and never restates these. If a project file contradicts this one, the project file wins for that project, and say so out loud rather than silently picking.

## The team

Orchestrator: the **`/marcus`** skill (`~/.claude/skills/marcus/SKILL.md`) — modes `evaluate · new · resume · status · reset · client · justflow · prototype · ultraflow`.
Agents (`~/.claude/agents/`): **polo** (Stage 2 gate, reports to the owner) · **linus** (CTO, Stage 1) · **ada** (backend) · **neo** (full-stack) · **dieter** (design) · **kira** (devops) · **magellan** (research, `evaluate` only).

## Why the work exists

`<your company>` has to make money. Every project here is a product someone pays for, or a client who pays. That is the tiebreaker on close calls: **does this make the thing worth paying for?** — not "is the ticket satisfied".

**Owning it means refusing to ship broken work, not wanting to ship.** The urge to be helpful by letting something through is the most expensive instinct on this team. When you are unsure, the answer is not go.

## Context budget — the window is a buffer, never the memory

**The memory is the tracker + the repo docs + `docs/handoffs/`.** A session that keeps growing gets dumber and more expensive; nothing important may live only in a transcript.

- **Checkpoint after 3 merged slices, or at any phase gate — whichever comes first.** `/usage` is a CLI command an agent cannot call, so token counts are not an observable: count slices and gates instead. Treat ~500K tokens as a hard ceiling, never as the trigger.
- At a checkpoint: finish only the in-flight slice → write the session handoff (`docs/handoffs/<date>-<CODE>-session-handoff.md`) → sync the tracker in one batch → tell the owner: `/clear` then `/marcus resume`.
- **The resume test:** a fresh session running `/marcus resume` must reconstruct everything from disk + the tracker alone. If it cannot, the handoff was bad — fix the handoff, not the session length.
- **Burn less inside a session:** delegate exploration and bulk reads to subagents (their transcripts never enter the main window — read only the returned summary) · batch tracker calls · read file *sections*, not whole files · never re-read what a handoff already records · never tail an agent transcript.

## Every ticket carries its own state

A ticket must be understandable by an agent who has read no transcript. It carries: **what to build** (end to end) · **acceptance criteria** · **blocked by** · links to ADR / spec / DESIGN / handoff **by path**, never pasted.

**Completion ritual — on every ticket, no exceptions.** When a slice is delivered and verified, before it is called done:
1. Status → `review` (or `complete` where the mode merged it).
2. A **handoff comment on the tracker task**: what was built · commit SHA + branch · what was verified (build/lint, the checks actually run) · what is left or waiting on the owner · **signed on the last line**, `— <Agent> · <mode> · session <id> · <YYYY-MM-DD>`.

That comment is the per-ticket handoff. The file in `docs/handoffs/` is the per-session map — different jobs, both required. **Batch these comments at the checkpoint**, not one call per slice: ClickUp's MCP budget is **300 calls per rolling 24 h window**, shared across every session and project — spend it and every session is locked out until the budget returns. `retryAfter` is the only figure the service gives and it is not a schedule (measured 2026-09-15; whether the budget then returns whole or call by call is unmeasured).

## Non-negotiable everywhere

- Agents commit **locally only**, under the owner's git identity, **no AI co-author / "Generated with" trailer**. Never push, open/merge PRs, `reset --hard`, `clean`, delete an unmerged branch, or apply a production migration. The one exception is `/marcus ultraflow` on a repo the owner has armed — see the skill.
- No credentials in code, prompts, or docs. A task needing a live key stops and returns a BLOCKER.
- Public/anon data reads go through the project's sanctioned path (on Supabase: `SECURITY DEFINER` RPCs), never a direct table read.
- Design tokens only — no hardcoded colors, `components/ui/*` untouched. The **slop test is an acceptance criterion**: generic AI-looking UI does not ship.
- Every to-do is a tracker task. Every agent prompt carries the task's code + id + URL.
- **Anything expected of the owner is a tracker task assigned to him** — an action tagged `ready-for-<his first name>`, or a decision at status `decision` that only he moves to `accepted` or `declined`. Never only a line in a chat, never only a paragraph in a handoff file.
