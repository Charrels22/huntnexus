# HuntNexus — status e ponto exato da transferência

**Data da fotografia:** 2026-10-13. **Última etapa publicada e evidenciada:** **FE-39**. **FE-40: build/QA local e CI PASS; PR #3 aberto. FE-41–44/46: incrementos e auditoria em continuação; FE-48: preparação documental.** Merge/publicação não executados. Próximos passos: revisão/CI da continuação e portões reais de homologação. Consultar `git log` e GitHub Actions antes de executar, pois este arquivo pode ficar desatualizado.

## FE-40 — execução no Codex
FE-45 parcial: Site URL/allowlist corrigidos e conferidos. Após uma tentativa bloqueada por cota, o usuário forneceu capturas das duas contas autenticadas e Dados/Sincronizados em navegador padrão/anônimo: login/resolução na UI PASS parcial. Celular apenas abriu a página, sem Auth concluído; dados A/B, negativos de acesso cruzado e sincronização real entre dispositivos seguem pendentes. [Checkpoint FE-45](docs/CHECKPOINT_2026-10-13_FE45_AUTH_REDIRECT_BLOCK.md).
Continuação [PR #4](https://github.com/Charrels22/huntnexus/pull/4): código/testes SHA `a06568276630ef2e79bc68638b56a87b771a7fd6`, [Web CI PASS](https://github.com/Charrels22/huntnexus/actions/runs/38357853053), [Browser/API QA PASS](https://github.com/Charrels22/huntnexus/actions/runs/38357853039). [Quadro consolidado de evidências/limites](docs/CHECKPOINT_2026-10-13_CONTINUATION_CI.md). Publicação continua em FE-39; PRs sem merge/deploy.
FE-41: implementada na branch de continuação, build e QA SYNTHETIC desktop/mobile das cinco vocações PASS. Preserva contexto entre Planner/detail e busca do catálogo, adiciona abas acessíveis e retry. [Checkpoint FE-41](docs/CHECKPOINT_2026-10-13_FE41_NAVIGATION_ACCESSIBILITY.md). CI consolidado acima.
FE-42: auditoria Supabase read-only PASS; fotografia e query reproduzível no [checkpoint FE-42](docs/CHECKPOINT_2026-10-13_FE42_FACTUAL_OVERLAY_AUDIT.md). 454 hunts elegíveis/core completo; zero overrides RubinOT aplicados; 14 candidatos oficiais v13.4–v13.9 pendentes/sem valor exato. Auditar armazenamento não equivale a validar patch live. Próximo bloco: FE-43.
FE-43: incremento Main/BP/imbuements local PASS, com testes SYNTHETIC separados por vocação e pacotes de mão públicos validados read-only. Ausência não vira potência 0%; denominadores e fonte ausente explícitos. Constraints completas, proficiências sem fonte e piloto privado não são homologados por essa UX. [Checkpoint FE-43](docs/CHECKPOINT_2026-10-13_FE43_BUILD_IMBUEMENT_UX.md).
FE-44: factual preservado em falhas auxiliares, cancelamento/timeout de busca; QA local PASS. Carga/cache/latência em produção pendentes. [Checkpoint FE-44](docs/CHECKPOINT_2026-10-13_FE44_DETAIL_RESILIENCE.md).
FE-46: incremento de teclado/menu mobile PASS; auditoria de acessibilidade completa pendente. [Checkpoint FE-46](docs/CHECKPOINT_2026-10-13_FE46_SHELL_ACCESSIBILITY.md).
FE-48: checklist operacional/rollback e health público read-only; preparação, sem release. [Checkpoint FE-48](docs/CHECKPOINT_2026-10-13_FE48_RELEASE_PREPARATION.md). FE-45/47 permanecem pendentes de contas/pilotos e dados consentidos; não houve escrita privada.

Catálogo `/hunts` acessível de Home/shell, busca com debounce e proteção contra respostas antigas, estados explícitos, links para Hunt Detail e Planner. Hunts sem sessões permanecem navegáveis, com fonte B separada de Tier C. Build/TypeScript, dez regressões canônicas, QA SYNTHETIC desktop/mobile, FE-38/39 browser e frontend local com API publicada real read-only passaram. Sem migration/deploy ou alteração de sessões privadas. Evidências e limitações: [checkpoint FE-40](docs/CHECKPOINT_2026-10-13_FE40_CATALOG_DISCOVERY.md).

[PR #3](https://github.com/Charrels22/huntnexus/pull/3); [Web CI PASS #38347197819](https://github.com/Charrels22/huntnexus/actions/runs/38347197819); [FE-40 QA PASS #38347197928](https://github.com/Charrels22/huntnexus/actions/runs/38347197928), commit `eba2a6a`. GitHub, Supabase read-only e Cloudflare/Worker settings acessíveis; não há bloqueio de configuração identificado para esta etapa.

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

**Fechar CI/revisão da [FE-40 — Issue #2](https://github.com/Charrels22/huntnexus/issues/2) e avançar para FE-41 conforme [ROADMAP_EXECUTION.md](ROADMAP_EXECUTION.md)**. A homologação manual das sessões fica para a fase final. Não declarar FE-40 publicada com base no QA local.
