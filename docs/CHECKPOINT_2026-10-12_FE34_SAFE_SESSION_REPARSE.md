# HuntNexus — FE-34: revisão privada e reprocessamento conservador

**Data:** 2026-10-12 (BRT). **Estado:** **FE-34 CONCLUÍDA TECNICAMENTE**, com Web CI, teste HTTP no Worker publicado, verificação transacional no Supabase e Browser QA local/publicado aprovados. **A homologação da sessão real The Void (Zao) continua PENDENTE e o Issue #1 permanece ABERTO.**

## Problema e objetivo

O retorno real do usuário mostrou uma sessão importada (MS, The Void/Zao) com lacunas de duração, misc, sprites, dano recebido e setup. As FE-32/33 melhoraram novas importações sem modificar dados antigos. FE-34 cria o caminho seguro para reavaliar *blocos que já foram preservados*, mostrando as diferenças **antes de gravar**.

Não é possível inferir linhas de Input/Misc que não foram fornecidas no momento do cadastro: um reparse não gera registros de combate ausentes.

## Implementação efetiva

- Migração aplicada Supabase: `db/migrations/0159_fe34_session_reparse_review.sql`.
  - `huntnexus_player_session_reparse_source(uuid,uuid)` retorna ao **servidor**, e somente a ele, os blocos originais/parsed + impressão de concorrência; exige `client_id` e `session_id` correspondentes.
  - `huntnexus_player_session_reparse_apply(uuid,uuid,text,jsonb,boolean)`: bloqueia sem confirmação, session inexistente ou escopo divergente, fingerprint desatualizado, parser inválido, dados principais ausentes e gravação idêntica. Em `SELECT ... FOR UPDATE` registra versão anterior em `player_session_parse_revisions` e troca **somente** `parsed_data`, `parser_version`, `status` e `updated_at`. Nunca altera `raw_blocks`, `loadout_snapshot`, `hunt_key`, personagem, titularidade ou metadados.
  - A nova tabela tem RLS habilitado e nenhum grant para `public`, `anon`, `authenticated`; functions service_role-only, seguindo a política anterior de funções privadas.
  - Fingerprint MD5 é apenas uma trava de concorrência sobre JSONB/texto+versão, **não é token de autorização**: a API já exige o escopo legítimo do cliente e JWT para clientes vinculados.
  - A tabela de revisões é eliminada junto com uma sessão expressamente excluída (ON DELETE CASCADE), mantendo a privacidade e limpeza do usuário.
- `web/app/src/lib/session-reparse-review.ts`: diff seguro de métricas observadas, disponibilidade e contagens, sem nomes, textos brutos, players ou loot individual. Conservador: bloqueia perda de valor conhecido, diminuição de linhas, novo warning, troca oculta do conteúdo de linhas de loot/criatura/stats/dano e mudança de texto de contexto temporal previamente registrado.
- `web/app/src/routes/api/huntnexus.ts`: ações `player_session_reparse_preview` e `player_session_reparse_apply`, ambos privados. A preview recalcula em memória os mesmos blocos brutos do banco e devolve **somente** resumo/diffs, sem texto original. O apply requer `confirm:true` e fingerprint idêntico, **recalcula no servidor** para recusar edições forjadas, recusa regressões e chama o update SQL transacional.
- `web/app/src/routes/sessions.tsx`: `Revisar importação antiga`, botão `Comparar parser`, tabela Antes/Depois, indicação de perdas e disable, checkbox confirmatório, segundo diálogo de confirmação `Aplicar revisão`, mensagens de recusa; nova consulta atualiza detalhes sem mexer no snapshot histórico.

## Evidências de testes verificadas

- [Web CI #38309748539 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38309748539): build/TypeScript, parser, regras FE-34 de diff seguro e regressões anteriores. Casos: duração recuperada, perda de métricas bloqueada, perda de linhas e troca de item sem expor nomes bloqueadas, novo warning e tentativa no-op bloqueados.
- [FE-34 Session Reparse Safety #38309748570 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38309748570): endpoint público publicado, seis verificações: outro guest não lê preview, preview privado não retorna raw blocks, outro guest não aplica, no-op e fingerprint falso rejeitados (HTTP 409), session e setup invariáveis após rejeições. **Uma sessão sintética criada e excluída**, sem conta real ou publicação comunitária.
- [Frontend Browser QA #38309664710 — SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38309664710): renderiza no preview local e no domínio publicado, consulta preview mockado sem dados de jogador, exige checkbox antes do botão aplicar, confirma fingerprint+session ID de payload; todas as gravações reais são interceptadas. Também mantém validações FE-32/33: seleção de build, histórico, duração, 3/3 sprites carregados. Artifact `huntnexus-fe32-session-visual-qa` ID `11774441792`, 2.183.854 bytes, screenshots `fe34-session-reparse-applied-synthetic.png` nos dois targets.
- `tests/sql/fe34_session_reparse_atomic_invariants.sql`: **executado e aprovado** no Supabase com fixture efêmera completamente removida. Incluiu leitura indevida negada, falta de confirmação, outro client_id não aplica, fingerprint obsoleto bloqueado, apply válido em transação, versão antiga gravada em `player_session_parse_revisions`, blobs brutos e snapshot *bitwise-identical JSONB*, replay bloqueado, cleanup sem resíduo de revisão.
- Fonte de CI/QA de cenários e contrato: `tests/fe34-reparse-review-regressions.mjs`, `tests/fe34-session-reparse-live-smoke.mjs`, workflow `.github/workflows/huntnexus-fe34-session-reparse-smoke.yml`.

## Limites e backlog real

1. **Nada foi reprocessado nos dados reais do usuário.** Antes de clicar aplicar em The Void, o proprietário deve revisar o diff, verificar duração e combat stats, e confirmar.
2. Se o Input/Misc original não estava entre os quatro blocos armazenados, estes dados são **não observados**: não reconstruir, inferir dano por elemento ou gerar notas falsas.
3. Se houver alteração de conteúdo pré-existente de linhas, a FE-34 bloqueia atualização automática; é necessário revisar parser ou desenvolver correção manual assistida, conservando o raw.
4. `player_session_parse_revisions` assegura auditabilidade de versões anteriores, mas ainda não tem um botão de **restaurar** pela interface. Não confundir revisão auditável com rollback pelo usuário.
5. Homologar com export real, inclusive casos EK/RP/ED/MS/EM; concluir testes de login real e hardening sem considerar fixtures como gameplay.

## Progresso estimativo

Backend 94%; Optimizer 92%; Profile/Inventário 96%; Session Analyzer 87%; Hunt Planner 86%; Conteúdo factual 74%; Frontend visual 74%; Produção/Contas/Segurança 70%. Estimativas editoriais mantidas até aceite de sessões reais.
