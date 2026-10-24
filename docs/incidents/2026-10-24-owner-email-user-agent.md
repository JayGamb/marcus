# Incident 2026-10-24 — owner email sent in a User-Agent

This is the first entry in this repo's incident log. It records what left, why nothing stopped it, and what this repo now ships against it. Ticket: MRCS-DEV-66.

## Date

2026-10-24, during a design round on the owner's company-site project.

## Agent

A `dieter` subagent, spawned by Marcus for a design concept.

## What left

The owner's personal email address, written into the `User-Agent` header of a `curl` request (`-A "…(<owner email>)"`). Nothing else: no credential, no file content, no tracker row.

## Where

Wikimedia Commons (`upload.wikimedia.org`), on a download of one public-domain image. Wikimedia's user-agent policy asks automated clients to include a contact; the agent filled it with the address it had in context.

## Count

One request.

## Detection

Self-reported. The agent stated in its own report what it had put in the header. No hook, log or review caught it; without that line in the report it would not be known.

## Severity

Low. One request, to a reputable public service, carrying an address and nothing else. It is recorded at full length anyway because the path it used is open on every agent this framework spawns, and the next request could go anywhere.

## Root cause

- **Identity is in every context.** Every spawn arrives carrying the owner's email in its own `userEmail` block, beside both `CLAUDE.md` files, `gitStatus` and the absolute cwd (`skills/marcus/SKILL.md` §11, measured 2026-09-19). No file read is needed to hold it.
- **The service asked for a contact.** The request was not an attack: a well-behaved client following Wikimedia's etiquette, with the nearest contact to hand.
- **No rule and no hook.** Nothing in §11, the §5 spawn template or any agent contract said the owner's identity stays off the wire, and no guardrail inspected outbound calls for it.
- **The gap was already written down.** §11 triad gap (1): *nothing here cuts the outbound leg* — `Bash` reaches the network. This is its first measured exploitation, by an obedient agent rather than an injected page.

## Corrective actions — state in this repo

| Action | State |
|---|---|
| `hooks/block-private-identifiers.sh` — PreToolUse hook that blocks an outbound call (`Bash` with a network keyword, `WebFetch`, `WebSearch`, any `mcp__*`) whose literal input carries an owner identifier, raw or URL-encoded. Fails closed without `jq`. | shipped, MRCS-DEV-66 |
| `hooks/test-block-private-identifiers.sh` — 14 cases on fake identifiers (an email and a full name); run by `scripts/diff.sh` on every call (exit bit 4). | shipped, MRCS-DEV-66 |
| Rule: never the owner's identity in a header, URL, query, search, form or MCP write — `skills/marcus/SKILL.md` §11 hard rule, §5 spawn-template `Outbound:` line, and one bullet in each of the seven `agents/*.md`. | shipped, MRCS-DEV-66 |
| `/marcus init` §4 guardrail 5 installs and declares the hook per project; §5 schema gains the optional `site` key and `guardrails.privacyHook`. | shipped, MRCS-DEV-66 |
| Install the hook globally on this machine (`~/.claude/settings.json`), so it covers repos that never ran `init`. | **open — owner decision** |
| Whether subagents should see `userEmail` at all. It is injected by the harness, not by this repo; removing it is not something a frontmatter key can do. | **open — owner decision** |

**The shipped generic User-Agent is config-derived, not a literal.** The source hook suggested a fixed bot string carrying the company name. The company name is scrubbed from this public repo (`scripts/snapshot.sh --check`), so the hook's block message and §11 both say `<company>Bot/1.0 (+<site>)`, built from `marcus.config.json` (`company`, `site`). With no `site`, the User-Agent carries no contact at all, never an email.

**What the hook does not do**, stated in its header: it sees only the literal call input — an identifier a script reads at runtime from a file, an env var or `git log` is not seen; its Bash check is a keyword prefilter; it fails open on empty or non-JSON input and on a hook timeout; and it blocks rather than redacts. Hardened in MRCS-DEV-66.1 after Linus's Stage 1: full names with inner spaces now match, the `mail` token no longer fires on `email`, and the prefilter covers the infra CLIs (`netlify`, `supabase`, `vercel`, `deno`, `dig`, `nslookup`, httpie `http`, any `gh` subcommand), matched as command words so a path segment such as `supabase/seed.sql` or `gh-pages` is not a call. The rule covers what it cannot see.

## Source

The original incident report: the owner's company-site repo, `docs/handoffs/2026-10-24-INCIDENT-owner-identifier-leak/README.md`.
