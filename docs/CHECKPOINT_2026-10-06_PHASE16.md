# Checkpoint — Phase 16 — 2026-10-06

## Confirmed active and validated

- 0027 level-relevance ranking
- 0028 HuntAnalyser incoming damage
- 0029 defensive analytics
- 0030 defensive item candidates
- 0031 recommendation preview v1
- 0032 offensive equipment evidence
- 0033 imbuement candidates

### Data state

Incoming damage:
- 100/100 HuntAnalyser detail snapshots processed
- 0 errors
- 82 linked subjects
- 395 elemental rows
- 295 monster-source rows
- 395/395 elemental rows linked to player
- 82/82 subject elemental sums match source totals
- 294/295 monster sources canonical
- only unresolved source: Icicle
- 22 canonical hunts with observed incoming damage

Recommendation preview v1 works end-to-end.

Offensive evidence:
- EK elemental weapon proxy validated
- RP/ED/MS offensive stat candidates validated

Imbuements:
- factual Powerful definitions loaded
- defensive imbuements weighted by observed incoming damage
- vocation skill candidates validated
- Strike/Vampirism/Void kept as separate factual candidates

## Prepared, not yet applied because Lovable Free-plan DB limit is active

Apply in this order:

1. 0034_recommendation_preview_v2.sql
2. 0035_core_spell_catalog.sql
3. 0036_boss_room_foundation.sql
4. 0037_recommendation_preview_v3.sql
5. 0038_canonical_boss_sync.sql

### 0034
Adds offensive equipment and imbuement evidence to recommendation preview.

### 0035
Adds core spell catalogue + hunt/boss spell candidate function.

### 0036
Adds boss profiles, adds, mechanics, spell/item guidance and boss profile function.
Primary-key compatibility issue was fixed before application.

### 0037
Adds spell candidates to recommendation preview v3.

### 0038
Automatically synchronizes canonical bosses from TibiaData:
structuredData.combatProperties.isBoss=true.

Also exposes RubinOT boss/boss-group changelog reconciliation queue.

## Next validation sequence

1. Apply 0034.
2. Smoke preview RP700/EK700.
3. Apply 0035.
4. Test spell candidates:
   - Cobra Bastion EK700 hunt
   - Nimmersatt RP700 hunt
   - Gloom Pillars ED1000 hunt
   - Azzilon Castle MS1000 hunt
   - boss context to verify lever-boss restricted spells are excluded.
5. Apply 0036.
6. Apply 0037.
7. Apply 0038 and run huntnexus_sync_canonical_boss_profiles().
8. Count canonical bosses and inspect RubinOT reconciliation candidates.
9. Begin sourcing/versioning exact boss-room mechanics, starting with RubinOT-changed encounters such as Magma Bubble and Soul War before generating final boss builds.
