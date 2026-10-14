# Tópico 5 — autenticação e recuperação

Checkpoint intermediário em 2026-10-14. O código, migration, regressões e QA sintética estão preparados. O tópico permanece **PENDENTE** porque autenticação real e deploy exigem autorização explícita e ainda não foram executados.

Baseline de implementação: commit `51d0cbd` (`feat(auth): require password and TOTP for private data`), documentada no commit `5e7d3a1` e publicada na [PR Draft #8](https://github.com/Charrels22/huntnexus/pull/8), com base na branch do Tópico 4. SHA-256 do arquivo `0164` preparado: `514f06f2f4c74b7ae72f33ce3feb8a9b4330cf97d87a0df6f9a91b2f80ccb49b`.

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

Evidência estruturada: [`2026-10-14-topic05-auth-audit.json`](evidence/2026-10-14-topic05-auth-audit.json). Modelo e plano: [`AUTHENTICATION_RECOVERY_MODEL.md`](AUTHENTICATION_RECOVERY_MODEL.md).
Verificação pós-migration preparada: [`2026-10-14-topic05-post-migration-verification.sql`](evidence/2026-10-14-topic05-post-migration-verification.sql).

## Implementação preparada

- entrada por e-mail + senha e cadastro com confirmação de e-mail;
- recuperação de senha sem revelar existência da conta;
- TOTP obrigatório antes de resolver ou acessar dados vinculados;
- QR/chave manual, desafio AAL2 e segundo TOTP reserva;
- remoção do último TOTP bloqueada; remover outro fator exige código atual do fator preservado e refresh imediato da sessão;
- troca de senha exige sessão AAL2, senha atual e nonce de reautenticação quando o provedor considerar a sessão antiga;
- logout local, das outras sessões e global;
- API exige token validado, `session_id`, sessão viva, fator verificado, AAL2 e ownership;
- `0164_topic05_auth_session_gate` é read-only sobre schema `auth` e executável apenas por `service_role`;
- rollback específico para `0164`.

## Evidências locais

| Verificação | Resultado |
| --- | --- |
| `npm run build` | PASS |
| `topic05-auth-assurance-regression.mjs` | PASS |
| `topic05-auth-contract.mjs` | PASS |
| PGlite: aplicar `0164` duas vezes | PASS |
| PGlite: sessão ativa, expirada e estrangeira | PASS |
| PGlite: execução somente `service_role` | PASS |
| FE-28 guest identity | PASS; não é Auth real |
| FE-30 scope isolation | PASS; não é Auth real |
| Browser desktop empty/loading/error e troca de senha com reautenticação | PASS (`SYNTHETIC`) |
| Browser mobile recovery/troca de senha e sem overflow | PASS (`SYNTHETIC`) |
| E-mail ou autenticação real | NÃO EXECUTADO |
| Teste A/B com contas reais | NÃO EXECUTADO |
| Migration `0164` em produção | NÃO APLICADA |
| Deploy Web | NÃO EXECUTADO; congelado |

Screenshots locais são gerados em `web/app/topic05-browser-qa/` e ficam fora do artefato de produção.

## Gate para concluir

1. autorização explícita para aplicar `0164` e alterar a configuração real do Supabase Auth;
2. política mínima de 12 caracteres com composição forte, troca segura, senha atual obrigatória, TOTP verificado e alertas de segurança habilitados;
3. decisão/configuração de SMTP operacional para não depender do limite padrão de 2 e-mails por hora no release;
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
