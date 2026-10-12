# HuntNexus — FE-27: conta vinculada, escopo privado e desvinculação segura

**Data:** 2026-10-12 (BRT). Continuação de `docs/CHECKPOINT_2026-10-12_FE26_MAIN_IDENTITY_GUARDS.md`.

## 1. Resultado: escopo protegido por vínculo de conta

Implementado `tests/fe27-bound-client-privacy-smoke.mjs`, com workflow `.github/workflows/huntnexus-fe27-bound-client-privacy.yml`.

Uma identidade **sintética e temporária** foi criada no Supabase com UUID de `auth_user_id` não vinculado a nenhuma conta real, Profile EK e arma Soulshredder no Main. Com esse `client_id` protegido pela tabela `player_account_bindings`, o teste HTTP alcançou o Worker publicado:
`https://huntnexus.charr3ls22.workers.dev/api/huntnexus`.

- **54 verificações de acesso negado PASS**, distribuídas por **18 ações privadas**: Profile get/save/delete; Inventory get/put/remove/review; choice get/save/delete; owned build options; session import/list/detail/delete/build performance; planner personalized; final optimizer.
- Cada ação foi testada em três modalidades: nenhum token no corpo, token falso no corpo e token falso apenas no header Authorization. Respostas foram **HTTP 401**, sem execução da rotina privada.
- Endpoints públicos `health` e Profile get de um convidado aleatório sem dados continuaram funcionando. O teste não atribui a proteção de uma conta autenticada ao convidado não vinculado: sua UUID é um identificador de capacidade.
- Evidência: **[GitHub Actions run #38276721693 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38276721693)**.
- Após o teste, a identidade, binding, Profile e item Main artificiais foram excluídos por SQL. Auditoria de resíduo resultou `bound_residue=0`, `inventory_residue=0`, `profile_residue=0`, `session_residue=0`; comunidade permaneceu em **100** sessões.
- Por segurança, o workflow é agora `workflow_dispatch` com UUID temporária explícita obrigatória; **não** mantém um canary público persistente ou fallback UUID obsoleto. Para outra execução, é preciso provisionar/limpar um fixture sintético isolado.

Importante: não houve token JWT real nem Magic Link, portanto isso **não prova** autorização correta de uma conta legítima, autenticação em navegadores A/B, recuperação de credenciais ou entrega de e-mail.

## 2. SQL cross-device: histórico completo

Criado `tests/sql/phase75_fe27_account_private_snapshot_recovery.sql` e executado no Supabase PROD com fixture totalmente isolado de UUIDs aleatórias e exclusão dentro do mesmo DO block. Status **OK**:
- Account A / dispositivo A grava Profile, Soulshredder Main, Gnome Sword BP, uma escolha `owned_variant` para Cobra Bastion e uma sessão privada **com texto/métricas sintéticos** e snapshot imutável.
- A mesma Account A / dispositivo B recebe o **canonical_client_id do A**; nenhuma mesclagem automática de dados de convidado.
- Account B não pode reivindicar o canonical_client_id da A.
- Profile, Main/BP, escolha para hunt e snapshot são recuperados sob identidade canônica; convidado local B separado não enxerga os dados.
- Após excluir a Gnome Sword da BP, a escolha antiga é invalidada, **mas o snapshot antigo permanece exatamente igual**.
- Todos os registros de fixture são removidos na transação. **Não houve jogador real nem sessão comunitária publicada.**

A regressão antiga `tests/sql/phase73_account_canonical_private_data_recovery.sql` também foi atualizada e executada com sucesso após o hardening de unbind.

## 3. Vulnerabilidade de exposição pós-unbind identificada e corrigida

**Problema encontrado:** a operação antiga `huntnexus_account_unbind` eliminava o binding, mas preservava Profile/Inventory/Hunt Choices/Sessions com o mesmo `client_id`. Isso tornava os dados antigos alcançáveis pelo fluxo de UUID convidado após desvincular; na prática, quem já soubesse o UUID perderia a barreira de autenticação. UUIDs aleatórias não são substituto de autorização quando já foram conhecidas.

**Correção PROD:** migração `db/migrations/0157_account_unbind_private_data_guard.sql` aplicada com sucesso. A função retém vínculo e retorna `error=private_data_present_unbind_blocked` se qualquer uma das quatro tabelas privadas ainda tiver dados daquele client_id. `account_unbind` só é permitido após remover explicitamente os dados privados; `signOut` e a recuperação canônica normal não mudam.

Na API Worker (`web/app/src/routes/api/huntnexus.ts`), a tentativa autenticada de unlink inseguro responde **HTTP 409** com erro significativo em vez de sinalizar falso sucesso. Essa rota HTTP409 **não foi testada com JWT genuíno** (faltam credenciais reais autorizadas), mas a mesma regra de domínio SQL foi validada em PROD por dois testes de fixture.

A função mantém lock transacional por `auth_user_id`, equivalente ao mecanismo FE-20 de account resolve, e permanece RPC `service_role` only:
- `anon_unbind_execute=false`
- `authenticated_unbind_execute=false`
- `service_role_unbind_execute=true`
- `unbind_data_guard_deployed=true`

## 4. Regressoes pós-correção

Após atualizar Worker/migração, passadas:
- [Web CI (Typescript, build e parser): #38277444023 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38277444023)
- [Profile: #38277443613 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38277443613)
- [Inventário: #38277443883 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38277443883)
- [Sessões: #38277443974 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38277443974)
- [FE-24 Profile/Main/BP e snapshots 5 vocações: #38277443658 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38277443658)
- [FE-25 multisslot e munição: #38277444015 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38277444015)
- [FE-26 invariantes de escolhas: #38277443884 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38277443884)
- [Cross-Vocation: #38277443569 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38277443569)

O teste `tests/account-security-smoke.mjs` foi ampliado para **9 tentativas falsas** de `account_status`, `account_unbind` e `account_resolve`. **[HuntNexus Account Security Smoke run #38277798697 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38277798697)**, `fake_auth_attempts_denied=9`.

## 5. Auditoria Supabase Security Advisors

A auditoria encontrou:
- **26 notices INFO** de RLS ativo sem políticas (inclui várias tabelas internas), mas as cinco tabelas pessoais têm RLS ativo e consulta/gravação direta pelo `anon` e `authenticated` revogadas. São intencionalmente de serviço: não adicionar políticas públicas só para apagar o alerta. Guia: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- **WARN** `pg_net` instalado no schema `public`. Alterar schema de extension sem avaliar funções dependentes pode quebrar ingestion e automação: manter como item de hardening para janela controlada. Guia: https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public
- **WARN** proteção contra senhas vazadas desabilitada no Supabase Auth. Avaliar com estratégia de login (Magic Link/email e eventual senha) antes da abertura de cadastros externos. Guia: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

Auditoria de privilégios confirmada: `player_account_bindings`, `player_character_profiles`, `player_character_inventory`, `player_hunt_build_choices` e `player_hunt_sessions` têm RLS ativo, `anon SELECT/INSERT=false`, `authenticated SELECT/DELETE=false`, `service_role SELECT=true`.

## 6. O que FE-27 não fecha

1. Login real por Magic Link com conta consentida e navegador A + navegador B, incluindo token real autenticado e expiração/refresco/logout/relogin.
2. Regra `account_unbind` validada em Worker com JWT válido, verificando HTTP 409 e estado permanente após conflito.
3. Remediação/homologação de `pg_net` e Auth leaked-password protection, conforme escopo.
4. Segurança do convidado baseada em UUID-capability não é autenticação independente; pessoas com client_id convidado conhecido podem acessar seus dados enquanto não houver binding.
5. Homologação humana real de EK/RP/ED/MS/EM, itens/perks e analyzers originais RubinOT.

O FE-27 conclui **as correções e regressões técnicas desse escopo**; não significa liberação pública nem segurança de produção 100% concluída.

## Estimativa visual de progresso

Escala editorial aproximada, **não** derivada de uma métrica formal de cobertura. Favor não usar como certificação de release:
- Backend estrutural ~94%
- Optimizer ~92%
- Profile/Inventário ~96%
- Session Analyzer ~87%
- Hunt Planner ~86%
- Conteúdo factual ~74%
- Frontend visual ~74%
- Produção/contas/segurança ~66–69% (estimativa provisória após FE-27)

A próxima etapa deve validar a autenticação real com sessão autorizada e completar checks de conta, depois revisar screenshots e funcionamento real no RubinOT antes do piloto externo.


## Confirmação de deployment Cloudflare

API Cloudflare `/accounts/{account_id}/workers/scripts/huntnexus/deployments`: última implantação `1ad1b74a-0b3f-433c-8038-4d3f4c0d3968`, criada `2026-10-12T16:27:32.501Z`, `source=wrangler`, versão `67eac236-524e-4232-8627-aa403e6d5f3b` servindo **100%** do tráfego. A API de deploy não associa diretamente essa versão a um commit GitHub, portanto não inferir SHA de origem apenas a partir do timestamp. O HTTP 409 da nova regra precisa de conta legítima de teste para execução ponta a ponta.

### Quadro pós-etapa

Estimativas visuais editoriais (não percentuais de cobertura instrumentada): Backend ~94%; Optimizer ~92%; Profile/Inventário ~96%; Session Analyzer ~87%; Hunt Planner ~86%; Conteúdo factual ~74%; Frontend visual ~74%; Produção/contas/segurança ~68%. O progresso de contas reflete correções de acesso não autenticado e unlink, **não** teste de JWT legítimo, piloto humano ou resolução dos alertas restantes do Supabase.
