---
name: marcus-diagnose
description: "The diagnosis loop every Marcus agent runs on a bug or a performance regression: reproduce → minimise → hypothesise → instrument → fix → regression test, red-green wherever a test seam exists. Use when something is broken, throwing, failing, flaky or slow, when a QA bug subtask comes back, or when the user says 'debug this' / 'diagnose this'."
---

# Marcus diagnose

> Built on two of **Matt Pocock's** skills in `mattpocock-skills` (MIT): `diagnosing-bugs`, whose central claim this keeps — a tight pass/fail loop is the whole job and everything after it is mechanical — and `tdd`, for red-green and the seam vocabulary. Shortened hard and written in our words, so the plugin carries no external dependency.

## The rule

**A fix whose cause was never reproduced is a guess wearing a commit message.**

Everything below exists to stop one failure mode: read code → form a theory → patch the theory → declare victory. The symptom disappears often enough for that to feel like it worked. It is how the same bug returns in three weeks under a different stack trace.

No repro, no fix. If you cannot reproduce it, **that is the finding** — return a BLOCKER, not a patch.

---

## 1. Reproduce

Build **one command that goes red on this bug**, and run it before you theorise.

In rough order of preference: a failing test at a seam that reaches the bug · a curl or HTTP script against the dev server · a CLI call on a fixture, diffed against known-good output · a headless browser script asserting on DOM, console or network · a replay of a captured payload or trace · a throwaway harness calling the one code path with its neighbours mocked · a fuzz loop, when the symptom is "sometimes wrong" · a bisection harness, when it worked at a known earlier state.

The command is good enough when it is:

- **red on the user's symptom** — the exact failure reported, not a neighbouring one. Wrong bug, wrong fix.
- **deterministic** — the same verdict every run. For a flaky bug, aim at the failure rate rather than at a spotless reproduction: loop it 100×, add stress, pin the clock, seed the RNG. 50% is debuggable, 1% is not.
- **fast** — seconds. Thirty seconds of flake buys you almost nothing over having no loop at all.
- **runnable by you, unattended.**

Show the invocation and its output. **Redact every secret to `<REDACTED>` first** — a captured trace ships authorization headers along with it, so quote the lines that carry signal and none of the rest. When what survives redaction will not support a diagnosis, say that and ask.

Catch yourself building a theory before this command exists → stop. That is the exact failure this skill prevents.

## 2. Minimise

Cut the repro down until it is the smallest thing that still fails. Remove one thing at a time — an input, a caller, a config row, a step — and re-run after each cut. Keep only what is load-bearing.

Done when removing any remaining element turns it green. Two payoffs: a far smaller hypothesis space in step 3, and the minimised case becomes the regression test in step 6.

## 3. Hypothesise

Write **three to five ranked hypotheses before testing any of them**. A single hypothesis is not a hypothesis, it is an anchor.

Each must be falsifiable — write down what it predicts:

> If `<cause>` is it, then `<change A>` makes the bug disappear, and `<change B>` makes it worse.

No prediction means a vibe: sharpen it or drop it. Show the ranked list to whoever is watching before you start testing — domain knowledge re-ranks it in one line ("we deployed number 3 yesterday"). Do not block waiting for the answer.

**Check the non-code causes in the same pass**: an unapplied migration, a missing env var, a stale build, a config nobody reloaded, cached data, the wrong branch deployed. A patch on top of a configuration problem is two bugs.

## 4. Instrument

One probe per prediction. **Change one variable at a time** or the result teaches you nothing.

Prefer a debugger or REPL breakpoint to logs — one breakpoint beats ten print statements. Where logs are the only option, put them at the boundary that separates two hypotheses, never "log everything and grep".

**Tag every temporary log with a unique prefix** — `[DBG-a4f2]`. Cleanup is then a single grep. Untagged debug logs ship to production; tagged ones do not.

**Performance regressions take the other branch.** Logs are the wrong instrument. Establish a baseline measurement first — a timing harness, a profiler, `EXPLAIN ANALYZE` — then bisect between the fast state and the slow one. Measure, then fix, never the reverse.

## 5. Fix

Only now. The minimum viable change, **at the cause, not at the symptom**. If the honest fix is large or architectural, say so rather than shimming it — a shim over a structural bug is a 🔴 at review, and correctly so.

Then re-run the step 1 command against the **original, un-minimised** scenario. Red before, green after, there. Anything less is not a fix.

## 6. Regression test

Write the test that **fails before the fix and passes after**, and write it before applying the fix wherever a seam exists.

**Picking the seam.** Prefer a seam that **already exists** · take the **highest** one that still reaches the bug, so the test asserts behaviour through the public interface and survives a refactor that keeps that behaviour · the **ideal is one** seam, not a fan of them. A test that reaches inside breaks on every refactor and tells you nothing about the bug.

Red-green-refactor, where a seam exists:

1. Move the minimised repro into a test living at that seam, and expect red.
2. **See the red yourself.** A red nobody watched is not a red — a test that has never failed proves nothing.
3. Land the fix.
4. See the green.
5. Refactor only with the test green, and only what your own change made ugly.

**No correct seam is a finding, not permission to skip.** A seam is correct when it puts the bug through the same shape it takes where the code is actually called; a unit test that cannot reproduce the chain that triggered the bug buys false confidence, which is worse than no test at all. Report that the architecture prevents this bug from being locked down, and file it.

Never assert by recomputing the value the way the code does. The expected value comes from an independent source — a worked example, a known-good literal, the spec.

## Test-first for new logic

Some slices arrive here with nothing broken — new pure logic, at a seam already agreed in the spec. **No repro is needed, because there is no bug yet:** §1–§5 do not apply. What carries over is §6's seam rule and its loop.

1. Write the failing test at the agreed seam — prefer one that **already exists**, take the **highest** one that still reaches the behaviour, and the **ideal is one**, never a fan of them.
2. **See it go red**, and red for the reason you expect. A red nobody watched proves nothing.
3. Write the least code that turns it green, then refactor with the test green — and only what your own change made ugly.

---

## Before you call it done

- [ ] The original repro no longer reproduces. **Re-run it; do not predict it.**
- [ ] The regression test passes, or the missing seam is written down.
- [ ] `grep` for your `[DBG-...]` prefix returns nothing.
- [ ] Throwaway harnesses and fixtures deleted.

## The report

Five lines, in this order, in the ticket comment. The hypothesis that turned out right also goes in the commit message, so the next person inherits it instead of re-deriving it.

```
Reproduced: <the command, and the symptom it produced>
Cause:      <the mechanism> — evidence: <the probe or measurement that proved it>
Fix:        <file:line> — <what changed, and why that is the cause not the symptom>
Test:       <path> — fails before the fix, passes after
Left:       <what is still open, or "none">
```

An unreproduced cause is reported as unreproduced: *"could not reproduce; here is what I ruled out and what I need"*, returned as a BLOCKER. Never dress a guess up as a diagnosis — a wrong diagnosis costs more than no diagnosis, because it stops the next person looking.
