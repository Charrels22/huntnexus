# ADR-0001 — domínio do produto e papel do HuntNexus Brain

- **Status:** aceito
- **Data:** 2026-10-13
- **Escopo:** produto, domínio privado, conhecimento, recomendações e sequência de desenvolvimento

## Contexto

O projeto cresceu a partir de catálogo factual, optimizer, Profile e Session Analyzer. `client_id`, que começou como identidade de navegador, passou a representar conta, personagem, inventário, escolhas e sessões. A autenticação posterior sincronizou essa identidade entre dispositivos, mas não criou o domínio correto para um jogador que possui vários personagens.

Em paralelo, migrations e checkpoints técnicos foram descritos como prontos em escopos locais. Isso não comprova que todas as fontes foram ingeridas, que o overlay RubinOT está reconciliado, que recomendações foram homologadas ou que o Brain aprende autonomamente.

## Decisão

### Produto e superfícies

1. **HuntNexus** é o produto.
2. **HuntNexus Brain** é a camada interna de conhecimento versionado e explicável para Tibia/RubinOT.
3. A experiência pública entrega descoberta e análise sem exigir conta: dashboard, hunts, criaturas, itens, builds de referência, comparação, fontes, metodologia e cobertura do Brain.
4. A conta existe para personalização, propriedade dos dados privados, sincronização e proteção.

### Domínio privado

```text
auth.users
    ↓ 1:1
huntnexus_accounts
    ↓ 1:N
player_characters
    ├── profile / skills / proficiency
    ├── Main / Backpack
    ├── builds por hunt
    └── sessões / revisões / snapshots
```

- Uma conta HuntNexus pode possuir vários personagens.
- Personagem ativo é contexto de navegação; nunca é identidade de autenticação.
- Perfil, inventário, builds, sessões e snapshots pertencem a um `character_id`.
- `client_id` é identificador legado de navegador/escopo e não será o modelo final de autorização.
- Adicionar um personagem não comprova automaticamente sua propriedade no jogo. Cadastro e verificação são estados diferentes.
- O HuntNexus nunca solicita ou armazena senha de Tibia/RubinOT.

### Conhecimento e recomendação

O Brain mantém as camadas separadas:

- A — fontes oficiais RubinOT;
- B — referências estruturadas/canônicas de Tibia;
- C — trackers e logs comunitários;
- D — conteúdo editorial.

RubinOT é overlay versionado sobre o fato Tibia. Fonte inferior não substitui silenciosamente fonte superior. Ausência de dado não equivale a zero.

O fluxo vinculante é:

```text
fonte → observação → validação → versão factual/regra
      → cálculo determinístico → recomendação + evidências
      → resultado observado → avaliação → candidato de ajuste
      → promoção controlada
```

O Brain não aprende sobrescrevendo fatos ou promovendo regras sozinho. Ele pode coletar, calcular, detectar divergências e propor candidatos. Uma mudança de regra exige critérios de evidência, versionamento, regressões e promoção controlada.

Cada recomendação futura deve identificar versão do Brain, entradas, personagem/contexto quando aplicável, regras, evidências, exclusões, limitações e cobertura. Mesmas entradas na mesma versão devem produzir o mesmo resultado reproduzível.

## Consequências

- A sequência FE-40–48 continua como histórico técnico nas branches/PRs #3 e #4, congeladas. Ela não determina a próxima implementação.
- O modelo multi-personagem deve ser uma migração aditiva, com inventário, builds, sessões e snapshots existentes preservados e reconciliados.
- Reforço de autenticação ocorre depois do modelo de conta/personagem, para não consolidar uma entidade incorreta.
- Catálogo global e Brain não pertencem a personagens. Dados privados nunca entram na camada comunitária sem consentimento e transformação explícita.
- Percentuais editoriais, `ready=true`, CI verde ou fixtures `SYNTHETIC` não provam completude do Brain, gameplay real ou release.

## Critérios de conformidade

Uma mudança está em conformidade quando:

1. usa os nomes HuntNexus, HuntNexus Brain, HuntNexus API, HuntNexus Analytics e HuntNexus Web;
2. não usa `client_id` como novo modelo de conta ou personagem;
3. mantém conta 1:N personagens e dados privados por `character_id`;
4. preserva as camadas A/B/C/D, fonte, URL, observação, validade e confiança;
5. mantém descoberta pública separada de personalização autenticada;
6. gera recomendações rastreáveis e reproduzíveis;
7. trata aprendizado como proposta e promoção controlada;
8. não declara completude sem matriz de cobertura e evidência.

## Decisões futuras ainda necessárias

- desenho detalhado da migração `client_id → account_id/character_id`;
- métodos de autenticação, MFA, recuperação e gestão de dispositivos;
- critérios quantitativos de promoção de candidatos do Brain;
- políticas RLS e contratos de API do novo domínio;
- portões de beta/release.
