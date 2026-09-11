<!-- Loaded on demand by the `marcus` skill. Core rules (§0–§4, §5–§11) live in
     ../SKILL.md and are already in context when this file is read. -->

## 4d. Mode `justflow` — work the night, hand back a morning of decisions

```
/marcus justflow            run until 07:00 local (default)
/marcus justflow 06:30      hard cutoff at 06:30
/marcus justflow 4h         hard cutoff in 4 hours
```

**The contract, in one line:** everything that does not need the owner gets done; everything that does need them arrives as a ClickUp task assigned to them, tagged, with the exact steps and commands to run. They wake up to decisions, never to homework.

**What this is not:** it is not permission to decide in their place. When the night hits a fork that is genuinely theirs — a product call, a design direction, a spend, an irreversible action — it stops that thread, writes the decision task, and moves to the next item. It never guesses to keep momentum.

### Running it

Start it with `/loop` so the session self-paces: `/loop /marcus justflow 07:00`. Prefer this over a cloud routine for one concrete reason — **the ClickUp MCP is an interactively-authenticated connector and may be absent in headless/cron runs**, and justflow's whole output is ClickUp tasks. If ClickUp is unreachable at any point, do not stop: write every pending task to `docs/handoffs/<date>-<CODE>-justflow-queue.md` — inside a wave, `docs/handoffs/<date>-<CODE>-wave-<n>-justflow-queue.md` — in the exact template below, and make the morning report say loudly that the queue is on disk, not in ClickUp.

Requirements before starting: laptop plugged in and awake, one clean `git status`, no half-finished worktree. If any is false, say so and do not start.

**Inside a wave.** When `docs/waves/[CODE]-plan.md` carries a wave claimed by this session (`wave.md` §`wave <n>`), justflow recomputes no frontier: it works that wave's tickets, in the plan's order, from `wave/<n>` — in that wave's own worktree, `.worktrees/wave-<n>`. Its queue and log are **wave-keyed** and committed on that branch, never on `[INTEGRATION_BRANCH]`: `docs/handoffs/<date>-<CODE>-wave-<n>-justflow-queue.md` and `docs/handoffs/<date>-<CODE>-wave-<n>-justflow-log.md`. Two waves running at once would otherwise write one another's file. Everything else below is unchanged, the eligibility rules included.

### Eligibility — what the night may touch

Work an item only if **all four** hold:

1. Its ClickUp blockers are `complete`, and its phase gate has passed.
2. It needs no gate to finish — nothing in it requires gates 1, 3, 4, 5, 6 or 8.
3. It is file-disjoint from every other item running tonight.
4. It can plausibly finish before the cutoff. Do not start what you cannot finish.

**Green — work these:** sanctioned DEV slices · bugs with a reproducer · 🟡 follow-ups from REV · i18n/copy already approved · migrations written but not applied (write only) · tests · handoff docs · ClickUp hygiene and reconciliation · audits and reports · preparing the next wave's tickets from an approved spec.

**Red — never at night, write the task instead:** anything needing push, PR, merge, prod apply, a paid key, DNS · new product behaviour not in the spec · design direction not signed off · deleting or rewriting anything you did not create · a fix whose cause you could not reproduce · a slice whose acceptance criteria are ambiguous.

**Amber — do the safe half:** if a slice is 80% unambiguous and 20% a question, build the 80%, commit it, and open a task at status `decision` for the 20%. Say in the commit what was left out.

### The night loop

Each round:
1. Recompute the frontier (one ClickUp read at the start of the night, then track state locally — do not re-poll per round).
2. Spawn up to **3 agents in parallel**, disjoint files, one worktree each.
3. Verify each return (§6), then **spawn linus on the slice diff before calling it done**. §6 + Linus green → local `review` state. Fail either → one retry with the exact failure; a second failure → `blocked`, write the task, move on.
   *A slice the owner has to review because no agent did is exactly the homework this mode exists to remove. Linus is read-only and cheap — never skip him to fit more slices into the night.*
   **Stage 2 is polo, and it runs once — per wave, never per round.** Inside a wave: `wave.md` §`wave close <n>` step 3. Outside one: over the night's accumulated `review` slices as a single diff, before the handback. Advisory here as in every mode but `ultraflow` — a `NO-GO` becomes a `decision` task carrying his reasons and a recommended fix slice, and nothing is merged either way.
