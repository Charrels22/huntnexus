# FE-42 — auditoria factual e overlays RubinOT

Data da consulta: 2026-10-13, timestamp UTC no JSON de evidência. **Auditoria PASS verificado; lacunas de conteúdo permanecem pendentes.** Somente SELECT via Supabase, sem ingestão, scraping, alteração de dados ou sessões privadas.

## Entrega reproduzível

- Query: `tests/sql/fe42-factual-overlay-audit.sql`.
- Resultado real: `docs/evidence/2026-10-13-fe42-factual-overlay-audit.json`.
- Cinco invariantes retornaram true: elegíveis com core completo, hunts com fonte/URL/data/snapshot, overrides com fonte A/patch/data, candidatos com fonte A/URL/data e ausência de intervalos de override sobrepostos. As duas verificações de overrides são **vacuamente verdadeiras**, pois não há nenhuma versão aplicada; não representam aprovação dos patches.

## Fotografia confirmada

459 entradas; 454 elegíveis/core completo; 455 spawns fixos; 4 entradas não fixas; 1 subárea fixa sem composição comprovada, excluída do Planner. 26 hunts com sessões e 22 com dano observado: enriquecimento comunitário, não requisito de core factual.

Todas as 459 hunts têm ByteWizards TibiaData, fonte B/tibia_factual, URL geral `https://tibiadata.bytewizards.de`, snapshot e data registrada. Datas registradas de 06/04/2026 a 28/09/2026; completude de armazenamento não comprova atualização do jogo ou patch.

Ausências opcionais no catálogo inteiro: cidade em 16, localização em 28, orientação de nível em 60. Essas contagens incluem entradas excluídas e não devem virar estimativas de nível ou exclusões adicionais silenciosas.

Exclusões documentadas pela semântica existente: `pits-of-inferno-levers` (quest_subarea, composição exclusiva não comprovada), `forsaken-mine`/`poacher-caves` (variáveis), `hunting-places` (diretório) e `magician-quarter` (região agregada). Nenhuma composição foi inferida para corrigir o audit.

## Overlays e prioridades reais

**Zero `rubinot_overrides` e zero overrides ativos.** Há 14 candidatos oficiais armazenados, todos com RubinOT Changelog, fonte A/rubinot_overlay, URL `https://rubinot.com.br/changelog` e observação em 07/10/2026. O audit valida o registro, não revalida o changelog ao vivo.

| Patch registrado | Pending | Needs exact value |
| --- | ---: | ---: |
| v13.4 | 1 | 1 |
| v13.5 | 0 | 1 |
| v13.6 | 0 | 2 |
| v13.7 | 1 | 0 |
| v13.8 | 2 | 1 |
| v13.9 | 3 | 2 |

Prioridades: reconciliar mecânicas Magma Bubble/Soul War antes de recomendações; obter valores oficiais exatos para Biscuit Barrier/Phantasmal Axe, Bloodjaw, Book World e Forked Glacier/Thorns; manter mudanças qualitativas de comportamento e sistemas de boss separadas de números. Fontes oficiais/versionamento devem ser verificados antes de qualquer futura inserção append-only autorizada.

**Não concluído:** correção/ingestão dos gaps, validação oficial live, atualidade absoluta e aplicação de overlays. Nenhuma dessas lacunas impede a FE-43 de melhorar a UX honesta com os contratos já existentes.
