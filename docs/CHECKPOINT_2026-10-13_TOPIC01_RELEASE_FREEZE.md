# Tópico 1 — congelamento de merge e produção

Checkpoint operacional de 2026-10-13. Este tópico interrompe promoções enquanto os objetivos e a arquitetura do HuntNexus são realinhados. Ele não desfaz código, migrations, dados ou a versão atualmente publicada.

## Estado congelado

| Superfície | Evidência registrada | Estado |
| --- | --- | --- |
| GitHub `main` | `f87893888d58dc8ccf589bd3294646a2cb8cc328` | congelado como base publicada conhecida no Git; não é possível atribuir este SHA ao Worker ativo porque o último deploy veio de Wrangler |
| PR #3 | base `main`; head `102513f8874bf26e86ab707861fc112a4dd9734b`; aberto e convertido para **Draft** | sem merge |
| PR #4 | base `codex/fe40-catalog-discovery`; baseline de código anterior a este checkpoint `373990fee73c837597b9c49975a8637c92b6aa89`; aberto e convertido para **Draft** | sem merge; o commit documental deste checkpoint avançará o head |
| Cloudflare Worker | `huntnexus`; versão ativa 250, ID `143d8692-b52c-4c0b-bd0e-af6cf980341e`; deployment `4df50565-35a8-4d58-9103-b406d920b059`, 100% | preservado |
| Cloudflare Builds | repositório `Charrels22/huntnexus`, branch de produção `main`; build `npm run build`; deploy `npx wrangler deploy`; raiz `web/app` | gatilho de produção bloqueado por filtro reversível |
| Supabase | projeto `urbncbjapasnjqjqicjv`, região `sa-east-1`, `ACTIVE_HEALTHY`, Postgres 17; 167 migrations, última `0161_fe39_hunt_evidence_context`; sem branches de desenvolvimento | somente leitura nesta etapa |

## Bloqueio aplicado

Antes do congelamento, commits em `main` que alterassem `web/app/**` podiam iniciar build e executar `npx wrangler deploy`. O filtro de produção foi alterado para `.__huntnexus_release_freeze__/**`, caminho inexistente e reservado para o bloqueio. `auto_build_enabled` continua ligado e previews continuam habilitados; assim, PRs podem gerar previews, mas alterações normais do repositório não satisfazem o filtro de produção.

Os PRs [#3](https://github.com/Charrels22/huntnexus/pull/3) e [#4](https://github.com/Charrels22/huntnexus/pull/4) foram convertidos para Draft. Nenhum PR foi fechado, mesclado ou publicado.

## Limite da prova

O Worker ativo informa `source=wrangler` e `last_deployed_from=wrangler`, sem annotation de commit Git. Portanto, a versão 250 e seu ID são a identidade comprovada da produção; afirmar que ela corresponde ao SHA atual de `main` seria inferência sem prova. O congelamento do gatilho Git também não revoga credenciais capazes de executar um deploy manual. A regra operacional permanece: não executar `wrangler deploy`, merge ou promoção até o descongelamento explícito.

## Verificação

- `GET` da configuração Cloudflare após a mudança: `path_includes=[".__huntnexus_release_freeze__/**"]`; branch `main`; previews habilitados.
- GitHub após a mudança: PR #3 e PR #4 abertos com `draft=true`, `merged=false`.
- Supabase: projeto saudável; inventário de migrations lido sem escrita.
- Health público read-only após o bloqueio: HTTP 200, `status=ok`, `recommendation_stage=preview_v7`, `final_recommendation_ready=false`.
- Nova leitura dos deployments após o bloqueio deve manter a versão 250/ID acima; o teste final registra essa confirmação.

## Descongelamento e rollback

1. Registrar o SHA candidato final e obter aprovação explícita de publicação.
2. Restaurar o filtro de produção para `web/app/**` somente no momento controlado de promoção.
3. Confirmar build/deployment e executar health e smoke read-only no SHA publicado.
4. Em regressão, retornar à versão `143d8692-b52c-4c0b-bd0e-af6cf980341e` pelo rollback do Cloudflare; isso cria um novo deployment com 100% do tráfego na versão escolhida. Revalidar bindings e health, pois rollback de Worker não reverte recursos conectados nem banco.
5. Se houver migration futura, tratar rollback de banco em plano próprio. Este tópico não alterou schema ou dados.

## Resultado

| Item | Resultado |
| --- | --- |
| Identidade de Git/PRs/produção/banco registrada | PASS |
| PRs protegidos contra merge normal | PASS |
| Gatilho automático de produção bloqueado | PASS |
| Produção atual preservada e rollback identificado | PASS |
| Relação exata Worker ativo ↔ SHA Git | PENDENTE — metadado não existe no deploy Wrangler atual |
| Merge, deploy ou escrita no banco | NÃO EXECUTADO |
