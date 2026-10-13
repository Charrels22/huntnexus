# HuntNexus — FE-37: integridade e completude das sessões privadas

**Data:** 2026-10-13 BRT. **Estado:** **FE-37 CONCLUÍDA TECNICAMENTE**, com Web CI, API privada no Worker publicado e Browser QA local/publicado **SUCCESS**. Homologação real The Void (Zao) permanece **PENDENTE**, Issue #1 aberto.

## Motivo

A sessão real de MS em The Void (Zao) revelou diferença entre expectativa do jogador e campos observáveis. A FE-36 corrigiu a importação de Input/Misc, porém não havia um diagnóstico separado no **histórico** que respondesse se o bloco foi fornecido, entendido, persistido e apresentado.

## Implementação

- `web/app/src/lib/session-integrity.ts`: diagnóstico **somente leitura, executado exclusivamente no servidor**, dos quatro blocos originais `hunt`, `input`, `misc`, `party` e valores `parsed_data` preservados. Estados `missing`, `unrecognized`, `partial`, `recognized`. A condição `partial` para Input com Total/Max-DPS sem tipos/fontes não significa que o parser inventou dados; informações ocultas no cliente permanecem não observadas.
- Consistência da sessão: compara as seis seções salvas `hunt_analyse`, `misc`, `damage`, `party_hunt`, `availability`, `validation` com o `player_session_detail` retornado pela função do banco. Compara JSON sem depender da ordem de chaves. Diferença = `storage_consistency=mismatch`; estes valores são privados e **não** são devolvidos na resposta.
- Separadamente, calcula `current_parser_drift` entre texto original reprocessado **em memória** e o `parsed_data` salvo. Drift do parser **não** equivale a corrupção da sessão nem autoriza gravação automática; revisão posterior passa pela FE-34/35.
- `web/app/src/routes/api/huntnexus.ts`: nova ação `player_session_integrity_review` com autenticação/guarda de `client_id` já exigida para sessões privadas; utiliza RPCs de origem e detalhe, verifica escopo em ambas, retorna apenas estados, quantidades, nomes fixos de seções e warnings codificados. **Nunca retorna os blocos originais, nomes de jogadores, loot ou fontes de dano.** Estritamente read-only.
- `web/app/src/routes/sessions.tsx`: painel `Conferência dos dados importados` por sessão com estados em português, resumo de coerência banco ↔ histórico, distinção de drift e botão de reconferência. Não faz reprocessamento e não altera snapshot.
- `tests/fe37-session-integrity-contract.mjs`: regressão de estados, mismatches, parser drift vs corrupção, não exposição de nomes e sem reprocessamento de dados reais, executada no Web CI.
- `tests/fe37-session-integrity-live-smoke.mjs` com workflow `.github/workflows/huntnexus-fe37-session-integrity.yml`: solicita o relatório ao **Worker publicado** com sessões sintéticas privadas recém-criadas e eliminadas, verifica owner isolation.
- `web/app/tests/fe32-session-browser-preview-smoke.mjs`: verifica os quatro badges e as seções de coerência em Playwright usando fixture no Browser QA local/publicado. Nenhuma gravação real é efetuada nesse teste; o workflow gera `fe37-session-integrity-private-report.png` em dois destinos.

## Evidências já verificadas

- **[FE-37 Live Session Integrity #38340804062 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38340804062):** testou no site publicado quatro casos: original armazenado coerente com histórico, outra identidade bloqueada com HTTP 404, Input parcialmente observado, Input/Misc enviados mas não reconhecidos. **Três sessões sintéticas criadas e excluídas**, zero dados reais.
- **[FE-37 Live Session Integrity atualizado #38341115989 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38341115989)**, após correções de import e fixtures.
- **[Web CI final #38341410338 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38341410338)**: build + TypeScript, teste de consistência FE-37 e regressões anteriores aprovados; [#38341173685](https://github.com/Charrels22/huntnexus/actions/runs/38341173685) também SUCCESS.
- **[Browser QA final #38341410291 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38341410291)**: valida renderização de blocos (Input Parcial, Misc Reconhecido, Party Não enviado), banco ↔ histórico coerentes, parser sem drift no mock autorizado, preservando FE-32/33/34/35 e sprites de loot **3/3 decodificados**. Passou **tanto na build local quanto no domínio publicado**; nenhuma gravação privada no Browser QA. Artifacts `huntnexus-fe32-session-visual-qa`, ID `11786942058`, **4.557.058 bytes**, com `fe37-session-integrity-private-report.png` em preview e published.
- Alguns runs intermediários do CI falharam por resolução da extensão `.ts` do helper em Node strip-types e por fixtures que usavam o mesmo objeto parsed para blocos diferentes; ambos corrigidos. Runs intermediários do Playwright tiveram locators não exatos (`Parcial`, `Reconhecido` dentro de textos mais longos); corrigidos com correspondência exata. Não atribuir esses erros a perda de sessão real.

## Critérios externos ainda pendentes

1. **The Void (Zao)**: relatórios da nova função na sessão real do usuário, somente após autorização; comparar quatro blocos preservados e screenshots sem compartilhar dados privados publicamente.
2. **Damage Input/Miscellaneous**: validar os arquivos brutos originais do mesmo cliente RubinOT; tipos e rótulos do Tibia padrão são guia, não prova de cobertura RubinOT.
3. **EK/RP/ED/MS/EM**: pilotos consentidos, com preview → storage → história e equipamentos reais, além de ações de reparse e restauração apenas sob decisão explícita do proprietário.
4. Magic Link de conta autorizada e testes de produção/segurança permanecem backlog. Nenhuma alteração de RLS ou migration SQL nesta etapa.

## Progresso editorial

Backend ~94%; Optimizer ~92%; Profile/Inventário ~96%; Session Analyzer ~87%; Hunt Planner ~86%; Conteúdo Factual ~74%; Frontend Visual ~74%; Produção/Contas/Segurança ~70%. **Percentuais não medem cobertura e não são aumentados por fixtures.**

## Correção de estabilidade do Browser QA

Um run intermediário do frontend publicado não exibiu o indicador de duração logo após o preenchimento antes da hidratação. O teste passou a repetir uma única colagem **apenas se** a duração não aparecer, e continua exigindo o resultado real visível; não simula nem injeta métricas. [Run final #38341410291 SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38341410291). Isso não prova que falhas intermitentes de rede foram eliminadas definitivamente.
