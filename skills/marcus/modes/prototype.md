<!-- Loaded on demand by the `marcus` skill. Core rules (§0–§4, §5–§11) live in
     ../SKILL.md and are already in context when this file is read. -->

## 4e. Mode `prototype` (alias `rapid`) — a clickable demo in one wave

```
/marcus prototype "<what to demo>"      one wave, 3 parallel agents, one artifact link
/marcus rapid "<what to demo>"          same thing
```

**What it is:** the fastest honest path from an idea to something the owner can click and show
someone. One contract, three parallel agents, one review, one published Artifact. Typical
cost: ~600K subagent tokens, ~25 min wall clock.

**When it fires:** the owner says *prototype*, *maquette*, *démo*, *POC*, *"just flow"*, *"no grill"*,
or hands you a fully-specified brief (he already did the thinking — grilling him again is rude
and slow).

**What it is NOT:** a shortcut for product work. It produces a demo, not a codebase you keep
building on. The moment the answer to *"will we build on this?"* is yes, stop and run
`/marcus new` properly — DISC, ARCH, DESI, ClickUp, the lot. Say that out loud when you see it.

### What it drops, and what it never drops

| Dropped | Why it is safe to drop | Kept, always | Why |
|---|---|---|---|
| Gate 3 grilling | The brief is the spec | **REV (Linus → Polo)** | Never hand the owner code no agent reviewed. This is the one gate that survives. |
| Gate 4 tickets, ClickUp | One wave, no queue to track | **§6 verification** | Build + lint + fence + secret scan, run by you |
| Gates 5/6 ARCH + DESI docs | You freeze the decisions in the contract yourself | **Owner-only git remote ops** | You still never push |
| Worktrees | Fences + no agent commits = no race | **Design bar** | Tokens are in the contract, not improvised per component |
| Phase lists, task ids | Nothing to reconcile | **Secret discipline** | No key in the frontend, ever |

Dieter is skipped, not overruled: you fix the tokens in the contract and say so, and he can pass
over the result afterwards if the owner wants it prettier.

### The procedure

**1. Scaffold yourself, and verify the empty build before anything else.**
```bash
cd <your projects directory> && npm create vite@latest <name> -- --template react --yes
cd <name> && npm install && npm i -D tailwindcss @tailwindcss/vite vite-plugin-singlefile
```
`vite.config.js` gets `react()`, `tailwindcss()`, `viteSingleFile()` and `base: './'`;
`src/index.css` becomes `@import "tailwindcss";`. Delete the Vite demo assets — **then fix
`src/App.jsx`, which imports them**, or the first build fails on `UNRESOLVED_IMPORT`.
`git init`, owner identity, `.gitignore`, one baseline commit. **`npm run build` must pass before
you spawn anyone** — debugging a scaffold through three agents' reports is misery.

**2. Write `docs/CONTRACTS.md` — this is the whole trick.**
Three agents that never talk to each other converge only if you decide everything shared, first.
It is Marcus's own work product, never delegated. It contains, in this order:
- **Design tokens** — a real table (name, value, usage). Radius, fonts, density, icon style,
  transitions. A *banned* list: no hardcoded hex in a component, no default Tailwind palette
  class, no emoji, no decorative gradient. Without this you get three different visual languages.
- **Data shapes** — every field of every entity, with a realistic example value, not a type name.
- **Module signatures** — the exact export names and call signatures each agent may rely on.
- **Component list** — one file per component, named.
- **Behaviours** — what each surface must actually do, including responsive breakpoints and a11y.
- **Volumes** — "12 items, 5/4/3 across categories" beats "some mock data".
- **Shared forbidden list** — no network calls, no new npm deps, no TypeScript if the brief said JS.

**3. Stub every shared module before spawning.**
Write `src/data/*.js` and `src/lib/*.js` as one-line stubs exporting exactly what the contract
promises (`export const tickets = []`, `export function renderMarkdown(md) { return String(md) }`).
This is what lets the UI agent build and QA its own work while the data agent is still writing.
Commit the scaffold + contract + stubs as one commit, then spawn.

**4. Spawn three agents in one message, fences disjoint.**
The natural cut for an interface prototype:

