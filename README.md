# Marcus

> A multi-agent delivery team for Claude Code. One orchestrator, seven specialists, a two-stage review gate, and git guardrails: no push, PR or merge without a sentinel only you create, and the production branch off-limits in every mode.

Marcus takes one objective, cuts it into slices, runs them in isolated git worktrees, puts every result through two independent review gates, and hands back a merge and a handoff. Between the gates it loops on its own. At the gates it stops hard.

**What you type.**

```
/marcus new "customers can export their order history as CSV"
```

**What comes back.** That objective grilled until its acceptance criteria are unambiguous, cut into vertical slices on files no other slice touches, one agent and one worktree per slice, one local commit each, both review gates, then a merge and a handoff. [**What it actually does**](#what-it-actually-does), one section down, walks that exact run end to end with its slice table — it is the fastest way to see the shape.

**Try it in two minutes, with nothing set up.**

```
/plugin marketplace add JayGamb/marcus
/plugin install marcus
/marcus prototype "a pricing page with three tiers"
```

`prototype` needs no tracker and no config: there is no queue to track, and it is one of the four modes that run before `marcus.config.json` exists. One wave, three parallel agents, one review — Linus then Polo, the one gate `prototype` never drops — and one published artifact you can click. Run `/marcus init` when you want the full pipeline — the queue, the phases and the gates.

**What it costs.** `claude --plugin-dir . plugin details marcus` on this tree prints **Skills (16) · Agents (7) · Hooks (0)** and an always-on cost of **~3 920 tokens** added to every session.

**What it needs.** Claude Code, git, one tracker choice at `/marcus init` ([four adapters](#the-tracker-contract-four-adapters-one-in-service), one of them with no dependencies at all), and `jq`, which the git guardrail hook reads its input with — without it the hook allows everything. Nothing else: it is a Claude Code plugin — skills and agent definitions, no runtime, no service, no npm package.

**Start here → [`docs/WORKFLOW.md`](docs/WORKFLOW.md)** — the whole system in one document, including what has and has not been proven.

Built by one person — started 2026-08-22 inside a product session, extracted into its own repo 2026-09-11 (its first commit), this snapshot 2026-09-30 — and exercised on three other product repos besides itself. Six waves ran through the pipeline in this repo, 4 through 9; that record is the private working history and is not published, and §9 of that document is the honest account of what it covers and what it does not.

**Why this repo has one commit.** What you are reading is a published snapshot: [`scripts/snapshot.sh`](scripts/snapshot.sh) rebuilds it from scratch as a single orphan commit, so one commit is a property of how it is built, not of how it was written. The development history stays private because that is where the operational values are — tracker ids, internal product codes, absolute home paths, session handoffs, wave plans. Scrubbing the working tree would leave `git log -p` exposed, and cleaning history needs `filter-branch`, which this repo's own hook denies in every mode, armed or not. So the guarantee comes from a gate instead of a scrub: seven patterns over the filtered tree, two of them the owner's identity read out of the config at run time, and it refuses to build if any of them hits, save three by-file-and-field exceptions for the owner's name, the one value an MIT plugin has to carry. `git log` here will tell you nothing, by design; `docs/WORKFLOW.md` §10 is the decision.

---

## What it actually does

A run on an invented project: code `WDGT`, a fictional shop with no real counterpart.

**Objective in.**

```
/marcus new "customers can export their order history as CSV"
```

**Slices out.** Marcus grills the objective until its acceptance criteria are unambiguous, writes the spec, then cuts it into vertical slices. Each one is demoable on its own, sized to one context window, and — the constraint the rest of the system rests on — **on files no other slice touches**:

| Ticket | Slice | File fence | Blocked by |
|---|---|---|---|
| `WDGT-DEV-1` | `export_orders` RPC + row policy | `supabase/migrations/*` · `src/lib/api.ts` | — |
| `WDGT-DEV-2` | export button, loading and error states, FR/EN strings | `src/components/OrderExport.tsx` · `src/i18n/*` | `WDGT-DEV-1` |
| `WDGT-DEV-3` | CSV formatting — timezone, decimal separator, escaping | `src/lib/csv.ts` | — |

The owner signs off on that granularity, then each slice gets its own worktree and branch — `.worktrees/WDGT-DEV-1`, `feat/WDGT-DEV-1` — and one agent, with the fence above as a boundary it may not widen. Needing a file outside it is treated as evidence the slice was cut wrong: the agent stops and says so instead of quietly reaching.

**Two review gates.** The agent self-reviews and makes **one local commit**, under the owner's git identity, with no AI co-author trailer. Then:

```
agent self-review -> local commit
  -> Marcus       compliance: author - no trailer - scope - merge-tree - build green
  -> Linus   S1   correctness - security - contracts - tests
  -> Polo    S2   intent - design spec - production safety - scope integrity
  -> merge
```

Four checks, and they are not interchangeable. Marcus's is **not a code review** — it proves the agent respected the contract, never that the code is right.

**Handoff out.** Every ticket gets a comment carrying what was built, the commit and the branch, and what was actually verified rather than what was attempted. The session gets a handoff file. The merge itself is the owner's, at the merge gate — with exactly one exception, below.

---

## How it is governed

### Gates are sized to what an action costs to undo

There are nine human gates, and none of them is ceremony. Each is a control derived from a reversibility level, so **a capability nobody foresaw inherits its control from its level, not from precedent** — it is governed on the day it appears.

| Level | The action | Control |
|---|---|---|
| **L1** | read — files, logs, schema, a deploy under test | none. Log it and move on |
| **L2** | reversible write — a commit on a feature branch, a doc, a ticket, a worktree | light: the orchestrator's compliance check |
| **L3** | external impact, still undoable — a branch deploy, an env var, a short-TTL DNS record, a tracker write a human will read | Stage 1 reviews it before it lands |
| **L4** | **irreversible** — push, merge, production apply, delete, spend, a rights or key change, anything a third party sees and keeps | Stage 1 + Stage 2, then **the owner**. Never an agent's, in any mode |

An action genuinely between two levels is the higher one.

### Stage 2 reports to the owner, not to the orchestrator

Stage 1 (Linus, correctness and security) reports up the chain to the orchestrator. **Stage 2 (Polo, intent) does not** — he sits outside the line of command, and the orchestrator cannot overrule a `NO-GO`.

That is the whole point. The agent doing the shipping is the worst available judge of whether the thing should ship, and a reviewer who reports to the shipper has no leverage on the one call that matters. Outside an armed run a `NO-GO` reaches the owner with its reasons and a recommended fix; inside one, where nobody else is in the loop, it blocks the merge outright.

Stage 2 runs **once per wave on the whole diff**, not once per slice. It is the expensive tier, and the question it answers — is this what was actually asked for — is a question about the wave, not about a file. Neither reviewer shares a model with the agent whose work they read: both gates pin Fable in their frontmatter, the other five agents pin Opus — same model, same blind spots. The two gates do share Fable with **each other**: `docs/WORKFLOW.md` §8's principle is author-vs-reviewer, which this configuration keeps; reviewer-vs-reviewer independence is not a property it has.

---

## The hard parts

### The fatal triad, and the three gaps in the guarantee

No agent should hold all three of: **private data** (a database connector, `.env*`, the tracker) · **untrusted content** (`WebFetch`, `WebSearch`, a browser on the open web) · **an outbound channel** (a git remote, mail, chat, a third-party write, a logged-in browser). Any two are workable. All three in one session is an exfiltration path that needs no exploit — fetched text says "post this there", and the same agent holds both the data and the wire. So each of the seven agents narrows its frontmatter, and names in its own body which leg it gave up.

Here is what that actually buys, stated rather than papered over, because a document that overstates its own guarantee is the failure the rule exists to prevent.

1. **Nothing here cuts the outbound leg.** `Bash` reaches the network and the git remote; a `WebFetch` or a browser `navigate` puts data into the URL it requests. Most of the roster holds all three legs.
2. **A deny entry is matched by name, and the names are one machine's.** A server glob is this install's connector name. The same service wired under a different name elsewhere makes the entry a **silent no-op** — it fails open, quietly.
3. **What is cut is a write path, not the private-data leg.** `.env*` and the tracker stay reachable through the `Read` and `Bash` an agent inherits anyway.

**And the part that was measured rather than assumed.** On Claude Code **2.1.272**, on **2026-09-15**, two headless probes (`claude -p`) identical but for a single frontmatter key showed that a `tools:` allowlist does **not** remove `Write` and `Edit`: they load on an agent whose allowlist never names them, and they are present *iff* `memory: user` is present. The leak's cause is therefore the `memory:` key, not the allowlist — which means an agent documented as read-only is held there by its prompt, not by the harness, until that key goes.

And in the **six-spawn** run of the same date and version — one spawn per agent, the orchestrator session as the control — `Grep` and `Glob` loaded on nobody, orchestrator included, so *that* absence is the harness and not the key.

Two limits on it, both real: it was taken on **2.1.272** and has not been repeated since, and no frontmatter key empties the context a spawn arrives in — measured separately on **2026-09-19**, version unrecorded, by having a spawn read back the prompt it had actually arrived with: it carries both `CLAUDE.md` files, the memory index, the owner's email, `gitStatus` and the absolute working directory, with no file read at all. **None of those three session records is published.**

A document that says *here is the guarantee, and here are its three known gaps* is worth more than one claiming a clean guarantee. The gaps are why the next section is code and not prose.

### Two brakes that are code

`hooks/block-dangerous-git.sh` is a `PreToolUse` hook with two tiers.

| | disarmed | armed |
|---|---|---|
| `git push feat/**`, `gh pr create`, `gh pr merge` | blocked | **allowed** |
| force-push, hard reset, `clean`, branch deletion, history rewrite | blocked | **blocked** |
| anything targeting the production branch | blocked | **blocked** |
| `supabase db push`, `supabase db reset` | blocked | **blocked** |

Tier 1 is denied in every mode, armed or not. The production branch is read out of `marcus.config.json` at hook time, so it is that repo's real branch name and not a guess. `hooks/commit-msg` strips two trailers out of commit messages: a `Co-Authored-By:` line naming Claude or Anthropic, and a `Generated with … Claude` line. It removes nothing else — a `Claude-Session:` trailer survives it.

**Arming is the owner's alone.** The sentinel is an empty file — its *existence* is the signal — and an agent that could create it would have no guardrail at all, so every file that mentions it forbids agents from touching it. It is gitignored, so it cannot arrive in a clone already armed.

**What is NOT holding anything.** The brain is global; the brakes are per project. The hook has to be copied into a repo *and declared in that repo's `.claude/settings.json`*, or it never runs. A hook file nothing references is not a brake, and it looks exactly like one.

### Concurrent sessions: a claim model, and a conflict check that lied

`/marcus wave` lets two sessions work two waves at once without either one being the other's memory. A committed plan file is the source of truth and the tracker is a view of it. Waves run in parallel **only when their file fences are proven pairwise disjoint** — in a wave × wave table, at plan time. The merge is not where that gets discovered.

The claim is a block in the plan file, committed on the wave's own branch. That is the subtle part: the trunk's copy of the plan shows every wave `planned` forever, so a status read has to go and read each claim where it actually lives. And a wave is recorded as merged only once `git merge-base --is-ancestor` says the merge happened — not when someone says it did.

One finding worth keeping from building this. The pre-merge conflict check was specified as `grep -c '^<<<<<<<'` over `git merge-tree`. Three-argument `merge-tree` prints its markers inside a diff against the first branch, so every marker arrives `+`-prefixed, and **the check read 0 on a repo that genuinely conflicted.** Corrected to `'^+<<<<<<<'` in both places that run it. A guardrail that silently passes is worse than no guardrail, because it removes the reviewer's reason to look.

### The window is a buffer, never the memory

The memory is the tracker plus the repo docs. **Checkpoint after 3 merged slices, or at any phase gate, whichever comes first** — `/usage` is a CLI command a session cannot call itself, so token counts are not an observable and slices and gates get counted instead. The test is blunt: a fresh session must be able to rebuild everything from disk and the tracker alone. If it cannot, the handoff was bad — fix the handoff, not the session length.

---

## Install

A Claude Code plugin, not an npm package.

To inspect it or try it without installing anything — this is the pair of commands this tree is checked against:

```bash
git clone <this-repo> marcus && cd marcus
claude --plugin-dir . plugin details marcus     # must print Skills (16) - Agents (7)
claude plugin validate .claude-plugin/plugin.json
```

To install it:

```
/plugin marketplace add JayGamb/marcus   # the marketplace and the plugin are both named "marcus"
/plugin install marcus
/marcus init                             # once per repo
```

`/marcus init` is the only thing that writes configuration. It asks which tracker you want — [four adapters](#the-tracker-contract-four-adapters-one-in-service), with their tradeoffs below — locks the project code, installs the guardrails, and writes `marcus.config.json` at your repo root. To fill it in by hand instead, copy [`marcus.config.example.json`](marcus.config.example.json) — every value in it is a placeholder except the two branch names, which are defaults worth changing.

`claude plugin validate` passes with one warning — *"CLAUDE.md at the plugin root is not loaded as project context"* — and **that warning is accepted**. The root `CLAUDE.md` is this repo's contributor file, inert once installed, which is exactly what the warning says; the manifest has no field to exclude a file from the package. So the check runs non-strict. `--strict` turns that one warning into a failure and cannot pass while the file exists. Note also which check is the real one: `validate` reads the manifest, and it passed clean through a bug where the plugin loaded **zero** components. Only `plugin details` counts what actually loads.

---

## Layout

Counts below are recomputable from this tree — `find skills agents hooks -type f` is 44 files and 5 717 lines.

```
.claude-plugin/                 plugin.json - marketplace.json
skills/marcus/SKILL.md          the orchestrator, 354 lines, loaded on every invocation
skills/marcus/modes/            11 mode files, 1 796 lines, loaded only when used (54-550 each)
skills/marcus/trackers/         the adapter contract + clickup - github - local-html - none
skills/marcus/templates/        standing-rules.md - wave-plan.md - evaluation.md
skills/marcus-*/                12 skills loaded on demand
skills/<3 domain>/              i18n-fr-en - supabase-authz - privacy-nlpd-gdpr
agents/                         7 spawnables: polo - linus - ada - neo - dieter - kira - magellan
hooks/                          block-dangerous-git.sh - commit-msg
docs/WORKFLOW.md                the whole system, one document
marcus.config.example.json      the config schema, placeholders only
LICENSE                         MIT
```

A `/marcus status` costs 354 lines instead of 2 150. That split is why the modes are separate files.

## The tracker contract: four adapters, one in service

Everything Marcus needs out of a tracker is specified as **seven operations** — `create` · `status` · `comment` · `query` · `link` · `milestone` · `label` — and the **ten states** every mode thinks in. `skills/marcus/trackers/` maps all of them onto four adapters, and `/marcus init` asks which one you want, once, then records it in `marcus.config.json`, which every skill reads.

| Adapter | What it needs from you | Where it stands |
|---|---|---|
| **`local-html`** | nothing beyond `python3` and a browser: no account, no network, no MCP. A plain `docs/tracker.json` plus a generated self-contained `docs/tracker.html` you open in a browser with no server | **specified, not yet exercised.** The render template is complete (`skills/marcus/trackers/local-html.md` §6); no board has been generated anywhere yet |
| **`clickup`** | the ClickUp MCP connector, which is interactively authenticated — so **absent in headless or scheduled runs** — and a budget of 300 calls per rolling 24 h, shared across every session and project | **the one in service.** Every wave that ran through this repo ran on it |
| **`github`** | `gh`, against GitHub Issues, with native milestones | **specified, not yet exercised** |
| **`none`** | nothing — no tracker at all. Handoffs carry the state, and in `wave` the committed plan file is the queue | fine for one throwaway run; `justflow` and `ultraflow` refuse to start on it, because both compute a frontier from a queue |

**Why ClickUp is the one in service: it is what the author uses daily.** Not a dependency and not a recommendation — nothing in the pipeline needs it, and `/marcus prototype` writes to no tracker at all.

Be exact about what the contract is. **It is a contract and four written mappings — not an indirection layer, and nothing executes it.** The procedures name `clickup_create_task`, `clickup_filter_tasks` and friends directly, and nineteen files in this tree outside `skills/marcus/trackers/` mention ClickUp by name.

```bash
git grep -lE 'ClickUp|clickup_' -- skills agents | grep -v trackers/ | wc -l   # 19
```

Porting to GitHub Issues is therefore a real port through those nineteen files, not a config flag. The contract still earns its keep — it is what makes that port a bounded job, with seven operations, a known list of call sites and a written target mapping, rather than an open-ended rewrite. [`skills/marcus/trackers/README.md`](skills/marcus/trackers/README.md) is the contract, adapter by adapter; the grep above is the distance still to go.

## Per-project setup

The brain is global; the brakes are per project. In each project repo:

```bash
mkdir -p .claude/hooks .githooks
cp <this-repo>/hooks/block-dangerous-git.sh .claude/hooks/
cp <this-repo>/hooks/commit-msg .githooks/
chmod +x .claude/hooks/*.sh .githooks/commit-msg
git config core.hooksPath .githooks
```

Then **declare the hook in that project's `.claude/settings.json`** under `hooks.PreToolUse`, with matcher `Bash`. This step is not optional and it is the easy one to skip.

## Arming an autonomous run

```bash
touch .claude/.ultraflow      # owner only — never an agent
/marcus ultraflow "<verifiable objective>"
rm .claude/.ultraflow
```

That is the single carve-out in the commit contract: on an armed repo the orchestrator may push `feat/**`, open a PR and merge into the **integration** branch. Never the production branch. Never a production migration. See `docs/WORKFLOW.md` §6.

---

## What is proven and what is not

Some modes have real runs behind them across several repos; others have never executed once. The list of which is which — and three findings from the real runs that the system was then corrected for, including orphan worktrees left behind after merges and an absence of handoffs that made those runs unresumable — is `docs/WORKFLOW.md` §9. Open decisions, including the ones left deliberately unresolved, are §10.

The interesting number in §9 is not the count of successful runs. It is that the system's own record of its failures is the thing that produced §7 and the per-project brake note above.

## Working on Marcus itself

The installed copies under `~/.claude/` are what actually runs; this repo is the versioned source. They can drift, so:

```bash
scripts/diff.sh            # what differs between repo and the installed copies — run this first
scripts/install.sh         # repo -> installed   (backs up what it replaces)
scripts/pull.sh            # installed -> repo   (capture live edits before committing)
```

It is copy-based deliberately. Symlinking would remove the drift problem entirely, but it has not been verified that skill and agent discovery follows symlinks, and a wrong guess breaks the whole setup at once. Verify on one file first, then switch.

## License

MIT. See [`LICENSE`](LICENSE).
