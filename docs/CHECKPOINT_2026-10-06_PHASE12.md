# Checkpoint — 2026-10-06 — Phase 12

## Ranking v2

`0027_level_relevance_ranking.sql` validated successfully.

Representative EK/RP/ED tests expose:
- performance_score
- confidence_score
- level_fit_score
- evidence_fit_score
- ranking_score
- level_evidence_label

Canonical minimum level remains the hard eligibility gate.
Observed player level is soft evidence.

## Incoming damage

`0028_huntanalyser_incoming_damage.sql` and `0029_defensive_analytics.sql` are active.

All 100 stored HuntAnalyser public detail snapshots were processed:
- sessions processed: 100
- errors: 0
- subjects with Input Damage: 82
- element rows: 395
- monster-source rows: 295
- element rows linked to players: 395/395
- subject elemental totals matching source total: 82/82
- resolved monster sources: 294/295
- canonical hunts with observed incoming damage: 22

The only unresolved damage source is `Icicle`, preserved as raw.

## Defensive equipment

`0030_defensive_item_candidates.sql` was applied successfully.

It combines:
- observed incoming-damage weights
- normalized item protections
- vocation compatibility
- level eligibility
- equipment slot

Candidate-output validation is still pending because the Lovable Free-plan database action limit was reached immediately after application.

## Recommendation composition

Created:
- `0031_recommendation_preview.sql`
- `api/RECOMMENDATION_PREVIEW.md`

The preview composes:
- ranking evidence
- factual hunt profile
- observed performance and kill mix
- defensive item candidates

It is not the final recommendation engine.

## Resume

1. Validate `0030` on hunts/vocations with observed incoming damage.
2. Apply `0031_recommendation_preview.sql`.
3. Test preview end-to-end.
4. Build offensive equipment candidates.
5. Add imbuements.
6. Add spell/rotation guidance.
7. Add boss-room mechanics/build layer.
8. Apply exact RubinOT overrides as they are resolved.
