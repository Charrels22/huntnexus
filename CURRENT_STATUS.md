# HuntNexus — status e ponto exato da transferência

**Data da fotografia:** 2026-10-13. **Última etapa técnica fechada e evidenciada:** **FE-39**. **Próxima etapa de desenvolvimento:** **FE-40**. Consultar `git log` e GitHub Actions antes de executar, pois este arquivo pode ficar desatualizado.

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

## Pendências reais — registradas, mas não bloquear FE-40

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

**Executar [FE-40 — Issue #2](https://github.com/Charrels22/huntnexus/issues/2), segundo [ROADMAP_EXECUTION.md](ROADMAP_EXECUTION.md)**: inspecionar fluxo existente de `search_hunts`, home, shell, Planner e Hunt Detail; implementar avanço tangível de navegação e descoberta do catálogo; testar CI e browser; documentar. A homologação manual das sessões fica para a fase final.
