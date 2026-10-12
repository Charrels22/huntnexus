# HuntNexus — FE-26: identidade real do Main e escolhas de build protegidas

**Data:** 12 de outubro de 2026 (BRT). Continuação de [FE-25](CHECKPOINT_2026-10-12_FE25_MULTISLOT_RP_AMMO_SNAPSHOTS.md).

## Falha de consistência identificada e corrigida

A função `public.huntnexus_player_hunt_build_choice_save` anteriormente verificava se o personagem possuía cada item da seleção e se os itens eram compatíveis com a vocação e o nível. Entretanto, **não verificava que a opção declarada como `option_type='main'` correspondia ao Set Main efetivamente equipado**. Era possível enviar os itens possuídos na Backpack como se fossem Main, ou usar um subconjunto parcial do Main, e a opção seria rotulada incorretamente. Isso comprometia o nome e a proveniência do build em uma escolha para hunt e seu snapshot histórico.

A migração `db/migrations/0156_hunt_main_choice_identity_guard.sql` corrige exatamente esse contrato. Antes do INSERT/UPSERT, quando `option_type='main'`, monta-se a seleção completa atual `{slot: item_key}` a partir de `player_character_inventory` com `storage_kind='main'`. Exige-se igualdade JSONB exata com a escolha recebida. Se houver qualquer diferença, a função retorna `error=main_choice_must_match_main_set` sem criar nem sobrescrever a escolha. Nenhum item da BP é proibido para `owned_variant`, e as validações anteriores de posse, nível, vocação e dependências não foram flexibilizadas. O usuário pode salvar a opção Main genuína da interface normalmente.

A migração foi aplicada ao projeto Supabase `urbncbjapasnjqjqicjv` com sucesso. A auditoria pós-migração confirmou:
- `deployed_guard=true`;
- `anon_may_execute=false`;
- `authenticated_may_execute=false`;
- `service_role_may_execute=true`.

Auditoria pré-migração indicou zero escolhas já persistidas, logo nenhuma escolha anterior precisou ser modificada ou apagada. A correção foi deliberadamente limitada à função de salvamento — não altera o motor de optimizer nem os dados de personagens e hunts.

## Regressões automatizadas

### Invariantes já verdes imediatamente após migração

As duas rotinas existentes de cinco vocações foram executadas automaticamente após a alteração SQL e **ambas passaram**:
- [FE-24 Profile/Main/BP e snapshots históricos: SUCCESS #38265043435](https://github.com/Charrels22/huntnexus/actions/runs/38265043435).
- [FE-25 Main/BP multisslot, RP quiver/arrow, snapshots: SUCCESS #38265043317](https://github.com/Charrels22/huntnexus/actions/runs/38265043317).

### Nova matriz adversarial FE-26

`tests/fe26-five-vocation-choice-guard-smoke.mjs` e `.github/workflows/huntnexus-fe26-build-choice-invariants.yml` executam, na API publicada e em cliente convidado de UUID aleatório, uma matriz para EK, RP, ED, MS e EM. As seleções usam o mesmo catálogo real de Main + BP do FE-25 (três slots em EK/ED/MS/EM e cinco em RP).

Cada caso exige:
- Rejeitar alternativa BP **indevidamente marcada como Main** e Main parcial, sem persistir escolha.
- Aceitar como `main` somente o Main integral e efetivo.
- Rejeitar nova tentativa de disfarçar BP como Main **sem sobrescrever a escolha Main previamente salva**.
- Rejeitar seleção acima do nível do contexto, `option_type` inválido, item colocado em slot errado, item não possuído e arma/equipamentos da vocação incompatível.
- Comprovar que um **segundo UUID convidado** não consegue salvar uma escolha com itens pertencentes apenas ao primeiro.
- Aceitar variante BP completa como `owned_variant`, preservar opção anterior caso ocorra nova tentativa de spoofing e garantir que Main nunca foi modificado.
- Remover todas as escolhas e itens temporários, verificar inventário/choice vazio. Não são geradas sessões falsas, não há publicação comunitária, não são utilizados perfis de jogadores reais.

A API valida o enum `option_type` por schema antes da função SQL: valor fora de `main|owned_variant` é um erro HTTP 400 `invalid_input`. A regressão foi ajustada para respeitar essa separação entre schema HTTP e regras de domínio SQL. A execução inicial #38265460594 falhou somente por tentar tratar o 400 esperado como retorno SQL positivo; **não houve indicação de concessão indevida de build**.

**Execução final da nova matriz:** verificar o resultado do workflow FE-26 mais recente antes de marcar aprovado.

## Limites / portas ainda abertas

- Trata-se de regressão técnica e de privacidade por UUID convidado. Não significa conta autenticada real por Magic Link em dois dispositivos.
- O catálogo de equipamentos tem proveniência, mas os testes não comprovam a equivalência visual ou mecânica com o RubinOT nem ganhos reais de XP/DPS.
- Nenhum usuário externo foi convidado ao piloto. Não foram criadas sessões públicas ou dados de comunidade.
- Prioridades posteriores: checks de client-bound auth real, validação do cliente RubinOT com cinco jogadores e análise de compatibilidade de novas armas/slots à medida que o jogo muda.
