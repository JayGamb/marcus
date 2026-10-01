# Evaluation memo — the template

> Installed with the `marcus` skill. `/marcus evaluate "<idea>"` (`../modes/evaluate.md`) fills this in and writes the result to `docs/evaluations/<YYYY-MM-DD>-<slug>.md`, with the four lane reports beside it in `docs/evaluations/<YYYY-MM-DD>-<slug>/`.
>
> **The memo is what the owner reads; the lane reports are what it stands on.** It links them and never pastes them — four reports inlined is a document nobody finishes, and the whole reason the reports are files is that this one can stay short enough to read in a sitting.
>
> **It is also what `/marcus new` inherits.** Every field below is read again, months later, by a session that was not there. A field filled with an impression instead of a finding will be read as a finding.

## How to use it

1. Copy the skeleton into `docs/evaluations/<YYYY-MM-DD>-<slug>.md` — that exact path, every time.
2. **Only write this file when a verdict was reached.** An aborted run — two or more lanes blocked, or no synthesis (`../modes/evaluate.md` §3) — writes **no memo at all**, and this template deliberately offers no `ABORTED` or `NOT RUN` value. The file's existence *is* the claim that four lanes ran and a verdict was rendered; a memo with `—` in its verdict slot gets read as a memo six months later, whatever its header says. An aborted run's trace belongs on the backlog card.
3. Fill **every** field. A field that does not apply is `—`; a check that could not be run is `could not check`, never a blank and never an optimistic guess. A blank reads as "fine" to the next reader, and that is the one thing it never means.
4. The **scorecard has no total.** No numeric headline score, no average, no 1–10 — the mode's rule, not a stylistic one (`../modes/evaluate.md` §4).
5. Cost is logged **as measured**, including an overrun. The ≤ 700K target is how the owner learns what an evaluation is worth to him; a smoothed number teaches him nothing.
6. The memo is the card's companion, not its replacement: the verdict also goes on the backlog card as a comment, and the card's status stays the owner's (`../modes/evaluate.md` §6).

---

## The skeleton

````markdown
# Évaluation — <nom de travail de l'idée> · <YYYY-MM-DD>

Slug: `<slug>`   Verdict: **<GO | PIVOT | KILL>**
Backlog card: <url — ou `— (tracker unreachable at <heure>; card not created/updated)`, jamais vide> — status at write time: `in evaluation`
Run by: session <id, or `no-session-id` where it is genuinely unreachable — never a guess> · <YYYY-MM-DD>
Supersedes: <the memo this re-run follows after a `pivot`, by path — or "none, first evaluation">

## L'idée

<One sentence: the thing that would exist, for whom, replacing what they do today.
 The owner's own words where they were already clear — this is not the place to improve them.>

## Les quatre lanes

| Lane | Rapport | Ce qu'elle a trouvé, en une ligne | Solidité |
|---|---|---|---|
| Competition | `docs/evaluations/<YYYY-MM-DD>-<slug>/competition.md` | <the one finding that matters> | <observé · second-hand · rien trouvé> |
| Demand | `docs/evaluations/<YYYY-MM-DD>-<slug>/demand.md` | … | … |
| Feasibility | `docs/evaluations/<YYYY-MM-DD>-<slug>/feasibility.md` | … | … |
| Wedge + name | `docs/evaluations/<YYYY-MM-DD>-<slug>/wedge-and-name.md` | … | … |

### Ce qu'aucune lane n'a pu établir
<Named, not omitted. Each line: what we wanted to know · why it was not reachable · what would settle it.
 These become DISC's open questions if this ever becomes a project.>

## Verdict — Polo

### Scorecard
<No total. No average. No score out of anything.>

| Axe | Lecture | L'évidence derrière |
|---|---|---|
| Demande | <strong \| mixed \| weak \| unknown> | <one line, with its source> |
| Concurrence | … | … |
| Faisabilité | … | … |
| Wedge | … | … |
| Pourquoi nous | … | … |

### Les 3 hypothèses les plus risquées
<Exactly three: the ones that, if false, make the whole thing worthless.>

| # | L'hypothèse | Le test le moins cher qui la tranche | Ce qu'il coûte |
|---|---|---|---|
| 1 | <if this is false, nothing else matters because …> | <the cheapest thing that settles it> | <hours / CHF> |
| 2 | … | … | … |
| 3 | … | … | … |

### Kill criteria — brouillon
<Written now, while nobody is attached to the idea — the only moment they are honest.
 Each one: the condition, the date or the number at which it fires, and what happens then.
 `/marcus new` inherits these at DISC-1.>

### Verdict: <GO | PIVOT | KILL>
<The reasons, in the order that decided it. On a PIVOT: the specific angle to re-evaluate —
 a pivot that names no new angle is a KILL nobody wanted to write.
 GO is not available over an unknown Demande or Concurrence row: that is a PIVOT.
 Never KILL on absence of evidence alone — an unread market is not an empty one.>

## Le nom

Proposé: **<name>**   CODE proposé: `<CODE>`

| Candidat | .com | .ch | .io | App stores | GitHub | npm | Marque (proxy) | CODE libre |
|---|---|---|---|---|---|---|---|---|
| <candidat 1> | <libre \| pris par X \| could not check> | … | … | … | … | … | <registre consulté — proxy, pas une clearance> | <oui \| collision: [CODE] existant> |
| <candidat 2> | … | … | … | … | … | … | … | … |
| <candidat 3> | … | … | … | … | … | … | … | … |

