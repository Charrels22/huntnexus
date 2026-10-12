# HuntNexus — FE-28: Auth frontend resiliency and real login acceptance readiness

**Data:** 2026-10-12 (BRT), após [FE-27](CHECKPOINT_2026-10-12_FE27_BOUND_ACCOUNT_SECURITY.md).

## Escopo executado (sem conta real de teste)

Este sprint reforça segurança e confiabilidade do frontend e prepara homologação de Magic Link sem criar pessoas, caixas de e-mail, sessões Auth reais ou testes com tokens autorizados inexistentes.

### 1. Corrigido o tratamento de sessão do frontend

Em `web/app/src/routes/account.tsx`:
- O `resolveAccount` antes descartava eventos Auth recebidos enquanto outra sincronização estava em progresso. Agora existe `pendingSessionRef`, que retém a sessão mais recente e processa o refresh ao fim da requisição anterior, apenas se o token ainda for atual. O token obsoleto não deve sobrescrever a identidade atual.
- `SIGNED_OUT` vindo de outra aba ou do provedor, com sessão anterior ativa, limpa rascunhos de Analyzer e a sessão privada aberta em `sessionStorage`, gera novo `client_id` convidado e remove o estado visual de sincronização. Evita manter UUID canônico vinculado em modo guest depois de perda de sessão.
- `signOut` manual continua protegendo dados, evitando rotações duplicadas do UUID quando o evento Auth já cuidou da identidade.
- A interface deixou de exibir o UUID canônico no cartão de conta. Mostra agora **Perfil vinculado — Acesso protegido pela sua conta**, reduzindo exposição de identificadores em screenshots/compartilhamento.
- `sendMagicLink` agora retorna a estado utilizável em `finally` mesmo diante de exceções de rede, exibe mensagem clara em rate-limit e erro Auth, e não declara que um e-mail foi efetivamente entregue quando a API apenas aceitou a solicitação.

**Nota de honestidade:** testes de código e navegador sem uma sessão legítima não demonstram a transição real `TOKEN_REFRESHED`/remote `SIGNED_OUT` com Supabase Auth, apenas que a UI compila e o fluxo guest e OTP simulado não regrediram. Casos Auth reais continuam no roteiro.

### 2. UUID client_id mais estrito

Em `web/app/src/lib/client-id.ts`, valores persistidos e passados a `setClientId` precisam de formato UUID completo incluindo grupos, versão e variante válidos; a regex anterior aceitava até 36 hifens, que seriam posteriormente rejeitados pela API e causariam erros inexplicáveis.

`tests/fe28-client-id-regression.mjs` cobre UUID armazenado estável, entradas malformadas, recuperação segura por `crypto.randomUUID`, compatibilidade de versões válidas, emissão de evento apenas em mudança e rejeição de substituições inválidas. Integrado ao obrigatório `.github/workflows/huntnexus-web-ci.yml`.

### 3. Browser QA com Magic Link simulado sem envio

`web/app/tests/frontend-live-browser-smoke.mjs` agora intercepta `/auth/v1/otp` com HTTP 429 e mensagem simulada; o browser preenche **domínio reservado .invalid**, sem solicitar e-mail real, verifica o erro visual e se o botão `Enviar link` volta a ficar utilizável. Gera screenshot `account-otp-mocked-rate-limit.png`.

A regressão existente de recuperar explicitamente o convidado anterior continua em execução. O teste não executa Magic Link, não solicita OTP real e não prova recebimento do e-mail.

### 4. Segurança CI automática

`.github/workflows/huntnexus-account-security-smoke.yml` agora dispara quando mudam auth/browser, Account UI, Worker API, client ID ou chamada ao HuntNexus; mantém as 9 tentativas autenticadas com credenciais falsas a account_status, account_unbind e account_resolve.

## Evidências finais (PASS)

- **[Web CI run #38282595610 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38282595610)**, commit `e9efb7d699f8ee188365d7bd5eb043a4d78dc69d`: build e TypeScript, test de UUID FE-28, parser, reconstruções de fontes Tier C.
- **[Frontend Browser QA run #38282541213 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38282541213)**, commit `fdad678b89fca155b2701099f6a306d52f0ad785`: account, mobile/desktop, recuperação explícita guest, 5 vocações em árvore/sprites, sessão, planner e **mock OTP 429**. Artifact `huntnexus-live-frontend-qa` (aproximadamente 6.29 MB), com screenshot `account-otp-mocked-rate-limit.png` e demais.
- **[Account Security Smoke run #38282929468 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38282929468)**, commit `8653ae4cd150d0980d769fbff1befca00866aa1c`: 9 tokens Auth fabricados negados em account_status/resolve/unbind.
- Runs iniciais de FE-28 Web CI falharam por *fixture* de RNG incorretamente consumido em teste de client-id (código produto funcionando, o teste esperava UUID errado). Corrigido no commit `e9efb7d`; resultado **SUCCESS** acima prevalece. Sem relaxar regra de validação.
- Cloudflare Worker deployments API: implantação mais recente `e7f06ea7-61cb-4d81-965e-17c799eef1d7`, criada em `2026-10-12T17:12:35.776Z`, versão `0109f444-e067-4843-b296-15a0a616d0ac`, 100% do tráfego. Esta API não estabelece um commit GitHub 1:1; não inferir SHA exato apenas por timestamp.

## Porta para teste real

Arquivo: `docs/FE28_REAL_AUTH_TWO_DEVICE_ACCEPTANCE.md`. Roteiro A/B cobre envio OTP autorizado, entrega do link, callback, login, recuperação canônica, mudanças entre navegadores, isolamento em 401/403, refresh e logout remoto, rate-limit e HTTP 409 de unbind. Capturas nunca incluem access/refresh JWT, OTP nem link mágico completo.

**Ainda NÃO executado:** entrega real de Magic Link, dois navegadores realmente autenticados, JWT válido, callback allowlist no Supabase, revalidação de usuário distinto e refresh remoto efetivo. Exigiria a autorização de um participante/conta dedicada.

## Security Advisors Supabase — pendências externas

A última auditoria FE-27 mostrou avisos para extensão `pg_net` instalada no schema public e leaked-password protection desabilitada, além de RLS sem políticas em tabelas server-only. Estas configurações **não foram modificadas neste sprint** para evitar quebrar pipelines ou trocar configuração Auth sem plano de rollback; manter no backlog de hardening controlado:
- https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

## Quadro de maturidade pós-FE28

**Estimativa visual editorial, não medição de cobertura ou aceite de release:**

| Pilar | Estimativa |
|---|---:|
| Backend estrutural | ~94% |
| Optimizer | ~92% |
| Profile / Inventário | ~96% |
| Session Analyzer | ~87% |
| Hunt Planner | ~86% |
| Conteúdo factual | ~74% |
| Frontend visual | ~74% |
| Produção / Contas / Segurança | ~70% |

A evolução de Produção/Contas/Segurança de ~68% para ~70% reflete hardening do frontend e testes; o fator limitante continua **Magic Link verdadeiro em dois dispositivos, Auth security settings, piloto real de RubinOT**. Não converter estimativas em SLA nem alegar produto 100% homologado.
