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


## Continuação FE-16 — Parser numérico, Profile e Weapon Proficiency
- Public Smoke `38101689114`: **success** após alinhar o contrato individual de impacto de proficiency com `weapon_proficiency_impact_preview_v2`. Consulta direta ao Supabase confirmou as duas seleções da Grand Sanguine Blade/Razor e o par `weapon_proficiency_pair_for_items_v2`. Não foi necessário enfraquecer asserts de vínculo real ou origem `item_key`.
- `parseIntegerLike` aceita apenas inteiros simples ou milhares explicitamente agrupados, rejeitando sufixos ou formas ambíguas como `1.2kk`, `2.5M` e `9e12`. Valores inválidos permanecem `null`; a lista de avisos inclui `invalid_numeric_format:<label>`.
- `tests/session-parser-contract.mjs` cobre formatos com ponto/vírgula/espaço, números inválidos, valores desconhecidos, party parcial, dano e charm. O `HuntNexus Web CI` roda esse contrato junto com build e typecheck (execução `38101707261`: success).
- A prévia do Session Analyzer apresenta avisos legíveis antes de salvar; sessões salvas mostram avisos de proveniência; colagem de outro analyzer do mesmo tipo exige confirmação antes de substituir um bloco preenchido.
- Profile agora transforma erros `invalid_proficiency_selections` em mensagens concretas por arma e nível. `tests/player-profile-smoke.mjs` tenta salvar dois perks no mesmo nível de uma árvore validada e verifica rejeição sem alterar o perfil anterior. Execução `38101877425`: success.
- Mapeamentos adicionais de sprites de Weapon Proficiency foram vinculados a nomes de arquivos **documentados**, incluindo attack, auto attack critical, leech, recursos on hit/kill, bestiary, Perfect Shot e spells de EK/RP/EM. Ícones ainda sem correspondência validada aparecem como pendentes no cabeçalho da árvore; não reivindicar cobertura integral.
- As associações de ícones são evidências canônicas TibiaWiki (tier B), não evidências RubinOT oficiais: 
  - https://www.tibiawiki.com.br/wiki/Perk_Shaping_Options
  - https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bow
  - https://www.tibiawiki.com.br/wiki/Sanguine_Razor
  - https://www.tibiawiki.com.br/wiki/Soulhexer
  - https://www.tibiawiki.com.br/wiki/Sanguine_Claws
  - https://www.tibiawiki.com.br/wiki/Soulpiercer
  - Consultadas em 2026-10-10 (BRT); precisa conferir sprites renderizados e eventuais divergências RubinOT.
- Cloudflare registrou publicações Wrangler recentes durante a rodada, mas não há prova de paridade commit->versão Worker para todas as mudanças de interface. Smoke API e deploy da UI são verificações separadas.

### Próximo foco obrigatório
1. CI mais recente verde, correspondência código publicado e QA de Session Analyzer (browser/colagens reais).
2. Validar visualmente os sprites de proficiency por árvore e completar os ainda sem fonte confirmada; verificar topologia e seleções EK/RP/ED/MS/EM.
3. Regressões de conteúdo factual, Planner/Hunt Detail, optimizer/imbuements e autenticação/sincronização.
4. Piloto externo por vocação somente após privacidade, determinismo dos resultados e QA integral.


### FE-16 verification at handoff
- Latest code commit: `f93cc9c68dc3ae7109a9a520f1835c79aa08d100`.
- Web CI `38102047487` — **success** (build, TS, parser regression).
- Player Inventory Smoke `38102047481` — **success**.
- Profile Smoke `38102047475` — **success**.
- Public Smoke `38101689114` — **success** após atualização do contrato individual de proficiency v2.
- These are CI/API pass signals, **not** a browser visual approval and **not** proof of source-to-Cloudflare deployment parity.
