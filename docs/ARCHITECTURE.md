# Arquitetura atual

```text
                         ┌────────────────────────┐
                         │ GitHub                 │
                         │ Charrels22/huntnexus   │
                         └───────────┬────────────┘
                                     │
                        ┌────────────┴────────────┐
                        ▼                         ▼
                Cloudflare Workers           Supabase
                HuntNexus Web/API            HuntNexus Brain
                TanStack Start               PostgreSQL
                        │                         │
                        └────────────┬────────────┘
                                     ▼
                             HuntNexus produto
```

## Runtime

### Cloudflare Workers
- app: `web/app`
- Worker: `huntnexus`
- runtime API: `POST /api/huntnexus`
- secrets server-side:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- service-role nunca é enviado ao navegador.

### Supabase
Projeto próprio do usuário, região São Paulo.

Responsabilidades:
- facts Tibia;
- overlay RubinOT;
- community observations;
- analytics;
- rankings;
- boss guards;
- RPCs da API.

## Ingestão

```text
TibiaData
   │
   ├─ catálogo nativo SQL
   └─ detalhes assíncronos pg_net
   │
   ▼
Supabase HuntNexus
```

Lovable/Bun não são mais necessários para a carga factual.

## Resolução de valor

1. carregar valor factual Tibia;
2. procurar override RubinOT válido por data/patch;
3. retornar valor efetivo;
4. anexar evidências;
5. nunca incorporar observação comunitária como fato canônico.

## Dano

Três famílias independentes:

- `incoming_damage`: dano recebido pelo jogador;
- `monster_vulnerability`: modificador recebido pelo monstro por elemento;
- `observed_player_output`: dano produzido em sessões.

## Community

Amostra pública atual:
- 100 sessões HuntAnalyser;
- limite mantido em 100 enquanto terms review segue pendente;
- dados são Tier C observacional;
- nenhuma sessão privada/autenticada é coletada.

## Bosses

Boss Room é separado de hunt normal.
Build final requer mecânica atual reconciliada.

Guards ativos incluem:
- Magma Bubble v13.8;
- Soul War v13.7.
