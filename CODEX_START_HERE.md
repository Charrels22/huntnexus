# Começar o HuntNexus no Codex

**Objetivo atual:** continuar o repositório `Charrels22/huntnexus` sem reiniciar a fundação, seguindo o realinhamento de produto e arquitetura definido no [ADR-0001](docs/ADR_0001_PRODUCT_DOMAIN_AND_BRAIN.md).

## Estado obrigatório antes de trabalhar

- A promoção está congelada. PRs #3/#4 estão Draft e o gatilho de produção Cloudflare está bloqueado por filtro reversível.
- FE-40–48 permanecem como histórico técnico reutilizável; não são a ordem corrente.
- Tópicos 1 a 4 do [roadmap](ROADMAP_EXECUTION.md) estão concluídos.
- O **Tópico 4** está na PR Draft #7; `0162` e o complemento de índices `0163` foram aplicados no Supabase após autorização explícita. Backfill, ownership, permissões, regressão `SYNTHETIC` e limpeza passaram.
- A próxima ação é o Tópico 5: auditar e reconstruir autenticação/recuperação. Preparar toda mudança e evidência antes de pedir autorização para alterar a configuração real do Auth.

## Ordem de leitura

1. `AGENTS.md`
2. `docs/ADR_0001_PRODUCT_DOMAIN_AND_BRAIN.md`
3. `PROJECT_CONTEXT.md`
4. `CURRENT_STATUS.md`
5. `ROADMAP_EXECUTION.md`
6. `TESTING_GUIDELINES.md`
7. `docs/ARCHITECTURE.md`
8. `docs/CODEX_HANDOFF_CHECKPOINT_INDEX.md`
9. checkpoints mais recentes de realinhamento

## Prompt de continuidade

> Continue o HuntNexus a partir do tópico marcado como próximo em `ROADMAP_EXECUTION.md`, um tópico por vez. Confirme HEAD, PRs, produção e estado local antes de alterar arquivos.
>
> Preserve a fundação existente e obedeça ao ADR-0001: experiência pública para descoberta; conta para personalização; uma conta com vários personagens; Brain versionado; recomendações explicáveis; aprendizado por candidatos e promoção controlada.
>
> Execute o Tópico 5: audite Supabase Auth, API e sessões; defina entrada forte, MFA, recuperação, gestão de dispositivos e isolamento entre contas/personagens. Prepare código e regressões sem alterar o Auth real até autorização explícita.
>
> Execute validações proporcionais, registre checkpoint e atualize `CURRENT_STATUS.md`. Publique branch/PR para revisão, mantendo merge e deploy congelados.

## Como acompanhar

- Repositório: https://github.com/Charrels22/huntnexus
- Actions: https://github.com/Charrels22/huntnexus/actions
- Produção preservada: https://huntnexus.charr3ls22.workers.dev
- Decisão arquitetural: `docs/ADR_0001_PRODUCT_DOMAIN_AND_BRAIN.md`
- Roadmap corrente: `ROADMAP_EXECUTION.md`
- Estado: `CURRENT_STATUS.md`
- Checkpoints: `docs/CHECKPOINT_*.md`

O Codex não recebe automaticamente conversas externas. Código, migrations, ADR, roadmap e evidências versionadas no GitHub prevalecem sobre resumos antigos. Documentar um plano não autoriza uma ação irreversível.
