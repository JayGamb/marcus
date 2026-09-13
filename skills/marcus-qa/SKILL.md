---
name: marcus-qa
description: "Report-only QA against a running deploy: every acceptance criterion, role, state and edge case driven in a real browser at four viewports, console and network read, a11y floor checked, plus a designer's-eye and slop pass — ending in a bug list and an owner checklist, and fixing nothing. Load in Phase 4 QA, before Gate 8."
---

# Marcus qa

> Replaces three **gstack** skills by Garry Tan (MIT, © 2026) — `qa-only`, `design-review` and `qa` — whose designer's-eye framing, AI-slop vocabulary and browser-driven method are the parts worth keeping; where that plugin is installed, its `browse` daemon is a perfectly good driver for the steps below. Rewritten here in our own words, at a tenth of the length, with the one change that matters: this version cannot fix anything.

## Report only. That is the whole point.

Two of the three originals carry `Write` and `Edit`, and end by fixing what they found. **This one does not, and must not.**

Three reasons, ordered by what they cost:

1. **It breaks the read-only contract.** QA runs as a judgment role. An agent that patches product code mid-QA is no longer the second opinion — it is the first one wearing a different hat.
2. **It destroys the evidence.** A bug fixed inside the QA run is a bug nobody else ever saw. The repro is gone, no ticket is written, the pattern is never counted, and the same class of defect ships again next month.
3. **It hides scope.** "QA found and fixed 9 issues" is unreviewable. Nine bug subtasks with repro steps are a queue the owner can price.

Found something trivial? It still becomes a subtask spec. **Never fix — report.**

## Driving the thing

QA runs against a **deployed, running build** — the staging URL Marcus names — never against source. Reading the code to predict behaviour is not QA, and reporting it as QA is worse than not running it.

Drivers, in order of preference:

1. The claude-in-chrome browser tools — `navigate`, `computer`, `read_page`, `find`, `get_page_text`, `read_console_messages`, `read_network_requests`, `resize_window`.
2. The headless browse daemon named in the credit note above, where the project has it installed.
3. **Neither available → say so in one line at the top of the report, and stop.** "QA not run: no browser driver on this machine" is a legitimate return. A code read dressed as a QA pass is not.

---

## The pass, in order

Do not shuffle these. Each stage assumes the one before it found nothing fatal — a 🔴 at stage 1 makes the rest of the run a waste of tokens, so return early and say why.

### 1. Acceptance criteria, one at a time

Straight off the ticket. For each: the exact action you performed and what you saw. An AC you could not reach is `UNVERIFIED — <why>`, never a silent pass. **Nothing is verified because the code looks right.**

### 2. Roles and states

Every role the spec names, plus the ones it forgot: signed-out · signed-in · wrong owner · admin. Then every state per surface: **empty · loading · partial · error · long content · slow network · double submit.** Empty and error are where products embarrass their owners, and they are the two states nobody builds.

### 3. Edge cases from the spec

Pulled out of the spec, not out of the air: the boundary number, the timezone, the second language, the expired token, the deleted parent row, the name with an apostrophe in it.

### 4. Viewports — 390 · 1024 · 1280 · 1440 px

Every surface at all four. Look for horizontal scroll, overflow, colliding text, a CTA that falls below the fold at 390, a touch target under 44 px, a table that becomes unreadable instead of scrollable. In a bilingual product, check the **longer** language too: layout that survives FR and breaks in EN is the normal failure, not the exotic one.

### 5. Console and network

Read both on every surface. Zero console errors is the bar; warnings get judged, not ignored. On the network: a 4xx/5xx on a happy path is 🔴, a failed asset is 🟡, and a request firing five times where it should fire once is a bug even when the page looks perfect.

### 6. Accessibility — the floor, not an audit

Tab through the surface: focus order follows reading order, the focus ring is visible on every interactive element, nothing is reachable by mouse alone. Every input has a real `<label>`. Headings descend without skipping a level. Body text meets 4.5:1 and large text 3:1 — measure it, do not eyeball it. Meaningful images carry alt text; decorative ones carry empty alt.

### 7. The designer's eye

The pass a functional checklist cannot do. The question is not "does it work". It is **would somebody pay for this.**

- **Spacing** — is there a rhythm, or is every gap a different number? Inconsistent spacing reads as *unfinished* long before anyone can name why.
- **Alignment** — do edges line up across sections, or does each block invent its own left margin?
- **Hierarchy** — on each screen, what does the eye land on first? If the answer is "three things", there is no hierarchy.
- **Consistency** — same component, same look, everywhere. Two button heights, three greys, two date formats: each is a finding.
- **Interactions** — anything past ~200 ms with no feedback feels broken. Check the submit, the tab switch, the filter, the first paint after login.

### 8. The slop test

Generic AI-looking UI does not ship. It is a 🔴, not a matter of taste, because it is the most visible possible signal that nobody designed this.

Look for: the purple-to-blue gradient hero · three identical feature cards with an emoji where an icon belongs · everything centred, nothing aligned · an untouched component-library default sitting beside custom work · four border radii on one screen · a shadow on every surface · copy that says *seamlessly* and *empower* · a stock illustration nobody chose · a colour that is not in `docs/DESIGN.md`.

