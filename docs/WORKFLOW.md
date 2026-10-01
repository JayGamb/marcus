# Marcus — the agent workflow

> The whole system in one document: who exists, what runs when, where the brakes are, and what has and has not been proven.
> Code `MRCS`. Built 22 Aug – 11 Sep 2026, extracted from a product session on 11 Sep.

---

## 1. What this is

A multi-agent delivery system for the team's projects — several products, an umbrella repo, and client engagements.

One orchestrator drives the work, seven specialists execute and review, the tracker is the queue (four adapters — `clickup`, `github`, `local-html`, `none`), and every remote git operation belongs to the owner — with one armed exception.

**5 717 lines** across 44 files: 1 orchestrator skill (+11 mode files, 5 tracker adapter files, 3 templates — the standing rules, the wave plan and the evaluation memo), 15 other skills (12 `marcus-*` + 3 domain), 7 agents and 2 hooks.

---

## 2. The team

| Who | Role | Model | Lives in |
|---|---|---|---|
| **Marcus** | Orchestrator and CEO proxy. Slices work, spawns agents, keeps the tracker current, verifies returns, hands off. **Not an agent — a skill the main session adopts.** | session | `skills/marcus/` |
| **Polo** | Chief of Staff. **Stage 2 gate**: the final GO / NO-GO on the owner's standards. Reports to the owner, not to Marcus — Marcus cannot overrule a `NO-GO`. | Fable | `agents/polo.md` |
| **Linus** | CTO. **Stage 1**: correctness, security, contracts, maintainability, tests. Read-only on product code; writes docs and ADRs only. | Fable | `agents/linus.md` |
| **Ada** | Backend — Supabase schema, migrations, RLS, `SECURITY DEFINER` RPCs, Edge Functions, the API layer. | Opus | `agents/ada.md` |
| **Neo** | Full-stack — React/Vite/TS/Tailwind, pages, components, i18n, API wiring. | Opus | `agents/neo.md` |
| **Dieter** | Design — `DESIGN.md`, tokens, prototypes, microcopy, a11y. **`marcus-qa`'s design pass is his only instrument.** | Opus | `agents/dieter.md` |
| **Kira** | DevOps — Netlify, CI, env vars, headers, domains, provisioning wizards. | Opus | `agents/kira.md` |
| **Magellan** | Research — one open-web research lane per spawn (competition · demand · feasibility · wedge + name), for `/marcus evaluate` only. Evidence with sources and dates; **no verdict** — that is Polo's. | Opus | `agents/magellan.md` |

**Chain of command:** owner → Marcus → Linus → Ada · Neo · Dieter · Kira. **Polo sits outside that line**, which is what makes his gate worth anything once the owner steps away.

### The roster is capped by a rule, not by taste

**A role exists only against a bottleneck someone counted** — a class of defect that reached the owner, a queue that idled a whole wave, a gate missed twice — and it is **removed when it catches nothing over three consecutive waves.** No new agent without a number, and none kept out of politeness: every extra role costs a spawn, a context and a verdict to reconcile on every wave, whether or not it earns them. **Polo is the first test of the rule** (§10), and what settles it is the measurement the checkpoint now writes onto every ticket: subagent tokens per slice, attempts taken, ceilings hit. The same rule runs in reverse — seven is not a floor either.

### Why Marcus is a skill and not an agent

An orchestrator has to be the main session: it holds state across the whole run, spawns subagents, and stays in the loop. A subagent gets one context, returns one result, and dies. So Marcus can only be a skill.

The consequence surprises people: **when you type `/marcus`, the session you are already talking to puts on his instructions.** There is no separate entity. Every other name in the roster is a file; Marcus is a mode.

---

## 3. The pipeline

Seven phases, one tracker list each, strictly sequential. A phase's gate unlocks the next.

```
DISC → ARCH → DESI → DEV → QA → REV → HAND
```

