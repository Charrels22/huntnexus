# HuntNexus — FE-35: restauração auditável de revisões privadas

**Data:** 2026-10-12 (BRT). **Estado:** banco e API privados implementados, SQL atômico e HTTP de rejeição aprovados; Web CI e Browser QA finais devem ser verificados antes de encerrar tecnicamente a etapa. Homologação da hunt real continua pendente no Issue #1.

## Objetivo e contrato

A FE-34 passou a guardar a interpretação anterior do parser ao aplicar uma revisão. FE-35 permite ao titular escolher qualquer interpretação anterior **salva na auditoria**, comparar valores com a versão atual e restaurar somente com confirmação explícita; perdas conhecidas requerem segundo aceite.

- Nenhuma restauração automática de sessão real. **A sessão The Void (Zao) NÃO foi alterada.**
- Blocos originais `raw_blocks`, build/snapshot de equipamentos, vínculo de conta, identificação da hunt e metadados continuam imutáveis.
- A restauração afeta apenas `parsed_data`, `parser_version`, `status` e `updated_at`.
- A interpretação atual é inserida no audit log *antes* de restaurar a versão escolhida: a restauração é reversível por nova ação, também opt-in.
- Escopo `client_id` + `session_id` e Auth obrigatória para contas vinculadas, conforme guarda global já existente da API. Nenhum conteúdo bruto é retornado à tela.

## Arquivos e implementação

- `db/migrations/0160_fe35_session_revision_restore.sql` aplicada ao Supabase: `huntnexus_player_session_revision_list` (somente resumo de até 30 revisões), `..._restore_source` (somente interno ao backend), `..._restore` (valida confirmação, aceite explícito, fingerprint, titularidade; trava a sessão `FOR UPDATE`, insere auditoria e restaura atomicamente). Funções não podem ser executadas pelos papéis public/anon/authenticated.
- `web/app/src/routes/api/huntnexus.ts`: novas ações `player_session_revision_list`, `player_session_restore_preview`, `player_session_restore_apply`; o cliente envia somente IDs, confirmação e fingerprint de concorrência. Servidor compara valores anteriores em memória e exige `accept_regressions` quando identifica regressões. Não aceita dados parseados fornecidos pelo navegador para substituir a revisão.
- `web/app/src/routes/sessions.tsx`: botão **Ver revisões**, listagem cronológica, **Comparar versão**, tabela Atual/Anterior com alertas, checkbox principal e aceite adicional de perda conhecida; diálogo final antes de restaurar e feedback da operação.
- `tests/sql/fe35_session_revision_restore_atomic.sql`: fixture sintética temporária criada, restaurada, desfeita e excluída. Confirma owner isolation, confirmation, fingerprint antigo e revision_id incorreto recusados, auditoria append-only, cleanup sem resíduos, blobs e snapshot preservados.
- `tests/fe35-session-revision-restoration-live-smoke.mjs`: teste público HTTP com uma sessão sintética privada criada e excluída, sem jogadores/contas reais. Outro guest não lista revisões, nem vê preview, nem aplica; IDs de revisão não registrados são recusados; nenhuma métrica ou setup foi alterado.
- `web/app/tests/fe32-session-browser-preview-smoke.mjs`: teste visual estendido FE-35. API de restauração mockada/interceptada; a tela exige comparação e *dois* checkboxes quando o rollback reduziria dados, diálogos, valida IDs de revisão/fingerprint, sem escrita real. Capturas FE-35 nas duas targets (preview e publicada), sujeitas ao resultado do workflow.

## Evidências verificadas

- Aplicação da migration `0160_fe35_session_revision_restore`: **SUCCESS**.
- Script transacional no Supabase `tests/sql/fe35_session_revision_restore_atomic.sql`: **PASS**, sem sessões reais alteradas.
- [FE-35 Session Restoration Safety — run #38325139153](https://github.com/Charrels22/huntnexus/actions/runs/38325139153): **SUCCESS**, acesso cruzado e revision id inexistente protegidos, fixture removida.
- [Web CI — run #38325171775](https://github.com/Charrels22/huntnexus/actions/runs/38325171775): verificar conclusão final.
- [Browser QA FE-32/33/34/35 — run #38325171739](https://github.com/Charrels22/huntnexus/actions/runs/38325171739): verificar conclusão final; publicada e preview.

## Escopo ainda aberto

1. Nenhum teste usou os analyzers originais da hunt real **The Void (Zao)**; reprocessar/restaurar requer consentimento e escolha do dono. Issue #1 permanece aberto.
2. Revisões apenas são produzidas quando há mudança real do parser; sessões não reprocessadas não apresentam versões anteriores, corretamente.
3. A opção de restaurar pode reverter valores já reconhecidos; o jogador vê explicitamente as regressões antes de aceitar. Nunca confundir isso com recuperação automática de Input/Misc ausentes.
4. Precisa aprofundar **Damage Input e Miscellaneous com exemplos originais legítimos** antes de afirmar suporte universal. Não inventar fontes de dano, Combat Stats ou topologia.
5. Magic Link autorizado A/B, testes reais com EK/RP/ED/MS/EM, segurança de contas e hardening de publicação seguem pendentes.

## Estimativas editoriais (não cobertura)

Backend ~94%; Optimizer ~92%; Profile/Inventário ~96%; Session Analyzer ~87%; Hunt Planner ~86%; Conteúdo factual ~74%; Frontend Visual ~74%; Produção/Contas/Segurança ~70%. Mantidos sem aumento artificial por testes sintéticos.
