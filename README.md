# HuntNexus

HuntNexus é uma plataforma de inteligência e análise para Tibia/RubinOT.

A arquitetura atual é independente do Lovable:

```text
GitHub
  │
  ├─ web/app ─────────────► Cloudflare Workers
  │                           └─ HuntNexus Web + /api/huntnexus
  │
  └─ db/migrations ───────► Supabase HuntNexus
                              └─ HuntNexus Brain + Analytics
```

## Continuidade no Codex

O projeto foi preparado para execução a partir da **FE-40** sem recomeçar o desenvolvimento. Use [**CODEX_START_HERE.md**](CODEX_START_HERE.md) para conectar o repositório ao Codex e copiar o prompt inicial. O agente deve seguir [AGENTS.md](AGENTS.md) e consultar [contexto](PROJECT_CONTEXT.md), [status](CURRENT_STATUS.md), [roadmap](ROADMAP_EXECUTION.md) e [testes](TESTING_GUIDELINES.md).

A criação desses arquivos **não inicia uma tarefa remota no Codex** nem concede acesso automático a Supabase/Cloudflare; conecte as permissões necessárias no ambiente do executor.

## Camadas

- **HuntNexus**: produto/plataforma.
- **HuntNexus Brain**: base versionada de conhecimento.
- **HuntNexus Analytics**: rankings, evidências e recomendações.
- **HuntNexus API**: contrato server-side em `/api/huntnexus`.
- **HuntNexus Web**: frontend TanStack Start hospedado no Cloudflare Workers.

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
- Recomendações precisam ser explicáveis por evidências.
- Boss build final permanece bloqueada quando a mecânica RubinOT atual não está reconciliada.
- GitHub é a fonte canônica do código/migrations.
- Cloudflare e Supabase são a infraestrutura de runtime atual.
- Lovable não é mais dependência de produção.

## Estrutura

```text
db/migrations/   schema, ingestão e analytics PostgreSQL
web/app/         aplicação TanStack Start + Cloudflare Workers
api/             contratos/clientes auxiliares
docs/            contexto, arquitetura e regras
tests/           smoke tests e invariantes
data/            catálogos/metadados
```

Leia `AGENTS.md` e `docs/` antes de alterar a arquitetura.
