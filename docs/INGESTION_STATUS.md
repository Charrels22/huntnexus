# Ingestion status

## 2026-10-01

### Ativo
- PostgreSQL/Supabase da HuntNexus Brain provisionado.
- Migração `0001_foundation.sql` aplicada.
- Fonte oficial RubinOT Changelog validada.
- RubinOT Wiki validada.
- TibiaWiki BR validada como referência factual.
- ByteWizards TibiaData validado por código-fonte para:
  - `/api/v1/creatures/sync`
  - `/api/v1/items/sync`
  - `/api/v1/hunting-places/sync`
  - endpoints `/sync/by-date` para atualização incremental.

### Modelo incremental
1. Consultar `/sync` na carga inicial.
2. Buscar detalhes apenas de IDs alterados.
3. Nas cargas seguintes usar `/sync/by-date?time=<UTC>`.
4. Preservar snapshot bruto antes de normalizar.
5. Aplicar RubinOT como overlay versionado, nunca como substituição do Tibia base.

### Próximos dados
1. detalhes de criaturas;
2. resistências e ataques;
3. detalhes de itens;
4. hunting places + criaturas;
5. Wiki RubinOT por página;
6. changelog completo histórico;
7. trackers comunitários.


## 2026-10-03 — Phase 3 progress

Validated detail ingestion through direct PostgreSQL HTTP access.

Confirmed successful:
- Phase 2 catalogs: 2,193 creatures, 6,470 items, 459 hunting places.
- Duplicate creature keys: 0.
- Duplicate item slugs: 0.
- Duplicate hunting-place slugs: 0.
- Phase 3 schema `0003_creature_hunt_details.sql` applied.
- Direct-ingestion migration `0004_direct_detail_ingestion.sql` applied.
- HTTP extension successfully fetched TibiaData creature detail responses.
- Initial creature detail test: 3 completed / 0 errors.
- Initial hunting-place detail test: 3 completed / 0 errors.
- First production creature batch: 100 completed / 0 errors.
- First production hunt batch: 25 completed / 0 errors.
- Second production creature batch: 100 completed / 0 errors.
- Confirmed creature details completed so far: 203.
- Confirmed hunting places detailed so far: 28.

After the first production batch, validation showed:
- 1,029 vulnerability rows.
- 103 creature-ability rows.
- 892 creature-loot rows.
- 258 hunt↔creature links.
- 222 raw snapshots.

Those row counts predate the second 100-creature batch and must be refreshed on the next database action; do not treat them as current totals.

Current blocker:
- Lovable Free-plan MCP database action limit reached temporarily.
- No remote-source error or ingestion error occurred.

Prepared for next execution:
- `0005_phase3_batch_orchestrator.sql`
- single-call execution: `select huntnexus_phase3_batch(100, 25);`
- returns run result, current totals and remaining counts in one database action.


## 2026-10-03 — Phase 3 continued

The Phase 3 batch orchestrator was applied and executed successfully.

Current confirmed totals:
- Creatures detailed: 1,003
- Creature detail errors: 0
- Hunting places detailed: 253
- Hunting place detail errors: 0
- Vulnerability rows: 10,000
- Creature ability rows: 1,003
- Creature loot rows: 8,421
- Hunt-creature links: 2,046
- Raw snapshots: 1,347

Remaining:
- Creatures: 1,190
- Hunting places: 206

The last attempted batch did not execute because the Lovable Free-plan MCP database action limit was reached. No ingestion/source error occurred.

Resume with:
```sql
select huntnexus_phase3_batch(100,25);
```


## 2026-10-04/05 — Phase 3 continued

Latest confirmed totals:
- Creatures detailed: 1,678
- Creature detail errors: 0
- Hunting places detailed: 398
- Hunting place detail errors: 0
- Vulnerability rows: 16,704
- Creature ability rows: 1,678
- Creature loot rows: 14,024
- Hunt-creature links: 3,219
- Raw snapshots: 2,167

