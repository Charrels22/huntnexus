# HuntNexus — contexto técnico para continuidade no Codex

**Última revisão:** 2026-10-13. **Fonte da verdade:** o código e as migrations neste repositório. Este documento é um mapa de navegação, não substitui inspeção da implementação atual.

## Propósito

HuntNexus é uma plataforma Tibia/RubinOT para descobrir hunts, analisar sessões, escolher sets reais e comparar builds. **HuntNexus Brain** é a camada versionada de conhecimento. O produto combina três fluxos que nunca podem ser confundidos:

1. **Tibia factual**: criaturas, elementos, itens, spells, loot, hunts, fontes e snapshots com procedência.
2. **RubinOT oficial**: overrides por patch/data/versão sobre fatos canônicos; sem sobrepor versões silenciosamente.
3. **Comunidade/Tier C**: estatísticas observadas em sessões, úteis para comparação, **não garantias** de XP, profit ou dano, nem descrição oficial de mecânicas.

Confiança: A (RubinOT oficial), B (Tibia canônico/estruturado), C (comunidade), D (editorial). Ausência de dados **não é zero**; nunca estimar como fato. Preservar URL, observação, validade/patch, revisão, confiança e termos de acesso. Referência: [AGENTS.md](AGENTS.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Organização e execução

- Repositório GitHub: https://github.com/Charrels22/huntnexus
- Produção: https://huntnexus.charr3ls22.workers.dev
- Frontend + API: `web/app/`, TypeScript/React, TanStack Start/Router, Cloudflare Workers; entrada do servidor `web/app/src/routes/api/huntnexus.ts`, endpoint `POST /api/huntnexus`.
- Backend: `db/migrations/`, PostgreSQL/Supabase (RPCs PL/pgSQL). Migrations versionadas são a fonte da verdade; nunca executar SQL de alteração em produção sem checar dependências, reversibilidade e autorização adequada.
- Tipos de conteúdo: `data/` e `collectors/`; analytics, contratos auxiliares e tests: `analytics/`, `api/`, `tests/`, `web/app/tests/`.
- Infra: Cloudflare Worker denominado `huntnexus`, Supabase PostgreSQL; o deploy de frontend e migrations não é necessariamente simultâneo. Confirmar código publicado antes de afirmar deploy.
- Frontend atual: `/`, `/planner`, `/hunts/$huntKey`, `/creatures`, `/bosses`, `/profile`, `/session`, `/sessions`, `/account` e `/loadouts`. Verificar rotas reais e `web/app/src/components/shell/app-shell.tsx` antes de adicionar navegação.
- Documentos de passagem: [CURRENT_STATUS.md](CURRENT_STATUS.md), [ROADMAP_EXECUTION.md](ROADMAP_EXECUTION.md), [TESTING_GUIDELINES.md](TESTING_GUIDELINES.md), [CODEX_START_HERE.md](CODEX_START_HERE.md).

## Decisões de produto já consolidadas

- Perfil do personagem é contexto padrão de Planner, Analyzer e optimizer: vocation, level, mundo e inventário. Vocações-alvo: **EK, RP, ED, MS, EM**. Não usar EK como única classe arquitetural.
- **Set Main** é baseline canônico do Profile; opções secundárias priorizam itens que o usuário já possui na **Backpack**; itens externos ficam separados e nunca são rotulados como possuídos. Builds de hunt são escolhas explícitas e privadas.
- Snapshot da build realmente escolhida no cadastro da sessão é **imutável**, independente de alterações futuras no Main/BP. FE-33 permite modos `auto/main/hunt/none`.
- Session Analyzer diferencia `Hunt Analyzer`, `Damage Input`, `Miscellaneous`, `Party Hunt`, dano causado vs. recebido vs. vulnerabilidade do monstro. Input total sem breakdown continua parcial; valores não observados não são inventados.
- FE-34/35 permitem comparação conservadora, reparse opt-in e restauração auditável de interpretação antiga **sem sobrescrever** `raw_blocks` ou `loadout_snapshot`.
- Dados por conta, `client_id` convidado e identidade Supabase vinculada não são intercambiáveis. RLS e RPCs só do service role devem proteger registros privados; nunca admitir IDs arbitrários como autorização. Testes com fixture sintética exigem limpeza.
- Weapon Proficiency: apenas marcar topologia `source_backed_level_position` quando posições e níveis estiverem comprovados por fonte; caso contrário mostrar `flattened_source_order` com aviso. Não inventar perks/ícones/posições.
- Planner usa observações reais do acervo de fonte Tier C, ranking **experimental**; `confidence_score` não é probabilidade estatística. Não substituir ausência de sessões por sugestões de performance imaginárias.
- Hunt Detail diferencia cobertura factual, snapshots/datas coletadas e amostra comunitária. Datas registradas não equivalem a verificação ao vivo. Boss Room permanece independente das hunts regulares.
- Interface: clara e rápida para jogador, responsiva desktop/mobile, ícones e imagens canônicos quando verificáveis, estados vazios honestos, testes visuais em Chromium com screenshots.

## Segurança e deploy

- Variáveis de runtime esperadas: `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` **somente no Worker**. Não copiar chaves, tokens, arquivos `.dev.vars`, segredos ou dados privados para Git, logs, screenshots ou tickets.
- Não presumir que Codex possua credenciais ou conexão a Supabase/Cloudflare. Solicitar apenas a autorização que faltar; continuar desenvolvimento e testes que não dependem de produção.
- Não recriar infraestrutura nem reconfigurar o que já funciona para começar uma nova etapa.
- Nunca executar cargas, scraping, migrações destrutivas, purge ou backfills em produção apenas para concluir um teste.
- Primeiro validar local/regressões, depois Actions, depois deploy/autorização e smoke publicado. CI verde não prova deploy; teste com API mockada não prova persistência.
- Separar explicitamente resultados: teste estático, fixture `SYNTHETIC`, API pública read-only, SQL transacional, Browser QA mockado, usuário/jogo real.

## O que é um checkpoint válido

Cada etapa deve registrar `docs/CHECKPOINT_YYYY-MM-DD_FE##_TEMA.md` com: objetivo, mudanças por arquivo, fonte e confiança, testes executados e links dos runs, artefatos/screenshots, deploy efetivamente confirmado ou não, limitações/pêndencias e próxima ação. Resumo conciso de progresso com quadrinho de estados **PASS / Pendente / Bloqueado**. Percentuais globais são estimativas editoriais, **não** cobertura medida.