| Agent | Slice | Fence |
|---|---|---|
| `neo` | the UI: shell, components, tokens in CSS | `src/App.jsx` · `src/components/**` · `src/index.css` |
| `ada` | mock data + the simulated service layer | `src/data/**` · `src/lib/**` |
| domain agent | the config/integration deliverable | `agent-config/**` · `server/**` · `docs/**` |

Three is the ceiling. A fourth agent means the contract is too vague or the slice is too big.

**5. Prompt additions specific to this mode** — on top of the §5 template:
- *"Another agent is writing `<paths>` RIGHT NOW. They currently hold stubs. Import them per
  contract §N. Your UI must behave correctly with the empty stubs. **Never 'fix' a stub.**"*
- *"**Make no git commit, no `git add`, no push — and never `git stash`.** The tree is shared with
  two other agents; Marcus commits at the end."* — this, not worktrees, is what prevents the race.
  Non-negotiable, and repeated in the report requirement (*"confirm explicitly: no commit, fence
  respected"*). Name `git stash` explicitly: an agent reached for it to get a clean lint baseline
  and stashed **the whole tree**, two other agents' uncommitted work included. It restored cleanly
  that time. The generic "no commit" instruction did not cover it, so say it.
- Point every agent at the **real domain source** if one exists (the owner's vault, an existing repo),
  read-only, so the mock vocabulary is credible instead of generic. A demo dies on fake jargon.
- Any slice touching an LLM API: *"invoke the `claude-api` skill first; never write a model id
  from memory."* Model ids and accepted parameters drift — a wrong one is a `400` in front of an
  audience.
- Give the UI agent the anti-slop bar explicitly and a self-check command:
  `grep -rnE '#[0-9a-fA-F]{3,6}\b|bg-(slate|gray|zinc|neutral|green|red|amber|blue)-' src/`.

**5b. Between waves, verify the tree survived.** After every parallel round: `git stash list` empty,
`git status --short` showing each fence, and one grep sentinel per slice (a symbol only that agent
could have written). Three agents in one tree is fast, not free — prove nothing was lost before you
build on it.

**6. Verify, then review. Both.** Your §6 pass, adapted — build, lint, the hex/palette grep, a
secret scan (`sk-ant-`, `dangerouslyAllowBrowser`), `git status --short` against the fences.
Then spawn **linus** on the whole working tree with the contract as the compliance reference, and
tell him the calibration: *this is a demo, missing unit tests are not 🔴, an XSS or an exposed key
is.* Ask him to settle any point an agent explicitly flagged as undecided — agents do raise them,
and the owner should not have to arbitrate CSS.
Then **polo**, Stage 2, on the same tree with Linus's verdict — fresh context, the owner's
standards, the same demo calibration. Advisory, as in every mode but `ultraflow`: a `NO-GO` comes
back with his reasons and a recommended fix, and nothing here ships anyway.

**7. Ship it as something the owner can click.**
`vite-plugin-singlefile` makes `dist/index.html` self-contained. Strip the wrapper and publish it
as an Artifact:
```bash
node -e "const fs=require('fs'),h=fs.readFileSync('dist/index.html','utf8');
fs.writeFileSync('<scratchpad>/<name>.html',
  h.slice(h.indexOf('<head>')+6, h.lastIndexOf('</head>')).replace(/<meta[^>]*>\s*/g,'').trimStart()
  + '\n<div id=\"root\"></div>\n')"
```
Keep the `type="module"` script where it is — it is deferred, so it still runs after `#root`
exists. Publish only **after** Linus is green and Polo has rendered Stage 2. Then commit, one
commit per slice by path, owner identity, no trailer. Hand the owner: the artifact URL, the repo
path, `npm run dev`, Linus's and Polo's verdicts, and the open questions.

### Hard rules for this mode
- Publish nothing before Linus and Polo have reviewed it. "Fast" never means "unreviewed".
- Agents never commit in this mode. You do, at the end.
- Never let the prototype quietly become the product. When the owner asks for the second wave of
  features on it, that is the signal: say so, and offer `/marcus new` or `/marcus reset <CODE>`.
- No ClickUp writes at all — there is no queue. If the owner wants it tracked, it is not a prototype.

---
