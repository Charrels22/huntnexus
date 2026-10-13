# HuntNexus — roadmap para execução contínua pelo Codex

**Ponto de partida:** FE-39 encerrada tecnicamente. **Etapa seguinte:** FE-40. Execute em blocos pequenos e verificáveis; o objetivo não é reescrever o projeto. Reavaliar a prioridade conforme código real, regressões e bloqueios. Atualizar `CURRENT_STATUS.md` e checkpoint ao fim de **cada** etapa.

## Processo de cada etapa

1. Ler `AGENTS.md`, `PROJECT_CONTEXT.md`, `CURRENT_STATUS.md`, este roteiro e `TESTING_GUIDELINES.md`.
2. Confirmar HEAD, pendências não commitadas, últimas execuções de Actions e arquivos existentes; **não presumir que documentação antiga seja a implementação atual**.
3. Analisar arquitetura, RPCs, dados de fonte e testes já disponíveis; desenhar mudança mínima; evitar N+1 queries, duplicações de fonte e breakage de API.
4. Implementar frontend, backend, migrations e docs estritamente necessários à etapa.
5. Executar `npm run build`, testes específicos e regressões; QA de browser com screenshots quando UI for alterada; verificar endpoint publicado apenas depois de deploy confirmado.
6. No GitHub, manter commits coesos e PR ou branch de trabalho quando disponível; não fazer merge com CI falhando. Criar checkpoint com hashes, Actions e evidências **efetivamente executadas**.
7. Entregar quadro compacto **FE-NN — PASS / Pendente / Bloqueado**, módulo alterado, URLs, risco residual e próximo bloco. Prosseguir com a próxima etapa permitida; pedir intervenção apenas para permissões, decisões essenciais, mudanças destrutivas ou dados privados.

## FE-40 (primeiro trabalho a executar) — navegação e descoberta do catálogo

**GitHub issue de implementação:** [#2 — FE-40 para Codex](https://github.com/Charrels22/huntnexus/issues/2).

**Problema:** Home mostra hunts com amostras observadas, Planner ranqueia subset e Hunt Detail funciona por slug. O usuário ainda precisa descobrir as demais hunts **factuais** facilmente, inclusive aquelas sem dados de performance.

**Investigar antes de codificar:**
- `web/app/src/routes/index.tsx`, `planner.tsx`, `hunts.$huntKey.tsx`, shell.
- API existente `search_hunts` em `web/app/src/routes/api/huntnexus.ts`, RPC `huntnexus_search_hunts` e filtro de elegibilidade em `db/migrations/0143_search_hunts_catalog_eligibility.sql`.
- Contrato real de resposta: colunas, busca vazia, limites, slug único, status de spawns não fixos, carga/latência; usar read-only para verificar. Não assumir endpoint ou campo não verificado.

**Implementação-alvo**, caso lacuna persista:
- Uma descoberta de catálogo acessível a partir da navegação ou Home (por exemplo `/hunts` com busca), conectando cada resultado à URL canônica `/hunts/$huntKey` e ao Planner.
- Diferenciar cards **catálogo factual** e **performance observada**. Não rotular ausência de sessões como hunt inexistente/inadequada. Não usar `confidence_score` como probabilidade.
- Busca responsiva com debounce, estados carregando/vazio/erro, atalhos de teclado/acessibilidade e proteção contra respostas fora de ordem (filtros antigos).
- Não ocultar cidades/hunts úteis por exigir amostra Tier C. Honrar exclusões `planner_eligible`, papéis boss/non-fixed e regras atuais da API, justificando filtros.
- Reutilizar sprites e estilos já existentes; não baixar imagens ou criar arte especulativa. Evitar consultas pesadas e N+1 por item.
- Navegação compatível mobile e desktop; breadcrumbs/links para retorno do detalhe quando apropriado.

**Aceite mínimo FE-40:**
- Pelo menos uma consulta com resultados **sem performance** permanece navegável no catálogo (se disponível na fonte), sem inventar métricas.
- Busca e resultado vazio testados; caracteres acentuados/slug preservados.
- Links de detalhes corretos e sem regressão do Planner/Session Analyzer/optimizer.
- `npm run build` e regressões verdes; Playwright com fixture `SYNTHETIC` mais teste read-only do catálogo real; screenshots antes de marcar visual PASS.
- Checkpoint `docs/CHECKPOINT_YYYY-MM-DD_FE40_CATALOG_DISCOVERY.md` e atualização de `CURRENT_STATUS.md`.

**Escopo fora da FE-40:** reparsing de sessões reais, login real, migração/ingestão massiva, deploy com credenciais desconhecidas, nova fórmula de ranking, reescrita completa da UI.

## Sequência após FE-40

| Bloco | Prioridade | Objetivo observável | Condição de aceite |
| --- | --- | --- | --- |
| FE-41 | Alta | Hunt Detail/Planner: navegação cruzada, acessibilidade e estados de fonte ausente | Desktop/mobile, filtros coerentes, snapshots visuais, API sem consultas extras pesadas |
| FE-42 | Alta | Auditoria de lacunas **factuais** e overlays RubinOT por fonte/patch | Fonte/tier/data e ausência explícita, sem inventar conteúdo; testes SQL read-only |
| FE-43 | Alta | Optimizer e imbuements: UX de opções reais Main/BP, trade-offs e proveniência | EK/RP/ED/MS/EM em testes distintos, constraints de mão/ammo e sem itens externos como possuídos |
| FE-44 | Alta | Performance, cache e robustez: rotas quentes, concorrência e falhas parciais | Medidas antes/depois, regressões e rollback claro; sem overclaim de SLO |
| FE-45 | Alta | Conta/sincronização e privacidade: Auth real em múltiplos dispositivos, RLS, guest↔conta | Teste autorizado, isolamento A/B, logs sem dados privados |
| FE-46 | Média/alta | Acessibilidade, visual final, navegação mobile e boas mensagens | QA visual/manual orientado, fallbacks, teclado e layout |
| FE-47 | Alta | Matriz real de pilotos EK/RP/ED/MS/EM, analisadores, conteúdo, builds e optimizer | Exports consentidos e dados reais; divergências rastreadas, nunca preenchidas |
| FE-48 | Alta | Preparação de release: deploy, health checks, monitoração e critérios de abertura pública | Checklist operação + rollback + termos/privacidade + aprovação do dono |

**A ordem é proposta, não promessa**: dividir etapas maiores e repriorizar quando os testes justificarem. Registrar claramente o que não foi concluído. Não travar o avanço de catálogo e UX por falta de exports privados que só serão usados no piloto.

## Bloqueios que requerem o usuário

- Conectar repositório/organização ao ambiente Codex ou autorizar permissões que faltarem.
- Fornecer secrets **via gestão segura do provedor**, nunca colando em código/issue.
- Aprovar operações irreversíveis no banco, exclusões/reimportação de dados privados, publicação comunitária, gastos de infraestrutura e mudança sensível de autenticação.
- Agendar participação de jogadores reais na homologação final.
