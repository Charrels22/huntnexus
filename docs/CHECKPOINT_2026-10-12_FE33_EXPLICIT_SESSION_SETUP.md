# HuntNexus — FE-33: Seleção explícita do equipamento por sessão

**Data:** 2026-10-12 (BRT). **Estado:** backend implantado, regressões HTTP vivas e snapshots de cinco vocações aprovados. O aceite visual completo é acompanhado em Actions e este documento será atualizado com seu resultado. **A validação do export privado de The Void (Zao) continua aberta no Issue #1.**

## Problema e contrato

O usuário constatou que a caixa "Setup usado" no histórico aparecia sem equipamento e não existia seleção direta no cadastro. O fluxo anterior vinculava automaticamente o build da hunt (se existisse e houvesse `hunt_key` + vocação) ou o Set Main e registrava `not_available` nos demais casos. A FE-32 explicou esse automatismo; a FE-33 permite escolha consciente, sem inventar itens e sem alterar as sessões antigas.

## Implementação

- **Interface** `web/app/src/routes/session.tsx`: campo persistível de rascunho `setupMode`, quatro opções: `auto` (legado), `main` (Set Main mesmo quando existe outra opção da hunt), `hunt` (build previamente salva para hunt/vocação) e `none` (sem equipamento observado). Busca ambos os candidatos reais do inventário e da build; exibe source, composição e disponibilidade; bloqueia escolha explicitamente não disponível e informa como corrigi-la. O servidor reconcilia novamente no salvamento, independentemente de preview/cache.
- **API** `web/app/src/routes/api/huntnexus.ts`: Zod permite somente os quatro modos, padrão `auto` para clientes antigos. Envia `setupMode` dentro de `p_metadata` e retorna HTTP 409 se a função rejeita Main/build indisponível; sem aceitar uma lista arbitrária de itens do navegador.
- **SQL** `db/migrations/0158_fe33_session_setup_choice.sql`: aplicada com sucesso ao Supabase `urbncbjapasnjqjqicjv`. Novo helper `huntnexus_player_session_loadout_snapshot_selected(uuid,text,text,text)` preserva o helper anterior, usa escolha apenas quando não força `main`, lê Main diretamente do inventário privado do `p_client_id` e mantém itens/slot/nome/storage_kind. A função original de salvamento recebe `setupMode` da metadata, valida, recusa vínculos explicitamente indisponíveis **antes de inserir**, e salva `setup_mode`, `source`, `items` e `captured_at` no snapshot imutável. Modo `none`: `source=not_recorded` explicitamente, não confundir com `not_available`.
- Compatibilidade: qualquer cadastro anterior sem `setupMode` continua no ramo `auto`, com o mesmo comportamento antigo; não houve `UPDATE` em `player_hunt_sessions`, alteração de conta/Auth, abertura pública de dados, nem manipulação de comunidade.

## Evidências de backend e API publicadas

- [FE-33 Setup Mode HTTP Smoke — #38307753310 SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38307753310): Main não cadastrado = HTTP 409 `session_setup_main_unavailable`; escolha de hunt sem `hunt_key` = HTTP 409 `session_setup_hunt_required`; `none` criou snapshot `not_recorded`; `auto` antigo manteve `not_available` sem hunt; sessão privada de convidado inacessível a outro `client_id`. **2 sessões totalmente sintéticas criadas e excluídas, 0 contas reais, 0 sessões de jogadores utilizadas**.
- [Five-Vocation Private Snapshot Smoke — #38307734053 SUCCESS](https://github.com/Charrels22/huntnexus/actions/runs/38307734053): **EK/RP/ED/MS/EM** com Profile/Main/BP reais do catálogo, performance numérica e analisadores **sintéticos**; Set Main forçado sobre build da hunt salva seleciona Main corretamente; modo `hunt` seleciona BP; Main original nunca substituído, sessão histórica permanece imutável, cleanup privado aprovado. Total no resumo: 5 perfis criados/excluídos, 10 sessões persistidas nos dois checkpoints de performance e excluídas; as sessões de escolha adicional também foram excluídas imediatamente.
- [FE-33 Browser QA local + publicado — execução mais recente](https://github.com/Charrels22/huntnexus/actions/runs/38307870729): acompanha UI de quatro modos e payload sem escrita de backend real. Resultado deve ser confirmado ao final do workflow, não inferido.

## Pendências — não marcar Issue #1 resolvido

1. Conferir no navegador do jogador a escolha explícita do setup de **The Void (Zao)** e confirmar no `player_session_detail` que o snapshot corresponde às peças que ele realmente utilizou.
2. Confirmar importação real dos quatro blocos originais Hunt Analyzer / Damage Input / Miscellaneous / Party quando aplicável; nenhum parser consegue inferir dados ausentes de entrada não colada.
3. Criar processo opt-in de revisão/reimportação de sessões antigas com diff, proteção de proprietário e preservação integral do snapshot histórico.
4. Após piloto com MS, seguir EK/RP/ED/EM; dados falsos/sintéticos e reconstruções indiretas não são prova de gameplay de RubinOT.
5. Dependências de produção/Auth real A/B e demais pontos do roadmap seguem abertas.

## Maturidade editorial

Backend 94%; Optimizer 92%; Profile/Inventário 96%; Session Analyzer 87%; Hunt Planner 86%; Conteúdo Factual 74%; Frontend Visual 74%; Produção/Contas/Segurança 70%. As estimativas **não são cobertura de testes** e não aumentam sem aceite real de sessões.
