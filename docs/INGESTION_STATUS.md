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
