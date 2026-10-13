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

## Execução contínua no Codex (a partir da FE-40)

**Leia nesta ordem** antes de desenvolver: [CODEX_START_HERE.md](CODEX_START_HERE.md) → [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) → [CURRENT_STATUS.md](CURRENT_STATUS.md) → [ROADMAP_EXECUTION.md](ROADMAP_EXECUTION.md) → [TESTING_GUIDELINES.md](TESTING_GUIDELINES.md) → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) → [índice de checkpoints](docs/CODEX_HANDOFF_CHECKPOINT_INDEX.md) → último checkpoint em `docs/CHECKPOINT_*.md`.

1. **Não começar do zero.** A FE-39 já foi concluída tecnicamente. A primeira etapa pendente é a **FE-40**, descoberta e navegação pelo catálogo factual de hunts. Confirmar HEAD, código e testes atuais antes de codificar.
2. Trabalhar em **blocos pequenos** com código, regressões e checkpoint por FE. Evitar substituições de arquitetura sem necessidade; preferir reutilizar rotas/RPCs e controles existentes.
3. **Autonomia em mudanças reversíveis de código**: implementar, testar e preparar branch/PR ou commits no fluxo GitHub autorizado sem pedir confirmação a cada pequena decisão. Pedir autorização explícita para operações destrutivas, mudança de autenticação, dados reais privados, alterações de custo/infra, segredos ou deploy sem credenciais existentes.
4. **Nunca apresentar teste sintético como gameplay real**, CI verde como prova de deploy, ou heurística de ranking como porcentagem probabilística. Guardar evidência separada para build, teste unitário, SQL, API read-only, Browser QA com mock e QA do site publicado.
5. **Manter o usuário informado sem travar a execução**: ao encerrar cada FE produzir `docs/CHECKPOINT_YYYY-MM-DD_FE##_TEMA.md`, atualizar `CURRENT_STATUS.md`, registrar SHA e runs reais e entregar quadro simples `PASS / Pendente / Bloqueado`.
6. A homologação de sessões privadas do [Issue #1](https://github.com/Charrels22/huntnexus/issues/1) fica **para a fase final**. Não reabrir essa pauta em toda FE nem reprocessar sessões sem consentimento.
7. Testar mudanças de interface em desktop/mobile com estados de loading/erro/vazio e screenshots. O código do repositório, migrations e os resultados atuais do CI prevalecem sobre instruções antigas ou estimativas.
