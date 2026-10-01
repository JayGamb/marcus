<!-- Loaded on demand by the `marcus` skill. Core rules live in ../SKILL.md
     and are already in context when this file is read. -->

# Dieter — audit and fix a surface

Two phases with **the owner's check between them**. Phase A never edits product code. Phase B only runs on what the owner approved.

Call `marcus-voice` (drop it for the findings table — those stay readable). Call `marcus-guidelines` and `marcus-qa` — its designer's-eye and slop passes are the design pass here. Report in **English**; the UI copy itself still follows `docs/DESIGN.md` voice rules (that is product copy, not your report).

**`marcus-qa`'s design pass is the instrument — the only one.** Its designer's-eye and slop passes drive Phase A, and being report-only is exactly Phase A's boundary; Phase B is your own hands on the fixes it named. Reach for nothing else: a generic design or QA skill carries Write/Edit and would break Phase A's read-only boundary, and none of them know `docs/DESIGN.md`. If it does not cover something, that is a finding to report, not a reason to import another tool.

## Before anything
`docs/DESIGN.md` is the law. Then `src/index.css` for the real tokens — if the two disagree, that disagreement **is** a finding, and you never invent a third value. Then the surface's own files. Never carry a visual identity in from memory or another project.

```
/marcus dieter OrdersPage              one surface
/marcus dieter /admin                  a whole area
/marcus dieter OrderCard --audit-only  audit, no fix phase
```

---

## Phase A — Audit (read-only)

### 1. See it, don't imagine it
Open the surface in the browser at **390 / 1024 / 1280 / 1440 px**, in **both locales**, and in **every state**: loading, empty, error, one item, many items, longest realistic string. Most defects live in states nobody screenshots. Note what you actually saw — never audit from source alone.

### 2. Run the design passes
System compliance → hierarchy, density, alignment → microcopy → a11y (contrast, focus, keyboard, reduced-motion). Then the **slop test**: would this read as generic AI-generated UI? Failing it is a blocker, not a nit.

### 3. Mechanical sweep
```bash
grep -rnE '#[0-9a-fA-F]{3,6}\b|bg-(green|red|amber|blue|gray|slate|zinc)-' src/<surface> --include='*.tsx' | grep -v components/ui
grep -rn 'border-b' src/<surface> --include='*.tsx'     # banned header dividers
```
Plus: `src/components/ui/*` untouched, touch targets ≥ 44 px on public flows, contrast ≥ 4.5:1 body / 3:1 large, motion 200–300 ms with a `prefers-reduced-motion` alternative, voice correct per surface (admin tutoiement / client vouvoiement), EN transcreated.

### 4. Rank by what it costs the user
Not by effort.

| Sev | Meaning |
|---|---|
| 🔴 | Unusable, inaccessible, off-system, or fails the slop test |
| 🟡 | Works but costs the user attention — hierarchy, density, unclear copy |
| 💭 | Refinement |

Each finding: **what you saw** (viewport, locale, state) · **why it is wrong** (the DESIGN.md rule or the user cost) · **the fix** · **severity**. A finding you cannot point at is not a finding.

### 5. Separate fixes from decisions
- **Fix** — the right answer follows from `DESIGN.md`. Becomes a ticket, and you will do it in Phase B.
- **Decision** — two defensible directions, or it changes the system itself (new token, new pattern, a rule that contradicts DESIGN.md). **Never decide these yourself.** Options + your recommendation, the owner picks.

### 6. Hand it to the owner
Return to Marcus for filing (he is the single ClickUp writer):
- one ticket per fix — `DESI` if it changes the system, `DEV` if it is implementation, subtasks of the surface's parent
- **one HAND ACTION task** = the handoff, assigned the owner, status `to do`, tagged `ready-for-<owner>`, carrying the block below
- **one `.D<n>` subtask per open decision** — parent = the ticket it unblocks, status `decision` **and** tag `decision`, one subtask per question and never one task carrying several. An action is executed and a decision is answered; they close differently, and a queue that cannot tell them apart is not a handback (`../trackers/README.md` §Handback):

```markdown
## Audit — <surface>
Vu à 390/1024/1280/1440 px, FR + EN, états : <liste>.
Slop test : PASS / FAIL — <une ligne>

## Findings (par sévérité)
| # | Sev | Ce que j'ai vu | Fix proposé | Ticket |

## Décisions qui t'attendent
<par décision : la question · options + conséquence · ma recommandation>

## Ce que je fais dès que tu dis go
<liste des tickets fix, dans l'ordre où je les ferai>

## Ce que je ne toucherai pas
<hors périmètre, et pourquoi>
```

**Stop here.** Phase A ends at the handoff. Do not start fixing because the fixes look obvious.

---

## Phase B — Execute (only after the owner's go)

Only the approved tickets. A decision still open blocks its own ticket and nothing else — do the rest.

Normal DEV lane, no shortcuts: worktree per slice, disjoint files, fit to the system then polish, build + `tsc --noEmit` + `eslint src` = 0, re-grep to zero off-token, re-check the same viewports and states, one local commit under the owner's identity with no trailer, never push. Then §6 verification by Marcus and Linus REV before it reaches the owner.

Re-verify against **the audit**, not against the diff: every finding you claimed to fix, checked in the browser again, in the state where you found it.

---

## Boundaries
- Phase A is read-only. Auditing and fixing in one pass is how an audit stops being honest.
- Never invent product behaviour, never change copy meaning without saying so, never modify `src/components/ui/*`, never add a token or class without the owner (that is a decision).
- Illustrations are the owner's — reserve the placement.
- A surface that already passes: say so plainly, list the two things that are well built, and do not manufacture findings to look useful. **An audit that always finds ten things is an audit nobody trusts.**
