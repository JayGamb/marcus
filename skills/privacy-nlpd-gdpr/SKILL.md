---
name: privacy-nlpd-gdpr
description: "Privacy method for Swiss + EU products (nLPD/FADP and GDPR) on a Supabase/Netlify stack: build the data map from the system rather than from memory, decide retention and lawful basis, cover the four data-subject rights as code paths, and run the checks that prove a deletion actually deleted. Load before shipping any feature that touches personal data, adding a vendor, or writing a privacy notice. Owner: Linus (review), Ada (implementation)."
---

# Privacy — nLPD + GDPR on our stack

Real personal data today: customer names, phone numbers, email addresses, uploaded reference photos, shop-owner accounts. Swiss company, EU customers → **both frames apply**. Running the GDPR analysis satisfies nLPD too; the reverse is not true.

## 1. The data map — enumerate from the system, never from memory

*"We don't store that"* is a hypothesis to disprove.

| Store | How to enumerate |
|---|---|
| Postgres | `information_schema.columns` — and read every migration, not just current schema |
| Free-text / JSONB | **Sample real rows.** `owner_notes`, kitchen notes and `metadata` hold unclassified PII |
| Object storage | Buckets **and object paths** — names and phone numbers leak into filenames |
| Auth | `auth.users`, `auth.identities`, OAuth provider payloads, refresh tokens |
| Logs | Postgres, edge functions, Netlify functions and access logs, error payloads |
| Analytics | Event props, `$current_url` query strings, person properties, session recordings |
| Email provider | Message bodies, recipient lists, webhook payloads, bounce/suppression lists |
| Backups | PITR window, manual dumps, anything on a laptop |
| Third parties | Every outbound host in the code, every processor with an account |

Moves that find what schema-reading misses: grep for identifier-shaped names (`email|phone|tel|name|address|photo|ip`) · grep for `console.log` / logger calls near request bodies · **diff the fields a form POSTs against the columns actually used downstream** · list every external domain the client and edge functions call.

