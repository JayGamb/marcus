---
name: marcus-spec
description: "Turn a finished Discovery interview into the project spec — problem, solution, user stories, implementation and testing decisions, out of scope — and publish it to the tracker. Synthesis only, never an interview. Run at DISC-2, after marcus-interview and before marcus-slice."
---

# Marcus spec

> The section list, the user-story form, and the rule that a spec records decisions rather than file paths come from **Matt Pocock's** `to-spec` (`mattpocock-skills`, MIT). His skill is user-invoked only, which is why Marcus had to inline the procedure; this is our version of it, shorter, and the plugin now depends on nothing external.

**No interview here — one confirmation only, the seams, and nothing else is asked.** Everything this needs was settled at DISC-1. This skill synthesizes — it does not interview, and it does not re-open decisions that already have an ADR.

## Read first

`docs/project-overview.md` and its glossary, every ADR touching this area, and the code as it actually stands today.

Use the glossary's words. A spec that invents a synonym for a term the owner already named restarts the argument the interview closed. Respect the ADRs: contradicting one is a **finding**, not a liberty — say so and reopen the ADR, never quietly spec around it.

## If you want to ask a question

The interview ended early. Write the question down, finish the sections you can, and send it back to DISC-1. **Do not fill the hole with a guess dressed as a decision** — a spec's authority is that an agent can build from it without checking, so one invented decision poisons the whole document.

One thing is confirmed with the owner, and only one: the seams.

## Seams, before you write Testing Decisions

Sketch where this feature gets tested from the outside.

- **Prefer a seam that already exists** to a new one.
- **Take the highest seam** that still proves the behaviour — the one closest to what the user does.
- **Fewer is better** across the whole codebase. The ideal number is one.

Put the sketch to the owner and get a yes. It is cheap now and expensive once the slices are cut against it.

## The template

**Problem Statement** — the problem in the user's terms, not the system's.

**Solution** — what the user will be able to do, from their side. No mechanism.

**User Stories** — numbered, long, exhaustive. `As a <actor>, I want <capability>, so that <benefit>`. Cover every actor, the admin and the anonymous visitor included, and the unhappy paths. The slices are cut from this list: a capability missing here is a capability nobody builds.

**Implementation Decisions** — modules to build or change, their interfaces, schema changes, API contracts, auth boundaries, and the clarifications the owner gave. **No file paths, no code.** Both go stale inside a week, and a stale spec is worse than no spec. Exception: a shape that carries a decision more exactly than prose can — a schema, a state machine, a type — goes inline, trimmed to the decision rather than a working demo.

**Testing Decisions** — external behaviour only. A test that knows how a module works inside breaks on every refactor and proves nothing. Name the agreed seams, what is tested through each, and the prior art in the repo worth copying.

**Out of Scope** — explicit. This is the section that holds the line three phases from now, so write it even when it feels obvious.

**Further Notes** — open questions, risks, and anything the next phase needs that has no other home.

## Publish

One tracker doc in the project's folder, linked on the DISC-2 task, task → `review`. That doc is the spec of record; if the project also keeps a file in `docs/`, it **points at the doc** rather than duplicating it — two copies drift, and the wrong one gets read.

Then the phase gate: the owner's sign-off. The cut (`marcus-slice`) starts from this document, not from the conversation that produced it.

---

**The test of a spec here:** an agent who has read no transcript can build from it. Every slice ticket links this doc by path, so nothing it needs may live only in the session that wrote it.
