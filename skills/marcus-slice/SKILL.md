---
name: marcus-slice
description: "Cut a spec into tracer-bullet vertical slices and publish them as tickets with real blocking edges — each slice demoable on its own, sized to one context window, on files no other slice touches. Run at DISC-3, after marcus-spec. Use when a spec, a plan or a refactor has to become a queue an agent can work."
---

# Marcus slice

> The tracer-bullet slice and the expand–contract sequencing for wide refactors come from **Matt Pocock's** `to-tickets` (`mattpocock-skills`, MIT): vertical not horizontal, demoable alone, blocking edges declared per ticket. His skill is user-invoked only, so Marcus inlined the procedure; this is ours, with the routing and the disjoint-files rule this workflow needs.

A slice is a **tracer bullet**: a narrow path cut through every layer at once — schema → API → UI → tests — that works end to end the day it lands.

## Four rules, all of them at once

- **Vertical, never horizontal.** "All the migrations" is not a slice. It demos nothing and blocks everything.
- **Demoable alone.** You can show the finished slice to the owner and they can tell whether it works. If the only proof is a green test file, cut it differently.
- **One context window.** A slice an agent cannot hold in one fresh session gets half-built by an agent that has forgotten the first half.
- **Disjoint files.** Two slices that want the same file are one slice cut wrong — **re-slice**. Genuinely dependent work stacks instead: the second branches off the first and declares it as a blocker.

**Prefactoring goes first, in its own slice.** Make the change easy, then make the easy change. A prefactor riding inside a feature slice is a diff nobody can review.

## Wide refactors are the exception

A change whose blast radius is the whole codebase — rename a column, retype a shared symbol — cannot land green as a tracer bullet. Sequence it **expand–contract**:

1. **Expand** — add the new form beside the old. Nothing breaks, nothing has moved.
2. **Migrate** — move the callers in batches sized by blast radius (per module, per directory). One ticket per batch, each blocked by the expand. The old form still exists, so every batch is green on its own.
3. **Contract** — delete the old form, in a ticket blocked by every migrate batch.

Where a batch genuinely cannot be green alone, keep the sequence but stack the batches on one integration branch and add a final integrate-and-verify ticket they all block. Green is promised there and nowhere earlier — write that on the tickets, so nobody merges a batch expecting it.

## What each ticket carries

A ticket is read by an agent who has read no transcript. It stands alone or it is not a ticket.

- **Title** — `[CODE]-[PHASE]-[NUM]`, then what it does, in the glossary's words.
- **What it delivers** — the end-to-end behaviour, from the user's side. Not a layer-by-layer to-do list; the agent picks the layers.
- **Acceptance criteria** — each one a check someone can actually run. "Handles errors" is not a criterion. "Submitting an email already on the list shows the inline error and creates no row" is.
- **Blocked by** — the tickets that genuinely gate this one. Only real gates: a false edge idles an agent for a whole wave.
- **Point d'arrêt** — the stop condition, in words a command can check, plus the iteration ceiling. Not a restatement of the acceptance criteria: those say what a finished slice *does*, this says **when the agent stops trying** — "one commit, `npm run build` and `tsc --noEmit` at 0, the two greps below return ≥ 1; ceiling 3 attempts on the slice, then a BLOCKER". **Write it on every ticket you cut**, including ARCH, DESI and bug tickets; the orchestrator copies it verbatim into the spawn prompt (`skills/marcus/SKILL.md` §5). A ticket without one licenses an agent to spend a whole context window on a criterion it was never going to reach, and to return a summary instead of a slice.
- **Links by path** — the spec doc, the ADRs, DESIGN.md. Referenced, never pasted.

No file paths and no code in the body, for the reason the spec gives: they go stale first. Same single exception — a shape that carries a decision more exactly than prose can.

## Routing

| The ticket is | List |
|---|---|
| code to write | **DEV**, status `to do` |
| a decision about structure, contracts or schema, needed before anyone can build | **ARCH** |
| a surface to design or copy to write, needed before anyone can build | **DESI** |
| more discovery | **DISC** |

**A build ticket never goes in DISC.** DISC holds the interview, the spec and this cut — nothing else. When a build slice is blocked by an architecture or design question, file both tickets and set the edge between them; do not park the build ticket in the phase that owns its blocker.

## The granularity check, before publishing

Present the whole cut to the owner first: numbered, each with title, what it delivers, and its blockers. Ask three questions.

- Is the granularity right — anything too coarse to review, anything too fine to be worth a branch?
- Are the edges real — does each blocker genuinely gate its ticket?
- Anything to merge, anything to split?

Iterate until the owner approves. This is the phase gate. Publishing a cut nobody approved wastes a wave, not a ticket.

## Publish

In **dependency order, blockers first**, so every edge can reference a real id. Use the tracker's native blocking relationship where it has one; otherwise write the edge into the body. Those edges are the schedule: the build phase works the **frontier** — every ticket whose blockers are all complete — and nothing else.

Do not close or edit the parent epic; link to it.

---

**A cut is good when** the first slice can start immediately, no two slices touch the same file, each one carries a `Point d'arrêt` an agent can check without asking, and each one, finished, is something the owner can look at.
