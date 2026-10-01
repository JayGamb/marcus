# `local-html` — `docs/tracker.json` + a generated `docs/tracker.html`

Zero dependency. No account, no network, no connector, no rate limit. The queue is two files in the repo, versioned with the diff that produced it.

Also **the adapter `config.tracker.fallback` names**. That names an adapter; it does not mean a degraded run writes this board — a project that runs it keeps it, and no other project acquires it at a failure (§7). The procedure below has to work on a machine with nothing but `python3` and a browser.

Config keys read: `code` · `tracker.adapter` · `tracker.fallback`. The paths `docs/tracker.json` and `docs/tracker.html` are fixed conventions, not configuration.

---

## 1. Auth

None. That is the entire point.

The credential is write access to the repo, which the agent already has. Missing `docs/` → create it. Missing `docs/tracker.json` → initialise it with `{"version":1,"code":"<CODE>","generated":"…","waves":[],"tasks":[]}` and say that you did — **as the project's adapter, never as a fallback target at a failure (§7)**.

The one real failure: `docs/tracker.json` exists but does not parse. **That is a hard stop, not a reinitialise.** Restore it — `git show HEAD:docs/tracker.json` — and if that fails too, stop and tell the owner. Overwriting a corrupt queue with an empty one loses the project's memory and looks like success.

---

## 2. `docs/tracker.json`

Source of truth. Hand-readable, diffable, one object.

```json
{
  "version": 1,
  "code": "MRCS",
  "generated": "2026-09-12T19:57:00Z",
  "waves": [
    { "id": "MRCS-WAVE-1", "title": "Tracker + packaging", "state": "open",
      "tickets": ["MRCS-DEV-4", "MRCS-DEV-9"], "plan": "docs/waves/MRCS-plan.md" }
  ],
  "tasks": [
    {
      "id": "MRCS-DEV-4",
      "title": "Tracker adapters",
      "body": "Four adapter files under the shipped path, against the seven-operation contract.",
      "phase": "DEV",
      "status": "in progress",
      "parent": null,
      "blocked_by": [],
      "tags": ["frontend"],
      "comments": [
        { "at": "2026-09-12T19:57:00Z", "by": "neo", "body": "four adapters under the shipped path" }
      ],
      "url": "docs/tracker.html#MRCS-DEV-4"
    }
  ]
}
```

| Field | Rule |
|---|---|
| `id` | `[CODE]-[PHASE]-[NUM]`, sub-work `[CODE]-[PHASE]-[NUM].[N]`. Unique. The primary key |
| `title` | No id prefix — the id is its own field |
| `body` | The ticket itself, markdown: what to build, acceptance criteria, links by path. Every other adapter carries it; this one is the only place it can live |
| `phase` | One of `DISC ARCH DESI DEV QA REV HAND`. Set at creation, never changed |
| `status` | One of the ten states, verbatim (§3) |
| `parent` | The parent's `id`, or `null`. One level is all any mode uses |
| `blocked_by` | Ids of the tickets that block this one, `[]` when none. Sibling edges, not hierarchy — the frontier is computed from this field |
| `tags` | `bug` · `backend` · `frontend` · `design` · `devops` · `decision` · `ready-for-<owner>` · `wave-<n>` |
| `comments[]` | Append-only. `at` UTC ISO-8601, `by` the agent or `owner`, `body` markdown |
| `url` | `docs/tracker.html#<id>` — always derivable, stored so `query` returns it without computing it |
| `waves[]` | One object per wave: `id` = `[CODE]-WAVE-<n>` · `title` the wave's goal · `state` `open` \| `in progress` \| `review` \| `closed` · `tickets` the member ids · `plan` the plan file's path. Appended at the plan, moved at the claim and at the `in review` mark, closed at the close (§8). §6 renders `state` **verbatim**, so the two new names need no template change — and they are §3's own `in progress` and `review`, not a second vocabulary |

Ordering in the file is irrelevant; the renderer sorts. Keep it stable anyway (phase order, then id) so a diff shows the change and not a reshuffle.

---

## 3. State mapping

The identity. `local-html` is the only adapter that stores our vocabulary as-is, which is why it can be everyone's fallback without loss.

| Marcus | `status` | ← read back |
|---|---|---|
| `to do` · `on hold` · `in progress` · `review` · `blocked` · `decision` · `accepted` · `declined` · `complete` · `cancelled` | same string | same string |

An unknown string is corruption, not a state. `query` reports it; it does not coerce it to `to do`.

---

## 4. Phase mapping

One section per phase in the rendered board, in the fixed order `DISC · ARCH · DESI · DEV · QA · REV · HAND`. A phase with no tasks renders nothing.

Waves render as their own block, above the phase sections: title, state, the plan file's path, and the ids they group.

