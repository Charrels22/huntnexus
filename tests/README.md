# Tests

Os testes devem validar principalmente:

- separação das camadas;
- preservação de histórico;
- proveniência;
- resolução Tibia + RubinOT;
- consistência temporal;
- qualidade de sessões;
- invariantes do recommendation engine;
- guards que impedem recomendações finais sem evidência suficiente.

Qualquer fixture simulada deve ser explicitamente marcada como `SYNTHETIC`.

## Regressões atuais

### Banco

`tests/sql/phase20_22_regression.sql`

Valida, com `raise exception` em regressão:

- recommendation stage `preview_v7`;
- ranking score e confidence como campos separados;
- `loadout_candidate_matrix_v5`;
- `loadout_set_preview_v3`;
- `ek_hand_options_v2`;
- `loadout_imbuement_compatibility_v1`;
- Ice Rapier fora de hunts sustentadas;
- `demongoblin -> demon-goblin`;
- 100% dos hunt-creature links resolvidos;
- Magma Bubble ainda bloqueado pelo guard RubinOT.

### Produção pública

`tests/public-api-smoke.mjs`

Executado pelo workflow `HuntNexus Public Smoke`:

- manualmente;
- diariamente;
- quando o próprio smoke/workflow é alterado.

O smoke usa somente o endpoint público do Worker e não depende de secrets do GitHub.
