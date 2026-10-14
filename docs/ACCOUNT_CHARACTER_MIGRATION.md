# Conta e personagens — desenho aditivo do Tópico 4

## Decisão

`client_id` continua temporariamente como escopo de compatibilidade. A propriedade alvo passa a ser:

```text
auth user verificado pelo Worker
  └─ huntnexus_accounts
       ├─ active_character_id
       └─ player_characters (1:N)
            ├─ profile
            ├─ inventory
            ├─ hunt build choices
            ├─ private sessions
            └─ parse revisions
```

As migrations [`0162_account_character_domain.sql`](../db/migrations/0162_account_character_domain.sql) e [`0163_topic04_scope_fk_indexes.sql`](../db/migrations/0163_topic04_scope_fk_indexes.sql) são aditivas. A primeira cria e migra o domínio; a segunda cobre as seis FKs novas após inspeção do advisor. Elas não mudam Magic Link, token, sessão, recuperação ou MFA.

## Dependências encontradas antes da migration

| Camada | Resultado em 2026-10-14 |
| --- | --- |
| Tabelas públicas com `client_id` | 6 |
| Tabelas privadas que recebem `character_id` | 5 |
| Índices que usam `client_id` | 10 |
| RPCs cuja definição usa `client_id` | 28 |
| Migrations históricas com `client_id` | 24 |
| Arquivos Web com `client_id` | 10 |
| Arquivos de teste com `client_id` | 33 |
| Workflows com `client_id` | 1 |
| Escopos privados atuais | 2, ambos vinculados; 0 órfãos |

Snapshot: [`evidence/2026-10-14-client-id-dependency-audit.json`](evidence/2026-10-14-client-id-dependency-audit.json). Consultas: [`evidence/2026-10-14-client-id-dependency-audit.sql`](evidence/2026-10-14-client-id-dependency-audit.sql).

## Compatibilidade e isolamento

- cada binding autenticado gera uma conta e um personagem inicial;
- Profile existente fornece somente nome, mundo, vocação e nível do personagem inicial; campos ausentes permanecem ausentes;
- `player_character_profiles`, inventário, escolhas, sessões e revisões recebem `character_id`;
- FK composta `(client_id, character_id)` impede combinar o legado de um personagem com outro personagem;
- triggers preenchem `character_id` quando RPC legado grava apenas `client_id`;
- dado guest ainda não vinculado pode permanecer com `character_id = NULL`; removê-lo ou exigir login pertence aos Tópicos 5/11;
- novos RPCs de conta/personagem aceitam `p_auth_user_id`, mas só `service_role` pode executá-los;
- mudança de personagem ativo exige ownership e personagem não arquivado;
- unbind passa a inspecionar dados de todos os personagens da conta.

## Ordem executada

1. O preflight confirmou 0 `client_id` privado órfão e preservou as contagens iniciais.
2. Após autorização explícita, `0162_account_character_domain.sql` foi aplicada em `urbncbjapasnjqjqicjv`.
3. A verificação read-only confirmou 2 contas, 2 bindings, 2 personagens, 2 perfis, 20 itens e 0 violações.
4. [`topic04_account_character_model.sql`](../tests/sql/topic04_account_character_model.sql) passou no Supabase; todos os dados eram `SYNTHETIC` e o resíduo final foi zero.
5. O advisor identificou seis FKs do tópico sem índice; `0163_topic04_scope_fk_indexes.sql` foi testada e aplicada.
6. A verificação final confirmou cobertura dos seis FKs, RLS ativa, acesso direto negado a `anon`/`authenticated` e RPCs novas exclusivas de `service_role`.
7. Seleção de personagem no Worker/Web continua reservada ao Tópico 11.

Evidência: [`2026-10-14-topic04-production-verification.json`](evidence/2026-10-14-topic04-production-verification.json). Backup/restauração completo continua como portão próprio do Tópico 6; não foi apresentado como realizado neste tópico.

## Rollback

[`0162_account_character_domain_rollback.sql`](../db/rollback/0162_account_character_domain_rollback.sql) é destrutivo e exige aprovação e backup. Ele recusa execução se já existir conta com múltiplos personagens ou qualquer pareamento incompatível, porque nesse ponto voltar a um único `client_id` perderia a separação de propriedade. [`0163_topic04_scope_fk_indexes_rollback.sql`](../db/rollback/0163_topic04_scope_fk_indexes_rollback.sql) apenas remove os seis índices de cobertura e não apaga dados.

Como as migrations já foram aplicadas, o rollback seguro preferido é uma correção aditiva. O rollback de `0162` existe apenas para a janela anterior ao primeiro dado multi-personagem real e deve ser precedido por backup verificado.

## Limite deste tópico

O Tópico 4 entrega o domínio e os guardas de ownership. Métodos de login, MFA, recuperação e rotação de sessão pertencem ao Tópico 5; RLS/grants completos e restauração ao Tópico 6; seletor visual e troca de contexto ao Tópico 11.