---

## 5. The seven operations, and how to write them

**One writer at a time.** Same rule as ClickUp: Marcus writes, agents report. Two concurrent rewrites of one JSON file is a lost write with no error.

Every write is the same shape: read → mutate → **atomic rewrite of the JSON** → **regenerate the HTML**. Never hand-edit either file; never edit the HTML at all.

```bash
python3 - <<'PY'
import json, os, re, datetime
J, H = 'docs/tracker.json', 'docs/tracker.html'
d = json.load(open(J, encoding='utf-8'))
now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# ---- create ----
# a NEW id, and a new wave number — §2: the id is the primary key and it is unique.
# append() does not update: re-using MRCS-DEV-4 or MRCS-WAVE-1 from §2 writes a second
# record under a live id, and nothing raises. Check membership before you append.
d['tasks'].append({"id":"MRCS-DEV-6","title":"Wave mode","body":"<markdown>","phase":"DEV",
  "status":"to do","parent":None,"blocked_by":[],"tags":[],"comments":[],
  "url":"docs/tracker.html#MRCS-DEV-6"})
T = {t['id']: t for t in d['tasks']}   # after the create, or a just-created id is a KeyError
# ---- status ----
T['MRCS-DEV-6']['status'] = 'in progress'
# ---- comment ----
T['MRCS-DEV-6']['comments'].append({"at":now,"by":"neo","body":"…"})
# ---- label ----
T['MRCS-DEV-6']['tags'] = sorted(set(T['MRCS-DEV-6']['tags']) | {'wave-2'})
# ---- milestone ----
d['waves'].append({"id":"MRCS-WAVE-2","title":"…","state":"open","tickets":["MRCS-DEV-6"],
  "plan":"docs/waves/MRCS-plan.md"})

d['generated'] = now

def atomic(path, text):                      # same dir → os.replace is atomic
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f: f.write(text)
    os.replace(tmp, path)             # interrupted before this line → a stray <path>.tmp, safe to delete

atomic(J, json.dumps(d, indent=2, ensure_ascii=False) + '\n')
# no '<' survives the escape, so no body can close, comment out or reopen the script tag
blob = json.dumps(d, ensure_ascii=False).replace('<', '\\u003c')
h = open(H, encoding='utf-8').read()   # missing → write the §6 template first, then re-run
h = re.sub(r'(?s)(<script type="application/json" id="data">).*?(</script>)',
           lambda m: m.group(1) + blob + m.group(2), h, count=1)
atomic(H, h)
PY
```

| Op | Mutation |
|---|---|
| `create` | append a task object — `body` is the ticket's markdown, `blocked_by` the ids that block it. Sub-work sets `parent` |
| `status` | set `status` |
| `comment` | append to `comments[]` |
| `query` | read-only — filter `tasks` on `phase` / `status` / `parent`. `body` and `blocked_by` come back with the record; there is nowhere else to read them from. No call, no limit, no pagination |
| `link` | `docs/tracker.html#<id>`, already in `url` |
| `milestone` | `create` appends to `waves[]` with `state: "open"`; `status` on that entry sets `"in progress"` at the claim and `"review"` at the `in review` mark; `close` sets `state: "closed"`. Also tag each member `wave-<n>` so a ticket carries its wave on its own |
| `label` | add to / remove from `tags[]` |

`os.replace` inside the same directory is the atomic part: a reader never sees a half-written file, and an interrupted run leaves either the old file or the new one, never a truncated one. Writing in place with `open(J,'w')` does not have that property.

---

## 6. `docs/tracker.html` — the render contract

**The JSON is inlined in the HTML, and the HTML is generated.** This is not a preference: `fetch('tracker.json')` from a page opened over `file://` is blocked by CORS in every browser and fails **silently** into an empty board. Do not write a version that fetches.

Contract:

- One file, no network, no build, no external CSS/JS/font. Opens from Finder.
- Carries the whole JSON verbatim in `<script type="application/json" id="data">` — the only thing a write touches.
- Sections in fixed phase order; subtasks indented under their parent; each row `id="<task id>"` so `docs/tracker.html#<id>` anchors and highlights.
- Status as a text badge, tags, wave and blocked-by as chips, body and comments behind a `<details>`.
- Waves first, above the phase sections — one line each: id, title, state, the plan's path, the ids it groups (§2).
- Every value rendered with `textContent` — a task title is data, never markup.
- Respects the reader's light/dark setting; nothing else.