<One line on why the proposed one wins over the other two.>

## Coût de cette évaluation

| Poste | Tokens |
|---|---|
| Lane Competition | <n>K |
| Lane Demand | <n>K |
| Lane Feasibility | <n>K |
| Lane Wedge + name | <n>K |
| Synthèse (Polo) | <n>K |
| **Total** | **<n>K** — cible ≤ 700K · <dans la cible \| dépassement de <n>K, raison: …> |

## Ce que `/marcus new` hérite d'ici

| Ce qui passe | Où ça atterrit |
|---|---|
| Le problème, l'ICP, les 3 vrais noms | DISC-1 — l'interview part de preuves, pas de mémoire |
| Le wedge et le hook | Le spec — la seule chose qu'on ne dérive pas d'une liste de features |
| Les 3 hypothèses risquées + leurs tests | Les premières slices — la plus risquée est le premier tracer bullet |
| Les kill criteria (brouillon) | DISC-1, à confirmer par le propriétaire |
| Le nom + le CODE | `config.code`, verrouillé pour la vie du projet |
| Ce qu'aucune lane n'a pu établir | Les questions ouvertes que DISC doit fermer |

**Rien ne démarre depuis ce mémo.** La carte passe à `approved` sur la parole du propriétaire, et
`/marcus new` se lance depuis la carte — jamais depuis ce fichier.
Ce passage de relais est **piloté par le propriétaire** : aucun mode ne balaie cette liste aujourd'hui.
````

---

## Field reference

**Verdict, in the header and again in full.** It is in the header because the owner reads the first six lines of a memo and decides whether to read the rest, and in full below because a verdict with no reasons is a mood. The two must say the same word. **The floor applies to both:** a `GO` requires the Demande and Concurrence rows of the scorecard above to read anything but `unknown` — over an `unknown` on either the verdict is `PIVOT`, whose angle is the cheapest test that would make that row known (`../modes/evaluate.md` §4). **And never `KILL` on absence of evidence alone** — an unread market is not an empty one: that is a `Solidité` of `rien trouvé` below, not a verdict. The header is the line the owner reads first, so a `GO` written there over an `unknown` row is the hole he will never see. **There is no fourth value:** a run that could not gather its evidence writes no memo at all (`../modes/evaluate.md` §3), so every file that exists carries one of the three.

**Backlog card.** A url, or the explicit unreachable note — never blank and never an invented id. A memo whose run could not write its card is still a valid memo (`../modes/evaluate.md` §2, *When the tracker is denied or unreachable*); what is not valid is a memo that leaves the reader unable to tell whether a card exists.

**Supersedes.** A `pivot` sends the card back to `to evaluate`, and the re-run writes a **new** memo at a new date — it never edits the old one. This line is the chain: what was tried, and what the new angle is. `none` at the first evaluation.

**Solidité.** Three values, and they are not decoration: `observé` (the lane saw the thing itself), `second-hand` (docs, reviews, a changelog, someone's write-up), `rien trouvé` (the search ran and returned nothing). An empty lane is a result. What is never allowed here is an absence dressed as a negative finding — *"nobody is doing this"* is `rien trouvé` until a lane proves the absence.

**Ce qu'aucune lane n'a pu établir.** The section that makes the memo trustworthy. A memo that hides its blind spots is worse than none, because the next session acts on it as if it were complete. Anything behind a login, a paywall, a private register, or a market nobody writes about publicly goes here.

**Scorecard — why there is no number.** A headline score invites arithmetic on judgements that do not add, and it lets one `weak` row hide inside a respectable average. Five rows, five words, five pieces of evidence: the reader forms the aggregate, which is the part only a human should do. `unknown` is a legitimate value and appears whenever the lane came back thin — it is not a polite `weak`.

**Pourquoi nous.** The row that has no lane, and the one that kills most ideas honestly: a real market with real demand that anyone could serve better than us is still a `KILL`. It is filled from the wedge lane and from what the team actually is.

**Les 3 hypothèses risquées.** Exactly three, each with the **cheapest** test — a landing page, ten calls, one afternoon against an API, one legal question to one lawyer. A list of every risk is not a judgement, and a test that costs a month is not a test, it is the project.

**Kill criteria.** Drafted here, confirmed by the owner at DISC-1, never invented later — after a month of building, nobody writes an honest stopping condition. Each one carries a number or a date, or it is a sentiment.

**Le nom.** Every box is filled before a candidate is proposed. `could not check` is a legitimate result and is written as one; a blank would read as free. The trademark column is explicitly a **proxy** — a public-register search, not a clearance, and the memo says so where a reader could mistake it for legal advice. The `CODE libre` column is the tracker collision check, run by Marcus, not by the researcher (`../modes/evaluate.md` §3b).

**Coût.** Per lane, plus the synthesis, plus the total against the target. An overrun is written with its reason. This table is the only place the plugin learns what its own research costs.

**Ce que `/marcus new` hérite.** The contract between this mode and the next one. If a row here is `—`, the project starts without it — which is a fine outcome, as long as it is written down rather than discovered at DISC-2.
