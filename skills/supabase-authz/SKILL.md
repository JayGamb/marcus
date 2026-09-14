---
name: supabase-authz
description: "Authorization method for Supabase multi-tenant products: RLS as the gate, SECURITY DEFINER functions for anonymous paths, session and token decisions, OAuth redirect allow-lists, account linking, first-admin bootstrap, role escalation, and the negative tests that actually prove isolation. Load before touching any policy, RPC, auth flow, storage bucket, or role. Owner: Ada (implementation), Linus (review)."
---

# Supabase authorization — the house method

## Pick the smallest model that expresses the rule

| Rule | Model | Where it lives |
|---|---|---|
| "Owner sees only their rows" | ownership | RLS policy `user_id = auth.uid()` |
| "Anyone may read a published shop" | public read | `SECURITY DEFINER` function, **no table grant** |
| "Staff edits menu, owner edits billing" | role | `role` on a membership table, read inside the policy |
| "Editable only while status = draft" | state | predicate in the same policy, not in app code |

## The five rules that prevent most incidents

**1. The database is the gate.** Every table gets RLS enabled and a policy *before* it gets a row. RLS off = public to anyone holding the publishable key.

**2. Identity comes from the token, never from input.** `auth.uid()`. Never accept `user_id` / `shop_id` from a request body as the authorization subject. A parameter may **narrow** a query, never **widen** it.

**3. The client is never the authority.** A hidden button, a route guard, a `.eq('user_id', id)` in `api.ts` — all UX. Assume the attacker calls PostgREST directly with the anon key.

**4. Anonymous paths are functions, not tables.** Public reads go through `SECURITY DEFINER` functions returning exactly the columns the public may see. Never grant anon `SELECT` "because the RPC needs it".

**5. Every `SECURITY DEFINER` is a hole you cut deliberately.** It bypasses RLS. For each one: `SET search_path = public, pg_temp` · `REVOKE EXECUTE … FROM PUBLIC` then `GRANT` to the intended role only · validate every argument · return an explicit projection, never `SELECT *`, never internal ids or costs.

**Write paths through functions need their own authorization.** A definer insert (`create_order`) runs as the definer — it must re-check everything itself: shop exists and is open, slot free, base/filling belong to the product type, price recomputed server-side. RLS will not do it for you.

**Avoid policy recursion.** A policy that queries another RLS-protected table can recurse or deadlock. Put the lookup in a `STABLE SECURITY DEFINER` helper (`is_owner_of(shop_id)`) and call that.

**Storage is a separate authorization system.** Every bucket private by default; policy keyed on a path convention (`{user_id}/…`), enforced on upload. Signed URLs live minutes, not months — any URL that reached an email is permanently disclosed.

**Edge functions** verify the caller's JWT and act *as that user* (forward the Authorization header). `service_role` only for genuinely system-level work, and **never let a request parameter choose whose data a service-role call touches**.

## Decisions to record in an ADR (with the rejected option written down)

- **Session storage** — cookie-backed over `localStorage` where XSS risk is non-trivial. Decide before shipping; migrating later logs everyone out.
- **Token lifetime** — short access token (≤1 h, 15 min if blast radius matters), rotating refresh with reuse detection. Sign-out must **revoke server-side**, not just clear local state.
- **Claims** — JWTs are readable by anyone holding them. Identifiers only: no secrets, no PII, no prices. A claim a policy reads (`role`, `shop_id`) must be set by a server-side auth hook, never writable by the user.
- **Redirect allow-list** — exact match, enumerated per environment: localhost, branch/preview deploys, staging, apex **and** `www`. No wildcard a subdomain takeover could claim. Provider console, auth settings and the app's `redirectTo` must agree — three places, one list.
- **Account linking (same email, two providers)** — auto-linking on email match is an account-takeover vector. Link only when the incoming provider asserts `email_verified` **and** the existing email is verified; otherwise force sign-in with the original method and link from an authenticated settings page. Never on email string match alone.
- **First-admin bootstrap** — never "first signup becomes admin" on a public URL. Best first: seed in a migration · one-shot invite token · manual promotion. Close the path after use, and audit it.
- **Invitations** — email + role + single-use token + short expiry + inviter id. Accepting requires a session whose email matches. Token deleted on accept. **You cannot invite above your own role.**
- **Role escalation paths** — enumerate every way a role can change (signup trigger, invite accept, admin UI, support action); each is a server-side function with its own check. `role` is never client-writable and never a trusted function argument.

