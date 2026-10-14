# Tópico 4 — conta 1:N personagens

Checkpoint parcial de 2026-10-14. Objetivo: substituir `client_id` como identidade acumulada de conta/personagem por ownership explícito, sem quebrar compatibilidade e sem alterar autenticação.

## Inventário anterior à mudança

- seis tabelas públicas contêm `client_id`;
- cinco tabelas privadas precisam receber `character_id`;
- 10 índices e 28 RPCs usam `client_id` no banco vivo;
- 24 migrations históricas, 10 arquivos Web, 33 testes e um workflow referenciam `client_id`;
- banco vivo: 2 bindings, 2 perfis, 20 itens, 0 escolhas, 0 sessões e 0 revisões;
- os dois escopos privados estão vinculados; não há `client_id` privado órfão.

Consultas e snapshot: [`2026-10-14-client-id-dependency-audit.sql`](evidence/2026-10-14-client-id-dependency-audit.sql) e [`2026-10-14-client-id-dependency-audit.json`](evidence/2026-10-14-client-id-dependency-audit.json).

## Implementação preparada

Commit `2ba2482` (`feat(account): add multi-character ownership model`), [PR Draft #7](https://github.com/Charrels22/huntnexus/pull/7), base PR #6.

- `db/migrations/0162_account_character_domain.sql`: `huntnexus_accounts`, `player_characters`, personagem ativo e backfill aditivo;
- Profile, inventário, escolhas, sessões e revisões recebem `character_id`;
- FK composta `(client_id, character_id)` impede cruzar legado e personagem;
- triggers mantêm RPCs legados funcionais e mapeiam guest ao vincular a conta;
- RPCs de listar/criar/ativar/resolver personagem são executáveis apenas por `service_role`;
- unbind protege dados de todos os personagens;
- autenticação, token, Magic Link, MFA e recuperação não mudam;
- rollback recusa execução quando já existir multi-personagem real.

Detalhes: [`ACCOUNT_CHARACTER_MIGRATION.md`](ACCOUNT_CHARACTER_MIGRATION.md).

## Validação executada

| Evidência | Resultado |
| --- | --- |
| Parser PostgreSQL `pglast` nos cinco arquivos SQL | PASS |
| PGlite 0.3.10: aplicar migration duas vezes | PASS |
| PGlite: conta com dois personagens e scopes distintos | PASS |
| PGlite: FK bloqueia `client_id` A + `character_id` B | PASS |
| PGlite: troca de personagem ativo e ownership estrangeiro negado | PASS |
| PGlite: unbind bloqueado com dados e limpeza final 0/0/0 | PASS |
| `node tests/topic04-account-character-contract.mjs` | PASS |
| `node tests/fe28-client-id-regression.mjs` | PASS; não é auth real |
| `node tests/account-security-smoke.mjs` | PASS; 9 tokens falsos negados, não é login real |
| links Markdown e `git diff --check` | PASS |

O teste PGlite usa somente fixture marcada `SYNTHETIC`; não leu nem escreveu dados reais.

## Gate pendente

A migration ainda não foi aplicada em `urbncbjapasnjqjqicjv`. Ela criará tabelas/constraints/triggers e fará backfill das linhas privadas existentes. A regra 3 de `AGENTS.md` exige autorização explícita para dados reais privados; por isso a execução no Supabase é o único gate restante deste tópico.

Após autorização:

1. confirmar novamente 0 escopos privados órfãos;
2. aplicar migration `0162_account_character_domain`;
3. executar [`2026-10-14-topic04-post-migration-verification.sql`](evidence/2026-10-14-topic04-post-migration-verification.sql);
4. executar `tests/sql/topic04_account_character_model.sql` (`SYNTHETIC`, autocontido e limpo);
5. consultar advisors Supabase e registrar resultados;
6. atualizar `production_migration_applied`, checkpoint, `CURRENT_STATUS.md` e SHA.

## Estado

| Item | Resultado |
| --- | --- |
| Inventário PK/FK/RPC/API/client storage | PASS |
| Modelo 1:N aditivo | PASS em código |
| Compatibilidade e rollback | PASS em código/PGlite |
| Autenticação alterada | NÃO |
| Migration no Supabase | **PENDENTE — autorização explícita** |
| Merge/deploy Web | NÃO EXECUTADO; congelado |
| Avançar ao Tópico 5 | BLOQUEADO até concluir este gate |
