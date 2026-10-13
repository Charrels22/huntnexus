# HuntNexus — testes e critérios de aceite para Codex

**Regra principal:** teste verde só sustenta aquilo que de fato foi exercitado. Não chamar fixture sintética de sessão real de RubinOT, nem CI de confirmação de deploy.

## Setup local

- Runtime CI atual: **Node 22**; aplicação em `web/app/`.
- Fluxo no clone:
  ```bash
  cd web/app
  npm install --no-audit --no-fund
  npm run build
  npm run dev
  ```
- `npm run build` executa Vite e `tsc --noEmit`.
- Para rodar os testes .mjs da raiz com imports TypeScript, em geral usar `node --experimental-strip-types ../../tests/<teste>.mjs` com cwd `web/app` — conferir exatamente o workflow. Para testes HTTP puros, `node tests/<teste>.mjs` na raiz, quando aplicável.
- Preview local: `npm run preview -- --host 127.0.0.1 --port 4173` (em `web/app`).
- Playwright: instalar versão usada pelos workflows (`playwright@1.56.1` nos workflows FE-39) e Chromium via `npx playwright install --with-deps chromium`, quando houver autorização de execução.
- Alguns testes usam `HUNTNEXUS_BASE_URL` para selecionar preview local/publicado e `HUNTNEXUS_ENDPOINT` para endpoint público; conferir o código do teste e nunca modificar URLs sem necessidade.

## Suítes canônicas

| Escopo | Arquivo/workflow de referência |
| --- | --- |
| Web build, TS, parser, privacidade e provenance | `.github/workflows/huntnexus-web-ci.yml` |
| QA geral desktop/mobile, 5 vocações, lazy optimizer e Hunt Detail | `.github/workflows/huntnexus-frontend-browser-qa.yml` |
| Catálogo/Planner: observações e limite de confiança | `.github/workflows/huntnexus-fe38-planner-evidence.yml` |
| Proveniência factual por hunt e visual | `.github/workflows/huntnexus-fe39-hunt-evidence.yml` |
| API pública read-only | `.github/workflows/huntnexus-public-smoke.yml`, `tests/public-api-smoke.mjs` |
| Contratos unitários FE-39 | `tests/fe39-hunt-evidence-contract.mjs` |
| Suíte com escopo de perfil/conta | `.github/workflows/huntnexus-account-security-smoke.yml` |
| Snapshots de Main/BP e cinco vocações | `.github/workflows/huntnexus-fe24-five-vocation-private-snapshot.yml`, FE-25/26 |
| Parser e sessões FE-32–37 | `tests/session-parser-contract.mjs`, `tests/fe36-damage-misc-contract.mjs`, `tests/fe37-session-integrity-contract.mjs` |
| SQL de integração/auditoria | `tests/sql/` e migration correspondente, executar apenas em contexto seguro e com autorização |

Nem todos os workflows disparam em alterações apenas de Markdown. **Não declarar novo CI aprovado quando ele não executou.** Se houver permissão para disparar `workflow_dispatch`, vincular o run real; caso contrário registrar “não executado”.

## Matriz mínima por mudança

- **UI ou navegação:** build/TS + Chromium desktop/mobile, busca, loading, erro, vazio, link canônico, screenshots e ausência de erro de página. API mockada serve para testar interface, **não** valida o backend publicado.
- **API/SQL:** contrato de tipos, casos válidos/inválidos, autorização, limites, índices e latência quando relevante. Não alterar RPC existente sem checar chamadas em produção e workflows.
- **Hunts/factual/Planner:** validar source/tier/data e override RubinOT, separar fatos de observações e dados indisponíveis de zero. Testar EK/RP/ED/MS/EM quando a mudança for comum.
- **Profile/Main/BP/optimizer:** as cinco vocações, mão/ammunition, item de propriedade do usuário vs externo, builds por hunt, snapshots históricos não mutáveis.
- **Sessions:** distinguir saída/entrada de dano e os 4 analyzers, original bruto vs parsed/reparse, no-op e rollback. Não testar com sessão privada real sem permissão.
- **Auth:** isolamento entre guests, conta Supabase vinculada e contas diferentes; nunca concluir “Magic Link real aprovado” usando token forjado ou simples mock do navegador.

## Higiene de fixtures e logs

- Identificar todas as fixtures como `SYNTHETIC` e distingui-las de dados extraídos de uma fonte pública.
- Um smoke que cria sessão temporária deve **sempre** excluí-la em `finally`, inclusive após falha; erro de cleanup não pode ser ignorado.
- Não publicar texto de analyzer, nome/CPF/email do jogador, IDs privados, tokens, cookies, service role ou screenshots de conta em artifacts/issue público.
- Não forçar operação destrutiva apenas para deixar o CI verde. Testes SQL de produção preferencialmente **read-only** ou transação sintética autorizada e limpa.
- Não afirmar que sprites carregam com base apenas na URL: no navegador confirmar decodificação/visibilidade (p. ex. `naturalWidth > 0`).
- Em Source tiers: check de URL e data registrada não substitui validação de atualização/patch oficial.

## Formato de evidência/checkpoint

| Item | Como registrar |
| --- | --- |
| Commit | SHA e URL do código que foi testado |
| Build/teste | Comando e conclusão, ou link de GitHub Actions com status **final** |
| Browser | local ou publicado; mockado ou live; dimensões; artifact e screenshot |
| API/DB | read-only, transação sintética ou escrita autorizada; escopo e cleanup |
| Fonte de jogo | URL/versão/observação/tier e se é sintético ou real |
| Segurança | comportamento observado, limitações, permissões conferidas |
| Próximo passo | FE-NN, aceite pendente e bloqueadores objetivos |

**Status válidos:** `PASS verificado`, `FALHOU`, `NÃO EXECUTADO`, `BLOQUEADO`, `PENDENTE DO USUÁRIO`. Nunca adivinhar métricas/performance, trocar falha por sucesso ou aumentar porcentagens editoriais por testes de fixture.