```html
<!doctype html>
<meta charset="utf-8">
<title>tracker</title>
<style>
 :root { color-scheme: light dark; --line: #8883 }
 body { font: 14px/1.5 ui-sans-serif, system-ui, sans-serif; margin: 0 auto; padding: 2rem 1rem; max-width: 60rem }
 h1 { font-size: 1.1rem; margin: 0 0 1.5rem }
 h2 { font-size: .75rem; letter-spacing: .08em; opacity: .6; margin: 2rem 0 .25rem }
 .t { border-top: 1px solid var(--line); padding: .6rem 0; display: flex; gap: .6rem; align-items: baseline; flex-wrap: wrap }
 .t.sub { padding-left: 1.5rem }
 .id { font-family: ui-monospace, monospace; font-size: .8rem; opacity: .7; min-width: 9rem }
 .ti { flex: 1 1 14rem }
 .st { font-size: .7rem; border: 1px solid var(--line); border-radius: 999px; padding: .1rem .5rem; white-space: nowrap }
 .tag { font-size: .7rem; opacity: .55 }
 details { flex-basis: 100%; font-size: .85rem; opacity: .8; margin-top: .4rem }
 details pre { white-space: pre-wrap; font: inherit; margin: .4rem 0 }
 :target { outline: 2px solid currentColor; outline-offset: .3rem }
</style>
<h1 id="h"></h1>
<main id="b"></main>
<script type="application/json" id="data">{"version":1,"code":"","generated":"","waves":[],"tasks":[]}</script>
<script>
const d = JSON.parse(document.getElementById('data').textContent);
const PH = ['DISC','ARCH','DESI','DEV','QA','REV','HAND'];
const el = (t, c, x) => { const e = document.createElement(t); if (c) e.className = c; if (x) e.textContent = x; return e; };
const waveOf = id => (d.waves || []).filter(w => (w.tickets || []).includes(id)).map(w => w.id);
document.getElementById('h').textContent = `${d.code} — ${d.tasks.length} tickets — generated ${d.generated}`;
const b = document.getElementById('b');
for (const w of d.waves || []) b.append(el('div', 't', `${w.id} · ${w.title} · ${w.state} · ${w.plan || '—'} · ${(w.tickets || []).join(', ')}`));
for (const ph of PH) {
  const ts = d.tasks.filter(t => t.phase === ph);
  if (!ts.length) continue;
  b.append(el('h2', null, ph));
  const key = t => (t.parent || t.id) + (t.parent ? '~' + t.id : '');
  for (const t of ts.sort((a, z) => key(a).localeCompare(key(z), undefined, {numeric: true}))) {
    const r = el('div', 't' + (t.parent ? ' sub' : ''));
    r.id = t.id;
    r.append(el('span', 'id', t.id), el('span', 'ti', t.title), el('span', 'st', t.status));
    for (const g of (t.tags || []).concat(waveOf(t.id))) r.append(el('span', 'tag', '#' + g));
    for (const b of (t.blocked_by || [])) r.append(el('span', 'tag', '← ' + b));
    const n = (t.comments || []).length;
    if (t.body || n) {
      const dt = el('details');
      dt.append(el('summary', null, [t.body && 'body', n && n + (n === 1 ? ' comment' : ' comments')].filter(Boolean).join(' · ')));
      if (t.body) dt.append(el('pre', null, t.body));
      for (const c of (t.comments || [])) dt.append(el('p', null, `${c.at} · ${c.by} · ${c.body}`));
      r.append(dt);
    }
    b.append(r);
  }
}
</script>
```

Write this template once, at init, then only ever replace its data block (§5).

---

## 7. Degradation — and being everyone's fallback

**This adapter's own failure modes are the filesystem's**, and there is nowhere below it to fall back to. So: a JSON parse failure stops the run (§1); a failed write stops the run. Never continue on an unwritten queue.

**As the fallback target.** `config.tracker.fallback` names this adapter. What it does **not** mean is that a degraded adapter initialises `docs/tracker.json` to hold a mirror at the moment of failure — `clickup.md` §7 step 3 rules on that, and names what carries the state instead. What it means is narrower: **a project whose `tracker.adapter` is `local-html` keeps its own board, by §5, whatever else is unreachable. A degraded `clickup` or `github` run writes no `docs/tracker.json`, present or not.** The protocol, from the degraded adapter's side:

1. **Where `local-html` is the project's own adapter**, its board is kept current by the procedure in §5 — the same schema, no "degraded" variant, so the board stays readable by a human. Anywhere else nothing is initialised and nothing is written: the readable state is `docs/waves/[CODE]-plan.md` inside a wave and `docs/handoffs/<date>-<CODE>-session-handoff.md` outside one, neither of which needs a tracker read to be written.
2. Pending remote writes are queued, one replayable line each, in `docs/handoffs/<date>-<CODE>-orchestrator-queue.md`. That queue file is the replay log; the readable state is the file step 1 named. Both, always — one without the other loses either the picture or the ability to catch the remote up.
3. **The session's next message to the owner says so out loud**, naming the trigger and both files. Not a footnote at the end of the run: the next message.
4. Nothing is dropped, nothing is assumed to have succeeded remotely, and the next session replays the queue before it audits.