## Checklists

**Per protected table / RPC** — RLS enabled · a policy per operation you intend to allow · subject is `auth.uid()` or a claim, not a parameter · **`USING` and `WITH CHECK` both present on writes, and matching** (a missing `WITH CHECK` lets a row be moved to another owner) · columns are a deliberate projection · anon has no direct grant unless intentionally public · if definer: `search_path` pinned, grants narrowed, args validated, business rules re-checked · rate limiting on anything anon can call (order creation, availability, `username_available` — that one is an enumeration surface) · **a negative test exists**.

**Per new role** — written definition of read/write/grant · every existing policy reviewed against it (a new role silently inherits whatever a permissive policy allows) · assignment path server-side and authorized · cannot grant itself or higher · removal revokes access immediately · three tests: positive, negative, escalation attempt.

**Pre-launch** — enumerate every table and read its policies aloud against intent · enumerate every definer function and execute grant · enumerate every bucket and its policies · try a rogue redirect and confirm rejection · password reset and email-change tested for enumeration phrasing and single-use tokens · **grep the built bundle for `service_role`** · run the platform security advisors and resolve or write down every finding · auth events logged with actor, target, source.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Owner A sees B's rows in prod, not in tests | Tests ran as `service_role`, which bypasses RLS | Test through the anon key with a real user JWT |
| Table returns rows to any anon key holder | RLS never enabled, or a scaffolding `USING (true)` left behind | Enable RLS; grep policies for `true` and missing predicates |
| A user moves their row to another account | `USING` without `WITH CHECK` | Add `WITH CHECK` with the same predicate |
| Policies recurse or stack overflow | Policy queries an RLS-protected table | Extract into a `STABLE SECURITY DEFINER` helper |
| Auth account exists, profile row missing, user lands in a broken app | `handle_new_user` raised and the failure was swallowed | Defensive idempotent trigger, **tested on a Supabase branch before prod**, plus a query for orphaned auth users and a repair path |
| OAuth works locally, fails on preview deploy | Allow-list missing that environment | Enumerate all environments; add it to the deploy checklist |
| A user becomes admin unbidden | `role` client-writable or trusted as a function argument | Remove from client-writable grants; derive server-side |
| Public page leaks internal data | Definer function returns `SELECT *` | Explicit column list |
| Definer function does something unintended | `search_path` unpinned — a caller-controlled schema shadowed a function | `SET search_path = public, pg_temp` |
| Signed-out user still has API access | Sign-out cleared client state only | Revoke server-side; keep access TTL short |

## Verification — the negative test is the one that matters

A passing positive test proves the feature works, not that the rule holds. Write the trio per rule:

1. **Positive** — the owner reads/writes their row, succeeds.
2. **Negative** — a *second real user*, authenticated with their own token, queries the first user's row by id. **Assert `data.length === 0`, not the absence of an error** — RLS filters silently, so an empty successful query is the pass condition and a returned row is the failure.
3. **Anonymous** — same query, no session, nothing back.

Run them with the **anon key** plus each user's session. Anything using `service_role` proves nothing about policies. Seed **two** users and two shops — a one-user fixture cannot fail a cross-tenant test.

Then: every public RPC called anonymously with its column set snapshotted, and called with hostile arguments (another shop's id, a closed shop, a past slot, a negative quantity, a price field) asserting refusal · every write path attempting to set `role` / `user_id` / `shop_id` / price directly, asserting ignored or rejected · storage upload to another user's prefix and fetch of their object, both refused · an unregistered `redirect_to` rejected, a reused invite or reset token rejected · the signup trigger exercised through the auth API (not a direct insert) with duplicate email and unusual provider payloads, asserting no orphan.

**Re-run the whole negative suite after any migration that adds a table, column, policy, role, or definer function.** That is exactly when isolation regresses.