Remaining:
- Creatures: 515
- Hunting places: 61

Execution notes:
- Large batches may return HTTP 504 to the client even when PostgreSQL completes the work successfully.
- Stable batch size during this window: 75 creatures + 15 hunting places.
- No source/normalization errors occurred.
- Last attempted batch did not execute because the Lovable Free-plan MCP database action limit was reached.

Resume with:
```sql
select huntnexus_phase3_batch(75,15);
```


## 2026-10-05 — Phase 3 completed

Phase 3 is complete.

Final confirmed totals:
- Creatures catalogued: 2,193
- Creatures detailed: 2,193
- Creature detail errors: 0
- Hunting places catalogued: 459
- Hunting places detailed: 459
- Hunting place detail errors: 0
- Vulnerability rows: 21,834
- Creature ability rows: 2,193
- Creature loot rows: 18,675
- Hunt-creature links: 3,745
- Raw snapshots: 2,743

Phase 3 result:
- 100% of TibiaData creatures detailed.
- 100% of TibiaData hunting places detailed.
- 0 ingestion errors.
- Creature resistances, raw abilities, combat properties and loot are normalized with source provenance.
- Hunting-place creature membership is normalized.

Next:
- Phase 4: item-detail enrichment, prioritizing combat/equipment-relevant items before non-combat catalogue items.


## 2026-10-05 — Phase 4 item enrichment started

Phase 4 migration `0006_item_detail_enrichment.sql` was applied successfully.

Validation:
- Initial test: 3 items completed / 0 errors.
- Additional attributes from the first 3 items: 21 rows.

Current confirmed totals:
- Combat-relevant items targeted: 1,610
- Combat-relevant items detailed: 803
- Item detail errors: 0
- Remaining combat-relevant items: 807
- Item attribute rows: 5,544
- Raw snapshots: 3,546

Execution notes:
- Stable batch size: 100 items.
- No source or normalization errors occurred.
- Last attempted batch did not execute because the Lovable Free-plan MCP database action limit was reached.

Resume with:
```sql
select huntnexus_ingest_item_details(100,true);
```


## 2026-10-05 — Phase 4 combat item enrichment completed

Phase 4 priority subset is complete.

Final confirmed totals:
- Combat-relevant items targeted: 1,610
- Combat-relevant items detailed: 1,610
- Item detail errors: 0
- Remaining combat-relevant items: 0
- Item attribute rows: 11,346
- Raw snapshots: 4,353

Result:
- 100% of the prioritized combat/equipment subset has full TibiaData detail payloads.
- Detailed fields now include attack, defense, armor, required level, vocation, imbue slots, elemental attacks, weight, upgrade class, NPC/value fields and additional attributes where provided.
- Full source payload and provenance snapshot are retained for every detailed item.

Next:
- Phase 5: inspect the real additional-attribute key space and normalize equipment effects such as elemental protection, skill/magic bonuses, speed and other combat modifiers without guessing field semantics.

Current blocker:
- Lovable Free-plan MCP database action limit was reached immediately after Phase 4 completion.


## 2026-10-05 — Phase 5 item effect normalization

Initial normalization run:
- Normalized effects: 888
- Items with normalized effects: 581
- Parse issues: 127
- Items with parse issues: 127

Investigation found the parse issues were caused primarily by a tokenization bug, not unknown source semantics:
- comma-separated attrib values were not being split because the migration used an over-escaped regex.
- Example affected value: `fist fighting +4, magic level +2`.

Verified source semantics before the fix:
- `resist`: 400 items.
- `resistPercent`: 94 items.
- 94 items contain both.
- All 94 overlapping values are exactly identical.
- Normalized protection therefore prefers `resistPercent` when present, otherwise `resist`, avoiding duplicate effects.

