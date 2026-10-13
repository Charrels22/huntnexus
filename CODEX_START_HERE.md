# Começar o HuntNexus no Codex

**Objetivo:** continuar o desenvolvimento do repositório **`Charrels22/huntnexus`**, sem iniciar do zero, a partir da **FE-40**.

## Pré-requisitos na interface Codex (uma vez)

1. Conectar/selecionar o repositório GitHub [Charrels22/huntnexus](https://github.com/Charrels22/huntnexus) no Codex e usar a branch `main` como base.
2. Permitir ao Codex ler/escrever código, executar comandos e testes **no ambiente autorizado**. Preferir branch + PR para mudanças funcionais, até confirmar CI.
3. Se integração com Supabase/Cloudflare não estiver disponível, **não colar credenciais no chat/repositório**; a preparação de código e QA local pode continuar. Autorizar ações reais e deploy quando necessário.
4. Verificar que o `AGENTS.md` na raiz foi lido pelo agente. Verificar estado atual/HEAD antes de assumir que 2026-10-13 ainda é a última mudança.

**Tarefa inicial rastreada:** [FE-40 — Issue #2](https://github.com/Charrels22/huntnexus/issues/2). **Histórico versionado:** [índice dos checkpoints](docs/CODEX_HANDOFF_CHECKPOINT_INDEX.md).

## Prompt inicial para enviar ao Codex

> Continue o desenvolvimento do HuntNexus no repositório `Charrels22/huntnexus` a partir da FE-40, **sem reescrever ou reiniciar** funcionalidades existentes.
>
> Antes de alterar código, leia `AGENTS.md`, `PROJECT_CONTEXT.md`, `CURRENT_STATUS.md`, `ROADMAP_EXECUTION.md`, `TESTING_GUIDELINES.md`, `docs/ARCHITECTURE.md` e o último checkpoint em `docs/CHECKPOINT_2026-10-13_FE39_HUNT_FACTUAL_PROVENANCE.md`. Confirme HEAD, workflows e os contratos de API reais.
>
> Sua primeira tarefa é implementar a **FE-40: descoberta e navegação pelo catálogo factual de hunts**, verificando e reutilizando `search_hunts` e conectando o catálogo ao Hunt Detail e Planner. Separe fonte factual de performance comunitária e respeite as regras de Tier/patch/proveniência. Não invente dados de RubinOT ou estatísticas de jogadores.
>
> Execute build/TypeScript, testes pertinentes, Playwright com evidência visual desktop/mobile e smoke read-only quando disponível. Não altere dados reais ou secrets. Faça commits coesos e entregue mudanças em branch/PR (ou no fluxo GitHub autorizado), links dos testes, screenshots e `docs/CHECKPOINT_YYYY-MM-DD_FE40_...`. Atualize `CURRENT_STATUS.md`.
>
> Ao encerrar FE-40, avance para a etapa seguinte do roadmap, desde que não dependa de permissões ausentes ou ação sensível. Não peça confirmação a cada microtarefa; peça apenas para decisões importantes, credenciais, operações destrutivas ou homologação com dados privados.
>
> No resultado de cada etapa, mostre um quadro curto de progresso `PASS / Pendente / Bloqueado`, arquivos alterados, QA comprovado, riscos e próximo foco. Os percentuais gerais não são cobertura medida.
>
> A homologação manual de sessões reais está adiada para a fase final; **não revisite repetidamente** a mesma pendência nem deixe que ela interrompa as frentes de catálogo, Planner, optimizer, visual e hardening.

## Como acompanhar

- Commits/PRs: https://github.com/Charrels22/huntnexus
- GitHub Actions: https://github.com/Charrels22/huntnexus/actions
- Ambiente público: https://huntnexus.charr3ls22.workers.dev
- Checkpoints versionados: `docs/CHECKPOINT_*.md`
- Estado de execução: `CURRENT_STATUS.md`

O Codex **não recebe automaticamente todas as conversas do ChatGPT**. Estes arquivos são o contexto transferível. O ambiente e suas permissões são definidos ao conectar a ferramenta; documentar um plano não equivale a disparar uma execução nem autoriza mudanças irreversíveis.
