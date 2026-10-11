# HuntNexus FE-20 — Real source evidence and canonical account recovery
Date: 2026-10-11 (America/Sao_Paulo).

## Completed: community observation evidence across 5 vocations

Read-only aggregate production audit of `community_sessions` and `session_players`:
- **100 community sessions**, all with a source URL, 68 with a resolved hunt key. Party members may cause the same session to appear under several vocations.
- Per-vocation distinct participating sessions / resolved distinct hunts:
  - EK: 53 / 12
  - RP: 47 / 13
  - ED: 51 / 12
  - MS: 31 / 5
  - EM: 16 / 6
- Chosen real-source vocation/hunt fixtures: EK Cobra Bastion 7, RP Iksupan Last Stand 1, ED Nimmersatt's Breeding Ground 5, MS Podzilla 7, EM Grounds of Undeath 2, counted as distinct community sessions with a participant of that vocation.
- `tests/sql/phase72_real_community_vocation_evidence.sql` executed in production **PASS**. Validates source URLs, positive duration, observed XP/h, Tier C methodology, sample counts and honest null on a nonexistent hunt.
- Public Cross Vocation HTTP Smoke extended to validate Tier C methodology, nonzero source-backed samples and sample provenance. Latest green rerun: https://github.com/Charrels22/huntnexus/actions/runs/38150842194

### New per-vocation sample (do not conflate party XP and individual XP)
- Migration **0155** applied: `huntnexus_hunt_vocation_observation_sample(hunt_key,vocation)` with service-role-only privileges. Returns observed session counts from real sources and median XP/h and Balance/h **only if there are at least 3 source-backed metric observations**.
- Five-class production sample response: EK 7 (median shown); RP 1 (median null); ED 5 (shown); MS 7 (shown); EM 2 (median null). Party-level XP is never claimed as belonging to the individual class member.
- New `hunt_detail.data.vocation_observed` is separated from `observed.performance` (all vocations pooled). The Hunt Detail UI labels the pooled sample and has a vocation-specific Tier C sample panel. Null remains unknown, not 0.
- Public test `tests/cross-vocation-smoke.mjs` asserts exact sample scope and absence of low-N median estimates; `web/app/tests/frontend-live-browser-smoke.mjs` captures the Community panel.
- Security: `anon`/`authenticated` cannot directly execute the new RPC, `service_role` can. Nonexistent hunt yields n=0 and null medians.

## Completed: real database-backed canonical client recovery
- `tests/sql/phase73_account_canonical_private_data_recovery.sql` executed in production **PASS** with isolated random synthetic fixtures and cleanup. A second canonical device resolved to the first device's saved Profile, EK Main weapon and backpack item. A competing account could not claim that canonical client ID. Unbind did not delete the saved private data.
- Migration **0154** applied: user-scoped transactional advisory lock serializes initial canonical binding and unbinding. Two distinct concurrent RPC invocations for the same synthetic auth user correctly returned one canonical client ID; one binding row existed afterward, then the fixture was deleted. This avoids concurrent first-device 502 due to uniqueness.
- `web/app/src/routes/account.tsx` explicitly explains that guest data are not merged. When an existing account displaces a local unbound guest client ID, the browser checks for saved Profile, Main/BP or sessions; it stores a recoverable guest client ID only if it finds data. After logout, the user can explicitly resume that guest identity without changing the account's canonical data. The account does NOT merge guest data automatically.
- Browser QA extended to check the guest recovery button, local client-ID restoration and removal of the pending marker without pretending a real Magic Link was tested.

## Source tier and privacy guarantees
- **Tier A**: official RubinOT source; **Tier B**: canonical Tibia reference; **Tier C**: player/community observations; **Tier D**: editorial interpretation.
- Public observations remain Tier C and separate from private `player_hunt_sessions`. No private session was published, no fabricated player fixture inserted into community evidence, and no source-less median was created.

## Outstanding release gates
1. Latest Web CI/browser run and returned Tier C public contract must be checked after code deployment; Wrangler timestamp is not a Git commit marker.
2. Real Magic Link delivery, browser A/B credentialed sign-in, and Profile/Set Main/BP recovery on two devices need a real consenting test user. The SQL fixture tests **database logic**, not email or browser session authentication.
3. Real player analyzer imports for EK/RP/ED/MS/EM, with class members reviewing setups and live game outcomes, remain undone. Tier C imported tracker entries are not equivalent to a player-supplied Hunt Analyzer raw text fixture.
4. Review the browser screenshots manually for aesthetics and sprite completeness; current browser QA verifies headings, responsiveness, runtime exceptions and important interactions.
5. Keep limiter and data security monitoring before opening invitations to the broader community.
