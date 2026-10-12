# HuntNexus — FE-29: OTP negative-path browser resilience without real credentials

**Data:** 2026-10-12 (BRT). Continuação do [checkpoint FE-28](CHECKPOINT_2026-10-12_FE28_AUTH_RESILIENCE_QA.md), que permanece concluído tecnicamente, sem declarar homologação de Magic Link real.

## Entregue

- `web/app/tests/frontend-live-browser-smoke.mjs`: regressão da rota Account publicada para **erro de transporte na solicitação OTP**, interceptando `/auth/v1/otp` com Playwright `route.abort('failed')`. Verifica mensagem de erro e botão `Enviar link` novamente habilitado, sem disparar e-mail.
- No mesmo browser, novo cenário de **HTTP 200 simulado** em `/auth/v1/otp`, verificando que a UI mostra apenas "Solicitação recebida" e mantém botão habilitado; **isso não afirma entrega de e-mail nem login real**.
- Preservado o cenário existente de HTTP 429 simulado da FE-28. Domínio usado: `example.invalid`, sem endereço de pessoa real.
- Resultados de QA geram `account-otp-mocked-network-failure.png` e `account-otp-mocked-request-accepted.png`; todos os arquivos no artifact do workflow.
- Nenhuma modificação no Worker de produção, banco de dados, políticas RLS, chaves Supabase ou fluxo de conteúdo comunitário.

## Evidências verificadas

- **[Commit FE-29](https://github.com/Charrels22/huntnexus/commit/a4286e1e86646fda9362a9abb461069fb1b34616)**: expansão dos cenários.
- **[Web CI #38285834405 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38285834405)** no mesmo commit: build+typecheck, regressão UUID FE-28, parser sintético, reconstrução de cinco vocações e excerpts públicos de Analyzer.
- **[Frontend Browser QA #38285834327 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38285834327)** no mesmo commit: testes contra `https://huntnexus.charr3ls22.workers.dev`; log de QA contém `network_failure_recoverable: true`, `api_request_accepted: true` e screenshots.
- **Artifact:** `huntnexus-live-frontend-qa`, GitHub artifact ID `11763192051`, 6.896.911 bytes; includes screenshots acima.
- **[Account Security Smoke FE-28 #38282929468 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38282929468)**, sem alteração de implementação Auth/API nesta FE-29.

## Limites e backlog

- **Não homologado:** entrega real de Magic Link, login autêntico A/B, token com JWT legítimo, refresh e logout remotos sob conta consentida, redirecionamento real allowlist e HTTP 409 com JWT válido. O roteiro permanece em [FE28_REAL_AUTH_TWO_DEVICE_ACCEPTANCE.md](FE28_REAL_AUTH_TWO_DEVICE_ACCEPTANCE.md).
- Não fingir que logs sintéticos ou excerpts públicos são sessões reais de jogador RubinOT; nenhum arquivo pessoal foi importado nesta etapa.
- Supabase Security Advisors (consulta de 2026-10-12): 26 avisos INFO de RLS sem policies em tabelas que devem ser avaliadas conforme seu modelo de serviço, `pg_net` em schema `public` (WARN) e proteção de senhas vazadas desabilitada (WARN). Nenhum ajuste invasivo feito. [pg_net](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public) e [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
- Próxima porta de produto: conta autorizada em dois navegadores e casos reais de EK/RP/ED/MS/EM. Antes de piloto aberto, revisar privacidade guest por UUID-capability e capturas visuais com participantes consentidos.

## Maturidade aproximada

Estimativa editorial herdada do FE-28 — **não cobertura de testes**:

| Pilar | Aproximação |
|---|---:|
| Backend | 94% |
| Optimizer | 92% |
| Profile/Inventário | 96% |
| Session Analyzer | 87% |
| Hunt Planner | 86% |
| Conteúdo factual | 74% |
| Frontend visual | 74% |
| Produção/Contas/Segurança | 70% |

FE-29 acrescenta evidência automatizada de resiliência, mas não muda percentuais porque a homologação real permanece pendente.