4. Batch anything owner-facing into the queue; do not write to ClickUp yet.
5. Log one line per event to `docs/handoffs/<date>-<CODE>-justflow-log.md` — inside a wave, `docs/handoffs/<date>-<CODE>-wave-<n>-justflow-log.md`. This is the audit trail — it must let the owner reconstruct the night without reading a transcript.
6. Next round. Stop per below.

### Stop conditions — any one of these ends the night

- The cutoff time is reached (mid-flight agents finish; nothing new starts within 30 min of cutoff).
- Two consecutive rounds produce nothing new — the frontier is dry.
- The frontier contains only red items.
- Any build/test failure you cannot diagnose in two attempts, on `[INTEGRATION_BRANCH]` itself rather than a branch.
- Anything at all looks destructive or irreversible. **Stop the whole night, notify, do not continue.**

### The handback — ClickUp tasks the owner actually wants to find

At the end of the night, in **one batch** (rate limit), create the tasks. Two shapes and no third (`../SKILL.md` §7): an **ACTION** he executes — status `to do`, tag `ready-for-<owner>` — and a **DECISION** only he can make — status `decision` **and** tag `decision`, opened as a subtask (`parent`) of the ticket it unblocks, id `….D<n>`. Both assigned to him with `config.tracker.ownerUserId`. Each tag needs to exist in the workspace — create it once, then reuse.

**What happens next is the handshake, and the night does not finish it.** He moves a decision to `accepted` or `declined` and answers in a comment; the next `/marcus resume` executes what he accepted and closes it. You never set either status yourself — `../SKILL.md` §7 step 2 is the whole reason this mode can run unattended and still leave nothing decided behind his back.

**Template — ACTION**, tag `ready-for-<owner>` (title: `[CODE]-[PHASE]-[NUM].[N] — <verb + object>`)

```markdown
## Ce que tu dois faire
<one sentence, in the owner's terms, not the system's>

## Pourquoi c'est toi
<push / merge / prod apply / paid key / DNS — the owner-only reason, one line>

## Étapes
1. <action>
   ```bash
   cd <absolute path>
   <exact command, copy-paste ready>
   ```
   Attendu : <what success looks like, verbatim if it prints something>
2. …

## Si ça casse
<the single most likely failure> → <the fix>

## Contexte vérifié
- Branche(s) : `feat/…` (`<sha>`, auteur = le propriétaire, 0 trailer)
- Vérifs : build ✓ · tsc 0 · eslint 0 · merge-tree 0 conflit · scope respecté
- Migrations : <ordre d'apply, ou "aucune">
- Tickets liés : <ids>
- Écrit par justflow <date>
```

**Template — DECISION**, status `decision` + tag `decision`, subtask of the ticket it unblocks (title: `[CODE]-[PHASE]-[NUM].D<n> — Décision : <the question>`)

```markdown
## La décision
<the question, one sentence, answerable>

## Options
| Option | Conséquence | Coût si on revient en arrière |
|---|---|---|
| A … | … | … |
| B … | … | … |

## Ma recommandation
<one option, with the reason in one sentence>

## Ce qui attend
<what is blocked until this is answered — ticket ids, or "rien, mais ça se dégrade si on attend">

## Ce que j'ai fait en attendant
<the safe 80%, or "rien">
```

Rules for both: one task per decision or action, never a digest task with six things in it. Both bodies keep their five section headings, in the order written above — the owner reads them in that order every morning and skips straight to the one he needs. Every command absolute and copy-paste ready — no `<fill this in>`. If a step cannot be reduced to a command, say exactly which button, in which UI, on which page.

### The morning report

One handoff doc `docs/handoffs/<date>-<CODE>-justflow.md` — what ran, what landed, what is in review, what is waiting on the owner, what broke. The report's **last** block is the owner's task block (`../SKILL.md` §10): every task the night just created, as clickable links. Then **one** `PushNotification`, one line: *"justflow: N slices en review, M décisions t'attendent."* Nothing else pings during the night. A pipeline that wakes the owner at 03:00 to say it is fine has failed.

### Hard limits

- Max 3 concurrent agents. Max 2 retries per item. Never start within 30 min of cutoff.
- Never push, merge, apply prod, rotate a key, or send anything outward. Unchanged, all night.
- Never edit a file outside a spawned agent's scope fence yourself.
- Never mark ClickUp `complete` — only the owner's merge does that.
- Every commit stays one-slice, owner identity, no trailer. The night does not lower the bar; it only removes the waiting.

---
