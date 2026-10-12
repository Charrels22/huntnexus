# HuntNexus — FE-30: escopo canônico isolado após perda de Auth fora da página Account

**Data:** 2026-10-12 (BRT). **Estado:** FE-30 **CONCLUÍDA TECNICAMENTE**, com Web CI, Account Security Smoke e Playwright em preview **e frontend publicado** aprovados. A homologação Auth real continua pendente.

## Problema encontrado

FE-28 tratava `SIGNED_OUT` em `/account`, mas um jogador com Profile/Inventory/Sessions abertos em outra rota poderia permanecer com estado privado renderizado após logout/expiração, até voltar à página de conta ou recarregar. Além disso, um `client_id` canônico persistido podia permanecer no navegador após inicialização já sem sessão Auth. A API server-side continua sendo o controle de autorização: o cliente não substitui HTTP 401/403 nem JWT válido.

## Implementação FE-30 (sem contas ou dados de jogador reais)

- `web/app/src/lib/account-session-guard.ts`: `markBoundClientId` grava marcador local **somente após `account_resolve` bem-sucedido** e confirmação de que o UUID canônico é o escopo atual; `isolateClientAfterAuthLoss` troca o UUID canônico por convidado quando há indício de vínculo/autenticação perdida, apaga rascunho privado do Analyzer e sessão aberta, remove marcador e é inerte para convidados puros. Chamada repetida sem sessão autenticada não rotaciona novamente.
- `web/app/src/routes/account.tsx`: valida formato de `canonical_client_id`, marca a identidade autenticada somente após persistir escopo e compartilha a rotina de limpeza para `SIGNED_OUT`, `INITIAL_SESSION` sem Auth e fallback de sign-out.
- `web/app/src/components/shell/app-shell.tsx`: observa evento Supabase Auth também fora de Account. Na perda da sessão, limpa escopo e direciona a `/account` para desmontar telas privadas e respostas locais antigas.
- `tests/fe30-auth-isolation-regression.mjs`: cobre pure guest, marcador incorreto, limpeza no cold start, não mesclar dados, idempotência e contexto SSR; marca os casos como sintéticos.
- `web/app/tests/fe30-auth-scope-preview-smoke.mjs` e workflow dedicado: Playwright carrega Profile em preview com **UUID sintético previamente marcado** sem sessão Auth. Exige troca por novo guest, limpeza de drafts e redirecionamento para Account; segundo contexto verifica que convidado puro permanece intacto. Requests privados de teste são interceptados (HTTP 401 sintético), nunca criam conta, sessão real nem enviam Magic Link. Inicialização sintética só ocorre uma vez por aba para evitar reinjeção no redirect.

## CI e evidências

- [Web CI — #38289410492 SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38289410492): build, TypeScript e regressão nova `FE-30 account-bound scope isolation regression`, mais parser/source regressions.
- [Web CI atualizado — #38290184871 SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38290184871), incluindo a regressão FE-30.
- [Account Security Smoke — #38289445573 SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38289445573) (ações negativas com tokens fabricados).
- [FE-30 Browser Preview — #38290109129 SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38290109129) após semear fixture uma vez por aba.
- [Frontend Browser QA geral — #38289236746 SUCCESS no rerun](https://github.com/Charrels22/huntnexus/actions/runs/38289236746). A primeira tentativa falhou por timeout em `waitForResponse` do catálogo Proficiency; retry passou. Este resultado testa o frontend publicado, mas **não prova** que o último código FE-30 foi implantado.
- **[FE-30 Browser Preview + Published — #38290202390 SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38290202390):** Playwright confirmou duas situações tanto na build local quanto em `https://huntnexus.charr3ls22.workers.dev`: `stale_bound_scope_without_session=PASS` (rejeita identidade antiga, limpa draft/sessionStorage e redireciona para Account) e `pure_guest_startup=PASS` (mantém ID/draft convidado). **Nenhuma requisição Auth real**, não prova Magic Link nem revogação efetiva de JWT. [Artifact `huntnexus-fe30-auth-browser-preview`](https://github.com/Charrels22/huntnexus/actions/runs/38290202390), ID `11766320036`, 1.260.090 bytes com capturas de preview e publicado.
- [Security scope helper](https://github.com/Charrels22/huntnexus/commit/343238621718d07607af17954930bbb87df51d35), [Account binding](https://github.com/Charrels22/huntnexus/commit/6f6dbfb83997d6c7fd0b8cfc6da469ef2321f7b3), [AppShell watcher](https://github.com/Charrels22/huntnexus/commit/647bf702cb439498d11d210faf6e3853f6a9c3a4), [unit regression](https://github.com/Charrels22/huntnexus/commit/43d5eb0d299cf01524e884164abe8a83ac5bcbf7).
- Último Cloudflare Worker deployment observado durante esta etapa: `1a2897cb-caba-4bc5-beff-8963142d1d87`, criado `2026-10-12T18:13:35.854717Z`, versão `46a9692d-5f32-45da-a84b-1d9b07c479c9` com 100% de tráfego, source `wrangler`. Não há prova de SHA GitHub correspondente.

## Pendências de aceite

- **Não homologado:** Magic Link recebido, callback/allowlist, JWT real, refresh real, autenticação em browsers A/B, logout remoto entre dispositivos, HTTP 409 de unlink com JWT válido e autorização por usuário distinto. Protocolo [FE28_REAL_AUTH_TWO_DEVICE_ACCEPTANCE.md](FE28_REAL_AUTH_TWO_DEVICE_ACCEPTANCE.md).
- Avaliar `pg_net` em `public` e leaked-password protection antes de abertura externa, sem criar policies públicas para tabelas intencionalmente service-only.
- Validar com participantes reais EK/RP/ED/MS/EM; manter origens/snapshots e não declarar fixtures como sessions reais.
- Não elevar percentual de Produção/Contas/Segurança com base em teste sem Auth genuíno.

## Estimativas editoriais, não indicadores de cobertura

Backend ~94%; Optimizer ~92%; Profile/Inventário ~96%; Session Analyzer ~87%; Hunt Planner ~86%; Conteúdo factual ~74%; Frontend Visual ~74%; Produção/Contas/Segurança ~70%.
