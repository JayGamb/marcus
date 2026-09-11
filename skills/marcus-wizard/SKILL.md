---
name: marcus-wizard
description: "Generate an interactive bash wizard for the provisioning steps only a human can perform — GitHub repo and its first push, Supabase project, Netlify site, Resend, PostHog, API keys, CI secrets, DNS. Each step says what to open and what to click, captures what the human pastes back, verifies it before moving on, and resumes where an interrupted run stopped. Never for a step the agent could do itself. Load at Phase 0 intake (human gate 2), or whenever work stops on a credential that does not exist yet."
---

# Marcus wizard

> Inspired by the **wizard** skill by **Matt Pocock** (`mattpocock-skills`, MIT), whose core insight this keeps: a manual dashboard procedure is a chore by hand and a worse chore to spell out to an AI on every run, so generate a script that walks the human through it once. Rewritten here — our own text, our own step contract, plus resumability and a check per step — so the Marcus plugin carries no external dependency. Credit for the idea is his.

A wizard is a bash script for the work an agent **cannot** do: clicking a dashboard, accepting terms, holding a credential. Everything else stays the agent's job.

## When this applies

**Yes:** creating the GitHub repo and its first push · creating a Supabase project and copying its ref, anon key and service role key · linking a Netlify site and its build settings · Resend domain + API key · PostHog project key · writing `.env.local` · CI secrets · DNS records at the registrar.

**No — and this is the rule that keeps it honest:** a step the agent can run itself never goes in a wizard. Scaffolding, migrations against a local stack, config files, `netlify.toml`, workflow YAML — the agent writes those. A wizard full of steps the agent could have done is a slower agent, not a helpful one.

## The contract of a step

Every step carries six parts, in this order. A step missing any of them is not finished.

1. **Intent** — one line: what exists after this step that did not before.
2. **Open** — the exact URL, opened by the script, before it asks for anything.
3. **Do** — the click path a stranger can follow: *Dashboard → Project settings → API → copy `anon` key*. Where the current UI is unknown, say so and check the docs. Never invent a menu.
4. **Paste back** — one named value, hidden entry if secret, or nothing at all when the step is a pure action.
5. **Check** — a command the script runs to prove the step landed, before it moves on. No check, no progress.
6. **Record** — where the value goes: `.env.local`, a CI secret, both, or nowhere.

Checks are what make the wizard worth running. Useful ones: `gh repo view <slug>` · `curl -fsS -o /dev/null "$SUPABASE_URL/rest/v1/" -H "apikey: $ANON"` · `netlify status` · `dig +short <host>` · `grep -q '^KEY=' .env.local`. A check that only tests "the human typed something" is not a check.

## Resumable by construction

The wizard is re-run after an interruption, not restarted. Before each step it runs that step's **check**; if the check passes, the step is announced as done and skipped. State lives in the world (the repo exists, the key is in `.env.local`), never in a progress file that can lie about it. The script must be safe to run three times in a row and change nothing on the second and third.

## Secrets

Secrets land in `.env.local` and nowhere else. `.env.local` is git-ignored and `chmod 600`. Read them with hidden entry (`read -rs`), write them with an idempotent upsert, and **never echo one** — not to the terminal, not into the script's summary, not into a tracker comment, not into the report the agent returns. Confirm a secret by its check, by its length, or by its last four characters — and those four go to the terminal the human is sitting at and nowhere else: never into the report, never into the transcript, never into anything an agent writes down. CI secrets are set through `gh secret set` reading stdin, never through an argument that lands in shell history.

## Procedure

1. **Scope it from the repo, not from memory.** Read `.env.example`, `.env.*`, `README`, the framework config and `.github/workflows/*` — every `secrets.*` reference is a value the wizard has to produce. Then show the owner the ordered step list and the value each one yields, and let them add, drop or reorder.
2. **Author it.** One shell function per step, in dependency order (repo → hosting → data → services → keys → CI → DNS). Announce `step N/TOTAL`, keep one step to one focused task, and `confirm` before anything irreversible.
3. **Verify without running it.** `bash -n <script>`, then `shellcheck` if it exists, then `chmod +x`. Never execute the whole thing yourself: it launches a browser and then waits on a person. Read it through on paper instead — each value step 1 promised is captured, each one lands in the place step 1 named, and each CI secret name matches a `secrets.*` reference in a workflow.
4. **Hand it off.** Ephemeral by default — write it to a scratch path and delete it when the job is done. Commit it to `scripts/` only when the owner wants a repeatable setup path, and point the README at it, so whoever comes next reaches for the script rather than re-deriving it with an AI.

## Shape

```bash
#!/usr/bin/env bash
set -euo pipefail
umask 077   # put() writes $ENV_FILE.t then mv's it over the chmod-600 file:
            # without this the first upsert leaves the secrets world-readable
ENV_FILE=".env.local"; TOTAL=2
touch "$ENV_FILE"; chmod 600 "$ENV_FILE"

have() { grep -q "^$1=" "$ENV_FILE"; }                      # check helper
put()  { grep -v "^$1=" "$ENV_FILE" > "$ENV_FILE.t" || true # idempotent upsert
         printf '%s=%s\n' "$1" "$2" >> "$ENV_FILE.t"; mv "$ENV_FILE.t" "$ENV_FILE"; }
open_url() { command -v open >/dev/null && open "$1" || echo "Open: $1"; }

step_netlify_site() {                                        # 1/2 — intent
  netlify status >/dev/null 2>&1 && { echo "1/$TOTAL site linked — skip"; return; }
  open_url "https://app.netlify.com/start"                   # open
  echo "Add new site -> Import an existing project -> pick this repo"   # do
  read -rp "Press enter once the site exists "               # paste back: none
  netlify status >/dev/null 2>&1 || { echo "check failed"; exit 1; }    # check
}
```

Keep the library helpers identical across wizards. The consistency is the point: a step reads the same in every one of them.

## What you report back

The script path, the step list with the check each one runs, which values it writes to `.env.local`, which CI secrets it sets, and the result of `bash -n`. **Never a value it captured.**