| # | Phase | Who | Gate |
|---|---|---|---|
| 0 | Discovery | Marcus + owner | spec + tickets published (build tickets land in `DEV`, never `DISC`) |
| 1 | Architecture | Linus | ADRs written, contracts locked |
| 2 | Design validation | Dieter | variant picked, slop test passed |
| 3 | Implementation | Neo · Ada · Kira | all AC implemented |
| 4 | QA | Linus | every AC verified in a browser |
| 5 | Review | Linus → Polo | Stage 1 clear, then Stage 2 — `GO`, or the owner's call on a `NO-GO` |
| 6 | Handoff & ship | Marcus | handoff written, PR ready |

### The review chain

```
neo/ada self-review → local commit
  → Marcus §6          compliance: author · no trailer · scope · merge-tree · build
  → Linus   Stage 1    correctness · security · contracts · tests
  → Polo    Stage 2    intent · DESIGN.md + slop test · prod safety · scope
  → merge
```

Four distinct checks, and they are not interchangeable. **Marcus §6 is not a code review** — it proves the agent respected the contract, never that the code is right. Polo runs on every wave, in every mode, and his verdict is **advisory outside `ultraflow`, binding inside**: outside it a `NO-GO` reaches the owner with its reasons and a recommended fix slice and he decides at Gate 7; inside it nobody else is in the loop, so it blocks the merge. Neither Linus nor Polo is ever overruled by the agent doing the shipping.

---

## 4. The modes

```
/marcus evaluate "<idea>"   is it worth building at all? 4 research lanes → memo + GO/PIVOT/KILL
/marcus new "<idea>"        greenfield: intake → scaffold → tracker → DISC → … → HAND
/marcus resume              pick up from the last handoff + one tracker audit
/marcus status              one screen: phase, frontier, blocked, waiting-on-owner
/marcus reset <CODE>        existing repo: normalise the tracker, re-discovery, backfill gates
/marcus client <name>       Studio workflow — 4 client stages, 7 phases inside Dev
/marcus justflow [until]   work the frontier overnight, leave a decision queue
/marcus prototype "<idea>"  one-wave clickable demo (alias: rapid)
/marcus ultraflow "<obj>"   CEO mode: run to the objective and merge it yourself
/marcus wave <sub>          waves on a committed plan file, several sessions at once
```

Core loads on every invocation (354 lines); the eleven mode files load only when used (54–550 lines each, 1 796 together). A `/marcus status` costs 354 lines instead of 2 150 — the split is why.

### justflow vs ultraflow — the distinction that matters

They are not a ladder. Two axes differ:

| | justflow | ultraflow |
|---|---|---|
| Scope | the **whole** unblocked frontier | one contracted objective |
| Ends on | the clock | the criteria |
| Stops at | `review` | **merged** |
| Arming | none | `.claude/.ultraflow` |
| Stage 2 | no | yes |

**justflow rakes wide and hands back. ultraflow digs deep and finishes.** Use justflow while you sleep, ultraflow while you are in a meeting.

### Waves

`/marcus wave` exists so two sessions can work two waves at once without either one being the other's memory. **The plan file — `docs/waves/<CODE>-plan.md`, committed, one file with a `Plan version:` header — is the source of truth, and the tracker is a view of it.**

`wave plan` has Linus partition the open tickets into waves with a predicted file fence per ticket, proves the fences pairwise disjoint in a wave × wave table, and stops at the owner; the ok buys one plan commit on the integration branch. `wave <n>` claims a wave — the claim block in the plan — and cuts `wave/<n>`; every slice is cut from and targets that branch, and **every orchestrator docs commit during the wave lands on it, never on the trunk**. `wave status` is read-only on both sides: it **reads** the wave's task on the tracker first and reports it beside the plan's status, correcting neither — a queued, un-replayed write is named as that and not as drift — then reads each wave's claim where the claim actually lives (the plan file on `wave/<k>` — the trunk's copy shows every wave `planned` forever) and runs the conflict check over the **cross product** of the in-flight waves' branch sets — a wave branch carries only its claim commits, so the conflict lives between two waves' `feat/` slices and comparing the wave branches alone reads 0. `wave close <n>` verifies the wave as one octopus, has Linus review it, hands the owner the plan's merge order at gate 7, and records `merged` only once `git merge-base --is-ancestor wave/<n> <integration>` says the merge actually happened.

**Two waves run in parallel only when their fences are pairwise disjoint and neither blocks the other.** The planner proves that. The merge is not where it gets discovered.

