# HuntNexus — status e ponto exato da transferência

**Data da fotografia:** 2026-10-13. **Última etapa publicada e evidenciada:** **FE-39**. **Release congelado para realinhamento:** PRs #3 e #4 em Draft; filtro de build de produção Cloudflare alterado de `web/app/**` para o caminho reservado inexistente `.__huntnexus_release_freeze__/**`; Worker ativo preservado na versão 250 (`143d8692-b52c-4c0b-bd0e-af6cf980341e`). Merge/publicação não executados. [Checkpoint do Tópico 1](docs/CHECKPOINT_2026-10-13_TOPIC01_RELEASE_FREEZE.md). Consultar `git log`, GitHub e Cloudflare antes de executar, pois este arquivo pode ficar desatualizado.

## Realinhamento — Tópicos 1 e 2 concluídos

GitHub `main` está em `f87893888d58dc8ccf589bd3294646a2cb8cc328`; PR #3 está no head `102513f8874bf26e86ab707861fc112a4dd9734b`; a baseline de código do PR #4 antes do checkpoint documental é `373990fee73c837597b9c49975a8637c92b6aa89`. Os dois permanecem abertos, agora como Draft. Supabase `urbncbjapasnjqjqicjv` está `ACTIVE_HEALTHY`, com 167 migrations e última `0161_fe39_hunt_evidence_context`; nenhuma escrita foi feita.

O deployment ativo foi criado por Wrangler e não contém SHA Git atribuível. A identidade comprovada de produção é Cloudflare deployment `4df50565-35a8-4d58-9103-b406d920b059`, versão 250. Não executar merge, `wrangler deploy` nem restaurar `web/app/**` até o descongelamento explícito após o realinhamento.

[ADR-0001](docs/ADR_0001_PRODUCT_DOMAIN_AND_BRAIN.md) agora fixa: HuntNexus como produto; Brain como conhecimento versionado; descoberta pública; conta para personalização; uma conta com vários personagens; `client_id` como legado; recomendações explicáveis; aprendizado por candidatos e promoção controlada. [ROADMAP_EXECUTION.md](ROADMAP_EXECUTION.md) substitui a sequência FE-40–48 como ordem corrente. **Próximo: Tópico 3, auditoria completa e mensurável do Brain.**

## Entregas que devem permanecer funcionais

| Área | Estado em 2026-10-13 | Implementação/evidência |
| --- | --- | --- |
| Perfil e inventário | Operacional em testes técnicos: Main, BP, build por hunt e validação de propriedade | `web/app/src/routes/profile.tsx`, migrations 0118–0128, FE-24–26 |
| Weapon Proficiency | UI/árvores com ícones e indicação explícita de topologia não comprovada | FE-31 e `web/app/tests/frontend-live-browser-smoke.mjs` |
| Session Analyzer | Parse dos 4 blocos, duração, sprites, damage/misc, snapshots, histórico | FE-32, FE-33, FE-36, FE-37 |
| Revisões de sessão | Preview de diff, reparse conservador, versões anteriores e restauração opt-in | FE-34, FE-35 |
| Planner | Ranking observacional, personalização leve com Profile, contagem de amostras, avisos e filtros reativos | FE-38 |
| Hunt Detail | Facts por hunt, medições observadas separadas, source/tier/data e 4 dimensões de cobertura | FE-39, migration `0161_fe39_hunt_evidence_context.sql` |
| Optimizer | Conjuntos concretos, imbuements, proficiency, compatibilidade e lazy calls | Ver workflows de optimizer e migrations 0088–0111 |
| Infra | GitHub, Supabase, Cloudflare Worker e workflows CI existentes | `docs/ARCHITECTURE.md`, `.github/workflows/` |

As etapas FE-32–39 estão nos respectivos `docs/CHECKPOINT_*`; **não reimplementar ou desativar** esse comportamento sem uma regressão explícita.

## Evidência mais recente verificada

- FE-39: [Web CI verde](https://github.com/Charrels22/huntnexus/actions/runs/38344655758), [QA do Hunt Detail e API publicado verde](https://github.com/Charrels22/huntnexus/actions/runs/38344677821), [Browser QA geral verde](https://github.com/Charrels22/huntnexus/actions/runs/38344690024).
- Detalhamento: [checkpoint FE-39](docs/CHECKPOINT_2026-10-13_FE39_HUNT_FACTUAL_PROVENANCE.md).
- Leitura do catálogo Supabase em 2026-10-13: 459 entradas; 454 hunts elegíveis para Planner com core factual completo; **26 hunts** com alguma observação. Essas contagens são fotografia do banco, não números permanentes, nem 454 hunts com performance comprovada.
- Confirmado em FE-39: Cobra Bastion com 11/11 criaturas cobertas nas quatro dimensões, Forest of Life com 3/3, ambas com proveniência fonte B. O link da fonte é geral e a data é a registrada na coleta.
- O último teste verde não garante que futuras alterações de infraestrutura/deploy continuarão iguais. Testar novamente ao alterar funcionalidades.

## Pendências reais — entradas do realinhamento

- [Issue #1](https://github.com/Charrels22/huntnexus/issues/1): aceite com exports originais e consentidos de sessão de jogador, incluindo MS/The Void (Zao), Damage Input, Misc, Combat Stats, localização, sprites e setup. Já foram corrigidas várias falhas técnicas; **não** usar o issue como motivo para interromper outras frentes a cada sprint. Não reprocessar dados do usuário sem aprovação.
- Validação externa com representantes **EK/RP/ED/MS/EM** e dados reais; testes sintéticos e reconstruções Tier C não substituem esse aceite.
- Magic Link real, sessões autenticadas em mais de um dispositivo, RLS/privacidade, monitoração e hardening de produção: critérios finais; não declarar homologado sem teste correspondente.
- Fontes oficiais RubinOT, overlays de patch/versionamento, casos de mecânica sem evidência e três árvores de weapon proficiency com topologia insuficientemente comprovada (`gnome-sword`, `moonsilver-katar`, `pair-of-monk-fists` no último levantamento). Verificar DB antes de afirmar que lacuna persiste.
- Conteúdo observacional ralo: a maior parte das hunts catalogadas não tem sessões públicas. Não inventar XP/profit para suprir lacunas.
- Acessibilidade, usabilidade desktop/mobile, busca/navegação de hunts, cache/performance e operação de release continuam backlog.

## Progresso editorial herdado (não interpretar como cobertura real)

| Frente | Estimativa anterior |
| --- | ---: |
| Backend | 94% |
| Optimizer | 92% |
| Profile/Inventário | 96% |
| Session Analyzer | 87% |
| Hunt Planner | 86% |
| Conteúdo factual | 74% |
| Frontend visual | 74% |
| Produção/Contas/Segurança | 70% |

Não incrementar automaticamente por ter criado documentação, fixtures ou testes novos. Priorizar critérios de aceite verificáveis.

## Próxima ação sem intervenção manual obrigatória

**Executar o Tópico 3 de [ROADMAP_EXECUTION.md](ROADMAP_EXECUTION.md): auditar o Brain completo**. Produzir uma matriz única por fonte com evidência de cadastro, acesso, coletor, ingestão, normalização, proveniência, automação, termos, cobertura e lacunas; atualizar a visualização a partir do mesmo snapshot. Não modificar fontes, banco ou autenticação durante a auditoria.
