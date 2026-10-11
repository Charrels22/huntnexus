# HuntNexus — FE-17: Product Closure, factual pages and Hunt Detail runtime

Date: 2026-10-10 (America/Sao_Paulo). Continues docs/CHECKPOINT_2026-10-10_SESSION_ANALYZER_CLOSURE.md.

## Evidence-backed baseline
- Existing Profile, Set Main, Backpack, Weapon Proficiency, immutable session snapshots and private per-build comparison are preserved.
- Supabase `huntnexus_product_readiness_audit()` reports **9/9 backend contract checks passed**: **454 eligible hunts / 454 source-core complete**, **34 weapon proficiency trees**, **24 Powerful Imbuements**. This is a backend contract audit, not UI/real-play certification.
- `huntnexus_hunt_catalog_readiness_audit()` reports 459 catalog entries, 455 fixed spawns, 454 Planner-eligible; only **26 entries with observed sessions** and **22 with observed incoming damage**. Missing Tier C observations must not be shown as zero or fabricated.

## Corrected
1. Hunt Detail no longer turns unreported XP/h or Profit/h into zero. Factual elemental modifiers that are null no longer become `0%`; incoming damage missing percent does not draw a 3% fake bar or a `0` median Max DPS.
2. Creature Explorer no longer treats null element modifier as numeric immunity and does not render missing HP/XP as zero; labels distinguish canonical Tibia baseline from official RubinOT overrides.
3. Expanded `tests/cross-vocation-smoke.mjs` to use real Planner top hunt for EK/RP/ED/MS/EM and validate source-backed factual creatures and other Hunt Detail contracts; no fake test result or assertion that a human player has validated these cases.
4. **Root cause confirmed in Supabase PostgREST logs**: SQLSTATE `57014` statement timeouts in `huntnexus_optimizer_set_selection_universal` (and under parallel load `huntnexus_vocation_composition_universal`). Database role `authenticator` has `statement_timeout=8s`; a representative EK700 Cobra Bastion optimizer run took **18.43 s** at set_limit=100 and **14.50 s** at set_limit=30, so merely reducing the limit is not a trustworthy solution.
5. Backend `hunt_detail` fetches source factual + Tier C observed + defensive + imbuements + media without the expensive optimizer/spell composition. Full universal frontier moved to separate action `hunt_detail_setup` triggered only on Setup tab. Spells and composition moved to `hunt_detail_spells` triggered only on Spells tab. A failed frontier is clearly marked, can be retried and does not prevent reading hunt facts or Main/BP history.
6. Corrected critical API-RPC signature mismatch: `huntnexus_spell_candidates_with_unlocks_universal` requires `p_spell_group`, **not `p_attack_type`**. The previous mismatch caused an HTTP 502 independent of optimizer timeout.
7. Spells endpoint handles optional composition failure explicitly and returns the real eligible spell catalog without pretending composition was computed.

## Verification and boundaries
- Web CI passed at `38103608248` (new lazy Hunt Detail) and `38104011570` (cached lazy setup fix). Check the newest CI run before claiming latest code is green.
- Cross Vocation public smoke reached Hunt Detail but caught HTTP 502 for Spells while a previous deployment was still serving. Recheck after Wrangler version is updated; do not treat old smoke run as evidence about new code.
- Cloudflare Worker is deployed through Wrangler, but version metadata contains no Git SHA. Version number and timestamps alone do not establish commit parity.
- **Not solved:** the full universal set optimizer takes more than the production RPC statement timeout. Need proper performance optimization, caching, or a bounded asynchronous job model with rate limits and transparent completeness. Do not silently use a reduced candidate universe while marketing results as complete.
- **Not yet performed:** authenticated cross-device magic-link sign-in, browser visual inspection, and real player cases for EK/RP/ED/MS/EM.

## Next execution order
1. Finish/verify production Cross Vocation smoke for factual and spell routes. Diagnose actual RPC errors rather than relaxing assertions.
2. Fix universal optimizer 8-second timeout without degrading result quality. Keep frontend's lazy failure state meanwhile.
3. Add provenance-aware content completeness UX for hunts lacking Tier C observations; verify with real sourced examples.
4. Browser visual audit of Session Analyzer / Profile / Proficiency / Hunt Detail and real case fixtures for each vocation.
5. Auth synchronization and external class-community pilot only after the above gates.


## Runtime regression closure — 2026-10-10 23:08 BRT
- Public Cross Vocation Smoke rerun **38104067122, attempt 3: SUCCESS** at https://github.com/Charrels22/huntnexus/actions/runs/38104067122
- API published supported real-hunt checks at level 700:
  - EK sword: `cobra-bastion`, 11 factual creatures, 6 proficiency trees
  - RP bow: `iksupan-last-stand`, 3 factual creatures, 5 trees
  - ED rod: `nimmersatts-breeding-ground`, 3 factual creatures, 4 trees
  - MS wand: `podzilla`, 11 factual creatures, 4 trees
  - EM fist: `grounds-of-undeath`, 5 factual creatures, 6 trees
- All five cases reported imbuements, spell contracts and vocation composition available. This is catalog/HTTP regression, **not real gameplay or visual approval**.
- A real API mismatch in spell RPC arguments was fixed (`p_spell_group` instead of `p_attack_type`), and the script now checks the separated heavy endpoints' contracts without pretending the full optimizer is complete.
- Core Hunt Detail data loads independently of the expensive optimizer. The universal frontier is now an **explicit button** on Setup, not a mandatory query on tab open; private Main/BP data and hunt facts remain readable if the full optimizer times out.
- Backend optimizer RPC under `authenticator` has `statement_timeout=8s`, while EK700/Cobra Bastion direct query takes around 18.43 seconds at 100 sets (and still >8 seconds with smaller caps). **Not production-ready**. Do not silently lower the candidate universe or advertise a full validated winner.
- Web CI **38104067099** and Player Session/Profile/Inventory Smokes **38104067079**, **38104067040**, **38104067050**: SUCCESS on the fixed RPC argument commit. Verify latest Web CI for subsequent explicit button change.
