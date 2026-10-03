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
