# HuntNexus — FE-36: Input Damage e Combat Stats sem inferências artificiais

**Data:** 2026-10-12 BRT (workflows concluídos 2026-10-13 UTC).
**Estado:** **FE-36 CONCLUÍDA TECNICAMENTE** — build, TypeScript, regressões do parser, gravação/leitura HTTP real com fixtures privadas e Browser QA publicado aprovados. **Homologação com o bloco original The Void (Zao) AINDA PENDENTE; Issue #1 continua aberto.**

## Contexto

O usuário relatou na sessão real The Void (Zao), MS, que Damage mostrava dano recebido por elemento e fontes ausentes e Misc/Combat Stats estavam incompletos. Em FE-32/33/34/35 já havíamos preservado blocos, setup e feito mecanismos de revisão/rollback. FE-36 verificou quais campos poderiam ser calculados diretamente do texto, sem transformar informações não observadas em dano zero ou elementos inventados.

**Fontes públicas usadas para validar a semântica, NÃO exports originais RubinOT:**
- Tibia oficial — Winter Update 2020: https://www.tibia.com/news/?id=5867&subtopic=newsarchive — Input mostra dano **recebido**, discriminado por tipos e fontes, distinto do dano causado.
- TibiaQA, resposta referenciando explicação de CM: https://www.tibiaqa.com/21950/how-does-the-damage-input-analyser-work — campos `Total`, `Max-DPS`, tipos e até cinco fontes (limite do cliente, não reconstruir fontes omitidas); gráficos, tipos e fontes podem estar desabilitados.
- Resumo parcial público previamente documentado em `tests/session-parser-contract.mjs`: https://www.hunt-analyser.com/hunt_sessions/2007 — somente transcrição curta dos números publicados; **não é clipboard original de jogador nem sessão real do usuário**.
- Para Combat Stats desta FE-36 foram criados **fixtures sintéticos com rótulos descritos pelo usuário**, por exemplo `Critical Hit`, `Mana Gain`, `Life Gain`; não há validação de compatibilidade de clipboard completo RubinOT.

## Mudanças implementadas

**`web/app/src/lib/session-parser.ts`**
- `detectAnalyzerType()` identifica também Input resumido quando contém `Received Damage Total` ou `Max-DPS`, evitando encaminhá-lo como Misc genérico quando se omitem os títulos de tipos/fontes.
- Parser de Input preserva `Total` e `Max-DPS` inteiros válidos independentemente de existirem listas. Rejeita dano recebido negativo e número malformado; porcentagem aceita só intervalo 0 a 100, sem gerar participação por estimativa.
- Sob seção `Damage Types`, **somente elementos reconhecidos** do jogo são gravados, não criaturas ou strings arbitrárias; valores de `Damage Sources` preservam a fonte como texto original, sem inferir um elemento a partir dela.
- Diagnosticador diferencia `input_breakdown_not_observed` (totais válidos, fontes/tipos ausentes possivelmente ocultos) de `input_block_present_but_no_damage_rows_recognized` (nenhum dado de dano recebido reconhecido).
- Novos alertas `input_element_labels_unrecognized`, `input_numeric_rows_unrecognized`, `input_percentage_invalid` e `misc_block_present_but_no_combat_stats_recognized`. Adicionadas contagens aos `validation` para inspeção; `availability.damage` considera também totais recebidos, sem confundir com `total_damage` causado.

**`web/app/src/routes/session.tsx`**
- Quando existe Input, exibe total recebido, Max-DPS, cada elemento e cada fonte reconhecida **antes de salvar**.
- Quando existe Misc, lista nome e `raw_value` de todos os Combat Stats importados; preserva valores não numéricos em vez de transformá-los em zero.
- Inputs parciais com total mas sem breakdown são marcados como **observados parcialmente**. Input/Misc enviados sem reconhecimento e porcentagens/elementos/linhas numéricas inválidas exigem confirmação explícita, preservando o bloco original privado.
- Sem Input ou Misc, campo continua **não observado** e não é reconstruído de dano causado, XP, combatência ou setup.

**Novos testes:**
- `tests/fe36-damage-misc-contract.mjs`: regressões de seções ocultas, semântica Input x Hunt, transcrição numérica de resumo público, elementos desconhecidos, percentuais inválidos, `Critical Hit/Mana Gain/Life Gain` e bloco Misc ilegível; integrado ao Web CI.
- `tests/fe36-private-input-misc-http-smoke.mjs` + `.github/workflows/huntnexus-fe36-input-misc-smoke.yml`: API pública contra Worker, duas sessões **sintéticas privadas** criadas, lidas e **excluídas**; testa persistência de 2 elementos, 2 fontes e 4 stats em uma; noutra, Total/Max-DPS sem listas e zero elementos fabricados. Nenhuma sessão de jogador ou conteúdo comunitário alterado.
- `web/app/tests/fe32-session-browser-preview-smoke.mjs` ampliado: percorre Input e Misc de exemplo durante cadastro, valida visualmente o preview, depois reseta os blocos para não contaminar os testes anteriores. Resultado validado em build local e site publicado. Screenshot `fe36-input-misc-observed-before-save.png` em ambos.

## Evidências de aceitação técnica

- **[Web CI #38337949613 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38337949613):** build, TypeScript, parser contract FE-36 e regressões anteriores.
- **[Private HTTP roundtrip #38338093588 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38338093588):** casos `complete_input_misc_saved_and_read` e `partial_input_totals_only_not_fabricated`, total de **2 sessões sintéticas criadas e excluídas**.
- **[Browser QA local + publicado #38337949663 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38337949663):** `fe36_optional_input_breakdown_and_combat_stats_previewed=true` nas duas versões. Regressões anteriores de local, setup, duração, reparse/restauração e 3/3 sprites GIF também aprovadas. Artifact `huntnexus-fe32-session-visual-qa` ID `11785299819`, 3.732.793 bytes.
- CI intermediário #38337918170 falhou por fixture com caracteres `\\n` literais em vez de quebra de linha; correção no commit `719fe98e`. Rerun na sequência atual validou. **Não foi defeito comprovado do parser em produção.**
- Nenhuma migration SQL ou regravação de sessões reais nesta etapa.

## Pendências que NÃO podem ser declaradas resolvidas

1. **The Void (Zao), MS:** obter separadamente o texto original copiado de **Hunt Analyzer**, **Damage Input** e **Miscellaneous** (e Party se houver), com consentimento, comparar preview → dados salvos → UI, registrar discrepâncias sem publicar identidade/nomes de jogadores. A sessão original permanece inalterada.
2. **Clipboard original RubinOT:** os rótulos e formatações exatos de diferentes clientes, idiomas e versões ainda não foram comprovados. Somente dados **efetivamente copiados** poderão elevar confiança de compatibilidade; cada formato novo exigirá fixture de regressão anonimizada com proveniência e versão.
3. Separar indicadores *não fornecido*, *fornecido mas não reconhecido*, *total sem breakdown*, *breakdown reconhecido parcialmente* em testes reais. A representação atual evita valores inventados, mas precisa de verificação com exports.
4. Resultados de EK/RP/ED/MS/EM usados até aqui são contratos sintéticos e reconstruções sourced, **não** hunts reais de participantes.
5. Hardening de produção, login A/B com Auth real, proteção de dados e possíveis revisões do parser permanecem no backlog.

## Progresso estimado

Backend 94%; Optimizer 92%; Profile/Inventário 96%; Session Analyzer 87%; Hunt Planner 86%; Conteúdo factual 74%; Frontend Visual 74%; Produção/Contas/Segurança 70%. **Não alterar por suíte sintética sem aprovação de gameplay real.**
