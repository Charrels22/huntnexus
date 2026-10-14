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

A migration [`0162_account_character_domain.sql`](../db/migrations/0162_account_character_domain.sql) é aditiva. Ela não muda Magic Link, token, sessão, recuperação ou MFA.

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

## Ordem de promoção

1. Confirmar novamente que não há `client_id` privado órfão.
2. Criar backup e testar restauração segundo o Tópico 6 antes da produção.
3. Aplicar `0162_account_character_domain.sql` em ambiente aprovado.
4. Executar [`2026-10-14-topic04-post-migration-verification.sql`](evidence/2026-10-14-topic04-post-migration-verification.sql).
5. Executar [`topic04_account_character_model.sql`](../tests/sql/topic04_account_character_model.sql); todos os dados são `SYNTHETIC` e removidos.
6. Somente depois expor seleção de personagem no Worker/Web, durante a experiência pessoal.

## Rollback

[`0162_account_character_domain_rollback.sql`](../db/rollback/0162_account_character_domain_rollback.sql) é destrutivo e exige aprovação e backup. Ele recusa execução se já existir conta com múltiplos personagens ou qualquer pareamento incompatível, porque nesse ponto voltar a um único `client_id` perderia a separação de propriedade.

Enquanto a migration não é aplicada, rollback significa simplesmente remover/reverter a branch. Depois da aplicação, o rollback seguro preferido é restaurar backup ou corrigir aditivamente; o script existe apenas para a janela anterior ao primeiro dado multi-personagem real.

## Limite deste tópico

O Tópico 4 entrega o domínio e os guardas de ownership. Métodos de login, MFA, recuperação e rotação de sessão pertencem ao Tópico 5; RLS/grants completos e restauração ao Tópico 6; seletor visual e troca de contexto ao Tópico 11.
