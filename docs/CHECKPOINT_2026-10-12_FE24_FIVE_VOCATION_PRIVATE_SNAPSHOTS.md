# HuntNexus — FE-24: Profile, Main/BP e snapshots históricos das cinco vocações

**Data:** 12 de outubro de 2026 (BRT).  
**Projeto:** `Charrels22/huntnexus` · continuação de `docs/CHECKPOINT_2026-10-12_FE23_PARTY_DAMAGE_BOUNDARY.md`.

## Escopo executado

A nova regressão `tests/fe24-five-vocation-private-snapshots-smoke.mjs` opera por HTTP na API **publicada** (`https://huntnexus.charr3ls22.workers.dev/api/huntnexus`) e utiliza apenas:
- item keys e hunts reais do catálogo versionado (fontes A/B conforme origem);
- perfis de testes **sintéticos** com client IDs UUID aleatórios, não vinculados a contas existentes;
- dois textos de Hunt Analyzer **sintéticos por classe** com métricas coerentes e diferenças de XP/balance;
- registros privados efêmeros que são excluídos no `finally`, com verificação pós-limpeza.

Este procedimento **não** significa testagem por jogadores do RubinOT, não é um Analyzer capturado no jogo e não aumenta a base de observações reais da comunidade.

### Matriz efetivamente verificada (level 700)

| Vocação | Família | Hunt do catálogo | Arma Main | Arma BP | Dependências |
|---|---|---|---|---|---|
| EK | sword | cobra-bastion | soulshredder | gnome-sword | — |
| RP | bow | iksupan-last-stand | soulbleeder | eldritch-bow | **quiver (offhand)** e **diamond-arrow (ammunition)** no Main |
| ED | rod | nimmersatts-breeding-ground | soulhexer | amber-rod | — |
| MS | wand | podzilla | soultainter | amber-wand | — |
| EM | fist | grounds-of-undeath | soulkamas | nunchaku-of-destruction | — |

Armas verificadas no banco via `huntnexus_player_profile_proficiency_catalog` antes de criar os dados de teste. Um perk válido da árvore Main é salvo no Profile de cada vocação e recuperado sem divergência.

### Contratos comprovados individualmente para EK, RP, ED, MS e EM

1. `player_profile_save`/`get`: vocação, level, família, perk ativo persistem; um UUID convidado diferente não recupera o perfil.
2. `player_inventory_put`/`get`: Main contém a arma da classe; BP contém a arma alternativa; outra identidade não enxerga Main nem BP; baseline Main não é substituída automaticamente.
3. `player_hunt_build_choice_save`: escolhe explicitamente a arma de BP para aquela hunt **sem** modificar o Main. A escolha salva é recuperável.
4. **Primeira sessão privada:** importação sintética registra `loadout_snapshot.source=saved_hunt_choice` e a arma da BP. `community_evidence_written=false`.
5. Depois de retirar a arma da BP e excluir a escolha da hunt, o Main permanece intacto e **o snapshot da sessão anterior é exatamente igual** ao JSON salvo antes das mudanças.
6. **Segunda sessão privada:** passa a capturar a arma Main, sem alterar o primeiro snapshot. O relatório de performance identifica **duas sessões, duas configurações distintas**, não infere efeito causal entre equipamento e desempenho.
7. `player_session_list`/`detail`: retornam somente dados do client ID correto. Outro UUID não recupera sessão, profile ou inventário.
8. `finally`: duas sessões, arma da BP, equipamentos Main, opção de hunt e Profile são removidos. O teste retorna erro se a limpeza falhar ou sobrar algum dado consultável.

### Defeito de fixture encontrado e corrigido — RP

Na primeira execução, EK passou, mas a tentativa de salvar `eldritch-bow` sozinho como variante da BP foi **rejeitada corretamente** pelo motor de compatibilidade como `invalid_loadout`. Não alteramos o validador nem o catálogo para fazer o teste passar.

A API e a função SQL `huntnexus_loadout_compatibility_universal` mostraram o requisito de `ammunition` e `offhand` para arcos de duas mãos. Validamos diretamente o conjunto:
`{"weapon":"eldritch-bow","ammunition":"diamond-arrow","offhand":"quiver"}` → `status=valid`, `combination_issues=[]`.

A regressão foi corrigida para registrar munição e quiver no Main e incluí-los na escolha do RP. Nenhum bypass, regra artificial ou item de propriedade presumida foi introduzido.

## Evidências de execução

- **Run #38252830804: SUCCESS** — [Five-Vocation Private Snapshot Smoke](https://github.com/Charrels22/huntnexus/actions/runs/38252830804) no código que fecha a correção do RP (`a9216412d7691895222135cb721bf43ea013992e`). Todos os cinco casos imprimiram PASS.
- O resumo dessa execução reporta **5 perfis criados/removidos**, **10 sessões criadas/removidas**, **10 snapshots imutáveis em dois estados por classe**, `distinct_historical_builds=2` para cada classe, identidades de teste diferentes e **zero gravações comunitárias**.
- Auditoria de SQL posterior à execução: `residual_fe24_profiles=0`, `residual_fe24_sessions=0`, `residual_fe24_observations=0`, e `community_total=100` (inalterado).
- Workflow: `.github/workflows/huntnexus-fe24-five-vocation-private-snapshot.yml` — executa a regressão sequencialmente e previne execuções simultâneas do mesmo workflow. Passa a ser disparado automaticamente também quando mudam API, parser e migrações do banco, além da própria regressão.

## Limites de evidência

- Armas e hunts são keys válidas e observáveis no catálogo, mas **XP, balance, dano e healing do teste são sintéticos**. Não são dados de player real nem foram apresentados como comparações de vantagem entre armas.
- Foram verificadas duas seleções historicamente estáveis por vocação **na API**, e não screenshots de animações ou equipamentos do cliente RubinOT.
- Prova de isolamento por UUID vale para o contrato de identidade convidada. Não substitui login real por Magic Link em dois dispositivos, permissões de conta autenticada ou testes de segurança adversarial mais amplos.
- O motor Main/BP, a construção de loadouts, a proveniência das sessões e o efeito das perks requerem validação humana dentro do RubinOT antes de declarar o site 100% homologado.
- A política atual evita publicação de dados privados na comunidade por padrão; `publishHighscores=false` foi aplicado em todas as importações de teste.

## Próximas portas de aceitação

1. Confirmar o rerun automático do workflow após a inclusão de caminhos monitorados.
2. Pilotagem humana controlada EK/RP/ED/MS/EM com originais do cliente RubinOT e comparações com o frontend por classe.
3. Login Magic Link real A/B com consentimento e recuperação entre dois dispositivos.
4. Auditoria completa de sprites/perks versus cliente RubinOT (mapeamento de fontes canônicas já existe).
5. Regressões adicionais de múltiplos slots, munição de RP e snapshot ao trocar várias peças de uma vez, com rastreabilidade de origem.
