# AGENTS.md — HuntNexus

HuntNexus é o produto. **HuntNexus Brain** é sua camada interna de conhecimento versionado para Tibia/RubinOT.

Leia `docs/` antes de alterar código ou modelo de dados.

## Nomenclatura

- Produto: HuntNexus
- Conhecimento: HuntNexus Brain
- API: HuntNexus API
- Analytics: HuntNexus Analytics
- Web: HuntNexus Web
- Repositório principal: `huntnexus`
- RubinOT continua sendo exclusivamente o nome do OTServer e de suas fontes/dados.

## Regras obrigatórias

1. Dados oficiais, comunitários e editoriais devem permanecer separados.
2. Histórico é append-only: alterações RubinOT viram novas versões, nunca substituições silenciosas.
3. Todo dado deve preservar fonte, URL, data de observação, validade e confiança.
4. RubinOT é um overlay sobre a base factual do Tibia.
5. `incoming_damage`, `monster_vulnerability` e `observed_player_output` são conceitos distintos.
6. Nunca inventar dado real de jogo.
7. Fixtures de teste devem estar claramente marcadas como `SYNTHETIC`.
8. Coletores devem respeitar limites, termos e métodos de acesso das fontes.
9. Preferir API/exportação estruturada a scraping.
10. Recomendações futuras devem apontar as evidências usadas.
11. GitHub é a fonte da verdade do projeto.

## Hierarquia de confiança

- A — fontes oficiais RubinOT
- B — referências estruturadas/canônicas de Tibia
- C — trackers e logs comunitários
- D — conteúdo editorial

Fonte de menor confiança nunca sobrescreve silenciosamente uma de maior confiança.