**Planned by Marcus, launched by the owner.** A wave is *what one session carries* — capped at 3 tickets by the 3-agents-in-flight budget — so `wave plan` partitions in rounds and lets unblocked, disjoint overflow open a **sibling** wave that runs in parallel, instead of packing everything into wave 1 where no proof table has an off-diagonal cell to compute. Each wave block carries a **paste-ready kickoff prompt**, and the owner's ok also creates that wave's task in the tracker, so he sees every wave before opening a session. **Marcus launches nothing** — no agent, no branch, no worktree, no terminal, in any mode; the owner opens one session per wave and pastes its prompt. `wave close <n>` then posts one **end-of-wave summary** — built · verified · blocks what · parked · independence — on that task and into the plan, after the merge is real.

One finding worth keeping from building it: the conflict check §6 prescribed was `grep -c '^<<<<<<<'`, and three-argument `git merge-tree` prints its markers inside a diff against the first branch — so every marker arrives `+`-prefixed and the check read **0 on a repo that genuinely conflicted**. Corrected to `'^+<<<<<<<'` in both places that run it.

---

## 5. The nine human gates

1 Intake (name + code) · 2 Provisioning wizard · 3 **Grilling** (the only long human moment) · 4 Ticket granularity · 5 ARCH go · 6 DESI variant + sign-off · 7 Merge per wave · 8 QA ok · 9 Ship `staging → main`.

**Where the nine come from — the reversibility grid.** A gate is not a ceremony; it is a control sized to what the action costs to undo. Every action a run can take sits at one of four levels, and **a new action inherits its control from its level, not from precedent** — so a capability nobody foresaw is still governed on the day it appears.

| Level | The action | Control |
|---|---|---|
| **L1** | read — files, logs, schema, a deploy under test | none. Log it and move on. |
| **L2** | reversible write — a commit on a feature branch, a doc, a ticket, a worktree | light: Marcus's compliance check (`skills/marcus/SKILL.md` §6) |
| **L3** | external impact, still undoable — a branch deploy, an env var, a short-TTL DNS record, a tracker write the owner will read | Linus reviews before it lands |
| **L4** | **irreversible** — push, merge, production apply, delete, spend, a rights or key change, anything a third party sees and keeps | Stage 1 + Stage 2, then **the owner**. Never an agent's, in any mode. |

An action genuinely between two levels is the higher one. The nine gates above are L3 and L4 made concrete for this pipeline. Source: `skills/marcus/SKILL.md` §3, mirrored for spawned agents in `skills/marcus-workflow/SKILL.md` §4.

Between gates Marcus loops autonomously. In `ultraflow`, gate 7 disappears — he merges himself.

**Between the gates, anything expected of the owner is a tracker task assigned to him** — an **action** he executes (status `to do`, tag `ready-for-<owner>`, copy-paste commands with the output they should print) or a **decision** only he can make (status `decision` + the `decision` tag, opened as a subtask of the ticket it unblocks). The decision is his signature, and the handshake is one-directional: Marcus opens it with a recommendation, the owner moves it to `accepted` or `declined` with his answer in a comment, and the next `/marcus resume` executes what he accepted, closes the decision with a comment and unblocks the parent — **Marcus never sets either status himself**. Every output that leaves anything with him ends with those tasks as clickable links. The reason is the reason behind §6: a chat line scrolls away and a report on disk is not a queue, so a handback that is not a task is a handback that did not happen.

---

## 6. The brakes

Nothing here is theatre; each one exists because something went wrong.

**Isolation.** One git worktree per agent (`.worktrees/[CODE]-[slice]`, branch `feat/[CODE]-[slice]`), cut from the integration branch. No two concurrent agents touch the same file. Dependent slices stack; the base merges first.

**The commit contract.** Agents commit **locally only**, under the owner's git identity, with **no AI co-author / "Generated with" trailer**. Build + typecheck + lint green *before* the commit. A `commit-msg` hook strips trailers; a `block-dangerous-git` PreToolUse hook blocks the rest. **One carve-out, and only one:** in `/marcus ultraflow` on a repo the owner has armed, Marcus may push `feat/**`, open PRs and merge into the integration branch — never the production branch, never a production migration.