Classify on three axes: **type** (direct identifier · quasi-identifier — postcode + date + city re-identify in combination · sensitive/*données sensibles* · content — **uploaded photos may carry EXIF GPS, faces, and third parties who never consented**) · **purpose** (the one job it does; "might be useful" is not a purpose) · **reach** (which stores, including derived copies).

**Output, one row per field:** `field → stores → purpose → basis → retention clock → delete path → processor(s)`. Everything downstream — DSAR, deletion, retention jobs, the nLPD register — is generated from this table. Regenerate after any migration; free-text and log fields drift.

## 2. Decisions

| Decision | What decides it | Default when unsure |
|---|---|---|
| Collect at all | Name a purpose, a reader, and an expiry **before** adding the column | Don't. Adding later is cheap; deleting everywhere is not |
| Granularity | Coarsest form that serves the purpose | Coarser |
| Retention | Clock starts at **purpose-end**, not creation. Swiss 10-year accounting retention covers **invoices**, not reference photos or phone numbers | Delete at purpose-end; keep only the accounting subset |
| Lawful basis | Contract for order fulfilment · consent for marketing and non-essential analytics · legitimate interest only with a written balancing test and a working opt-out | Contract or consent |
| nLPD framing | No Art. 6 basis list; it requires transparency at collection, proportionality, purpose limitation, and **explicit consent for sensitive data and high-risk profiling** | Run the GDPR analysis anyway |
| Consent vs LI | **If "no" would break the product's core promise, it is not consent** — stop calling it that | Consent, purpose-scoped and versioned |
| Processor agreement | Any vendor touching personal data on our behalf needs a DPA. Here: Supabase, Netlify, the email provider, analytics. New vendor = map entry + DPA + notice update, or it does not ship | Block the integration |
| Cross-border | Swiss export needs an adequate destination (EU/EEA is adequate) or SCCs **with the Swiss addendum**. US needs Swiss–US DPF or SCCs | Pick the vendor's EU/CH region — it removes the question |
| Anonymous vs pseudonymous | Reversible with a key we hold, or re-identifiable from quasi-identifiers → still personal data | Call it pseudonymous, keep it in the map |

## 3. Checklists

**Per feature touching personal data** (blocking in review) — every new field in the map with purpose, basis, retention, delete path · coarsest sufficient granularity · read path RLS-gated or a definer RPC returning only the caller's rows · minimum columns, no `select *` · **nothing personal in URLs or query strings** (they reach analytics, logs, referrers) · request bodies, error objects and webhook payloads not logged verbatim · uploads: private bucket, path-scoped policy, **non-guessable key that is not the customer's name**, short-TTL signed URLs, EXIF stripped · new outbound vendor → DPA + region + notice line, or it does not ship · **the deletion routine extended to cover the new field, with a test asserting it** · the retention job knows about it, or it never expires.

**Pre-launch** — map regenerated against production reality · privacy notice matches the map field for field (categories, purposes, retention, recipients, transfers, rights, controller contact) · nLPD register of processing activities written (small companies are exempt *except* for sensitive data or high-risk processing — **uploaded photos and health-adjacent order notes can pull you in**; it is one page from the map) · DPIA if high risk · **deletion executed end-to-end against a seeded real user, then verified by scan** · export path produces a complete machine-readable file · analytics in EU/CH region with inputs masked, no PII in event props, and the consent gate blocking the network call *before* consent · breach runbook: notify FDPIC as soon as possible (nLPD) **and** the supervisory authority within 72 h (GDPR) where EU residents are affected, documented even when not notifiable · backup retention window written down and reconciled with the deletion promise · prod data access enumerated (who holds `service_role`, who can open the SQL editor) and minimal.

**The four rights, as code paths, not inbox work**
- **Access** — one query set per store in the map, assembled into an export, including derived and analytics data plus retention/recipient metadata. 30 days.
- **Deletion** — ordered fan-out: rows → storage objects → auth user → analytics person → email provider contact and suppression list → cached copies. Idempotent, retried, per-system ACK, audit record. **Legally retained items are explicitly listed as kept with the reason**, never silently skipped.
- **Portability** — the contract/consent data the person supplied, structured and machine-readable, photos as files.
- **Rectification** — a real edit path plus propagation. If a corrected value cannot reach a downstream copy, that copy should not exist.
- Identity verification for all four, **without collecting new identity documents**.

## 4. Failure modes

| Symptom | Fix |
|---|---|
| Order row deleted, reference photo still in the bucket | Deletion is a transaction across DB **and** storage; enumerate objects by owner prefix, delete, then re-list to confirm. A DB cascade never touches buckets |
| `auth.users` deleted but profile/orders remain, or the reverse | One orchestrated routine, tested both directions |
| PII in logs — full request bodies, error payloads, `console.log(formData)` | Log identifiers not payloads; redact at the logger; shorten provider log retention. **Assume logs are outside the delete pipeline unless proven otherwise** |
| Analytics captures emails from autocapture, URL params or replay | Mask inputs by default, allow-list what is captured, strip query strings, delete the person profile as part of DSAR |
| Consent stored but never checked | Gate at the network call site, not the settings screen. Test: opt out, assert zero outbound requests |
| Third-party script or CDN font loads before consent | Self-host what you can; load trackers only after consent; verify on a fresh profile |
| Backups outlive the deletion request | Written policy: backups are not re-mined, restores replay a deletion tombstone list, the window is short and disclosed. **Do not claim instant erasure you cannot perform** |
| "Anonymised" export still has postcode + date + order details | That re-identifies. Aggregate to a real k, or keep treating it as personal data |
| Public bucket, or year-long signed URLs pasted into emails | Private bucket + policy + minutes-long URLs |
| Edge function uses `service_role` and returns more than the caller owns | Service-role code re-implements the ownership filter explicitly; review every call site as a privilege boundary |
| Email provider retains full order bodies indefinitely | Check its retention setting, minimise the body, include the provider in the deletion fan-out |
| Deploy previews or seed data contain real customer records | Never copy prod personal data to non-prod; generate fakes or mask on export |
| A vendor added by a quick integration never entered map, notice or DPA | Vendor addition is a reviewed change, same as a migration |
| Data past retention lingers | Scheduled job that **reports how many rows and objects it deleted**; alert when it reports zero for suspiciously long |

## 5. Verification — a claim without an executed check is worthless

- **Map complete** — diff live `information_schema.columns` + bucket listing against the map. Any unmapped column or bucket is a finding. Run it in CI.
- **No PII in logs** — grep a real log window for `@`, phone patterns, and known seeded test values. Zero hits, or a redaction bug.
- **Deletion works** — seed a canary customer with an order, a photo, an auth account, an analytics event and an email. Run deletion. Then **independently** query every store for the canary's identifiers and list the bucket prefix. Non-empty = incomplete pipeline. Keep the run as audit evidence.
- **RLS protects it** — query with an anon key and with a second user's JWT, expect zero rows. Test policies, do not read them.
- **Consent gates it** — load with consent denied, inspect the network log for the analytics host, then accept and confirm it fires.
- **Uploads private** — open a stored object URL unauthenticated and from another account, expect denial. Check a downloaded file's EXIF for GPS.
- **Anonymised** — join the release against a plausible auxiliary set on quasi-identifiers and count unique matches. **Any singleton kills the label.**
- **Retention enforced** — query for rows older than the stated limit. Non-zero means the clock is decorative.
- **Export complete** — compare the export's fields against the map for that person. Anything in the map and missing is a rights gap.
- **Transfers covered** — list every processor with region and legal instrument. A vendor without a row is an undocumented transfer.
