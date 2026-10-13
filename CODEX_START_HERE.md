# Começar o HuntNexus no Codex

**Objetivo atual:** continuar o repositório `Charrels22/huntnexus` sem reiniciar a fundação, seguindo o realinhamento de produto e arquitetura definido no [ADR-0001](docs/ADR_0001_PRODUCT_DOMAIN_AND_BRAIN.md).

## Estado obrigatório antes de trabalhar

- A promoção está congelada. PRs #3/#4 estão Draft e o gatilho de produção Cloudflare está bloqueado por filtro reversível.
- FE-40–48 permanecem como histórico técnico reutilizável; não são a ordem corrente.
- Tópicos 1 e 2 do [roadmap](ROADMAP_EXECUTION.md) estão concluídos.
- A próxima etapa é o **Tópico 3: auditoria completa e mensurável do HuntNexus Brain**.
- Não executar merge, deploy, migration, mudança de autenticação ou escrita privada durante essa auditoria.

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
> No Tópico 3, produza uma matriz auditável para todas as fontes informadas e registradas. Para cada fonte, prove ou negue cadastro, acesso, coletor, ingestão, normalização, proveniência, atualização, termos, cobertura e lacunas. Gere a visualização a partir do mesmo snapshot versionado. Não invente conexão nem confunda cadastro com ingestão.
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
