# Checkpoint — 2026-10-07 — HuntNexus MVP + Phase 18/19

## Database active and validated

### Product/API
Applied:
- 0043_api_lookup_functions.sql
- 0045_fix_rubinot_warning_view_order.sql

Smoke confirmed:
- creatures: 2,193
- hunts: 459
- items: 6,470
- bosses: 548
- spells: 39
- community sessions: 100
- blocked bosses: 9
- Soul War members: 8
- RubinOT server: v13.9
- RubinOT client: v4.064
- ED unresolved spell warnings: 2
- global boss-system warnings: 1
- health RPC: OK
- hunt search RPC: OK
- boss search RPC: OK

Recommendation Preview v3 was validated end-to-end:
- EK 700 / XP / Solo
- first hunt: Cobra Bastion
- ranking_score: 0.776
- confidence_score: 0.848
- defensive candidates: 17
- defensive imbuements: 2
- spell candidates: 4

Boss Build Preview validated:
- Magma Bubble blocked by v13.8 guard
- Goshnar's Hatred blocked by Soul War v13.7 guard
- Chivalrous Challenge appears as boss-restricted for EK
- Divine Dazzle appears as boss-restricted for RP

## Lovable MVP implementation

Lovable commit:
- 380f51a7ef60a19266f6056d8bb2df941a5c37d5

Implemented:
- POST /api/huntnexus server route
- service-role Supabase usage remains server-only
- actions:
  - health
  - search_hunts
  - search_bosses
  - recommend
  - boss_build
- Hunts UI
- Bosses UI
- product name changed to HuntNexus
- pt-BR HTML language
- robots noindex
- dark theme
- no project publication

Lovable's own execution validated:
- typecheck passes
- health endpoint
- recommendation endpoint
- boss preview endpoint
- invalid input rejection
- non-POST rejection

Full browser click-through could not be completed because Lovable agent credits ran out immediately afterward.

Known pending Lovable UI correction:
- defensive incoming damage payload uses `weight`;
- canonical GitHub patch already displays it as `Math.round(weight * 100)%`;
- this one-line correction is not yet applied to the Lovable live preview.

## GitHub canonical mirror

Current Lovable implementation mirrored under:
- web/lovable-live/src/routes/index.tsx
- web/lovable-live/src/routes/api/huntnexus.ts
- web/lovable-live/src/routes/__root.tsx
- web/lovable-live/README.md

Canonical next patch:
- web/lovable-patch/src/routes/index.tsx
- web/lovable-patch/src/routes/api/huntnexus.ts
- web/lovable-patch/src/routes/__root.tsx

Project Knowledge in Lovable was updated with:
- HuntNexus naming rules
- trust tiers
- current architecture
- boss guards
- source-of-truth rules
- current data counts
- do-not-publish rule

## Phase 18 — loadout candidate matrix

Prepared:
- 0046_loadout_candidate_matrix.sql
- 0047_recommendation_preview_v4.sql

Compatibility fix applied:
- 0048_fix_loadout_imbue_slots.sql

0047 was applied.

The matrix validation was blocked by the temporary Lovable DB action limit immediately after application.

Additional quality filter prepared, not yet applied:
- 0049_filter_loadout_equipment.sql

Purpose:
- keep defense/offense/imbue dimensions separate
- avoid arbitrary single equipment score
- remove irrelevant catalogue items from loadout candidates

## Phase 19 — factual boss combat

Prepared, not yet applied:
- 0050_boss_factual_combat.sql

Adds from existing Tier B creature detail:
- attack_type
- abilities_raw
- max_damage
- uses_spells
- observed_at

Does not clear RubinOT guards.

## Tests prepared

- tests/sql/phase16_17_smoke.sql
- tests/sql/phase18_19_smoke.sql

## Resume order

1. Apply 0049_filter_loadout_equipment.sql.
2. Validate huntnexus_loadout_candidate_matrix on Cobra Bastion EK700.
3. Confirm Recommendation Preview v4.
4. Apply 0050_boss_factual_combat.sql.
5. Run tests/sql/phase18_19_smoke.sql.
6. When Lovable agent credits return, apply the one-line incoming damage weight UI fix.
7. Run full browser click-through:
   - EK700 XP Solo
   - ED1000 Balanced x4
   - Magma Bubble EK700
   - Goshnar's Hatred ED1000
   - Scarlett Etzel RP700
8. Do not publish.
