---
name: marcus-code-review
description: "Read-only code review for the Marcus review chain. Owns the 🔴 blocker / 🟡 should fix / 💭 thought ladder every agent speaks, and reads a diff on five axes: spec, standards, correctness, security, performance. Use for Linus Stage 1, for any pre-merge review of a slice or a wave, or when asked to review a diff, a branch or a PR."
---

# Marcus code review

> The two-axis frame — **standards** (does it follow the repo's documented rules?) and **spec** (does it do what the ticket asked?) — is **Matt Pocock's**, from the `code-review` skill in `mattpocock-skills` (MIT). The three-rung severity ladder is the convention a loose local `code-reviewer` skill used on this machine; no author was recorded there and nothing was taken from it. The ideas are credited, the words are ours, and the plugin carries no external dependency.

## The contract: read-only

You **never edit, never commit, never fix**. You read a diff and return findings. A reviewer who patches destroys the second opinion the chain exists to buy — the author fixes, you re-review. If the fix is one character, you still only write that character inside a finding.

The only thing you write is the review itself — a ticket comment, a report. Nothing in the tree.

## The ladder — this skill owns it

Every Marcus agent speaks these three rungs. They are not adjectives; each carries a test.

| Rung | Test | Consequence |
|---|---|---|
| 🔴 **blocker** | Would merging this do damage a follow-up ticket cannot undo? Data loss, an auth or credential hole, a broken contract another slice already builds on, silently wrong output, a migration that locks prod, an acceptance criterion claimed but never verified. | **Must fix before merge.** Back to the author as a fix slice, then re-review. |
| 🟡 **should fix** | Real, worth someone's time, but merging today costs nothing irreversible. Missing validation on a non-hostile path, a duplicated shape, an absent test, a name the next reader will misread. | **Follow-up ticket**, filed and linked. Does not hold the merge. |
| 💭 **thought** | Would you re-open the branch for it? No. An alternative approach, a nit no linter catches, a note for later. | **No action required.** The author may ignore it without replying. |

Two rules keep the ladder honest:

- **If you cannot say the test out loud, it is not a 🔴.** Severity inflation is how a review stops being read.
- **Taste is 💭.** A preference with no documented standard behind it never climbs, however strongly held.

## The five axes

Run all five. The first two stay separate on purpose: code can follow every rule and build the wrong thing, or build the right thing against every convention. One axis masking the other is the failure to avoid.

1. **Spec** — does it match the ticket? Read the acceptance criteria, then the diff. Report: an AC missing or partial · behaviour nobody asked for (scope creep) · an AC that looks implemented but is implemented wrong. Quote the AC line you are judging against.
2. **Standards** — does it follow `docs/code-standards.md` and the conventions already in the file? A documented standard beats your taste, and where they disagree the document wins. Skip whatever the linter already enforces — you are not a second eslint.
3. **Correctness** — the edge the author did not run. Empty, null, zero, the error branch, off-by-one, the second concurrent caller, the retry.
4. **Security** — injection, a new path with no authorization, a direct table read where the sanctioned path is a `SECURITY DEFINER` RPC, a secret in code or in a log line, unvalidated input crossing a trust boundary.
5. **Performance** — N+1, an unbounded query, work inside a render, a migration locking a hot table. Only where the diff plausibly hits it; speculative perf is 💭.

## Findings format

Ordered worst first — every 🔴, then 🟡, then 💭. Each finding is these things and nothing more:

```
🔴 path/to/file.ts:42 — <what is wrong, one line>
   Why: <the consequence, concretely>
   Fix: <the change, specific enough to apply>
```

Specific or it does not count: *"no authorization check on the `/orders` PATCH handler"*, never *"security concerns"*. Name what is genuinely good in one line, and only when it is true.

## The verdict

The last line of the review, always, with nothing after it:

```
clear
```

or

```
🔴 ×2 · 🟡 ×3
```

`clear` means zero 🔴. It does not mean zero findings. A slice or a wave merges at zero 🔴; 🟡 and 💭 travel onward as tickets, never as blockers.

## Where this sits

This is Stage 1 — correctness and security, run by Linus. Stage 2 is Polo on the owner's bar: intent, `docs/DESIGN.md` and the slop test, production safety, scope. Clearing Stage 1 is not clearing Stage 2, and neither gate can be overruled by whoever is shipping. See `docs/WORKFLOW.md` §3.
