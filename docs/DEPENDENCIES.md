# Provenance — what Marcus replaced, and who to credit

Marcus started as one orchestrator skill that made **67 skill invocations across 19 other skills**. Most of them were not ours: third-party plugins and loose local skills that would not exist on anyone else's machine. That gap — between "works on one machine" and "installable plugin" — is the whole reason the `marcus-*` skills exist.

Every one of them is rewritten from scratch, in our own words, deliberately **shorter** than what it replaces: gstack's `design-review` is 1 965 lines and `qa-only` 1 227, and a skill nobody can read is a skill nobody maintains. Each carries its own credit header at the top of its `SKILL.md` — this file is the map, those headers are the detail.

**No third-party plugin is a dependency today**, optional or otherwise. The only skills Marcus calls that it does not ship are Claude Code's own built-ins.

---

## What each `marcus-*` skill replaces

| Skill | Replaces | Why it is load-bearing |
|---|---|---|
| `marcus-voice` | `caveman` (gstack) | An agent's filler is paid for twice — once to generate, once to read. On a multi-agent run that is the difference between a twelve-slice session fitting its budget and not. |
| `marcus-guidelines` | `karpathy-guidelines` | The four rules against over-building, silently picking a reading, drifting out of scope, and declaring success without checking. |
| `marcus-code-review` | `code-reviewer` · `mattpocock-skills:code-review` | Owns the 🔴 / 🟡 / 💭 ladder — the severity vocabulary the whole review chain speaks — plus the two-axis Standards/Spec pass. |
| `marcus-diagnose` | `mattpocock-skills:tdd` · `mattpocock-skills:diagnosing-bugs` | reproduce → minimise → fix → regression test, and the test-first lane. Without it "fix" means "guess". |
| `marcus-interview` | `grilling` · `domain-modeling` | The grill at Gate 3, and the domain model and ADRs that come out of it. |
| `marcus-spec` | `to-spec` (user-invoked only, so the procedure was inlined in `SKILL.md` §4) | DISC step 2. The inlined procedure stays; the detail has a home. |
| `marcus-slice` | `to-tickets` (user-invoked only, same reason) | DISC step 3 — vertical slices, blocking edges, the granularity gate. |
| `marcus-build` | `plan-eng-review` · `backend-architect` | Phase ARCH — Linus's inputs. |
| `marcus-qa` | `qa-only` · `design-review` · `qa` | Phase QA, **report-only**: the originals can edit, which breaks Linus's read-only contract. Owns the design pass and the slop test outright. |
| `marcus-wizard` | `wizard` · `mattpocock-skills:wizard` | The provisioning steps only a human can perform (repo, Supabase, Netlify, keys). |
| `marcus-checkpoint` | `context-save` · `context-restore` · `handoff` | The resume test depends on it. **Automatic — never invoked by hand**; `/marcus relay` is the manual pull of the same cord. |
| `marcus-workflow` | — (new) | Reference skill: the pipeline, the gates, the review chain, in one place instead of six. |

### Deleted rather than replaced

**`review`** (gstack). It is a pre-landing skill carrying `Write`/`Edit`, which is why `/marcus review` already excluded it: reviewing and patching in one pass destroys the second opinion. The references are out and nothing took their place.

### Retired

**`impeccable`**. Dropped when the decision was taken to build the team's own UI kit instead. The slop test stays, credited to impeccable's craft floor as its origin.

### Ships with Claude Code

**`security-review`** and **`claude-api`** (the latter in `modes/prototype.md`) ship with the product. Calling them is free and safe, so they were never candidates for replacement.

---

## Credits

The ideas below are other people's. The words in this plugin are ours, and that is the point: credit the insight, carry no dependency.

- **Andrej Karpathy** — the observations about where LLMs reliably go wrong when they write code, which `marcus-guidelines` is our version of.
- **Matt Pocock** — `mattpocock-skills` (MIT). The two-axis review frame, the diagnosis loop and red-green, the grilling and domain-modeling discipline, the tracer-bullet slice and expand–contract sequencing, the spec's section list, and the generate-a-wizard idea. Six of our skills owe him something.
- **the gstack authors** — Garry Tan (MIT, © 2026). `caveman`'s insight about the real cost of filler; the designer's-eye framing, AI-slop vocabulary and browser-driven QA method; the eng-manager plan review; and the session-state discipline behind `marcus-checkpoint`. Where gstack is installed, its `browse` daemon is a perfectly good driver for `marcus-qa`'s steps.
- **`msitarzewski/agency-agents`** — the public collection the four research lanes' interrogation lists, source hierarchies and scorecard shapes are adapted from. **Read for craft, never installed as-is:** those files inherit every tool in the session and carry no fence, no stop condition and no report contract. `agents/magellan.md` says what it added.
- Two originals carried no licence header and no traceable author — a loose local `code-reviewer` and a loose local `backend-architect`. They are named for honesty; nothing was taken from either but the severity-ladder convention, and that is noted where it is used.