Cross-check `docs/DESIGN.md` before ruling. **Off-token colour is a 🔴 with a grep behind it**, not an opinion:

```
grep -rnE '#[0-9a-fA-F]{3,6}\b|bg-(red|green|blue|amber|gray)-[0-9]' <changed .tsx> | grep -v components/ui
```

---

## Severity

| Marker | Means | DEBUG-SOP | Typical |
|---|---|---|---|
| 🔴 | Blocker — must be fixed before the gate | S0 outage · S1 blocker | checkout 500s · data visible across users · an AC not met · off-token UI · a keyboard trap |
| 🟡 | Should fix — fix now or ticket it | S2 degraded | empty state missing · layout breaks at 390 · slow interaction with no feedback |
| 💭 | Nit — optional | S3 cosmetic | 2 px misalignment · copy that could be tighter |

**Rank by what it costs the business, not by how hard it is to fix.** A one-line CSS bug that makes the price unreadable outranks a week-long refactor.

This is the same vocabulary Linus uses in REV and Polo uses at Stage 2. Keep it — a private severity scale makes three reports impossible to compare.

---

## One bug → one subtask spec

You never call the tracker. **Marcus is the single writer.** You return the spec; he creates the task.

```
[CODE]-DEV-[NUM].[N]-BUG — <the symptom, not the fix>
Severity:    🔴 (S1)        — the marker and its DEBUG-SOP level, both, from the table above
Environment: <staging URL> · <browser> · <viewport> · <role / locale>
Steps:       1. … 2. … 3. …     (from a cold load, every time)
Expected:    <the AC or the DESIGN.md rule, quoted>
Actual:      <what happened>
Evidence:    <verbatim console error / HTTP status / screenshot path>
```

What makes one worth writing: the title names the symptom, never the proposed fix. Steps start from a cold load and contain no "obviously". Expected is quoted from the ticket or `DESIGN.md`, not from your judgment. Errors are **verbatim** — never paraphrased, never tidied. One bug per subtask even when three share a cause; the shared cause is a line in your summary, not an excuse to merge tickets.

---

## Output — the two things you return

**1. The Gate 8 checklist.** What the owner runs himself before he says ok. Build it from the spec: one line per criterion that actually changes the decision, each a single observable he can check in under a minute, ordered by what breaks first. **8–12 lines, hard cap.** A 40-line checklist does not get run, and an unrun checklist is worse than none, because it still gets signed.

Each line is an action followed by an observable. No line that needs an opinion to score. Collapse the matrix: if an AC has to hold in two roles and four viewports, the line names the one combination most likely to fail.

> **Worked example** — spec: *login page, magic link, FR/EN.*
>
> 1. Fresh private window, `Accept-Language: fr`, open `/login` → page renders FR, no raw i18n keys, no EN string leaking through.
> 2. Switch to EN and reload → EN persists across the reload, and no label wraps or clips at the new string lengths.
> 3. Submit a valid address → success state names that address and says to check the inbox; the form does not silently reset.
> 4. Open the emailed link in the same browser → lands signed in on the post-login destination. Open it a second time → refused with a human sentence, not a stack trace.
> 5. Alter one character of the token → explicit "link expired or invalid" plus a way to request a new one. Never a blank page, never a redirect loop.
> 6. Submit empty, then malformed, then the same address six times fast → inline field error each time, throttle message on the last, and **the response must not reveal whether that account exists.**
> 7. 390 / 1024 / 1280 / 1440 px, FR and EN → no horizontal scroll anywhere; at 390 the field and the CTA are both above the fold.
> 8. Keyboard only: address bar → field → CTA in a visible ring order, Enter submits, the input has a real `<label>`; console clean and no 4xx/5xx on the happy path.

**2. The bug list.** Most severe first. Then, explicitly: **what you could not test and why.** An untested area named is a decision the owner gets to make. An untested area unnamed is a lie the report tells on your behalf.

```
QA — [CODE] — <staging URL>
Driver:      <chrome tools | browse daemon | NONE — not run>
AC:          <n> verified · <n> failed · <n> unverified (<why>)
Bugs:        🔴 <n> · 🟡 <n> · 💭 <n>    [specs below]
Not tested:  <area — reason>
Gate 8 checklist: <8–12 lines>
Verdict:     QA PASS / QA FAIL — <blocking bug ids>
```

**A QA pass with zero findings is a claim, and it is the claim that needs the most evidence.** Say what you drove, at which viewports, in which roles and locales. If that list is short, the pass is worth exactly as little.

---

## Failure modes this exists to stop

| What it looks like | Which part |
|---|---|
| "Reviewed the code, looks correct" filed as a QA report | Driving the thing |
| A bug found and fixed inside the same run | Report only |
| Nine issues, one merged ticket, no repro steps | One bug → one subtask |
| A desktop-only pass; 390 px never opened | Stage 4 |
| Console never read — the 500 was there the whole time | Stage 5 |
| Off-token purple shipped because "it looked fine" | Stage 8 |
| A 40-line Gate 8 checklist nobody ran | Output |
| "Everything passes", with no list of what was never tested | Output |
