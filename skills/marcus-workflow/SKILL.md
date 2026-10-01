---
name: marcus-workflow
description: "The shape of the Marcus delivery system, readable on its own: the seven-phase pipeline, the four-check review chain, the human gates, the worktree and one-commit contract, the checkpoint rule and the tracker-as-memory rule. Load it when you are working inside a Marcus run without the orchestrator's SKILL.md in context — a spawned agent, a reviewer, or anyone asking who decides what. Structure only; every procedure lives at a path this file points to."
---

# Marcus workflow

Derived from `docs/WORKFLOW.md`, which is the full report. This is the **shape**: enough to act correctly without the orchestrator in context. Where a detail belongs somewhere else, this file gives you the path rather than a second copy that can drift.

Names in this file: **the owner** is `marcus.config.json` → `config.owner` — the one human, and the only holder of the remote.

---

## 1. Who exists

| Who | Role | Where |
|---|---|---|
| **Marcus** | Orchestrator. Slices work, spawns agents, verifies returns, tracks the queue, hands off. **A skill the main session adopts, not an agent** — an orchestrator has to hold state across the run, and a subagent gets one context and dies. | `skills/marcus/SKILL.md` |
| **Polo** | Chief of Staff. **Stage 2 gate** — the final GO / NO-GO on the owner's bar. Reports to the owner, not to Marcus. | `agents/polo.md` |
| **Linus** | CTO. **Stage 1** — correctness, security, contracts, tests. Read-only on product code; writes docs and ADRs only. | `agents/linus.md` |
| **Ada** | Backend — schema, migrations, RLS, `SECURITY DEFINER` RPCs, Edge Functions, the API layer. | `agents/ada.md` |
| **Neo** | Full-stack — pages, components, routing, i18n, API wiring. Implements the design; does not invent it. | `agents/neo.md` |
| **Dieter** | Design — `DESIGN.md`, tokens, prototypes, microcopy, a11y, the slop test. | `agents/dieter.md` |
| **Kira** | DevOps — hosting, CI, env vars, headers, domains, the provisioning wizards. | `agents/kira.md` |
| **Magellan** | Research — one open-web lane per spawn, for `/marcus evaluate` only. Three tools; no `Read`, no shell, no MCP — credentials on disk out of reach, but the injected context still carries the owner's identity and a fetch URL is a wire, so private data and outbound stay **narrowed, not cut**. Returns evidence, never a verdict. | `agents/magellan.md` |

Chain of command: **owner → Marcus → Linus → Ada · Neo · Dieter · Kira.** **Polo sits outside that line**, which is the only reason his gate is worth anything once the owner steps away.

## 2. The pipeline

Seven phases, one queue list each, strictly sequential. A phase's gate unlocks the next.

```
DISC → ARCH → DESI → DEV → QA → REV → HAND
```

| # | Phase | Who | Gate |
|---|---|---|---|
| 0 | Discovery | Marcus + owner | spec + tickets published (build tickets land in `DEV`, never `DISC`) |
| 1 | Architecture | Linus | ADRs written, contracts locked |
| 2 | Design validation | Dieter | variant picked, slop test passed |
| 3 | Implementation | Neo · Ada · Kira | all acceptance criteria implemented |
| 4 | QA | Linus | every criterion verified in a browser |
| 5 | Review | Linus → Polo | Stage 1 clear, then Stage 2 `GO` |
| 6 | Handoff & ship | Marcus | handoff written, PR ready |

Per-phase procedures: `skills/marcus/SKILL.md` §4. Modes (`evaluate · new · resume · status · reset · client · justflow · prototype · ultraflow`): §2 and `skills/marcus/modes/`. A slice may skip a phase it genuinely does not need — but it says so out loud; it never skips one quietly.

## 3. The review chain

```
neo/ada self-review → local commit
  → Marcus §6        compliance: author · no trailer · scope · merge-tree · build
  → Linus Stage 1    correctness · security · contracts · tests
  → Polo  Stage 2    intent · DESIGN.md + slop test · prod safety · scope
  → merge
```

Four checks, not interchangeable.

- **Marcus §6 is not a code review.** It proves the agent respected its contract — right identity, no trailer, inside the fence, tree merges, build green. It says nothing about whether the code is right. Detail: `skills/marcus/SKILL.md` §6.
- **Linus, Stage 1**, returns ordered findings on the 🔴 / 🟡 / 💭 ladder. He does not patch what he reviews: reviewing and fixing in one pass destroys the second opinion.
- **Polo, Stage 2**, renders `GO` or `NO-GO` on intent — is this what was actually asked for.
- **Neither reviewer can be overruled by whoever is shipping.** **Marcus cannot overrule a `NO-GO`**; nor can the agent that wrote the code. A `NO-GO` is lifted only by fixing what it names and re-running Stage 2, or by the owner — Polo reports to the owner, which is what puts him out of Marcus's reach.

**Who merges:** the owner, at gate 7 — Marcus and every agent stop at `review`. The single exception is `/marcus ultraflow` on a repo the owner has armed, where Marcus merges into the **integration** branch himself and Stage 2 still runs. The production branch and production database are never in that exception.

## 4. The human gates

**The grid the gates come from.** A gate is a control sized to what the action costs to undo, and **a new action inherits its control from its level** rather than from precedent:

