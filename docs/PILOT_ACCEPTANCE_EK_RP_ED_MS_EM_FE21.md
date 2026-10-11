# HuntNexus FE-21 — Plano de homologação real por vocação (pré-piloto)

**Estado:** protocolo de aceitação preparado, *não* representa jogador convidado, sessão humana recebida ou convite público enviado.

## Fontes de evidência

- **A:** RubinOT oficial — dados de mecânica/servidor, changelogs, notícia, Wiki do servidor.
- **B:** Tibia canônico — itens, sprites e mecânicas quando não há adaptação oficial RubinOT confirmada.
- **C:** sessões públicas da comunidade e sessões voluntárias de jogadores — sempre registrar URL original, data e ambiente; não generalizar amostras pequenas.
- **D:** inferência editorial e recomendações com método documentado — nunca rotular como DPS/XP reais ou fatos oficiais.

### O que já foi comprovado
- 100 `community_sessions` com URLs, mas **nenhum** `raw_payload` conserva o texto do Hunt Analyzer.
- `tests/fixtures/reconstructed-source-sessions-2026-10-11.json` fixa cinco observações reais vinculadas à URL. `tests/five-vocation-real-source-reconstruction.mjs` reconstrói **texto sintético de importação** a partir dos **valores verdadeiros** e verifica o parser. Não equivale ao texto produzido pelo jogador no jogo.
- CI de parser sintético, Profile/Set Main/BP, Session Analyzer privado, optimizer e smoke factual por classe já existentes; FE-21 acrescenta prova técnica mas não humana.
- Exportações originais de jogadores de EK, RP, ED, MS e EM: **ainda não recebidas**.

## Protocolo por vocação

| Vocação | Família principal | Hunt de referência do catálogo | Verificação necessária no jogo |
|---|---|---|---|
| EK | Sword | Cobra Bastion | weapon/swap Main-BP, perk por nível, dano físico/elemental, custo de supplies |
| RP | Bow | Iksupan Last Stand | bow/ammunition/quiver, perk, dano e loot, Profit |
| ED | Rod | Nimmersatt's Breeding Ground | rod, runas/healing, Magic Level, party quando aplicável |
| MS | Wand | Podzilla | wand, spells/runes, leech/crítico, estatísticas de dano |
| EM | Fist | Grounds of Undeath | fist, movimentos/spells próprios, perks, stats de cura/dano |

Os locais são *casos para teste*, não destinos obrigatórios nem prova da melhor hunt.

## Procedimento de homologação individual

1. Jogador voluntário fornece a vocação, nível, mundo RubinOT e captura da tela de perfil e da árvore de Weapon Proficiency ativa. Não solicitar senha, cookie, token, login do servidor ou acesso remoto à conta.
2. Registrar no Profile o Set Main real e itens da BP. Marcar separadamente itens que não pertencem ao personagem.
3. Conferir se todos os perks ativos correspondem a um **item_key** real da arma cadastrada. Validar topologia/níveis, sprite mostrado, tooltip e descrições com o jogo; fotografar divergências (sem PII).
4. Rodar Hunt Planner para aquele personagem. Anotar opções e justificativas e checar apenas fatos verificáveis; ganho de DPS/XP previsto não é observação real.
5. Antes da hunt, escolher uma das opções Main/BP. Após a hunt, copiar do jogo **Hunt Analyzer original**, preferencialmente mais `Party Hunt Analyzer`, `Damage Input Analyzer` e `Misc` quando disponíveis. Não substituir o texto original por métricas de sites.
6. Revisar prévia de duração, Raw XP, XP/h, loot, supplies, balance, damage, healing, Killed Monsters e damage source. Valores ausentes devem aparecer como *não informados*, não `0`; inválidos devem disparar aviso.
7. Salvar a sessão **privada** e verificar se o snapshot do build anterior ficou imutável após uma mudança posterior no Main/BP.
8. Verificar comparações privadas entre builds apenas quando houver pelo menos duas sessões observadas com metadados comparáveis. Não publicar sessões na comunidade sem opt-in separado e consentimento granular.
9. Registrar divergências como bug reproduzível: screenshot, classe, versão, URL da página, texto exato da mensagem de erro, reprodução e resultado esperado. Redigir e anonimizar nomes de jogadores das amostras compartilhadas.

## Critérios para marcar uma vocação como aprovada

- [ ] Captura real do perfil, Main/BP e árvore de perks verificada com o participante
- [ ] Ícones/nomes/números de perks batem com o cliente RubinOT
- [ ] Hunt Detail/Planner exibem fatos com proveniência correta
- [ ] Pelo menos uma sessão raw Hunt Analyzer fornecida por jogador e comparada linha a linha à prévia
- [ ] Casos de dados faltantes/erros numéricos preservam `null` e mostram aviso
- [ ] Snapshot do build permanece igual mesmo após mudanças de equipamento
- [ ] Nada privado é divulgado na comunidade por engano
- [ ] Participante aprova as observações após ler resultado e limitações

**Atenção:** Teste de navegador sem login real, testes reconstruídos e source-linked Tier C não marcam essas caixas.

## Portas para convite ao piloto fechado

- Check de Magic Link **com conta autorizada real em dois dispositivos**, token nunca exposto nos logs.
- Verificação do fallback de recuperação de perfil convidado, sem auto-merge de contas.
- Scrubbing de screenshots, raw analyzer e URLs antes de compartilhamento público.
- Proteção distribuída do optimizer validada em produção (já existe).
- Visual/perks validados nas cinco classes.
- Aprovação explícita para abrir cadastro/convites externos.

Registros de regressão devem apontar SHA/versão de Worker e hora da execução; não presumir deploy idêntico ao último commit apenas por timestamp.
