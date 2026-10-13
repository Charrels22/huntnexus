# Índice histórico HuntNexus para Codex

**Criado:** 2026-10-13, após FE-39. O objetivo é dar acesso rápido ao conhecimento **versionado dentro do GitHub** quando o executor não dispõe das conversas do ChatGPT. A fonte da verdade continua sendo o código, as migrations e os testes atuais.

## Leia primeiro

1. [AGENTS.md](../AGENTS.md): invariantes, tiers, segurança e execução por etapas.
2. [CODEX_START_HERE.md](../CODEX_START_HERE.md): prompt inicial para Codex.
3. [CURRENT_STATUS.md](../CURRENT_STATUS.md): estado mais recente confirmado.
4. [ROADMAP_EXECUTION.md](../ROADMAP_EXECUTION.md): FE-40 e próximas frentes; tarefa [Issue #2](https://github.com/Charrels22/huntnexus/issues/2).
5. [TESTING_GUIDELINES.md](../TESTING_GUIDELINES.md): procedimentos verificáveis de CI/QA.
6. [ARCHITECTURE.md](ARCHITECTURE.md): camadas e infraestrutura.

## Primeiras fases: base e infraestrutura

- [Phase 12](CHECKPOINT_2026-10-06_PHASE12.md) — evolução inicial do produto/backend.
- [Phase 16](CHECKPOINT_2026-10-06_PHASE16.md) e [Phase 16.2](CHECKPOINT_2026-10-06_PHASE16_2.md) — primeiras integrações.
- [Cloudflare + Supabase](CHECKPOINT_2026-10-07_CLOUDFLARE_SUPABASE.md), [infra independente](CHECKPOINT_2026-10-07_INDEPENDENT_INFRA.md), [MVP Phase 19](CHECKPOINT_2026-10-07_MVP_PHASE19.md), [Product API](CHECKPOINT_2026-10-07_PRODUCT_API.md).

## Produto, optimizer e Session Analyzer: FE-15 a FE-22

- [FE-15 Recovery](CHECKPOINT_2026-10-10_FE15_RECOVERY.md)
- [FE-17 Product Closure](CHECKPOINT_2026-10-10_PRODUCT_CLOSURE_FE17.md)
- [Session Analyzer Closure](CHECKPOINT_2026-10-10_SESSION_ANALYZER_CLOSURE.md)
- [Optimizer Perf FE-18](CHECKPOINT_2026-10-11_OPTIMIZER_PERF_FE18.md)
- [FE-19 API + Account Browser QA](CHECKPOINT_2026-10-11_FE19_API_ACCOUNT_BROWSER_QA.md)
- [FE-20 Community Account Sync](CHECKPOINT_2026-10-11_FE20_COMMUNITY_ACCOUNT_SYNC.md)
- [FE-21 Source Parser + Proficiency](CHECKPOINT_2026-10-11_FE21_REAL_SOURCE_PARSER_PROFICIENCY.md)
- [FE-22 Online Analyzer Excerpts](CHECKPOINT_2026-10-11_FE22_ONLINE_ORIGINAL_ANALYZERS.md)

## Segurança, Profile, inventário e proficiência: FE-23 a FE-31

- [FE-23 Party/Damage boundary](CHECKPOINT_2026-10-12_FE23_PARTY_DAMAGE_BOUNDARY.md)
- [FE-24 Five-vocation private snapshots](CHECKPOINT_2026-10-12_FE24_FIVE_VOCATION_PRIVATE_SNAPSHOTS.md)
- [FE-25 RP ammo/multislot snapshot](CHECKPOINT_2026-10-12_FE25_MULTISLOT_RP_AMMO_SNAPSHOTS.md)
- [FE-26 Main identity guards](CHECKPOINT_2026-10-12_FE26_MAIN_IDENTITY_GUARDS.md)
- [FE-27 Bound account security](CHECKPOINT_2026-10-12_FE27_BOUND_ACCOUNT_SECURITY.md)
- [FE-28 Auth resilience QA](CHECKPOINT_2026-10-12_FE28_AUTH_RESILIENCE_QA.md)
- [FE-29 OTP negative Browser QA](CHECKPOINT_2026-10-12_FE29_OTP_NEGATIVE_BROWSER_QA.md)
- [FE-30 Global auth boundary](CHECKPOINT_2026-10-12_FE30_GLOBAL_AUTH_BOUNDARY.md)
- [FE-31 Source-backed Proficiency Browser QA](CHECKPOINT_2026-10-12_FE31_PROFICIENCY_SOURCE_BROWSER_QA.md)

## Sessions, Planner, Hunt Detail: FE-32 a FE-39

- [FE-32 Real-user session feedback & deferred acceptance](CHECKPOINT_2026-10-12_FE32_SESSION_REAL_USER_FEEDBACK.md)
- [FE-33 Explicit session setup](CHECKPOINT_2026-10-12_FE33_EXPLICIT_SESSION_SETUP.md)
- [FE-34 Safe session reparse](CHECKPOINT_2026-10-12_FE34_SAFE_SESSION_REPARSE.md)
- [FE-35 Session revision restoration](CHECKPOINT_2026-10-12_FE35_SESSION_REVISION_RESTORE.md)
- [FE-36 Damage Input & Misc parser truth](CHECKPOINT_2026-10-12_FE36_DAMAGE_MISC_TRUTHFUL_IMPORT.md)
- [FE-37 Session integrity/completeness](CHECKPOINT_2026-10-13_FE37_SESSION_INTEGRITY_COMPLETENESS.md)
- [FE-38 Planner observational evidence](CHECKPOINT_2026-10-13_FE38_PLANNER_OBSERVATIONAL_EVIDENCE.md)
- [FE-39 Hunt factual provenance](CHECKPOINT_2026-10-13_FE39_HUNT_FACTUAL_PROVENANCE.md)
- [FE-40 Catalog discovery](CHECKPOINT_2026-10-13_FE40_CATALOG_DISCOVERY.md) — código/QA local; consultar o checkpoint para CI e publicação.
- [FE-41 Navigation/accessibility](CHECKPOINT_2026-10-13_FE41_NAVIGATION_ACCESSIBILITY.md).
- [FE-42 Factual/overlay audit](CHECKPOINT_2026-10-13_FE42_FACTUAL_OVERLAY_AUDIT.md).
- [FE-43 Build/imbuement UX](CHECKPOINT_2026-10-13_FE43_BUILD_IMBUEMENT_UX.md).

**Observação:** a numeração inicial `PHASE` e os nomes de arquivos FE-15–22 não necessariamente representam cobertura homogênea de todas as tarefas; não inventar checkpoints ausentes nem interpretar qualquer PASS sintético como aceitação de sessões reais.

## O que o Codex deverá fazer

- Criar checkpoint FE-40 após modificar código e executar testes.
- Adicionar o novo link a este índice.
- Atualizar [CURRENT_STATUS.md](../CURRENT_STATUS.md) com o progresso real e próximo passo.
- Não reabrir repetidamente o aceite manual de [Issue #1](https://github.com/Charrels22/huntnexus/issues/1); deixá-lo para a fase final, sem alterar dados do usuário.
