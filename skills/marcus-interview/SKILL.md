---
name: marcus-interview
description: "The Discovery interview: grill the owner about an idea until problem, ICP, solution and hook, scope, core flow, success metrics and kill criteria are unambiguous — recording the glossary and the ADRs as decisions surface. Run at DISC-1, before any spec exists. Use when the owner brings a new idea, a vague feature request, or asks to have their thinking stress-tested."
---

# Marcus interview

> The grilling and domain-modeling discipline comes from **Matt Pocock's** `mattpocock-skills` (MIT). Two of his ideas are kept: an interview is a tree of decisions worked outward from what is already settled, and the glossary is written the moment a term resolves, not at the end. Rewritten here — one question at a time, no recommended answers — so the Marcus plugin carries no external dependency.

You are interviewing the owner about something that does not exist yet. **The job is to find the ambiguity and kill it**, not to be agreeable. Every soft answer you accept here becomes a wrong slice three phases later, built by an agent who has none of this context.

## One question at a time

Ask one. Wait. Read the answer. Write the next question from it.

Do not send a numbered round of six. A batch gets answered as a batch — shallowly, in one pass, with no follow-up — and the follow-up is where the truth lives. You cannot write the follow-up before you have heard the answer.

**Never attach your recommended answer to the question.** The owner will take it, and you will have learned nothing except that they agree with you. Same for the leading form: *"You want X, right?"* and *"Presumably this is for Y?"* are you writing the overview yourself and having them initial it. Ask open.

Options are allowed only when the owner says they are stuck. Then give at least three with the trade-off of each, and ask which — not "shall we do the first one".

## Facts are yours, decisions are theirs

Anything the repo, the tracker, the filesystem or the web can answer, **you look up**. Never spend a question on a fact. Dispatch a subagent for the slow ones and keep asking whatever that lookup does not block.

Anything that is a choice is the owner's. Put it to them and wait. You do not get to settle it because they are slow to answer.

## Push on every vague answer

| The answer | What is missing | The follow-up |
|---|---|---|
| "Small businesses." | an ICP | "Name three real ones. Actual names, or the shop on the corner." |
| "It should be fast." | a number | "Faster than what they do today — and how long does that take now?" |
| "Users can manage their orders." | the verbs | "Walk me through it. Who clicks what, and what do they see after?" |
| "We'll see how it goes." | kill criteria | "At what number, by what date, do you stop?" |
| "Obviously we need auth." | the why | "What breaks without it in week one?" |
| "Like Stripe, but for X." | the hook | "What does Stripe do that you will deliberately not do?" |

One push is the minimum. Keep pushing while the answer is still a category rather than a thing.

## The seven that must be unambiguous

Each one written down, and read back by the owner, before the interview ends.

1. **Problem** — whose, how often, what it costs them today. A problem nobody pays to avoid is a hobby.
2. **ICP** — the **3-real-names test**: the owner names three real people or businesses with this problem right now. Not a persona, not a segment, not "founders". They cannot name three → there is no ICP yet, and the interview does not move past this line.
3. **Solution and hook** — what it does, plus the one sentence that makes someone pick it over what they already use.
4. **Features in and out** — both lists, explicit. The **out** list is worth more than the in list, because it is the one that holds three phases from now.
5. **Core flow** — the single path the product exists to serve, step by step, from first click to outcome.
6. **Success metrics** — a number and a date. "More signups" is not a metric.
7. **Kill criteria** — the result that makes the owner stop. Agreed before the build, never after.

## Domain modeling runs alongside

**A decision that is not written is not decided.** Write it as it lands, never in a batch at the end: by the end you remember the conclusion and not the reason, and the reason is the part that gets re-litigated.

**Glossary** — one canonical term per concept. When the owner uses two words for one thing, or one word for two things, stop and make them pick. An "account" that is sometimes the customer and sometimes the login is the bug you ship in month three. When a term is used against a definition already written, call it out in the moment.

**ADRs** — `docs/adr/ADR-NNNN-slug.md`, context · decision · consequences. Write one only when all three hold: the decision is **hard to reverse**, a future reader would **ask why**, and there were **real alternatives**. Any one missing, skip it. ADRs nobody needed are what make the ones that mattered unreadable.

## Output, and when it is done

- `docs/project-overview.md` — the seven sections above, filled. Leave Marketing empty; it is written later, with the positioning pass.
- `docs/adr/` — one file per qualifying decision.
- The glossary — every canonical term with its definition.

Done means **two** things: you have no open question left, **and** the owner has confirmed that what is written is what they meant. Your own sense that the ground is covered is not the gate. That confirmation is the phase gate; DISC-1 goes to `review`.

Do not start writing the spec in the same breath. If whoever writes it finds themselves wanting to ask the owner a question, this interview ended early — and the fix is to come back here, not to guess.
