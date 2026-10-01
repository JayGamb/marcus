---
name: i18n-fr-en
description: "FR/EN bilingual method for the team's surfaces, where EN is a transcreation and not a translation: routing and locale precedence, namespace-per-voice catalogs, key naming, ICU plurals, Intl formatting in the shop's timezone, and the parity checks that prove it. Load before adding or changing any user-facing string, or when a locale bug is reported. Owner: Neo (implementation) with Dieter (copy)."
---

# FR / EN — the house method

**The premise that changes everything: EN is a transcreation.** The two catalogs are independent copy artifacts that share a key structure — not source and target. EN may have different sentence counts, different CTA phrasing, different emphasis. Consequences:

- Parity checks verify **keys and placeholder sets**, never text similarity.
- **Never machine-translate a key to fill a gap.** A missing EN string is a copy task, not a build fix.
- "Falls back to FR" on a customer surface is a visible defect. EN coverage is a hard requirement.

## Locale resolution

Precedence, always in this order: **explicit user preference (persisted) → `Accept-Language` → geolocation → default.** Geolocation alone strands a French speaker in London with EN and no way out. If location picks the default, a switcher is mandatory and the choice persists (storage + user row).

URL strategy: path prefix (`/fr/…`) when pages must be crawlable and linkable per locale — that is the marketing/site case, with `hreflang` and locale-aware canonicals. Context + persisted preference is enough for an auth-gated SPA.

**Locale must resolve outside React** — emails, edge functions, helpers. One module-level source the React provider also reads. Two independent states drift, and the drift shows up in email only.

## Namespaces carry the voice

Split catalogs per **surface sharing a voice register**, not per component. `admin.*` is tutoiement by definition; `shop.*` / `order.*` is vouvoiement. The namespace is the enforcement unit.

**Duplicate a string rather than share it across registers.** Shared strings are the main way "Ton panier" ends up on a customer page. Cross-register reuse is a bug, not DRY.

## Keys

`namespace.surface.element.variant` — structural, stable, describing **role not content** (`order.confirm.cta`, never `order.placeOrderButton`, never the English text as the key). Text-as-key orphans translations the moment copy is edited, and makes a transcreated EN indistinguishable from a missing one.

No dynamic key construction (`t('status.' + s)`) unless the variants are a typed union — otherwise extraction and unused-key detection go blind.

## Plurals, and why a ternary is always wrong

FR and EN both have `one`/`other`, but the boundaries differ: **French uses singular for 0** ("0 commande"), English uses plural ("0 orders"). A shared `n === 1` ternary is wrong in one of the two languages by construction. Use ICU `{count, plural, …}` with `other` always present; `=0` only when the zero case has distinct copy.

**Never assemble a sentence from fragments.** One key = one complete sentence with named placeholders. Word order and agreement differ.

## Dates, numbers, money, time

Everything through `Intl`, locale injected. Never a hand-rolled formatter, never a hardcoded `DD/MM/YYYY`, never a `['lundi', …]` array — weekday and month names come from `Intl.DateTimeFormat`.

**Locale, currency, and timezone are three independent inputs.** A CHF price for an EN user is `Intl.NumberFormat(locale, {currency})` — the locale does not imply the currency.

**Shop times format in the shop's timezone, not the viewer's.** Store UTC, format with an explicit `timeZone` from the shop record, or a 19:00 pickup reads 18:00 abroad. And `new Date("YYYY-MM-DD")` parses as UTC — it shifts the day. This has already shipped once.

## Checklists

**Before implementing** — namespace picked and its register unambiguous · locale reachable on every path the feature touches (component, helper, edge function, email) · currency/timezone/locale each have an identified source · **copy exists in both FR and EN before you start**, EN written not pending.

**Per string** — complete sentence, no concatenation · named placeholders · ICU plural for anything countable · register matches the surface (check verb forms and possessives) · **added to `fr` and `en` in the same commit** · identical placeholder set both sides · no date/number/price formatted inside the string · interpolated user content never translated or case-transformed in JS.

**Before shipping** — key parity, zero missing and zero orphan · no hardcoded literal in changed components · both locales walked in the browser on every changed screen · **layout survives the longer language** (FR runs 15–25% longer; short labels can double — `min-width` not fixed `width`, nav and table headers wrap) · dates and prices spot-checked in both locales and in the shop timezone · **empty, zero, error and toast states checked** — that is where untranslated strings survive longest.

## Failure modes

| Trap | Symptom | Fix |
|---|---|---|
| Sentence concatenated | Fine in FR, garbled word order in EN | One key, one sentence |
| `count === 1` ternary | "0 commandes" in FR, "1 items" in EN | ICU plural |
| Register leak via shared key | "Ton panier" on a client page | Duplicate into the right namespace |
| Key added to `fr` only | EN users see the raw key — invisible in dev because dev runs FR | Same-commit rule + CI parity + throw on missing in dev |
| Hand-rolled formatting | `1234.5 €`, `08/22/2026` on a FR screen | `Intl` behind one locale-injected util |
| Viewer timezone for shop times | Slot off by an hour for a traveling customer | Explicit `timeZone` from the shop |
| Locale only in React context | Emails and edge functions silently default | Module-level source |
| Fixed-width button / `whitespace-nowrap` nav | FR label truncated where EN fit | `min-width`, allow wrap, test the longest string |
| Missing key renders the key | `order.confirm.cta` visible in prod | Throw in dev/CI, fallback locale in prod |
| Geolocation with no switcher | User stuck in the wrong language | Preference above geo, switcher mandatory |

## Verification

Key parity — the highest-value check, belongs in CI:
```bash
diff <(jq -r 'paths(scalars)|join(".")' src/i18n/fr/<ns>.json | sort) \
     <(jq -r 'paths(scalars)|join(".")' src/i18n/en/<ns>.json | sort)
```

Placeholder parity — the only text-level invariant under transcreation:
```bash
jq -r 'paths(scalars) as $p | [($p|join(".")), (getpath($p)|[scan("\\{([a-zA-Z0-9_]+)")]|flatten|sort|join(","))] | @tsv' \
  src/i18n/{fr,en}/<ns>.json
```

Hardcoded strings:
```bash
grep -rnE '>[[:space:]]*[A-Za-zÀ-ÿ][^<>{}]{3,}<' src/ --include='*.tsx'
grep -rnE '(placeholder|title|aria-label|alt)="[^"{]{3,}"' src/ --include='*.tsx'
```

Register spot-check:
```bash
grep -rniE '\b(ton|ta|tes|tu |peux|veux)\b' src/i18n/fr/{shop,order}*.json   # tutoiement leaked to client
grep -rniE '\b(votre|vos|vous )\b'          src/i18n/fr/admin*.json          # vouvoiement leaked to admin
```

In the browser: each changed screen in FR and EN, comparing the longest label; remove a key temporarily and confirm the fallback renders rather than a raw key; set the browser to `en-US` against a `fr-CH` shop and confirm prices, dates and slot times still follow the shop.

No RTL language today — use logical properties (`text-align: start`, `ms-*`/`me-*`) where they are free, but do not build a `dir` layer for a need that does not exist.
