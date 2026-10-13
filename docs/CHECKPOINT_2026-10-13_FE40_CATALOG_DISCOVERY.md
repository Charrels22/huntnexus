# FE-40 — descoberta do catálogo factual

Data: 2026-10-13. Issue: https://github.com/Charrels22/huntnexus/issues/2.
Base inspecionada: `f87893888d58dc8ccf589bd3294646a2cb8cc328`.
Branch: `codex/fe40-catalog-discovery`. Status: **FE-40 CONCLUÍDA TECNICAMENTE**, implementação, QA local e CI PASS; merge/publicação não executados.
PR: https://github.com/Charrels22/huntnexus/pull/3.
Commit de implementação testado localmente e no CI: [eba2a6ad09a3c8f04948cc8a3464e61a465dec70](https://github.com/Charrels22/huntnexus/commit/eba2a6ad09a3c8f04948cc8a3464e61a465dec70).

## Mudança

- `web/app/src/routes/hunts.index.tsx`: `/hunts` reutiliza `search_hunts`, busca por nome/cidade/slug, debounce de 300 ms, descarte de respostas antigas e após unmount, loading/erro/retry/vazio, limite explícito de 50 e query compartilhável via Enter/Buscar. Limite de texto de 100 caracteres acompanha o schema real da API.
- Home/shell: entrada do catálogo e busca do cabeçalho funcional. Navegação mobile reutilizada; catálogo ativo também em Hunt Detail.
- Hunt Detail/Planner: caminhos de retorno ao catálogo e acesso ao Planner, inclusive quando o detalhe falha.
- Cards: referência factual Tibia/fonte B separada de contagem observacional Tier C, zero sessões continua navegável, nível ausente permanece não informado. Nenhuma XP/profit inventada, fórmula de ranking ou sessão alterada.
- Sem migration, scraping, deploy, alteração de secrets ou consulta por card. A API/RPC existente mantém a elegibilidade. Leitura direta no Supabase confirmou a definição publicada de `huntnexus_search_hunts` equivalente à migration 0143 e os três índices de `tibia_hunting_places`: PK id, slug único e external_id parcial. Nenhum índice trigram presente nesta tabela. Sem `EXPLAIN`, não atribuir desempenho a um índice não verificado.

## QA executado localmente

Runtime local Node 24.14.1; CI configurado para Node 22. Cwd dos testes frontend: `web/app`.

| Evidência | Resultado |
| --- | --- |
| `npm run build` (Vite + `tsc --noEmit`) | PASS |
| Dez testes canônicos de Web CI (FE-28/30, parser, FE-36/37/39/32/34, reconstrução de cinco vocações e excerpts) | PASS; limites de fixtures/fontes mantidos |
| `node ../../tests/fe40-catalog-live-smoke.mjs` | PASS; API publicada read-only, busca inicial/slug/cidade/acento/vazio/limite e detalhe de hunt sem sessões |
| `node tests/fe40-catalog-preview.mjs` | PASS; SYNTHETIC, desktop 1440×1000 e mobile 390×844, debounce, respostas fora de ordem, retry, vazio, erro, loading, limite, teclado, acentos e slug canônico, Home/shell/Planner/detail, sem overflow ou pageerror |
| `node tests/fe40-catalog-live-browser.mjs` | PASS; frontend compilado local + API pública real, desktop/mobile, Forest of Life com zero sessões, detalhe com ByteWizards TibiaData; requests privados do shell mockados vazios |
| FE-38 Planner e FE-39 evidência factual browser com `HUNTNEXUS_BASE_URL=http://127.0.0.1:4173` | PASS; fixtures SYNTHETIC, não gameplay real |
| `git diff --check` | PASS |

Screenshots locais: `web/app/fe40-catalog-qa/` (resultados/loading/vazio/erro SYNTHETIC e catálogo/detail com API real). Capturas desktop/mobile inspecionadas visualmente. Artefatos não entram em Git; o workflow FE-40 preserva as imagens por 14 dias.

## CI confirmado e integrações

- [Web CI #38347197819](https://github.com/Charrels22/huntnexus/actions/runs/38347197819): **completed/success**, Node 22, build e dez regressões.
- [FE-40 Catalog Discovery #38347197928](https://github.com/Charrels22/huntnexus/actions/runs/38347197928): **completed/success**, build, API read-only, QA SYNTHETIC desktop/mobile, regressões visuais FE-38/39 e frontend local com API real. Screenshots no artefato `huntnexus-fe40-catalog-qa` deste run.
- GitHub autenticado com permissão admin e push/PR realizados. Supabase projeto `urbncbjapasnjqjqicjv` / HuntNexus `ACTIVE_HEALTHY` e SQL read-only acessível. Cloudflare autenticado; leitura do Worker `huntnexus` confirmou compatibility date `2026-10-07` e bindings `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` do tipo `secret_text`. Apenas nomes/tipos dos bindings foram lidos; nenhum valor de secret coletado.
- Não foi identificada configuração ausente para a FE-40. Essas verificações não autorizam escrita em produção nem comprovam permissões de deploy.

API real: consulta vazia retornou 50, `forest-of-life` retornou 1 com zero sessões, consulta inexistente retornou 0. `São` foi preservado e retornou 0; isso não comprova busca sem diacríticos. No smoke formal, `abdendriel-elf-cave` foi encontrado sem sessões e o detalhe confirmou fonte B. Latências das cinco buscas formais: 183/75/50/238/58 ms nesta execução, sem promessa de SLO.

## Limites e próximos passos

| Frente | Estado |
| --- | --- |
| Implementação e QA local FE-40 | PASS verificado |
| CI do PR | PASS verificado; runs de código acima |
| Publicação da FE-40 e browser no site publicado | NÃO EXECUTADO; API publicada existente validada separadamente |
| Metadados/RPC/índices SQL de produção read-only | PASS verificado; sem escrita |
| Sessões privadas / Magic Link / alteração SQL de produção | NÃO EXECUTADO; fora do escopo |

Próximo bloco: FE-41, aprofundar navegação cruzada Hunt Detail/Planner, contexto de filtros e acessibilidade/estados de fonte ausente. FE-40 já oferece os links básicos; não interpretar isso como aceite integral da FE-41. Merge/deploy não realizados neste checkpoint.