Verified attrib patterns include:
- magic level and elemental/healing magic levels;
- sword/axe/club/distance/fist fighting;
- shielding;
- speed;
- life leech;
- cleave;
- damage reflection;
- perfect shot with range;
- magic shield capacity;
- faster regeneration;
- magic shield;
- invisibility.

Fix committed:
- `0007_item_effect_normalization.sql` corrected for fresh installs.
- `0008_fix_item_effect_tokenization.sql` added for already-applied environments.
- `0008` was applied successfully to the current database.

Current blocker:
- Lovable Free-plan MCP database action limit was reached immediately before the corrected rebuild could execute.

Resume with:
```sql
select huntnexus_rebuild_item_effects();
```

Then inspect `item_effect_parse_issues`; remaining issues should represent genuinely unsupported source patterns rather than comma-tokenization failures.


## 2026-10-05 — Phase 5 completed / Phase 6 prepared

### Phase 5 — normalized equipment effects
Corrected rebuild result:
- Normalized effects: 1,658
- Items with normalized effects: 695
- Parse issues: 0
- Items with parse issues: 0

By effect type:
- protection: 657
- skill: 386
- magic_skill: 250
- offense: 241
- special: 75
- movement: 34
- defense: 13
- leech: 2

### Hunt-creature integrity
After explicit alias/split resolution:
- Total hunt-creature links: 3,745
- Resolved to canonical TibiaData creatures: 3,743
- Unresolved: 2

The two unresolved links are both Demongoblin (Oasis Tomb and Pits of Inferno). Public Tibia references confirm the creature exists; it is absent from the current TibiaData creature catalogue. No guessed canonical mapping was created.

### Phase 6 — RubinOT official layer
Prepared in GitHub:
- 0010_source_collection_metadata.sql
- 0011_rubinot_system_mechanics.sql
- 0012_rubinot_change_candidates.sql
- 0013_rubinot_vip_loyalty.sql

Official mechanics prepared for structured ingestion:
- Huntfinder capabilities
- Equipment Preset constraints
- Guild Ascension dynamic modifiers
- Linked Tasks behavior
- VIP Weapon Proficiency bonus
- Loyalty skill tiers and vocation mapping

Changelog changes are staged as reconciliation candidates rather than immediate overrides when exact numeric values are not exposed.

Access note:
- Direct PostgreSQL HTTP to rubinot.com.br is blocked by Cloudflare 403.
- HuntNexus records browser/web collection as the permitted method and does not bypass the protection.

Current blocker:
- Lovable Free-plan MCP database action limit. The Phase 6 migrations are prepared but not yet applied.


## 2026-10-05 — Phase 6 applied / Phase 7 live / Phase 8 prepared

### Phase 6 — RubinOT official layer
Applied successfully:
- 0011_rubinot_system_mechanics.sql
- 0012_rubinot_change_candidates.sql
- 0013_rubinot_vip_loyalty.sql

Confirmed database totals:
- RubinOT system facts: 6
- RubinOT modifier definitions: 14
- Loyalty tiers: 11
- Changelog reconciliation candidates: 9
- Candidates pending: 4
- Candidates needing exact values: 5
- Applied numeric/state overrides: 0

No qualitative changelog statement has been converted into a fabricated numeric override.

### Phase 7 — factual analytics foundation
Applied successfully:
- 0014_analytics_factual_views.sql

The HuntNexus Brain now exposes:
- hunt × monster × element factual profiles;
- hunt-level unweighted elemental summaries;
- equipment protection catalogue;
- equipment combat-effect catalogue;
- `huntnexus_hunt_factual_profile(hunt_key)`.

The methodology explicitly marks these profiles as:
- not kill-weighted;
- not final recommendations.

