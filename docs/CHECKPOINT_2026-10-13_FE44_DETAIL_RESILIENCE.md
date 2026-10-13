# FE-44 — falhas parciais e cancelamento

Incremento local PASS em 2026-10-13; CI da continuação será verificado no PR. Não é homologação de SLO/cache/concorrência em produção.

Antes: uma rejeição em qualquer uma de seis consultas auxiliares (exceto evidence já tolerada) interrompia o factual de Hunt Detail. Depois: sete leituras públicas continuam paralelas e limitadas; factual é obrigatório; falha/ausência/error nas outras dimensões retorna null e availability=false. A UI diferencia indisponibilidade de zero confirmado e não inventa amostra insuficiente.

Catálogo cancela consultas obsoletas e limita cada fetch de busca a 15s. Não há retry automático, alteração de autenticação, cache compartilhado privado, SQL/migration ou nova consulta pesada.

QA: build/TypeScript; `tests/fe44-detail-resilience-contract.mjs` prova sete leituras iniciadas antes de completar qualquer uma, ausência de optimizer/player, degradação das seis auxiliares, factual obrigatório, timeout e abort sem retry. `web/app/tests/fe44-resilience-preview.mjs` PASS SYNTHETIC desktop 1440/mobile 390, factual visível, Community sem zero fabricado, Damage/imbuements indisponíveis e nenhuma escrita/pageerror/overflow.

Comparação reproduzível: o padrão anterior Promise.all rejeita todo o grupo ao primeiro erro auxiliar; o novo contrato mantém o factual nas mesmas sete leituras. Nenhuma redução de latência é reivindicada. Medidas de carga/latência antes-depois no Worker, política de cache e concorrência de usuários continuam pendentes.

Rollback: reverter o commit deste incremento, reconstruir e executar CI; promoção para produção exige revisar o comportamento anterior de falha total. Nenhum estado persistido foi alterado.