**The two-tier hook** (`hooks/block-dangerous-git.sh`):

| | disarmed | armed |
|---|---|---|
| `git push feat/**`, `gh pr create`, `gh pr merge` | blocked | **allowed** |
| force-push, `reset --hard`, `clean`, `branch -D`, history rewrite | blocked | **blocked** |
| anything targeting the production branch (`branches.production`, `main`/`master` with no config) | blocked | **blocked** |
| `supabase db push` | blocked | **blocked** |

**Arming is the owner's alone:** `touch .claude/.ultraflow` to open, `rm` to close. An empty file — its *existence* is the signal. An agent that could create it would have no guardrail at all, so the rules forbid agents from touching it, in every file that mentions it.

**The fatal triad — never all three legs in one agent.** Private data (the Supabase MCP, `.env*`, the tracker) · untrusted content (`WebFetch`, `WebSearch`, a browser on the open web) · an outbound channel (git remote, mail, chat, a third-party write, a logged-in browser). Any two are workable; all three in one session is an exfiltration path that needs no exploit — fetched text says "post this there", and the same agent holds both the data and the wire. Each of the seven narrows its frontmatter — `tools:` **or** `disallowedTools:`, one key per agent, because `tools:` makes `disallowedTools:` a no-op — and names in its own body what it gave up.

