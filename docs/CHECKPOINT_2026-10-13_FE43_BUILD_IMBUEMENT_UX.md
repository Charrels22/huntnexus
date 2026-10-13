# FE-43 — Main/BP, comparação e imbuements

Data: 2026-10-13. Incremento de UX/build/testes local PASS; CI na branch de continuação. Sem mudança em ranking, constraints, propriedade ou dados de usuários.

- Comparação Main/BP passa a ter botão nativo explícito `Comparar Nª opção`, estado `aria-pressed` e teclado sem card interativo envolvendo outro botão. Salvar a build continua uma ação separada; fixture não salva nem escolhe uma build real.
- Imbuements separa potência do efeito de parcela de dano total/protegível, declara origem observacional Tier C da prioridade e uso comunitário independente. Fonte específica do efeito não fornecida por esse contrato permanece explicitamente ausente. Não se transforma prioridade em atribuição final, compatibilidade ou garantia de desempenho.
- Valor ausente, unidade ausente, contagem ausente e zero confirmado são distintos; removido o fallback `powerful_value || 0` que inventava potência zero.
- Main continua baseline, BP candidata e itens externos continuam em bloco independente. Não altera proficiência ou supõe topologia de árvore não comprovada.

## QA

Build/TypeScript PASS. `tests/fe43-imbuement-evidence-contract.mjs` PASS para ausente/zero/unidade e denominadores. `web/app/tests/fe43-build-imbuement-preview.mjs` PASS em EK/RP/ED/MS/EM com fixtures SYNTHETIC, teclado, opções/Main/BP/externos, amostra zero/ausente, ammo RP, sem escrita, sem consulta pesada automática, overflow ou pageerror. Screenshots mobile por vocação em `web/app/fe43-build-qa/`.

SQL real read-only reproduzível: `tests/sql/fe43-hand-packages-readonly.sql`; evidência `docs/evidence/2026-10-13-fe43-hand-package-validation.json`. Função previamente conferida STABLE. Pacotes retornados: EK 12, RP 8, ED 10, MS 10, EM 2; todos com validação `valid`. Armas Two não carregam offhand incompatível; RP permite a exceção canônica quiver e exige ammunition/offhand. Estes são pacotes públicos limitados a nível 700 e cinco hunts, não auditoria de todas as combinações/níveis/patches ou prova de propriedade privada.

API real existente `hunt_detail` de Cobra Bastion/EK confirmou unidade percent, parcelas total/protegível e que uso comunitário não altera prioridade. Nenhuma nova query por card ou RPC foi adicionada.

Pendente: piloto de propriedade privada, revisão de proficiências sem fonte, imbuements atribuídos por set completo e patch RubinOT reconciliado. A UX não declara esses itens homologados. Próximo bloco: FE-44, concorrência/falhas parciais e desempenho medido.
