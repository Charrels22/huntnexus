# HuntNexus — FE-39: proveniência e cobertura factual no Hunt Detail

**Data:** 2026-10-13. **Status:** **FE-39 CONCLUÍDA TECNICAMENTE**. Migração Supabase, regressão SQL, Web CI, API publicada, Browser QA local/publicado e Browser QA geral **SUCCESS**.

## Objetivo e contexto

Avançar o conteúdo factual sem travar o roadmap pela homologação de exports individuais. O catálogo continha dados de origem e snapshots, mas a página da hunt mostrava métricas sem exibir o fornecedor ou a cobertura factual por criatura. Também é importante separar claramente informações de fonte factual Tier B e dados comunitários Tier C, evitando tratar performance observada como fato garantido.

## Mudanças realizadas

1. **Migração `db/migrations/0161_fe39_hunt_evidence_context.sql`** aplicada com sucesso ao Supabase `urbncbjapasnjqjqicjv`. RPC `huntnexus_hunt_evidence_context(text)` com `SECURITY DEFINER` e grants exclusivos para `service_role`; computa em consulta direta **somente a hunt pedida**, sem varrer todo o catálogo e sem gravações. Une `tibia_hunting_places`, `sources`, `hunting_place_catalog_semantics`, `hunting_place_creatures` e cobertura existente de vulnerabilidades, detalhes, habilidades e loot. Expõe nome da fonte, camada/tier, URL geral, data de atualização registrada, presença do snapshot (boolean), status e contagens por dimensão. Não retorna `source_id`, `snapshot_id` nem informações privadas. Se não houver hunt, devolve `hunt_not_found`.
2. **`web/app/src/routes/api/huntnexus.ts`** integrou a proveniência à mesma ação já existente `hunt_detail`, em paralelo às consultas leves factuais e comunitárias. O resultado é opcional: uma falha transitória do RPC não deve derrubar a página factual/observacional inteira; a interface exibe **indisponível**, nunca inventa dados. O optimizer e spells continuam on-demand.
3. **`web/app/src/lib/hunt-evidence.ts`** usa um adaptador puro para validar URL `https:`, formatar data registrada sem apresentá-la como checagem em tempo real, preservar a diferença entre **zero observações** e **valor não informado**, e classificar cobertura core completa/incompleta/indisponível, sem usar um índice opaco.
4. **`web/app/src/routes/hunts.$huntKey.tsx`** incluiu o painel **Origem e cobertura factual** no Overview: fonte geral, tier e camada, última atualização, status de snapshot, contagens elementos/detalhes/habilidades/loot, status parcial e disponibilidade comunitária de todas as vocações e da vocação selecionada. A UI diz que completude de registro **não garante** atualização absoluta ou XP/profit de uma hunt.

## Estado da base consultado diretamente

`huntnexus_hunt_catalog_readiness_audit()->'summary'` em 2026-10-13: 459 entradas de catálogo, 455 spawns fixos, 454 elegíveis e com core completo, 1 core incompleto, 4 não fixos; **26 hunts** com sessões observadas e **22 hunts** com dano recebido observado. Essas são **contagens de hunts com cobertura**, não volume de jogadores ou prova de sessões de gameplay.

Exemplos:
- `cobra-bastion`: ByteWizards TibiaData, fonte B `tibia_factual`, snapshot vinculado, data registrada **09/04/2026**, criaturas e todas as quatro dimensões factuais **11/11**.
- `forest-of-life`: mesma camada factual, data registrada **31/08/2026**, cobertura **3/3**.
- Fonte geral de origem: `https://tibiadata.bytewizards.de`; **não** é deep link específico da hunt nem prova de atualização online atual.

## Evidências técnicas

- Migração 0161: **SUCCESS**, dados anteriores preservados.
- `tests/sql/fe39_hunt_evidence_parity.sql`: **executado e aprovado** contra Supabase (DO block), verificando paridade da cobertura do novo RPC com o audit global para Cobra Bastion, Forest of Life e uma entrada com core incompleto; ausência de caça inexistente e não vazamento do snapshot ID.
- **[Web CI FE-39 #38344655758 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38344655758):** build TypeScript, regressões anteriores e `tests/fe39-hunt-evidence-contract.mjs` aprovados.
- **[FE-39 Hunt Evidence #38344677821 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38344677821):** API real Cobra Bastion (11 criaturas) e Forest of Life (3 criaturas), fonte factual, snapshot boolean, cobertura e separação de observação aprovados; teste pure model e Browser QA **local e publicado** aprovados (dois cenários em cada: cobertura incompleta explícita; origem indisponível sem estimativas). Artefato `huntnexus-fe39-factual-provenance`, ID `11787798638`, **1.641.662 bytes**, com screenshots dos 4 cenários. O QA de browser utiliza **fixtures sintéticas** para os estados parcial/ausente, não gameplay real.
- **[Frontend Live QA #38344690024 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38344690024):** publicou QA Chromium desktop/mobile com **Cobra Bastion real** no domínio Cloudflare, exibindo ByteWizards TibiaData, core factual preenchido, elementos/detalhes/habilidades/loot **11/11**, data de atualização registrada e camada comunitária separada; manteve testes de lazy optimizer, classes, sessão, conta e demais abas. Captura `hunt-fe39-factual-provenance.png` no artefato do workflow.

## Próximos blocos

Melhorar a navegação entre o catálogo e hunts detalhadas, as lacunas factuais específicas e o uso de fontes RubinOT com overrides explícitos e versionamento. A homologação manual e os testes de conta reais ficam para a fase final, não bloqueiam FE-40.

**Maturidade editorial anterior mantida** até novos pilotos: Backend 94%; Optimizer 92%; Profile/Inventário 96%; Session Analyzer 87%; Hunt Planner 86%; Conteúdo 74%; Frontend 74%; Produção/Segurança 70%. Esses números não são cobertura automatizada.