A run that silently fell back and read like a normal run is the single failure this whole file exists to prevent.

---

## 8. Wave view

No new mechanism: a wave is the `waves[]` array of §2, rendered by the §6 template as a block above the phase sections. It is written by the ordinary `milestone` and `label` mutations of §5 — one JSON rewrite, one HTML regeneration, no service that can be unreachable.

| Moment | Mutation |
|---|---|
| **Plan**, after the owner's ok | append `{"id":"[CODE]-WAVE-<n>","title":"…","state":"open","tickets":[…],"plan":"docs/waves/[CODE]-plan.md"}` to `waves[]`, and add `wave-<n>` to each member's `tags[]` — **every wave of the plan in one pass, one rewrite**. Then write `[CODE]-WAVE-<n>` — the id, this adapter has no url — into that wave's `Tracker task:` line in the plan |
| **Re-plan**, a `wave plan` re-run | append **only** where that wave's `Tracker task:` line is empty · set each superseded `planned` wave's `state` to `"closed"` — `waves[].state` has no `cancelled` (§2), and `closed` is the nearest true thing. The members **keep** their `wave-<n>` tag: the closed entry is the authority (`README.md` §Wave view). Same pass, same rewrite as the plan's |
| **Claim** (`wave <n>` step 2.4) | set that wave's `state` to `"in progress"` — one rewrite, one regeneration, no call and nothing that can be unreachable. **No comment**: a `waves[]` entry is not a task and takes none (below), so the claim's `session` · `machine` · `claimed_at` stay in the plan file the entry's `plan` field already points at |
| Checkpoint | nothing |
| **`in review`** (`wave close <n>` step 4) | set that wave's `state` to `"review"`. It does **not** become `"closed"` — closed is the owner's merge, and the Close row is where that lands |
| **`wave status`** (step 0) | nothing — it is a **read**: `waves[].state` for every wave of the plan in one read of `docs/tracker.json`, no rewrite and no regeneration. Nothing here can be unreachable, so this adapter never reports `tracker: unreachable`; a wave with no entry in `waves[]` reads `tracker: not recorded` (`../modes/wave.md` §`wave status` step 0) |
| Close | set that wave's `state` to `"closed"`, and each member ticket's `status` to `"complete"` — `1 + N` mutations, one pass, one rewrite. The member tags stay. An **empty** `Tracker task:` line costs no lookup here, unlike the remote adapters: the id is `[CODE]-WAVE-<n>` by construction (§2), so read `waves[]` for it and write the line back |

**Neither the end-of-wave summary nor the claim comment is written into `tracker.json`.** A wave here is a `waves[]` entry, not a task, so there is nothing on it that takes a comment — and inventing a field for one would put a key in the JSON that §2's schema and the §6 render do not know about. Widening `state` costs nothing by comparison: the key already exists and §6's wave line prints it as text. **The status half of the mirror therefore lands here and the comment half does not**, which is the same split the summary takes. Both go where every adapter's copy of them goes anyway: **under that wave in `docs/waves/[CODE]-plan.md`** — the claim block the mode writes at `wave <n>` step 2, and the summary at the close — which is exactly the file this entry's `plan` field already points at. The board shows the wave's state and the path; the path holds who holds it and what it delivered.

A ticket carries its wave twice — in `waves[].tickets` and in its own `tags[]` — and `waveOf()` in the render reads the first. The redundancy is deliberate: the tag is what survives a ticket being mirrored here from `clickup.md` §7 or `github.md` §7, where the wave arrives as a tag and nothing else.


---

## 9. Handback — the owner's actions and decisions

The shape is `README.md` §Handback, on the §2 schema and nothing new: both are ordinary tickets, and the fields carry the split.

- **ACTION** — `status: "to do"`, `ready-for-<owner>` appended to `tags[]`, `parent: null`. He executes it.
- **DECISION** — `id` `[CODE]-[PHASE]-[NUM].D<n>`, `parent` = the ticket it unblocks, `status: "decision"`, `decision` appended to `tags[]`. **The owner** sets `accepted` or `declined` and appends a `comments[]` entry with `by: "owner"`; Marcus never writes those two states.
- **The sweep**, on `resume` — read `docs/tracker.json` for a `status` of `accepted` or `declined`, take the answer from that ticket's last owner comment, append the execution comment there, and move the **parent** off `blocked`. The decision keeps the status the owner gave it.

There is no assignee field (§2), so **the tags are how the board says it is his** — both render as chips on the row (§6), and both are what he scans for.
