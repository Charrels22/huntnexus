# HuntNexus FE-25 — Trocas multisslot Main/BP, dependências RP e histórico imutável

**Data:** 2026-10-12 (America/Sao_Paulo). Continuação do [FE-24](CHECKPOINT_2026-10-12_FE24_FIVE_VOCATION_PRIVATE_SNAPSHOTS.md).

## Escopo e método

Implementação: `tests/fe25-multislot-five-vocation-snapshot-smoke.mjs`. Execução automatizada recorrente via push/dispatch em `.github/workflows/huntnexus-fe25-multislot-snapshot.yml`. A regressão consulta **a API real publicada** do HuntNexus, cria UUIDs convidados aleatórios, Profile e inventário sintético, grava duas sessões privadas sintéticas com XP/loot/dano construídos para teste, e remove tudo no `finally`.

**Proveniência:** chaves de itens, restrições de vocação/nível e hunts são do catálogo real do HuntNexus (Tier A/B quando referenciados). Os números das sessões **não vieram do jogo**. Não são dados C de jogadores, não aparecem em recomendações comunitárias, e não demonstram ganho causal de equipamento.

### Matriz de equipamentos, todos válidos pelo SQL `huntnexus_loadout_compatibility_universal` a level 700

| Vocação | Main (weapon/head/body, e dependências) | BP alternativa | Slots testados |
|---|---|---|---:|
| EK | Soulshredder / Falcon Coif / Falcon Plate | Gnome Sword / Cobra Hood / Lion Plate | 3 |
| RP | Soulbleeder / Alicorn Headguard / Gnome Armor / Quiver / Diamond Arrow | Eldritch Bow / Falcon Coif / Soulshell / Eldritch Quiver / Crystalline Arrow | 5 |
| ED | Soulhexer / Gnome Helmet / Soulshroud | Amber Rod / Falcon Circlet / Frostmind Raiment | 3 |
| MS | Soultainter / Gnome Helmet / Soulmantle | Amber Wand / Eldritch Cowl / Dawnfire Sherwani | 3 |
| EM | Soulkamas / Dark Vision Bandana / Soulgarb | Nunchaku of Destruction / Demon Mengu / Naga Tanko | 3 |

O SQL de compatibilidade confirmou `main_status=valid` e `bp_status=valid` para **10/10** contextos sem dispensar restrições de classe. A opção BP exige que cada item alternativo esteja de fato salvo na backpack privada.

### Assertivas HTTP por vocação

1. Salva Profile isolado e cria peças Main e BP em slots reais do catálogo.
2. Confirma que outro UUID convidado **não** enxerga o equipamento de Main/BP.
3. Salva a variante BP composta por **3 ou 5 slots**; `main_set_mutated=false`.
4. Importa uma sessão privada sintética e verifica todas as chaves de seleção do snapshot `saved_hunt_choice`, sem publicação comunitária.
5. Outro UUID convidado não consegue carregar a sessão privada por ID.
6. Remove **todas** as peças BP e a escolha da hunt; Main continua intacto.
7. Recupera a sessão anterior e compara o JSON de snapshot integral byte a byte com a versão original.
8. Importa a segunda sessão após retorno ao Main; o novo snapshot é composto pelos mesmos slots originais e o anterior continua inalterado.
9. Consulta desempenho por build sem inferência causal: `sessions=2`, `distinct_builds=2`; confirma listagem privada restrita à identidade correta.
10. `finally` exclui sessões, escolha se existir, todas as peças Main/BP e Profile, e consulta novamente para assegurar vazio. Não imprime token ou dados de pessoas reais.

### Casos negativos RP

O mesmo `eldritch-bow` foi testado com regras de compatibilidade que **não devem ser contornadas**:
- Sem quiver: SQL `incomplete`, issue `required_quiver_missing`.
- Sem arrow: SQL `incomplete`, issue `required_ammunition_missing`.
- Com spectral bolt em arco: SQL `blocked`, issue `ammunition_family_mismatch`.
- Com Soulmantle (armadura de sorcerer): SQL `blocked` por `vocation_restriction`.

Adicionadas validações via API para resposta `saved=false`/`invalid_loadout`, ausência de escolha persistida, e Main preservado. **Conferir o resultado do rerun acionado pela alteração antes de declarar estes quatro testes aprovados por HTTP.**

## Evidências verificadas

- [Execução FE-25 inicial, cinco vocações — **SUCCESS**](https://github.com/Charrels22/huntnexus/actions/runs/38261424540), commit `453c57ed786bc3fe24d6df013a841f978f18e281`.
- Validado na execução: cinco vocações, **5 Profiles + 10 sessões temporárias**, todos os 10 snapshots historicamente distintos e imutáveis após retirada das BP, isolamento por client ID.
- Auditoria SQL após execução: `fe25_profiles=0`, `fe25_sessions=0`, `fe25_session_observations=0` e `community_total=100` inalterado.
- A verificação adicional de rejeições RP, commit `90ca566ec4ba52c9e5c0c8550d6c302d5af3f07d`, será registrada no adendo de conclusão depois de validar o GitHub Actions.

## Limites e próxima frente

- Os resultados são **regressões API de equipamentos e snapshots**, não simulações reais de dano/DPS e não sessões jogadas no RubinOT.
- Testes com duas identidades UUID convidadas não substituem um login autorizado com Magic Link em dois dispositivos.
- Homologação de sprites de perks e efeitos próprios do RubinOT depende de capturas no cliente do jogo e sessões originais consentidas.
- Piloto externo exige convite e autorização explícitos; não houve inscrição, convite ou publicação de dados de jogador.
