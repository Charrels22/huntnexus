# HuntNexus — FE-38: transparência das evidências do Planner

**Data:** 2026-10-13 (BRT). **Estado:** **FE-38 concluída tecnicamente**, com Web CI de implementação, API de todas as cinco vocações e Playwright local + publicado **SUCCESS**. Outras validações automatizadas adicionais posteriores podem ser executadas sem bloquear as próximas frentes.

## Motivo da mudança

Não deixar o desenvolvimento do catálogo, Planner e produção parado aguardando exports particulares. Esta etapa atua em uma falha de comunicação factual do Planner: o frontend exibia uma porcentagem de `confidence_score` como "Conf." sem dizer que se tratava de um índice heurístico do modelo experimental. Isso podia ser interpretado como probabilidade estatística de sucesso. Também mostrava resultados antigos quando o jogador alterava filtros, permitindo abrir uma hunt com vocação/level distintos dos dados que a ranquearam.

## Evidência do catálogo em Supabase (consulta read-only)

Execução em 2026-10-13 de `huntnexus_hunt_catalog_readiness_audit()->'summary'`:
- 459 entradas; 455 spawns fixos e 4 entradas não fixas.
- **454 hunts elegíveis no Planner, 454 com source core completo**.
- 1 spawn fixo fora desse conjunto com source core incompleto.
- **26 hunts com sessões observadas**, 22 com dano recebido observado. São contagens de cobertura por hunt, **não número total de sessões, pessoas nem aceites de jogadores reais**.
- O RPC `huntnexus_rank_observed_hunts` traz `session_count` e `confidence_score`. Amostras de teste EK, MS, ED, EM incluem hunts com apenas 1–2 sessões; metodologia `experimental_observed_ranking_v2`, `source_layer=community_observations`, `final_recommendation=false`.

## Mudanças executadas no código

1. `web/app/src/routes/api/huntnexus.ts`, ação `planner_personalized`: atribui a cada hunt `evidence` com camada de fonte, quantidade real de sessões, marcador de amostra limitada quando há menos de três, e flags explícitas de ranking experimental e `confidence_index_is_statistical_probability=false`; adiciona contagens agregadas de amostra nos resultados. Mantém o ranking original, escopo privado do inventário, limites e custo de RPCs (não acrescentou query por hunt). Metodologia acrescenta `performance_values_are_observed_not_guaranteed=true` e `no_results_does_not_mean_no_hunts_exist=true`.
2. `web/app/src/routes/planner.tsx`: troca porcentagem de "Conf." sem contexto por **quantidade de sessões**; sinaliza "**Amostra limitada — comparar com cautela**" para menos de 3, indica que XP e profit vêm de observações e não são promessas nem estatística garantida, e apresenta estado vazio honesto quando nenhum resultado existe. Título agora "**Hunts com desempenho observado**", não resultados definitivos para todo o catálogo.
3. Corrige resultado obsoleto de filtros: toda alteração de Vocação/Level/Objetivo/Set/Party invalida a busca anterior; respostas HTTP antigas de requisições ainda em voo não reintroduzem cards inconsistentes.

## Testes e evidências

- [Web CI de implementação #38342627824 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38342627824): build e TypeScript.
- [FE-38 Browser QA inicial #38342705224 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38342705224): Playwright no site compilado local e no Cloudflare Worker publicado, com API mockada e sem gravações privadas; card de 1 sessão com aviso e sem falsa porcentagem de confiança, mudança de filtros limpando resultado antigo, sem sessões apresentando estado vazio. Capturas sob `fe38-planner-qa`.
- **[FE-38 Browser QA + API live #38342758472 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38342758472):** verificou no Worker real, por leitura, **EK/RP/ED/MS/EM** com número de sessões, flags de confiança não probabilística, conservação do ranking e amostra limitada; não criou dados privados. Depois validou no Chromium a apresentação do Planner local **e publicada**: 1 sessão → amostra limitada; remoção da falsa porcentagem `Conf.`; filtros alterados → cards anteriores não reaparecem; sem observações → estado vazio, sem estimar XP ou profit. Artifact `huntnexus-fe38-planner-evidence-qa`, id `11787109120`, 504.425 bytes com dois cenários em cada frontend.
- **[FE-38 QA final, após ajuste de robustez #38342838599 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38342838599):** repetição completa de API live para EK/RP/ED/MS/EM, frontend local/publicado e screenshots no commit de QA final.
- **[Web CI final #38342838604 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38342838604):** build e TypeScript, regressões do Session Parser, autenticação privada, snapshots e testes de cinco vocações aprovados após último ajuste de QA.

## Limites de aceitação

- Os exemplos visuais são fixtures **sintéticas** de QA e o teste live de API é somente leitura; nenhum cliente, ficha de personagem ou sessão real foi alterado.
- O ranking depende de observações disponíveis. Mesmo 3+ sessões não tornam os resultados representativos da população ou garantidos para qualquer jogador.
- O índice interno de confiança continua disponível na API para estudo técnico, mas não é exibido como porcentagem de chance.
- Antes do aceite completo, aprofundar acervo factual com proveniência/versionamento e ampliar cobertura real de vocações e spawns; login real A/B, hardening e homologação final seguem nas respectivas frentes.
- Maturidade editorial anterior mantida: Backend 94%, Optimizer 92%, Profile/Inventário 96%, Session Analyzer 87%, Planner 86%, Factual 74%, Frontend 74%, Produção/Segurança 70%. Não representam métricas de cobertura.

## Próximo bloco sugerido

FE-39: melhorar a apresentação de **cobertura factual/observacional por hunt** e no Hunt Detail, aprofundando catálogo e acessibilidade sem reabrir sessões reais.
