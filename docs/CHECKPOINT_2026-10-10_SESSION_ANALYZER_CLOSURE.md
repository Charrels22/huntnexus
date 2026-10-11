# HuntNexus — Product closure / Session Analyzer checkpoint (2026-10-10 BRT)

## Baseline preservado
- Profile + Set Main + Backpack (BP) estão operacionais.
- Main permanece a baseline; recomendações 2ª/3ª priorizam equipamentos existentes na BP; externos permanecem identificados.
- Weapon Proficiency tem árvores recolhíveis e suporte a ícones; conferir sprites canônicos antes da homologação visual.
- Build é selecionável por hunt; a sessão grava snapshot imutável do setup; comparação de performance por build é privada.
- Planner personalizado deve ser mantido leve.
- Proveniência do Brain e separação oficial / canônico / comunitário continuam obrigatórias.

## Entrega realizada neste checkpoint
- Substituído gráfico temporal decorativo, com barras fixas, por comparação factual de XP/h e Raw XP/h **quando disponíveis**.
- Campos ausentes não são convertidos em zero por `formatCompact` ou `rate`; Profit/h não é mais exibido como zero quando faltam Balance ou duração.
- Posições de participação da party não exibem `0%` se dano ou healing do player não foram informados.
- Percentuais de dano recebido ausentes são mostrados explicitamente como indisponíveis, sem barra inventada.
- Histórico de sessões descarta resposta de detalhe obsoleta quando o usuário muda rapidamente de seleção; refresh valida se a seleção ainda existe.
- Parser passa a registrar `total_kills = null` quando a seção `Killed Monsters` não foi enviada; explicitamente vazia registra 0.
- Prévia distingue campos ausentes dos observados, e o botão de salvar exige ao menos uma métrica reconhecida.
- Opção de rankings esclarece que registra preferência futura e **não publica** a sessão atualmente.
- Análise da sessão apresenta fonte, versão do parser, preservação dos blocos e avisos de validação.
- Regressão sintética adicionada em `tests/session-parser-contract.mjs`, executada no `HuntNexus Web CI`.
- `tests/public-api-smoke.mjs` atualizado para exigir o parser v2 (substituiu expectativa v1 obsoleta).

## Evidências de execução
- Web CI `38100507419` — success; build + typecheck + `Session Parser synthetic regression`.
- Web CI `38100584459` — success no commit `94b0ac116767cf05666e9fab2a03b808a584024c` (build, typecheck, regressão sintética).
- Player Session Smoke `38100449471` — success sobre o parser atualizado do commit `7aa930575c7f652b4c9d69209ec156d08cdc5fb5`.
- Public Smoke `38100543682`: failure em `contextual recommendation actual weapon proficiency payload regression`; refazer com a última versão publicada e investigar contrato contextual sem relaxar invariantes.
- No Cloudflare ocorreram deployments via Wrangler após a primeira correção, mas nem todo deployment possui associação de commit visível; requer confirmação de paridade de produção.

## Pendências para fechar Session Analyzer
1. Validar browser ponta a ponta com analyzers **reais** e formatos variáveis (solo, party, Damage Input, Misc), inclusive colagem, edição, rascunho, salvar, alternar e excluir.
2. Rever o parser de números de entrada: atualmente `parseIntegerLike` remove caracteres não numéricos indiscriminadamente. O caso `1.2kk` não deve virar `12`; precisamos rejeitar ou normalizar explicitamente formatos suportados. Uma tentativa de commit da correção não foi aplicada; nenhuma validação dessa proteção deve ser presumida.
3. Confirmar escopo de conta, privacidade e eventuais políticas de armazenamento dos raw blocks, principalmente em navegadores compartilhados.
4. Corrigir ou reconciliar a regressão pública do recommendation contextual.
5. Só classificar Session Analyzer como homologado após verificação visual e casos reais, não apenas após build/fixture.

## Sequência combinada para produto
Session Analyzer -> Profile / Proficiency -> cobertura factual -> Planner / Hunt Detail -> optimizer / imbuements -> conta / sincronização -> hardening -> pilotos reais por EK / RP / ED / MS / EM.

## Regras de aceite
- Nenhum placeholder apresentado como métrica de jogo.
- Ausência de dado é `null` / “não informado”, não zero automático.
- Snapshot de setup deve resistir a alterações posteriores no Profile/BP.
- Evidências privadas jamais entram na comunidade sem fluxo explícito de publicação.
- CI, smokes, publicação e validação visual são gates independentes.
