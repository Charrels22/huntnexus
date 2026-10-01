# HuntNexus

HuntNexus é uma plataforma de inteligência e análise para Tibia/RubinOT.

O projeto começa pela **HuntNexus Brain**: uma base versionada de conhecimento que combina:

- dados factuais do Tibia;
- alterações específicas do RubinOT;
- observações reais de hunts da comunidade;
- referências editoriais separadas dos fatos.

O site público será construído somente depois que a camada de dados estiver confiável.

## Princípio central

```text
Tibia factual
      +
RubinOT overlay versionado
      +
observações reais da comunidade
      ↓
HuntNexus Brain
      ↓
HuntNexus Analytics
      ↓
HuntNexus API
      ↓
HuntNexus Web
```

## Regras

- Nunca misturar fato oficial com dado comunitário/editorial.
- Nunca sobrescrever histórico de alterações do RubinOT.
- Toda informação relevante deve guardar fonte, data e validade.
- Separar:
  - dano recebido na hunt;
  - vulnerabilidade/resistência dos monstros;
  - dano observado dos jogadores.
- Recomendações futuras precisam ser explicáveis por evidências.

## Estrutura

```text
docs/        contexto, arquitetura e regras
collectors/  coleta por fonte
db/          schema e migrations
api/         contratos de leitura
analytics/   motor analítico futuro
web/         site futuro
tests/       validações
data/        catálogos e metadados
```

Leia `AGENTS.md` e `docs/` antes de alterar a arquitetura.
