# Tópico 4 — conta 1:N personagens

Checkpoint concluído em 2026-10-14. Objetivo: substituir `client_id` como identidade acumulada de conta/personagem por ownership explícito, preservar compatibilidade e migrar os dados existentes sem alterar autenticação.

## Inventário anterior à mudança

- seis tabelas públicas continham `client_id`;
- cinco tabelas privadas precisavam receber `character_id`;
- 10 índices e 28 RPCs usavam `client_id` no banco vivo;
- banco vivo: 2 bindings, 2 perfis, 20 itens, 0 escolhas, 0 sessões e 0 revisões;
- os dois escopos privados estavam vinculados; não havia `client_id` privado órfão.

Consultas e snapshot: [`2026-10-14-client-id-dependency-audit.sql`](evidence/2026-10-14-client-id-dependency-audit.sql) e [`2026-10-14-client-id-dependency-audit.json`](evidence/2026-10-14-client-id-dependency-audit.json).

## Implementação versionada

Baseline no commit `2ba2482` (`feat(account): add multi-character ownership model`), gate documental em `f1cd23e` e [PR Draft #7](https://github.com/Charrels22/huntnexus/pull/7), com base na PR #6.

- `0162_account_character_domain`: cria `huntnexus_accounts`, `player_characters`, personagem ativo e backfill aditivo;
- Profile, inventário, escolhas, sessões e revisões recebem `character_id`;
- FK composta `(client_id, character_id)` impede cruzar legado e personagem;
- triggers mantêm RPCs legados funcionais e mapeiam guest ao vincular a conta;
- RPCs de listar/criar/ativar/resolver personagem são executáveis apenas por `service_role`;
- unbind protege dados de todos os personagens;
- `0163_topic04_scope_fk_indexes` cobre as seis FKs introduzidas no tópico;
- autenticação, token, Magic Link, MFA e recuperação não mudaram;
- os rollbacks de `0162` e `0163` estão versionados; `0162` recusa colapsar multi-personagem real.

Detalhes: [`ACCOUNT_CHARACTER_MIGRATION.md`](ACCOUNT_CHARACTER_MIGRATION.md).

## Aplicação no Supabase

Após autorização explícita do usuário, as migrations foram aplicadas em `urbncbjapasnjqjqicjv`:

| Versão Supabase | Migration | SHA-256 do arquivo aplicado |
| --- | --- | --- |
| `20261014114545` | `0162_account_character_domain` | `417b3022ba8582ea2c66741dc035f98994c71a08d360803bb706aa2ff1782ff3` |
| `20261014114749` | `0163_topic04_scope_fk_indexes` | `549928fc9ef1620b85d2fb909bed78aabd84a0121b5ed880fa15dda820cb7324` |

O segundo passo foi necessário porque o advisor detectou seis FKs novas sem índice de cobertura. Após `0163`, todas as seis ficaram cobertas e nenhum aviso `unindexed_foreign_keys` introduzido pelo Tópico 4 permaneceu.

## Evidência pós-migration

| Invariante | Antes | Depois | Resultado |
| --- | ---: | ---: | --- |
| Bindings | 2 | 2 | PASS |
| Perfis privados | 2 | 2 | PASS |
| Itens privados | 20 | 20 | PASS |
| Contas explícitas | inexistente | 2 | PASS |
| Personagens explícitos | inexistente | 2 | PASS |
| Contas sem personagem ativo | n/a | 0 | PASS |
| Bindings sem conta | n/a | 0 | PASS |
| Violações `client_id` + `character_id` | n/a | 0 | PASS |

As duas novas tabelas têm RLS habilitada. `anon` e `authenticated` não possuem SELECT ou escrita direta; `service_role` possui acesso. As quatro RPCs novas também são exclusivas de `service_role`.

Evidência estruturada: [`2026-10-14-topic04-production-verification.json`](evidence/2026-10-14-topic04-production-verification.json). SQL read-only: [`2026-10-14-topic04-post-migration-verification.sql`](evidence/2026-10-14-topic04-post-migration-verification.sql).

## Regressões

| Evidência | Resultado |
| --- | --- |
| PGlite 0.3.10: aplicar `0162` e `0163` duas vezes | PASS |
| PGlite: seis índices de FK presentes | PASS |
| PGlite: conta com dois personagens e scopes distintos | PASS |
| PGlite: FK bloqueia `client_id` A + `character_id` B | PASS |
| PGlite: troca de personagem ativo e ownership estrangeiro negado | PASS |
| PGlite: unbind bloqueado com dados e limpeza final 0/0/0 | PASS |
| Supabase: regressão `topic04_account_character_model.sql` | PASS (`SYNTHETIC`) |
| Supabase: resíduo sintético de personagem/perfil/inventário | 0/0/0 |
| `node tests/topic04-account-character-contract.mjs` | PASS |
| `node tests/fe28-client-id-regression.mjs` | PASS; não é auth real |
| `node tests/account-security-smoke.mjs` | PASS; tokens falsos, não é login real |
| `git diff --check` | PASS |

O advisor de segurança mantém `rls_enabled_no_policy` como INFO nas tabelas privadas. Isso é esperado no desenho server-only: elas não possuem policy permissiva e os privilégios diretos de `anon`/`authenticated` estão revogados. O advisor de desempenho mantém um FK antigo de `session_id` sem índice e avisos de índices recém-criados ainda não usados; nenhum deles invalida o modelo ou foi introduzido sem controle pelo Tópico 4.

Após o push da branch, o Worker `huntnexus` continuava no deployment `4df50565-35a8-4d58-9103-b406d920b059`, versão `143d8692-b52c-4c0b-bd0e-af6cf980341e`, com 100% do tráfego. Nenhum deploy Web foi provocado.

## Estado

| Item | Resultado |
| --- | --- |
| Inventário PK/FK/RPC/API/client storage | PASS |
| Modelo conta 1:N personagens | PASS |
| Migração aditiva de dados existentes | PASS |
| Isolamento por ownership e FK composta | PASS |
| Compatibilidade, verificação e rollback | PASS |
| Regressão `SYNTHETIC` e limpeza | PASS |
| Autenticação alterada | NÃO |
| Merge/deploy Web | NÃO EXECUTADO; congelado |
| Tópico 4 | **PASS** |

Próximo: Tópico 5 — reconstruir autenticação e recuperação. Mudanças reais de autenticação continuam sujeitas à autorização explícita prevista em `AGENTS.md`.