### Phase 8 — community observations
Research confirmed:
- HuntAnalyser public pages are directly accessible from Supabase with HTTP 200.
- Public catalogue currently contains thousands of sessions and exposes stable session IDs.
- List pages expose duration, party size, XP Gain, Balance, XP/h, Raw XP/h, vocation/level and descriptions.
- Individual public session URLs are available as `/hunt_sessions/<id>`.
- Hunts.RubinOT public pages currently report zero public hunt locations/ranking records.
- PT Finder web retrieval currently returned HTTP 502.
- Hunt Tracker RubinOT Community is reachable as an SPA but indexed page content is unavailable.

Prepared:
- 0015_huntanalyser_public_smoke.sql
- 0016_community_hunt_resolution.sql
- docs/PHASE_8_COMMUNITY.md
- docs/COMMUNITY_HUNT_RESOLUTION.md

The HuntAnalyser smoke ingestion is capped at 5 public pages / 100 sessions per run and keeps terms review pending before any larger-scale collection.

Current blocker:
- Lovable Free-plan MCP database action limit. Migrations 0015 and 0016 are prepared but not yet applied.


## 2026-10-05 — Phase 8 public community smoke

Applied successfully:
- 0015_huntanalyser_public_smoke.sql
- 0016_community_hunt_resolution.sql
- 0017_huntanalyser_public_details.sql

Public list smoke result:
- Pages fetched: 5
- Sessions inserted: 100
- Errors: 0
- Player rows from list cards: 208
- Sessions with hunt title: 100/100
- Sessions with duration: 100/100
- Sessions with party size: 100/100
- Sessions with XP Gain: 100/100
- Sessions with XP/h: 100/100
- Sessions with Raw XP/h: 100/100
- Sessions with Balance: 100/100
- Sessions with at least one parsed player: 99/100
- Exact canonical hunt matches: 13
- Unresolved hunt labels: 87

Example validated public detail page exposes:
- Party Members table;
- vocation and level;
- player Damage;
- player Healing;
- Supplies;
- member Balance;
- Monster Killed table;
- monster name and kill count;
- richer character/build sections.

Detail-parser privacy behavior:
- public character names are SHA-256 hashed in session_players;
- raw player names are not stored in session_players.

Source-policy note:
- HuntAnalyser's own public pages distinguish Public vs Private sessions.
- HuntAnalyser pricing/FAQ state that public hunt sessions are a supported/unlimited Free-plan feature.
- This confirms the public/private intent of the source, but does not by itself establish bulk-harvesting permission.
- Keep terms_review_status=pending before any large-scale ingestion.

Current blocker:
- The 0017 parser is installed, but its first 5-session execution was blocked by the temporary Lovable Free-plan MCP database action limit.

Resume with:
```sql
select huntnexus_ingest_huntanalyser_public_details(5);
```


## 2026-10-05 — HuntAnalyser detail parser validated at parser level

Detail smoke progression:
- Initial 5-session run: 5 errors caused by supplies/balance regex capturing an HTML class hyphen.
- Numeric parsing fix applied via 0018.
- Second run completed 5/5, but audit showed undercapture (1 member + 1 creature per session).
- Multi-row regex fix applied via 0019.
- Same 5 sessions were reprocessed idempotently.

Corrected result:
- Sessions detailed: 5
- Detail errors: 0
- Player rows written: 11
- Creature rows written: 16
- Remaining list-smoke sessions without detail enrichment: 95

The corrected row counts match the expected party composition of the selected sample, including two x4 sessions.

Parser fixes:
- 0018_fix_huntanalyser_detail_numeric_parsing.sql
- 0019_fix_huntanalyser_detail_multirow.sql

The parser now:
- isolates Party Members and Monster Killed tables;
- parses multiple rows correctly;
- captures vocation, level, damage, healing, supplies and member balance;
- captures monster name + kill count;
- hashes public character names in session_players;
- resolves creatures only by strict exact/explicit alias logic.

Current blocker:
- Final per-session audit (player count, monster count, total kills, creature resolution status) was blocked by the temporary Lovable Free-plan MCP database action limit immediately after the successful reprocessing.

Do not scale beyond the 5-session detail smoke until that final audit is completed.