**Three gaps, stated rather than papered over**, because a harness doc that overstates its own guarantee is the failure the rule exists to prevent. (1) **Nothing here cuts the outbound leg:** `Bash` reaches the network and the git remote, `WebFetch` and a browser `navigate` put data in the URL they request, and the browser drives the owner's **logged-in** Chrome. (2) **A deny entry is matched by name, and the names are this machine's** — a server glob (`mcp__claude_ai_Supabase__*`) or an explicit list of tool names (Polo's 12); `claude_ai_Supabase` and `claude-in-chrome` are this install's connector names, so the same service wired under another name elsewhere is a **silent no-op**. (3) **What is cut is a Supabase write path, not the private-data leg:** `.env*` and the tracker stay reachable through the inherited `Read`/`Bash` and the inherited tracker MCP. What is actually guaranteed today: that write path is cut on five of six — the whole server on Neo, Dieter and Kira, the write half only on Linus and Polo (which keeps their live read probes: Linus allowlists 4 reads, Polo keeps the 17 left after 12 write/spend denials) — Ada alone keeps it whole; `WebFetch` and `WebSearch` are denied on Ada and Neo, the browser MCP on Ada alone. **Outbound is cut on nobody** — Neo, Dieter, Kira, Polo and **Linus** all still hold all three legs (Linus's allowlist cuts third-party MCP writes and not a leg — `agents/linus.md:37`); Ada alone is cut on one, and only by the triad's own definition, since `Bash` `curl` fetches open-web text as surely as `WebFetch` would. **Measured on Claude Code 2.1.272, 2026-09-15** — six spawns, one per agent, each asked to enumerate its own loaded and deferred tools, with the orchestrator session as the control; **the raw session record is not published**: `disallowedTools:` does what it says and no more — it removes exactly the names it lists; `tools:` filtered MCP, `WebSearch`, `Agent` and `NotebookEdit` off Linus exactly, but **not `Write`/`Edit`, which his allowlist never names** (`agents/linus.md:7`) and which load on him anyway — a leak past the key on 2.1.272 whose cause was measured on 2026-09-15 — two throwaway probes on the same version, headless (`claude -p`) rather than in auto mode, identical but for that one frontmatter key, `Write`/`Edit` present iff `memory: user` is — record not published — so removing that key is the harness cut, and until then his documentation-only rule is a fence and not a harness guarantee; `Grep`/`Glob` load on nobody, orchestrator included, on 2.1.272 in auto mode, so that absence is the harness and not the key. What neither key removes: the five inheriting agents keep `Agent`, the tracker's writes and Gmail's send — the single-writer rule and the no-spawn rule are prompt discipline, not a harness guarantee. **Magellan, added after that measurement, still cuts no leg:** three names on its allowlist (`WebSearch`, `WebFetch`, `Write`), no `Read`, no `Bash`, no MCP. Untrusted content is its job; private data and outbound are **narrowed, not cut**. Dropping `Read` (`MRCS-DEV-16.D2 = B`, owner 2026-09-27 — an earlier version of this paragraph said he had kept it) puts credentials on disk out of reach, but no `tools:` line empties the context a spawn arrives in: measured on 2026-09-19 by having a freshly spawned agent in this repo read back the prompt it had actually arrived with, before any brief (the version was not recorded, and the session record is not published), that context carries both `CLAUDE.md` files — the owner's global one names his products, their codes and a client — the project auto-memory index, the owner's email in a `userEmail` block, `gitStatus` (git user, branch, recent commit subjects) and the absolute cwd, his home path. Only the agent-memory block depends on `memory:`. No credentials and no tracker rows, but identity enough to leave in a search query with **no file read at all**, and a home path that makes `.env.local` guessable for anything downstream that does hold a read. By gap (1) the fetch URL is that wire. All three legs are present on the role that ingests attacker-controlled text, and what stands between them is the rules in its body plus a context thrown away after one lane — a smaller blast radius than the six, not a harness guarantee. Its `Write` is still filtered by name and not by path, and it is the one frontmatter with **no `memory:` key**, deliberately: that key is what appends `Write`/`Edit` past an allowlist, so its tool list at first spawn is a third data point on the leak above. Full statement: `skills/marcus/SKILL.md` §11.

**What is NOT holding anything.** The product repos are private on a free GitHub plan, so **branch protection is unavailable** (`403 Upgrade to GitHub Pro`). During an armed run the only controls are the hook, the skill's rules, Linus and Polo. There is no server-side net.

---

## 7. Context budget

The rule lives once in the owner's own `CLAUDE.md` under `~/.claude/`, loaded in every session. The plugin ships it as a template at `skills/marcus/templates/standing-rules.md`, which `/marcus init` offers to append — the installer never writes the owner's file.

**The window is a working buffer, never the memory. The memory is the tracker + the repo docs + `docs/handoffs/`.**

- **Checkpoint after 3 merged slices, or at any phase gate — whichever comes first.** `/usage` is a CLI command an agent cannot call, so token counts are not an observable; count slices and gates instead. ~500K tokens is a ceiling, never the trigger.
- At a checkpoint: finish the in-flight slice → write the session handoff → sync the tracker in one batch → `/clear` then `/marcus resume`.
- **The resume test:** a fresh session must rebuild everything from disk + the tracker alone. If it cannot, the handoff was bad — fix the handoff, not the session length.
- **Per-ticket handoff** = a tracker comment on the task (what was built · commit + branch · what was verified · what is left). **Per-session handoff** = the file in `docs/handoffs/`. Different jobs, both required. Batch the comments at the checkpoint: ClickUp's MCP budget is **300 calls per rolling 24 h window**, shared across every session and project — spend it and every session is locked out until the budget returns. `retryAfter` is the only figure the service gives and it is not a schedule; whether the budget then returns whole or call by call is unmeasured (`skills/marcus/trackers/clickup.md` §6).

---

## 8. Costs

| Model | In $/1M | Out $/1M | Used by |
|---|---|---|---|
| Fable 5.1 | $10 | $50 | Marcus, Linus, Polo |
| Opus 5 | $5 | $25 | Ada, Neo, Dieter, Kira, Magellan |
| Sonnet 5 | $2 | $10 | — |

**Fable is the most capable *and* the most expensive — 2× Opus.** Three judgment roles run on it, so a slice carries three Fable agents. Polo's Stage 2 is **one Fable run per wave, not per slice** — the whole octopus diff, once, after Linus clears. If cost becomes a problem the lever is **effort** (`low` on subagents) before model choice, and the executor downgrade is **Sonnet 5**, not Fable.

One principle worth keeping whatever you choose: **author and reviewer should not share a model.** Same model, same blind spots.

---

## 9. What is proven and what is not

**Proven.** ~20 `/marcus` invocations across `new`, `resume`, `status`, `justflow`, `rapid` **(pre-rewrite)**, plus `/linus-check` ×3, `/linus-review` ×3, `/ui-research` ×1. Artefacts on disk, across three product repos: 36 worktrees on one, 7 worktrees + 14 `feat/` branches on a second, 16 handoffs on a third.

**`wave` has run, and the record is the private working repo's history, which is not published.** Six waves — 4 through 9 — were planned on the committed plan file and each was merged into the integration branch: **there**, `git merge-base --is-ancestor wave/<n> staging` exits 0 for all six, and the plan file records each as `merged` after the merge rather than before it. Neither those branches nor that plan file is in this snapshot — §10 says why. The numbering starts at 4 because three earlier groupings predate the plan file — `wave/2` left a merge commit, the wave-3 chain left a handoff, `wave/1` left neither — so nine numbers exist and only six are evidence of the mode.

**`evaluate` has run twice**, both against this repo: 2026-09-29 as a test of the mode — its artefacts carry the `test-` slug prefix `modes/evaluate.md` requires of one — and 2026-09-30 in earnest. Each wrote a memo and four lane reports; those are session state and are not published, so neither run's evidence ships with the plugin.

**`ultraflow` — armed, and running as this was written, 2026-09-30.** The sentinel `.claude/.ultraflow` exists in this repo, and the wave that produced this paragraph is an `ultraflow` run; the sentinel is gitignored, so it never ships with the plugin. **No `ultraflow` run has yet completed end to end**, and half its carve-out cannot be exercised here at all: this repo has no git remote, so the push and PR steps have no target and only the local merge path runs.

**Never run.** `prototype` — the current mode, whose alias is `rapid`: the runs above hit the pre-rewrite `rapid`, not the mode that answers to that name today. No cloud routine has ever been created.

**What the real runs already told us, and nobody acted on:**

- **43 orphan worktrees across two older product repos** (36 on one, 7 on the other). The SOP says remove the worktree after every merge. Either those runs never cleaned up or they stopped mid-flight.
- **Zero handoffs on those same two repos**, despite 43 worktrees between them. Those runs could never have resumed. §7 is the correction — written after the fact, aimed correctly.
- **Two of the older repos still carry the old "agents NEVER COMMIT" rule.** That plausibly *causes* the orphan worktrees: agents were forbidden to commit, so the work sat uncommitted. Not yet fixed — the owner is handling those two separately.

---

## 10. Open decisions

| Decision | Why it is open |
|---|---|
| **GitHub Pro (~$4/mo)** | Without it, no branch protection on any private repo. CI reports; nothing enforces. The owner chose to stay free for now. |
| **Polo's overlap with Linus** | ~80% of his axes are Linus's. Only *intent* is uniquely his. Settle it empirically: 3 slices through both; if Polo catches nothing Linus missed, fold intent into Linus and delete him. |
| **Executor model** | No run data on where quality actually matters. Change nothing until a run says otherwise. |
| **Two older repos' CLAUDE.md** | Still on the old git rule. The owner's call, deliberately deferred. |

**Repo visibility — settled, and it is why this tree has one commit.** What is published is a de-personalised **snapshot**: a single orphan commit, no history. The working repo stays private, because the things this snapshot deliberately drops — session handoffs, wave plans, evaluation memos, the tracker ids and the project config — are exactly where the operational detail lives. Reading `git log` here will therefore tell you nothing; §9 is the honest account of what has and has not run.

---

## 11. Where everything lives

```
skills/marcus/SKILL.md            → ~/.claude/skills/…           the orchestrator, 354 l
skills/marcus/modes/*.md                                         11 mode files, on demand
skills/marcus/templates/standing-rules.md                        the standing rules — /marcus init offers them, the installer never copies them to the owner's file
skills/marcus/trackers/*.md                                      the adapter contract + clickup · github · local-html · none
skills/<15 others>/                                              12 marcus-* + 3 domain skills
agents/*.md                       → ~/.claude/agents/            the 7 spawnables
hooks/block-dangerous-git.sh      → <project>/.claude/hooks/     per project, not global
hooks/commit-msg                  → <project>/.githooks/         per project
```

The brain is global; **the brakes are per project**. That is why the two older product repos have none — and why the hook only gates where it is installed *and declared in that project's `settings.json`*. A hook file that `settings.json` does not reference never runs. That is the state of one of them today.
