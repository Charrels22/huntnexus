# Tópico 5 — autenticação e recuperação

Checkpoint intermediário em 2026-10-14. O código, migration, regressões e QA sintética estão preparados. O tópico permanece **PENDENTE** porque autenticação real e deploy exigem autorização explícita e ainda não foram executados.

Baseline inicial de implementação: commit `51d0cbd` (`feat(auth): require password and TOTP for private data`), documentada no commit `5e7d3a1` e publicada na [PR Draft #8](https://github.com/Charrels22/huntnexus/pull/8), com base na branch do Tópico 4. Head revalidado em 2026-10-28: `48b7a88`. SHA-256 atual do arquivo `0164` preparado: `829b33132b0e9b10893a0ab9a28583a4ad7fba91d1dde602f2ec99f307090b16`.

## Estado encontrado

- Supabase `urbncbjapasnjqjqicjv` ativo e saudável;
- e-mail habilitado, confirmação automática desabilitada e cadastro permitido;
- Magic Link era a entrada implementada pela Web;
- a API validava o usuário e ownership, mas não exigia AAL2 nem verificava a existência atual da sessão;
- RLS está habilitada em contas/personagens e `anon`/`authenticated` não possuem leitura direta das tabelas de conta/binding;
- migration `0164` não existe em produção e nenhuma configuração real de Auth foi alterada.

Auditoria somente leitura do Dashboard em 2026-10-14:

- `0162_account_character_domain` e `0163_topic04_scope_fk_indexes` estão aplicadas; `0164` não está;
- TOTP já está habilitado, com até 10 fatores por usuário e limite de 15 minutos para elevar sessões `aal1`;
- senha mínima está em 6, sem composição obrigatória;
- `Secure password change` e exigência da senha atual estão desabilitados;
- proteção contra senhas vazadas e controles avançados de duração de sessão exigem plano Pro; o projeto está no plano Free;
- o limite atual de envio é 2 e-mails de autenticação por hora;
- `Site URL` e a única URL permitida de retorno apontam para o Worker publicado e `/account`; `localhost` não está na allow list;
- recuperação usa o modelo padrão não editável do Supabase e `{{ .ConfirmationURL }}`;
- SMTP personalizado está desabilitado e os sete alertas de segurança do Auth estão desligados;
- a autorização recebida citou `0162`, já aplicada, e por isso não cobre a migration pendente `0164`.

Evidência estruturada: [`2026-10-14-topic05-auth-audit.json`](evidence/2026-10-14-topic05-auth-audit.json). Modelo: [`AUTHENTICATION_RECOVERY_MODEL.md`](AUTHENTICATION_RECOVERY_MODEL.md). Execução real preparada: [`2026-10-14-topic05-production-activation-runbook.md`](evidence/2026-10-14-topic05-production-activation-runbook.md).
Verificação pós-migration preparada: [`2026-10-14-topic05-post-migration-verification.sql`](evidence/2026-10-14-topic05-post-migration-verification.sql).

Revisão de segurança em 2026-10-27: a migration ainda não aplicada foi endurecida conforme o Advisor oficial do Supabase. A função `security definer` passou de um `search_path` fixo contendo `public` para `search_path = ''`, com funções e tabelas qualificadas. Contrato e PGlite agora verificam essa propriedade; o hash acima substitui o anterior.

Revisão de transporte em 2026-10-28: novos clientes passaram a enviar o JWT no cabeçalho `Authorization: Bearer`, removendo-o do corpo JSON. A API preserva compatibilidade temporária com o campo legado, rejeita cabeçalho malformado ou tokens divergentes e valida `session_id` com formato UUID estrito.

## Implementação preparada

- entrada por e-mail + senha e cadastro com confirmação de e-mail;
- recuperação de senha sem revelar existência da conta;
- TOTP obrigatório antes de resolver ou acessar dados vinculados;
- QR/chave manual, desafio AAL2 e segundo TOTP reserva;
- remoção do último TOTP bloqueada; remover outro fator exige código atual do fator preservado e refresh imediato da sessão;
- troca de senha exige sessão AAL2, senha atual e nonce de reautenticação quando o provedor considerar a sessão antiga;
- logout local, das outras sessões e global;
- novos clientes enviam JWT por `Authorization: Bearer`; o corpo legado permanece apenas como compatibilidade temporária e conflito entre transportes é rejeitado;
- API exige token validado, `session_id`, sessão viva, fator verificado, AAL2 e ownership;
- `0164_topic05_auth_session_gate` é read-only sobre schema `auth`, usa `search_path = ''` com referências qualificadas e é executável apenas por `service_role`;
- rollback específico para `0164`.

## Evidências locais

| Verificação | Resultado |
| --- | --- |
| `npm run build` | PASS |
| `topic05-auth-assurance-regression.mjs` | PASS |
| `topic05-auth-contract.mjs` | PASS |
| `topic05-auth-transport-regression.mjs` | PASS; Bearer presente e JWT ausente do JSON |
| PGlite: aplicar `0164` duas vezes | PASS |
| PGlite: sessão ativa, expirada e estrangeira | PASS |
| PGlite: execução somente `service_role` | PASS |
| PGlite: SQL pós-migration executável com três `verification_pass=true` | PASS |
| PGlite: rollback duas vezes e preservação das linhas Auth | PASS |
| FE-28 guest identity | PASS; não é Auth real |
| FE-30 scope isolation | PASS; não é Auth real |
| Browser desktop empty/loading/error e troca de senha com reautenticação | PASS (`SYNTHETIC`) |
| Browser mobile recovery/troca de senha e sem overflow | PASS (`SYNTHETIC`) |
| Browser autenticado: Bearer presente e JWT ausente do JSON | PASS (`SYNTHETIC`, 4 requisições observadas) |
| Cloudflare build `9ca032b0-39da-4444-939d-275b317ca2c6` no commit `13312ee` | BUILD PASS; `wrangler preview` FAIL por ausência do bloco `previews`; nenhum deploy |
| E-mail ou autenticação real | NÃO EXECUTADO |
| Teste A/B com contas reais | NÃO EXECUTADO |
| Migration `0164` em produção | NÃO APLICADA |
| Deploy Web | NÃO EXECUTADO; congelado |

Screenshots locais são gerados em `web/app/topic05-browser-qa/` e ficam fora do artefato de produção.

## Gate para concluir

1. autorização explícita para aplicar `0164` e alterar a configuração real do Supabase Auth;
2. política mínima de 12 caracteres com composição forte, troca segura, senha atual obrigatória, TOTP verificado e alertas de segurança habilitados;
3. decisão/configuração de SMTP operacional: o serviço padrão é best-effort, sem SLA e oficialmente restrito a destinatários autorizados da equipe; as duas contas piloto não são membros da organização;
4. migração controlada das duas contas consentidas de Magic Link para senha + TOTP;
5. casos positivos e negativos A/B, segundo dispositivo, recuperação, sessão revogada e logout por escopo;
6. autorização de deploy, versão publicada e rollback verificado.

## Quadro

| Item | Resultado |
| --- | --- |
| Desenho de entrada forte, MFA, recuperação e sessões | PASS |
| Implementação e regressões locais | PASS |
| Banco/RLS atual auditado por metadados | PASS |
| Auth real e `0164` | **BLOQUEADO POR AUTORIZAÇÃO** |
| Isolamento A/B real | PENDENTE |
| Deploy | PENDENTE; congelado |
| Tópico 5 | **PENDENTE** |

## Revalidação antes do gate real — 2026-10-28

- branch `codex/authentication-recovery`, head `48b7a88` e PR #8 Draft/mergeável;
- hash de `0164` confirmado e rollback presente;
- `npm run build`, assurance, transport, contract, PGlite e regressões FE-28/30: PASS;
- rollback PGlite repetido duas vezes: função removida e linhas de sessões/fatores preservadas;
- verificador pós-migration executado integralmente no PGlite: assinatura/configuração/grants, retorno nulo e schema produziram três checks positivos;
- preflight Supabase read-only confirmou tabelas/colunas esperadas e a role `service_role`;
- o corpo lógico de `0164` foi executado como consulta read-only no PostgreSQL de produção, sem criar função, e retornou `active_session=false`, `verified_factor_count=0` e `requires_aal2=true` para entradas nulas;
- baseline anterior à migration: 4 usuários Auth, 2 sessões, 0 fatores MFA, 2 contas HuntNexus e 2 personagens;
- `huntnexus_auth_session_gate(uuid,uuid)` ausente; nenhuma migration, configuração Auth, conta, e-mail ou deployment foi alterado.