## 2026-10-06 — HuntAnalyser detail smoke expanded to 85/100

Final audit of the original 5-session detail sample passed:
- party_size matched parsed player rows;
- all sampled creature rows resolved to canonical TibiaData creatures;
- damage/healing totals were rebuilt from parsed member rows;
- no unresolved sampled creatures remained.

Validated sample examples:
- session 58781: solo, 1 player, 3 creature rows, 3,381 kills;
- session 58776: solo, 1 player, 2 creature rows, 864 kills;
- session 58761: solo, 1 player, 3 creature rows, 3,377 kills;
- session 58756: x4, 4 players, 4 creature rows, 1,721 kills;
- session 58752: x4, 4 players, 4 creature rows, 2,746 kills.

The detail smoke was then expanded only inside the existing 100-session list sample.

Current confirmed detail totals:
- Sessions detailed: 85 / 100
- Detail errors: 0
- Player rows written across completed detail batches: 170
- Creature rows written across completed detail batches: 327
- Remaining sessions in the existing smoke: 15

The next batch did not execute because the temporary Lovable Free-plan MCP database action limit was reached.

Prepared for the next step:
- 0020_community_analytics_views.sql
- docs/PHASE_9_COMMUNITY_ANALYTICS.md

Phase 9 will add:
- community session structural-quality view;
- observed hunt performance summaries;
- observed kill mix by hunt;
- kill-weighted elemental profiles;
- `huntnexus_hunt_observed_profile(hunt_key)`.

The kill-weighted layer remains Tier C observational evidence and is explicitly not labeled as a final recommendation.

Resume detail ingestion with:
```sql
select huntnexus_ingest_huntanalyser_public_details(10);
```
then:
```sql
select huntnexus_ingest_huntanalyser_public_details(5);
```
After 100/100 completes, apply `0020_community_analytics_views.sql`.


## 2026-10-06 — HuntAnalyser smoke 100/100 complete / Phase 9 live

### Detail ingestion complete
- Public list sample: 100 sessions
- Detailed sessions: 100 / 100
- Detail errors: 0
- Player rows: 210
- Creature rows: 437
- Resolved creature rows: 436
- Unresolved creature rows: 1

Audit:
- 99/100 sessions have parsed player count matching party_size.
- The single exception is session 57775, whose public detail page contains no Party Members table and an empty Top Damage Name; this is a source-data omission, not a parser failure.
- The only unresolved creature is `Nomad` in session 57902. The canonical catalogue contains multiple variants (Nomad Basic / Blue / Female), so no arbitrary mapping was created.

### Phase 9 analytics
Applied successfully:
- `0020_community_analytics_views.sql`

Observed analytics now expose:
- community-session structural quality;
- observed performance by canonical hunt;
- kill mix by hunt;
- kill-weighted elemental profile;
- `huntnexus_hunt_observed_profile(hunt_key)`.

Example currently observed:
- Cobra Bastion has 5 resolved sessions in the 100-session smoke sample.
- Observed averages/medians are available for XP/h, Raw XP/h and Balance.

### Hunt alias expansion
Prepared but not yet applied:
- `0021_safe_community_hunt_aliases.sql`

Only high-confidence aliases are included:
- Podzilla Quaras → Podzilla
- Azzilon Castle party/spelling variants → Azzilon Castle
- Gloom Pillar event variants → Gloom Pillars
- Brain Grounds descriptive variant → Brain Grounds
- Nimmersatt's Breeding Ground floor/party variants → canonical Nimmersatt's Breeding Ground

Ambiguous subareas such as Energy Library / Fire Library remain unresolved deliberately to avoid blending distinct hunt areas.

Current blocker:
- Temporary Lovable Free-plan MCP database action limit was reached while searching additional canonical alias candidates.

Resume by applying `0021_safe_community_hunt_aliases.sql`, then re-check resolved-hunt coverage before any further community scale-up.
