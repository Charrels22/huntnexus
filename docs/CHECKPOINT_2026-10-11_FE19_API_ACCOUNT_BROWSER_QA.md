# HuntNexus — FE-19: Distributed API Guard, Account Isolation, Browser QA

Date: 2026-10-11, BRT.

## Scope and completed implementation

### Advanced optimizer protection
- `db/migrations/0153_optimizer_distributed_admission.sql` applied in the production Supabase project. Introduces service-role-only, RLS-protected `huntnexus_optimizer_rate_state` and `huntnexus_optimizer_leases` with atomic global admission protected by `pg_advisory_xact_lock`.
- Configured **2 global active computations**, **1 per caller**, **12 starts per caller per 10 minutes**, **35-second expiring lease**; database functions release leases after requests finish, with automatic expiry as fallback.
- The Cloudflare Worker never writes caller IPs to the database; caller identity is HMAC-SHA256 keyed by the pre-existing server-only Supabase secret over the Cloudflare-injected `cf-connecting-ip`. The arbitrary browser `client_id` is not used for quotas; if no trusted header exists, unknown callers share a conservative fallback identity.
- Applies the same admission guard to both `hunt_detail_setup` and `final_optimizer`, so the second API action cannot bypass global/per-subject protection.
- Responses exceeding concurrency or start quota return HTTP 429, `Retry-After`, localized explanation and no IP/HMAC value. Regular factual APIs, profile and sessions do not consume advanced-computation permits.
- SQL verification: 2 distinct callers admitted, same caller denied (`subject_busy`), third denied (`global_busy`), freed slot reusable; 12 starts permitted, 13th denied (`rate_limit`). Fixture rows cleaned. Anonymous/authenticated roles cannot execute the admission RPC; only service role can. After live HTTP tests, no leaked database leases remained.
- **Public live concurrency + bypass smoke PASSED**, latest rerun:
  https://github.com/Charrels22/huntnexus/actions/runs/38146498954
  It verifies the first real optimizer completes, a second same-origin setup gets 429, a concurrent `final_optimizer` also gets 429, the `health` endpoint stays available, and `Retry-After` is present.
- Web CI on the shared-admission implementation PASSED:
  https://github.com/Charrels22/huntnexus/actions/runs/38146462364

### Account / guest identity
- `web/app/src/routes/account.tsx`: `useRef` lock prevents concurrent account-resolve attempts from `getSession` and auth-state callbacks; a token freshness check stops stale resolve responses from overriding an already signed-out identity.
- On authenticated logout, a **new random guest client ID** is generated. Private saved data stays linked to the prior authenticated account rather than appearing in guest mode or causing misleading 401s under the old canonical client ID.
- An unsaved raw Session Analyzer draft and its transient open-session marker are cleared at logout to avoid exposing names/combat stats in guest mode. The UI explains the behavior explicitly.
- Account negative-auth HTTP smoke PASSED:
  https://github.com/Charrels22/huntnexus/actions/runs/38146720864
  `account_status`, `account_unbind` and `account_resolve` reject invalid tokens (401). This is **NOT** a real Magic Link delivery / cross-device authentication test.

### Real browser frontend check
- Initial Cloudflare Browser Rendering accessibility tree for `/account` successfully confirmed rendered navigation, guest state and sign-in form.
- Automated headless Chromium test `web/app/tests/frontend-live-browser-smoke.mjs` and GitHub workflow `huntnexus-frontend-browser-qa.yml` verify **live production** pages Account, empty Profile, Session Analyzer, Planner, Cobra Bastion Hunt Detail, lazy Setup; also mobile Account and Hunt Detail at width 390px.
- The test checks expected headings, browser JS exceptions, horizontal overflow and avoids triggering the universal optimizer without user interaction.
- First live browser QA PASSED with **eight screenshots**, stored in GitHub Actions artifact `huntnexus-live-frontend-qa`:
  https://github.com/Charrels22/huntnexus/actions/runs/38147028268
- Browser QA now triggers automatically on changes to important Account/Profile/Analyzer/Planner/Hunt Detail screens, in addition to workflow/script changes.
- Screenshot generation + structural browser checks are verified; screenshots still require subjective visual assessment. Logged-out Magic Link flow was not authenticated.

## Remaining gates (do not claim 100%)

1. Verify current browser QA and Web CI on the latest Account draft-cleanup commit and visually review the screenshot artifact. Don't infer direct deployment SHA parity solely from Wrangler timestamps.
2. Sign in through an actual Magic Link on device A, recover canonical client ID and saved Profile/Set Main/BP on device B, sign out, confirm guest identity isolation and no private draft residue.
3. Validate real session analyzers, contextual build and actual item images/perks for EK, RP, ED, MS and EM with source-linked player fixtures.
4. Load test admission under multiple distinct IPs, monitor global 429 rate and tune quotas prior to external invitation. Optimize full universal set compute beyond current ~7–11 second single-case response.
5. Continue Supabase security/performance advisor remediation with change-impact review; in particular existing `pg_net` extension warning.
