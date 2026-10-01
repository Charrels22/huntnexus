# Arquitetura

```text
Fontes
  │
  ├─ RubinOT oficial
  ├─ Tibia factual
  ├─ Trackers/logs
  └─ Editorial
  │
  ▼
Collectors
  │
  ▼
Raw Snapshots (imutáveis + hash)
  │
  ▼
Normalização
  │
  ├─ tibia_factual
  ├─ rubinot_overlay
  ├─ community_observations
  └─ editorial
  │
  ▼
HuntNexus Brain
  │
  ├─ Analytics
  ├─ API
  └─ MCP futuro
  │
  ▼
HuntNexus Web
```

## Resolução de valor

Para um dado factual:

1. carregar valor base do Tibia;
2. procurar override RubinOT válido na data/patch;
3. retornar o valor efetivo;
4. anexar evidências;
5. nunca incorporar valor comunitário nessa resolução factual.

Dados comunitários são exibidos como observação estatística, não como verdade canônica.

## Dano

Três famílias independentes:

- `incoming_damage`: dano causado por monstros/hunt ao jogador;
- `monster_vulnerability`: quanto cada criatura recebe por elemento;
- `observed_player_output`: dano efetivamente produzido por jogadores em sessões.

## Diretórios

- `collectors/`: ingestão por fonte.
- `db/`: migrations PostgreSQL.
- `api/`: contratos e read models.
- `analytics/`: métricas e recomendações futuras.
- `web/`: frontend futuro.
- `data/`: catálogo e metadados.
- `tests/`: qualidade e invariantes.
