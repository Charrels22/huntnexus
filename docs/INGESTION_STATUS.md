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
