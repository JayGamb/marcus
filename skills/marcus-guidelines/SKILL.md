---
name: marcus-guidelines
description: "The coding discipline every Marcus agent works under: think before coding, minimum viable change, surgical edits, and goal-driven execution with a verifiable finish. Active for the whole of any implementation task. Load before writing, refactoring or reviewing code."
---

# Marcus guidelines

> Built on **Andrej Karpathy's** observations about where LLMs reliably go wrong when they write code — over-building, silently choosing between readings, drifting outside the request, and declaring success without checking. The framing is his; this is our version, written so the plugin carries no external dependency.

Four rules. They stay active for the entire task, not just its first minute.

---

## 1. Think before coding

**Never silently pick between two readings of a request.** If "add caching" could mean an in-memory map or a CDN layer, those are different weeks of work. Say which you assumed, or ask. A wrong assumption discovered at review costs more than the question would have.

State what you are assuming, name the tradeoff you are taking, and flag the thing that worried you. **Surfacing a concern is not hedging** — it is the part of the job the user cannot do for themselves.

And when the real cause is not code — an unapplied migration, a missing env var, stale data, a config nobody reloaded — **say that before writing a fix.** A patch on top of a configuration problem is two bugs.

## 2. Simplicity first

Write the minimum that satisfies the request. Nothing speculative.

- No abstraction invented for one caller. Three similar lines beat a premature interface.
- No configuration option nobody asked for. Every flag is a branch that has to be tested forever.
- No "while I was in there" refactor riding along in a bug-fix diff.
- No new dependency where fifteen lines do the job.

The test: **can you name the caller that needs this?** If the answer is "someone might later", it does not go in.

## 3. Surgical changes

Touch only what the task requires.

Match the surrounding style even when you would have written it differently — a file with two conventions is worse than a file with one you dislike. Clean up **only the orphans your own change created**, never the ones you found. If you spot something genuinely wrong nearby, report it; do not fix it in this diff.

**Stay inside the scope fence.** Needing a file outside it is a signal the slice was cut wrong — stop and say so rather than widening quietly. A diff that touched three unexpected files is a diff nobody can review.

## 4. Goal-driven execution

**Define what "done" means before you start**, in terms a command can check. "The orders page looks better" is not a finish line. "No badge overflow at 320–1920 px, FR and EN, build green" is.

Then: **reproduce → fix → verify.** For a bug, reproduce it first — a fix whose cause was never reproduced is a guess wearing a commit message. Where there is a test seam, write the failing test before the fix.

Loop until verified. **Run the check, do not predict it.** "This should work now" is not a result; `npm run build` exiting 0 is. Report what you actually ran and what it actually printed.

If you cannot verify something, say which criterion is unverified and why. **An unverified claim presented as done is the most expensive thing you can hand anyone**, because it removes the reviewer's reason to look.

---

## The failure modes these exist to stop

| What it looks like | Which rule |
|---|---|
| A 400-line diff for a 10-line ticket | 2 — simplicity |
| A bug fix that also renames six variables | 3 — surgical |
| "I've implemented the caching layer" with no cache hit measured | 4 — verify |
| Two plausible readings, one silently chosen, wrong one built | 1 — think first |
| A fix for a symptom whose cause was a missing migration | 1 — surface it |
| An abstraction with exactly one implementation | 2 — name the caller |
| "Should be working now" as the final report | 4 — run the check |