| Level | The action | Control |
|---|---|---|
| **L1** | read — files, logs, schema, a deploy under test | none. Log it and move on. |
| **L2** | reversible write — a commit on a feature branch, a doc, a ticket, a worktree | light: Marcus's §6 compliance check |
| **L3** | external impact, still undoable — a branch deploy, an env var, a short-TTL DNS record, a tracker write the owner will read | Linus reviews before it lands |
| **L4** | **irreversible** — push, merge, production apply, delete, spend, a rights or key change, anything a third party sees and keeps | Stage 1 + Stage 2, then **the owner**. Never an agent's, in any mode. |

An action genuinely between two levels is the higher one. Detail: `skills/marcus/SKILL.md` §3.

Nine places the run stops: 1 intake (name + code) · 2 provisioning wizard · 3 **grilling** — the one long human moment · 4 ticket granularity · 5 ARCH go · 6 DESI variant + sign-off · 7 merge per wave · 8 QA ok · 9 ship, integration → production. Between gates Marcus loops on his own. In `ultraflow`, gate 7 disappears; the rest do not.

## 5. Isolation and the commit contract

**One worktree per agent.** `.worktrees/<CODE>-<slice>`, branch `feat/<CODE>-<slice>`, cut from the integration branch. Each agent gets a **file fence** — no two concurrent agents touch the same file. Dependent slices stack, and the base merges first. Needing a file outside the fence means the slice was cut wrong: stop and say so, never widen quietly.

**One slice, one local commit**, and every clause of this is load-bearing:

- committed **locally only**, under the **owner's git identity**
- **no AI co-author and no "Generated with" trailer** — a `commit-msg` hook strips them
- build, typecheck and lint **green before** the commit, not after
- **never** push, open or merge a PR, `reset --hard`, `clean`, delete an unmerged branch, rewrite pushed history, or apply a production migration

**One carve-out, and only one:** in `/marcus ultraflow`, on a repo the owner has armed, Marcus may push `feat/**`, open PRs and merge into the **integration** branch — never the production branch, never a production migration.

Enforcement is `hooks/block-dangerous-git.sh`, a PreToolUse hook with two tiers. Disarmed, every remote operation is blocked. Armed — the owner creating `.claude/.ultraflow`, an empty file whose *existence* is the signal — `feat/**` pushes and PR create/merge open up, while force-push, history rewrite, `reset --hard`, `clean`, branch deletion, anything targeting the production branch, and production database pushes stay blocked in **every** mode.

**Arming is the owner's alone.** No agent creates, deletes or edits that file, and no agent modifies, disables or works around a guardrail — the hooks, the hard rules, or the mode file that grants them. An agent that can edit its own restraints has none. A guardrail blocking legitimate work is a decision for the owner, not a file to edit.

Two things worth knowing about the net: the hook is **per project** — it runs only where it is installed *and declared in that repo's `.claude/settings.json`* — and on a private repo without a paid plan there is **no branch protection**, so during an armed run the hook, the rules, Linus and Polo are the only controls. There is no server-side backstop. Detail: `docs/WORKFLOW.md` §6.

## 6. The checkpoint

**The context window is a working buffer, never the memory.** The memory is the tracker plus the repo docs plus `docs/handoffs/`.

The rule — when to checkpoint and why — lives once in **`~/.claude/CLAUDE.md` → "Context budget"**, loaded in every session. The orchestrator's share is `skills/marcus/SKILL.md` §12; the procedure is the **`marcus-checkpoint`** skill, which the orchestrator runs on its own trigger, and `/marcus relay` is the manual override. Nothing important may live only in a transcript.

For a spawned agent this cashes out as one habit: **report compact.** Your transcript never reaches the orchestrator's window — only what you return does, and that gets paid for again on every turn after. Reference by path, never paste a file back.

## 7. The tracker is the queue

Every to-do is a task. **If it is not a task, it does not exist.** Every agent prompt carries the task's code, id and URL.

A ticket must be actionable by an agent who has read no transcript, so it carries its own state: what to build end to end · acceptance criteria · blocked-by · links to ADR, spec, `DESIGN.md`, handoff **by path**, never pasted.

Delivery is not finished when the code works. It is finished when the ticket carries a **handoff comment** — what was built, commit SHA + branch, what was verified with what it printed, what is left or waits on the owner, signed on its last line `— <Agent> · <mode> · session <id> · <YYYY-MM-DD>` — and its status moved to `review`. Those comments go out **in one batch at the checkpoint**: ClickUp's budget is 300 calls per rolling 24 h window, shared across every session and project, and spending it locks out every session until that window rolls.

## 8. Blocked

A task needing a live credential, a decision only the owner can make, or a file outside its fence **stops and returns a blocker** — with a proposed solution, never a bare problem. Escalating costs one message; a wrong assumption built out costs the slice. Decisions that are not written are not decided.

## 9. Where to look next

```
docs/WORKFLOW.md            the whole system, and what is proven vs never run
skills/marcus/SKILL.md      the orchestrator: §4 phases · §6 verification · §9 handoff · §11 hard rules · §12 budget
skills/marcus/modes/        the heavy modes, loaded on demand
skills/marcus-checkpoint/   the checkpoint procedure
skills/marcus-guidelines/   the coding discipline · skills/marcus-voice/ the reporting voice
agents/*.md                 the seven spawnables
hooks/                      the brakes — per project, and inert unless declared
~/.claude/CLAUDE.md         the standing rules, loaded in every session
```
