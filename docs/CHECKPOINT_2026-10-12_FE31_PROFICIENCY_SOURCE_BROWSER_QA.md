# HuntNexus — FE-31: Proficiency Browser QA, fonte real e transparência da topologia

**Data:** 2026-10-12 (BRT). **Status:** CI e API pública aprovados; Browser QA final de topologia ainda em execução quando este registro inicial foi criado.

## Motivo e limites

Na FE-30, um run de Browser QA falhou uma vez em `page.waitForResponse` (30 s), na etapa da árvore Weapon Proficiency. O rerun do mesmo workflow foi aprovado. Não é correto assumir que a falha foi causada pelo Worker, nem declarar que uma única execução verde elimina instabilidade intermitente. FE-31 torna o teste observável e permite separar: resposta HTTP errada, requisição nunca emitida pelo frontend, falha de rede, e divergência de payload de vocação/família.

## Implementação

1. `web/app/tests/frontend-live-browser-smoke.mjs`: troca filtro de string JSON por `postDataJSON()` com ação, vocação e weapon family explícitos. Aumenta timeout isolado do catálogo de 30 s para 40 s e registra requests, responses, HTTP status, eventuais falhas de rede e erro de runtime. Em falha salva screenshot `fe31-proficiency-failure-<vocation>.png` e diagnóstico no log. A fonte factual do catálogo **continua API pública de produção**, apenas Profile e Inventory são fixtures de UI.
2. O mesmo Browser QA registra quando a árvore selecionada tem `source_backed_level_position`, sem atribuir confiança de topologia a uma sequência linear não comprovada.
3. Adicionada validação visual de `flattened_source_order`: quando existe árvore elegível com posição não comprovada, a UI deve mostrar aviso de que apresenta somente a ordem observada; screenshot de evidência.
4. `tests/fe31-live-proficiency-catalog-smoke.mjs`: consulta **somente leitura** a API de catálogo publicada duas vezes para EK/sword, RP/bow, ED/rod, MS/wand, EM/fist. Não cria contas, inscrições ou sessions. Registra 200, latência, árvores elegíveis e número de topologias com evidência.
5. Workflow `.github/workflows/huntnexus-fe31-proficiency-live-qa.yml`, `workflow_dispatch` e trigger de mudanças relevantes. Não usa credenciais ou dados reais de jogador.

## Evidências verificadas

- [Web CI após instrumentação #38299883097 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38299883097).
- [Web CI com verificação visual de topologia #38300193689 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38300193689).
- [Live catalog QA #38299948284 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38299948284): dez respostas HTTP 200, mediana **653 ms**, máximo **1.179 ms** (amostra pontual de Github Runner, não SLO).
- [Live catalog QA após alteração final #38300193639 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38300193639).
- [Frontend Browser QA #38300193630](https://github.com/Charrels22/huntnexus/actions/runs/38300193630) — aguardando resultado final para o fechamento desta etapa.
- [Frontend Browser QA instrumentado #38299883208](https://github.com/Charrels22/huntnexus/actions/runs/38299883208) — passou em primeira execução; rerun de estabilidade solicitado, resultado pendente neste momento.

### Cobertura factual apurada — chamada pública read-only de 2026-10-12

| Vocação/família | Árvores elegíveis | Com topologia source-backed | Topologia não validada |
|---|---:|---:|---:|
| EK / sword | 6 | 5 | 1 |
| RP / bow | 5 | 5 | 0 |
| ED / rod | 4 | 4 | 0 |
| MS / wand | 4 | 4 | 0 |
| EM / fist | 6 | 5 | 1 |

SQL read-only do Supabase confirmou três árvores `flattened_source_order`: `gnome-sword` (2 perks), `moonsilver-katar` (17 perks) e `pair-of-monk-fists` (4 perks), com origem Tier B e sem `weapon_proficiency_topology_sources`. Apenas parte dessas árvores é elegível sob cada filtro de vocação/família. Não inventar a grade de posições por heurística; preservar fallback com aviso.

## Backlog e aceites externos

- A causa da única falha intermitente de Browser QA do ciclo anterior não foi reproduzida/provada. Nova instrumentação coleta erros para permitir correção definitiva se voltar a acontecer, sem retornar resultados falsos de catálogo.
- Proficiency: pesquisar evidência adicional legítima do nível/posição de `gnome-sword`, `moonsilver-katar` e `pair-of-monk-fists`, com versão, data e URL; não promover níveis do jogo sem fonte.
- Faltam casos reais consentidos EK/RP/ED/MS/EM, dados integrais originais do Analyzer e Magic Link em dois dispositivos com conta autorizada.
- Segurança guest UUID-capability, `pg_net` e proteção de senha vazada continuam no backlog controlado; regressões não demonstram homologação real.
- Não foi alterado código de backend, database, inventário, optimizer ou Cloudflare Worker de produção nesta etapa. Testes de frontend usam o site publicado, mas QA de UI com fixture **não é homologação de gameplay real**.

## Maturidade aproximada

Estimativas editoriais **não** medidas por cobertura ou SLA: Backend 94%; Optimizer 92%; Profile/Inventário 96%; Session Analyzer 87%; Hunt Planner 86%; Conteúdo Factual 74%; Frontend Visual 74%; Produção/Contas/Segurança 70%. Sem aumento artificial apenas por instrumentação de QA.
