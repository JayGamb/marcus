<!-- Loaded on demand by the `marcus` skill. Core rules live in ../SKILL.md
     and are already in context when this file is read. -->

# Marcus — set up a repo

Run once per project. Everything Marcus does afterwards reads the file this produces.

**This is a conversation, not a form.** Look first, present what you found, let the user correct you, then write. Never guess a value into the config silently — a wrong tracker id surfaces as a confusing failure three sessions later.

---

## 1. Look before asking

Gather, quietly, then show the user what you found:

```bash
git remote -v                                  # GitHub? which repo? is gh authenticated?
git branch -a                                  # what branches exist — do not assume main/staging
git log -1 --format='%an <%ae>'                # the owner identity commits already use
ls docs/tracker.json marcus.config.json        # has this run before?
ls package.json supabase/ netlify.toml         # stack signals
ls .claude/settings.json .claude/hooks/        # existing guardrails
```

Also check what the **session** has: is a ClickUp connector live? `gh` authenticated? Say which you can see. A connector you cannot reach right now is not the same as one the user does not have — ask rather than conclude.

Open with a short summary of what you found and what you are about to ask. Then work through the sections below, confirming as you go.

---

## 2. Where do issues live

**The one question that actually matters.** Present the options with their real trade-offs — not a neutral list, because they are not equivalent:

| Option | Good when | The cost |
|---|---|---|
| **ClickUp** (MCP connector) | You already run ClickUp; you want real subtasks and custom statuses | Interactively authenticated, so it may be **absent in headless or scheduled runs**. 300 calls per rolling 24 h window, shared across every session and project, then locked out until that window rolls |
| **GitHub Issues** (`gh`) | The code is on GitHub; you want the queue next to the diff; you want CI to reach it | No real subtasks, no custom statuses — both live in labels |
| **Local HTML board** | No tracker yet; you want the queue committed with the code; you want zero dependencies | Single-machine unless committed; no notifications; you are the only reader |
| **None** | A throwaway prototype | `justflow` and `ultraflow` **refuse to run** — they need a queue to compute a frontier from |

Ask which they use. **If they name one we have no adapter for** (Linear, Jira, Notion…), say so plainly and offer the nearest working option. Do not improvise an adapter mid-setup, and do not promise one.

Then collect what the chosen adapter needs — the workspace, space and list ids for ClickUp; nothing beyond a passing `gh auth status` for GitHub; nothing for local HTML — its paths are fixed. Read `../trackers/<name>.md` for the exact list, and **verify each value by calling the tracker once** before writing it down. An id that does not resolve is caught here or it is caught in production.

---

## 3. The rest

Short, and mostly confirmable from what you found:

- **Project code** — 3–5 uppercase letters, locked for the life of the project. Ids are always `[CODE]-[PHASE]-[NUM]`, sub-work `[CODE]-[PHASE]-[NUM].[N]` as a real child. **This convention does not bend per project or per tracker.** Check the code is not already in use.
- **Owner identity** — the name and email every agent commit is authored with. Default to what `git log` already shows; confirm it.
- **Branches** — integration (what agents cut from and target) and production. Read the real branch list; do not assume `main`/`staging`. The shipped `block-dangerous-git.sh` hook reads `branches.production` from `marcus.config.json` and falls back to `main`/`master` when no config is readable — so the production branch you write here is the one the hook protects, and only once the hook is installed **and declared in `.claude/settings.json`** (§4).
- **Stack** — Supabase is the default backend and the one the agents know best: `ada` carries RLS, `SECURITY DEFINER` RPCs, migrations and storage policies out of the box. Anything else works, but say clearly that the backend guidance becomes generic.
- **Language** — English is the default for all agent reporting. It costs roughly 20% fewer tokens than French for the same content.

---

## 4. Guardrails

Offer all three, explain each in one line, let the user decline any:

1. **`block-dangerous-git.sh`** → `.claude/hooks/`, **and declared in `.claude/settings.json`** under `hooks.PreToolUse`, matcher `Bash`. A hook file that settings does not reference **never runs** — installing the file alone is the most common way to end up with no protection while believing you have some.
2. **`commit-msg`** → `.githooks/`, then `git config core.hooksPath .githooks`. Strips AI co-author trailers.
3. **`.claude/.ultraflow`** → add to `.gitignore`. Do **not** create it. It is the arming sentinel for autonomous runs and only the owner ever creates it; explain that and move on.

Then say plainly what is **not** protecting them: on a private repo on a free GitHub plan, branch protection is unavailable, so CI reports but nothing enforces. That is a fact they should hold before they arm anything.

---

## 5. Write it

`marcus.config.json` at the repo root:

```json
{
  "version": 1,
  "code": "…",
  "company": "…",
  "owner": { "name": "…", "email": "…" },
  "branches": { "integration": "…", "production": "…" },
  "stack": { "backend": "supabase", "frontend": "vite-react-ts", "host": "netlify" },
  "language": "en",
  "tracker": {
    "adapter": "clickup",
    "workspace": "…",
    "space": "…",
    "folder": "…",
    "ownerUserId": "…",
    "lists": { "DISC": "…", "ARCH": "…", "DESI": "…", "DEV": "…", "QA": "…", "REV": "…", "HAND": "…" },
    "fallback": "local-html"
  },
  "guardrails": { "gitHook": true, "commitMsgHook": true, "ultraflowGitignored": true }
}
```

`company` is **optional**: it is the only value the standing-rules template needs (§6). Omit it and `owner.name` is used instead.

`tracker.ownerUserId` is the owner's **assignee id in the tracker** — every action and every decision handed back to him is assigned with it (`../SKILL.md` §7). Resolve it here, once, with the adapter's member lookup on `owner.name`, and show him the id before you write it; if the lookup is ambiguous or the connector is absent, leave the key out rather than guess. A mode that finds it missing at runtime resolves it once for that session and raises an action task asking him to record it — **no mode but this one ever writes this file**, and this one only with him in the room.

Then write a short `## Marcus` section into the repo's `CLAUDE.md` (create it if absent) pointing at the config — so a session that never runs this skill still knows the setup exists.

Finally, **echo the config back** and state, in one line each: which tracker is live, which guardrails are on, and what is still the user's job. If anything could not be verified, list it as unverified rather than letting it read as confirmed.

---

## 6. Standing rules — offer, never impose

`~/.claude/CLAUDE.md` is **the user's own file**, loaded in every session on their machine. Marcus never writes it silently, and never rewrites what is already in it.

The plugin ships the cross-project rules — context budget, the completion ritual, the non-negotiables — de-personalised, at `skills/marcus/templates/standing-rules.md` (installed to `~/.claude/skills/marcus/templates/`). Offer them, once the config exists:

1. **Fill the placeholder** from `marcus.config.json`: `<your company>` → `config.company` when it is set, otherwise `config.owner.name`. That is the only placeholder — the rules carry nothing per-project, so the same filled block is correct in every repo.
2. **Show the filled block in full**, and say exactly where it would go: appended to the end of `~/.claude/CLAUDE.md`, created if it does not exist.
3. **Ask a plain yes/no.** On no, give the path and move on — appending it by hand later costs them nothing.
4. **On yes, append only.** Never overwrite, never reorder, never touch a line that was already there. If the file already carries a standing-rules block, say so and stop: it already covers this repo — nothing per-project is owed — and reconciling two versions is the owner's edit, not Marcus's.

---

## Boundaries

- Never create the `.ultraflow` sentinel. Never push, never create a remote repo, never merge — those are the owner's.
- Never write a tracker id you did not resolve successfully.
- Never overwrite an existing `marcus.config.json` without showing the diff and getting an explicit yes.
- If the user's tracker has no adapter, say so. An honest "not supported yet, here is the nearest option" beats a config that fails on first use.
