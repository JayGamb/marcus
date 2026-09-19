<!-- Loaded on demand by the `marcus` skill. Core rules live in ../SKILL.md
     and are already in context when this file is read. -->

# UI research — benchmark, then adapt

```
/marcus research les meilleurs CRM, pour l'UX de notre back-office
/marcus research onboarding SaaS --surfaces "signup, first-run, empty state"
/marcus research dashboards de commandes --report-only
```

## The rule that makes this useful instead of harmful

**Steal the reasoning, never the look.** A pattern is worth taking when you can say *what problem it solves for which user under what constraint*. Copying a competitor's visual language produces exactly the generic, AI-looking result `docs/DESIGN.md` bans — and it would fail the slop test on arrival.

So the deliverable is never "here are five screenshots, let's look like this". It is: **this is the job, this is how serious products solve it, this is the one worth adopting and what it costs us.** Dieter then rebuilds it in our system, from our tokens.

Call `marcus-voice`. Report in **English**; keep product names and quoted UI copy verbatim.

---

## Phase 1 — Frame the job before looking at anything

Looking first is how you end up with a mood board instead of an answer.

1. **Name the job to be done**, in our users' terms, not the category's. "CRM" is not a job. "The shop owner scans twenty incoming orders and finds the three that need action today" is.
2. **List the surfaces** that carry that job — list, detail, bulk action, filter, empty state, error, mobile. If the owner passed `--surfaces`, use that list. These are the comparison axes, fixed *before* research so every reference is judged on the same thing.
3. **State our constraints** from `docs/project-overview.md` and `docs/DESIGN.md`: who the user is, on what device, how often, and what our system already commits to (tokens, radius, type scale, motion budget, banned patterns). A pattern that needs a component library we do not have is a cost, and it gets recorded as one.

Say the job and the surfaces back to the owner in two lines before researching. A wrong frame wastes the whole pass.

## Phase 2 — Choose references deliberately

**4 to 6, no more.** Beyond that the report stops being read.

- 2–3 **category leaders** — what the user's expectations are already shaped by
- 1 **craft outlier** — a product known for design quality, even if smaller
- 1 **adjacent category** solving the same job differently — this is where the non-obvious idea comes from
- optionally 1 **deliberate counter-example** — something popular and bad, to name what to avoid

Justify each pick in one line. "It's famous" is not a reason.

## Phase 3 — Look, honestly

Use `WebSearch` and `WebFetch`, and `claude-in-chrome` to open what is publicly reachable. **Prefer what you can actually see** over what you remember — product UIs change, and memory of a UI is unreliable in a way memory of an API is not.

**Say what you could not see.** Most serious product UI sits behind a login, and marketing screenshots are idealised: they show three perfect rows, never the ninety-row Tuesday. When a surface is not publicly reachable, your sources become public docs, design-system pages, changelogs, review-site screenshots and walkthrough videos — and you label that evidence as second-hand. **A benchmark that hides its blind spots is worse than none**, because the team will act on it as if it were observed.

Per reference and per surface, record:
- **what the screen does** — the actual mechanic, not the aesthetic
- **the pattern** — named plainly (inline edit, split view, command palette, saved views, optimistic status change)
- **what it solves** and **what it costs** (density vs scannability, speed vs discoverability, power vs onboarding)
- **what would break if we copied it** — our data shape, our volumes, our mobile-first constraint, our token system

## Phase 4 — The report

```markdown
# Recherche UI — <catégorie> · <date>

## Le job
<une phrase, en termes de nos utilisateurs> · Surfaces comparées : <liste>

## Références
| Produit | Pourquoi celle-là | Ce que j'ai vu de mes yeux | Ce qui est de seconde main |

## Inventaire par surface
| Surface | A | B | C | D | Ce que ça résout |

## Ce sur quoi tout le monde converge
<= les attentes de l'utilisateur. S'en écarter demande une raison, pas un goût.>

## Là où ils divergent — donc là où il y a un vrai choix
<par divergence : les options, ce que chacune coûte, ce qu'elle suppose de l'utilisateur>

## Anti-patterns observés
<ce qui est répandu ET mauvais, avec pourquoi>

## Ce que je recommande d'adopter
<3 maximum. Par pattern : le problème qu'il résout chez NOUS · ce qu'il coûte ·
 ce qu'il tend dans DESIGN.md (nouveau token ? nouveau composant ? motion ?) · l'effort>

## Décisions qui t'attendent
<par décision : la question · les options · ma recommandation, avec la raison>

## Ce que je n'ai pas pu vérifier
<les surfaces derrière un login, les captures marketing, ce qui a peut-être changé depuis>
```

Three adoption candidates maximum. A report recommending nine patterns has not made a judgement; it has deferred it to the owner.

**Stop here if `--report-only`.** Otherwise the report goes to Marcus for filing, in the two handback shapes and never one task for both (`../trackers/README.md` §Handback): one `DESI` ticket per adopted pattern · **one HAND ACTION task** assigned the owner, status `to do`, tagged `ready-for-<owner>`, carrying the report · and **one `.D<n>` subtask per open choice**, parent = the ticket it unblocks, status `decision` **and** tag `decision`. An action is executed, a decision is answered — they do not close the same way.

## Phase 5 — Hand to Dieter (after the owner picks)

Spawn **dieter** with the approved patterns. His brief:

> Adapt these patterns to `<surface>` from `docs/DESIGN.md` and the tokens in `src/index.css`.
> **Take the structure and the interaction. Take nothing of the reference's visual language** — not its palette, not its type, not its density, not its motion.
> Where a pattern needs something our system does not have, that is a decision for the owner, not a new token you invent.
> Then the normal `/marcus dieter` Phase B lane: `adapt` → `polish` → slop test → 390/1024/1280/1440 px, FR and EN.

**The slop test is the gate on the way out.** A pattern borrowed from a well-known product and rendered in our tokens can still read as generic — if it does, it failed, however respectable the source.

## Boundaries
- Research is read-only. No product code in phases 1–4.
- Never present a competitor's copy as ours; quote it as a quote.
- Never recommend a pattern you did not see solving the job — "X probably does this" is not a finding.
- Never let the number of references grow to look thorough. Six well-read beats fifteen skimmed.
- Do not recommend adopting our current design's opposite because it is novel. Novelty is not a user benefit.
