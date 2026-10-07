# Checkpoint — Phase 16.2 — 2026-10-06

## Applied in database

- 0034_recommendation_preview_v2.sql
- 0035_core_spell_catalog.sql
  - schema applied
  - candidate function applied
  - spell rows inserted in four batches: EK, RP, ED, MS
- 0036_boss_room_foundation.sql
- 0037_recommendation_preview_v3.sql
- 0038_canonical_boss_sync.sql

The canonical boss sync call was attempted immediately before the Lovable Free-plan database action limit closed. Its result was not returned, so rerun it idempotently and validate counts before assuming sync completion.

## Prepared in GitHub, not yet applied

- 0039_boss_reconciliation_guards.sql
- 0040_boss_spell_evidence.sql
- 0041_boss_build_preview.sql
- 0042_rubinot_v13_9.sql

## RubinOT current release

Official changelog on 2026-10-06 reports:
- client v4.064 — 12 changes
- server v13.9 — 36 changes

Relevant visible changes:
- Forked Thorns / Forked Glacier range-targeting behavior corrected based on monster proximity.
- Familiar creation corrected in some boss rooms.
- Boss instances added for Bloodback, Darkfang, Sharpclaw, Black Vixen and Shadowpelt.
- Equipment Preset support added for Shield of the White Knight.

## Boss reconciliation

Official RubinOT changelog states:
- v13.7: all Soul War boss fight mechanics were completely reworked.
- v13.8: Magma Bubble fight mechanics were completely reworked.

Therefore final boss builds for these encounters must remain unavailable until exact current RubinOT mechanics are reconciled.

## Resume order

1. Rerun huntnexus_sync_canonical_boss_profiles().
2. Validate spell count and boss profile count.
3. Apply 0039.
4. Run huntnexus_refresh_boss_groups().
5. Apply 0040.
6. Apply 0041.
7. Apply 0042.
8. Test:
   - regular hunt preview v3
   - EK/RP/ED/MS spell candidates
   - lever-boss restricted spell filtering
   - Magma Bubble readiness guard
   - Soul War readiness guards
   - canonical boss spell evidence.
