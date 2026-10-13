# FE-41 — contexto de navegação e acessibilidade

Base: FE-40 `102513f8874bf26e86ab707861fc112a4dd9734b`. Data: 2026-10-13.
Status: código/build/QA local PASS; CI será registrado na entrega da branch de continuação. Sem merge ou deploy.

## Mudanças verificadas

- `planner-context.ts`: valida contexto público de URL (EK/RP/ED/MS/EM, nível 1–10000, objetivos, party 1–5); IDs de conta e propriedade nunca entram no contexto.
- Planner → Hunt Detail → Planner preserva vocação/nível/objetivos/party. Perfil recebido tardiamente não sobrescreve filtros explícitos da URL nem edições já feitas.
- Catálogo → detalhe → catálogo preserva texto de busca, incluindo acentos.
- Abas do detalhe usam tablist/tab/tabpanel, roving tabindex, setas/Home/End, seleção anunciada e painel rotulado. Seletores do QA geral foram atualizados para o novo papel ARIA.
- Carregamento com status acessível, erro com alert e retry. Proveniência ausente continua explícita, sem virar zero ou fonte inventada.
- Nenhuma nova ação de API/RPC, alteração de ranking, autenticação ou dados privados.

## Evidência local

`npm run build`: PASS (Vite + TypeScript).
`node --experimental-strip-types tests/fe41-planner-context-contract.mjs`: PASS.
`node tests/fe41-navigation-preview.mjs` em `web/app`, preview compilado porta 4174: PASS nos dez casos EK/RP/ED/MS/EM × desktop 1440/mobile 390. Fixtures SYNTHETIC; contexto mantém valores mesmo com Profile atrasado, abas navegáveis por teclado, source indisponível, retry e busca preservada. Overview/Creatures/Community exigiram apenas a chamada inicial `hunt_detail`; sem overflow/pageerror. Screenshots em `web/app/fe41-navigation-qa/`, incluindo MS/450/Sustain/Profit/x4, inspecionados visualmente.

Workflow do catálogo e Web CI estendidos para esta regressão e PRs empilhados em branches `codex/**`. API real e gameplay não foram inferidos dessas fixtures.

Próximo bloco: FE-42, auditoria read-only das lacunas factuais/overlays por fonte e patch.
