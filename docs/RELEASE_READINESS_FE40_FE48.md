# Preparação operacional — FE-40 a FE-48

Fotografia: 2026-10-13. Este documento prepara uma decisão de release; não autoriza nem registra publicação.

## Estado comprovado

- FE-40: PR #3 separado, build e QA público/SYNTHETIC PASS. FE-41–44/46 em branch de continuação, PR empilhado sobre FE-40.
- Nenhuma migration, alteração privada ou deploy nestes incrementos. GitHub permite leitura/push/PR. Supabase read-only e Cloudflare settings acessíveis. Credenciais locais para deploy não foram comprovadas.
- Worker existente `huntnexus`; bindings server-side SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY presentes como secret_text, sem leitura dos valores. Supabase HuntNexus ACTIVE_HEALTHY. Isso não comprova Auth/RLS de ponta a ponta.
- Health público deve ser registrado em `docs/evidence/2026-10-13-fe48-public-health.json`; identifica o ambiente já publicado, não a branch nova.

## Portões de abertura pública

| Critério | Estado |
| --- | --- |
| Build, contratos e QA browser no SHA final | Conferir os runs do PR de continuação |
| Busca/factual/ausência de sessões sem promessa de XP | Implementado; QA fixtures + API publicada separado |
| Overlays RubinOT reconciliados, fontes e proficiency pendente | Pendente; FE-42 é auditoria de armazenamento |
| Main/BP/imbuements completos em todas as constraints | Incremento UX; piloto completo pendente |
| Latência/carga/cache, monitoração e alertas | Pendente; FE-44 não certifica SLO |
| FE-45 Magic Link real, dispositivos, isolamento A/B e RLS | Pendente de teste autorizado com contas de teste |
| FE-46 leitor de tela, contraste e dispositivos reais | Incremento teclado/mobile; auditoria completa pendente |
| FE-47 pilotos EK/RP/ED/MS/EM e Issue #1 | Pendente de exports originais consentidos |
| Termos/privacidade, direitos de conteúdo e abertura pública | Pendente de revisão/aprovação do dono |
| Aprovação do dono para merge/publicação | Pendente |

## Sequência de promoção

1. Revisar PR #3 e o PR empilhado; CI verde do SHA aprovado. Registrar commits-base, SHA candidato e versão/deployment Cloudflare ativo antes de qualquer promoção.
2. Confirmar trigger Cloudflare atual. A documentação de infraestrutura registra auto-build de main com path web/app/**; portanto merge pode disparar produção. Actions verde não é deploy. Revalidar trigger e credenciais pelo provedor, sem copiar secrets.
3. Após aprovação explícita do dono, promover FE-40 e depois continuação, ajustando a base do PR. Conferir build/deployment Cloudflare do SHA exato e verificar HTTP/health, catálogo vazio/busca, Hunt Detail, Planner e assets.
4. Executar `node tests/fe40-catalog-live-smoke.mjs` como leitura pública; testes browser com fixtures devem continuar identificados SYNTHETIC. Validação autenticada usa contas descartáveis autorizadas e logs sanitizados, sem exports privados neste fluxo.
5. Revisar falhas/latência nos recursos de observabilidade do Worker; definir responsáveis e limites de alerta antes de abertura pública. Não inferir performance de usuários a partir de CI.

## Rollback

Guardar ID da versão ativa antes da promoção e garantir que está apta a servir assets e bindings. No caso de quebra, usar a gestão de deployments do Cloudflare para retornar à versão registrada, com autorização correspondente, e confirmar health/rotas. Um git revert seguido de build/deploy é alternativa, sujeita ao trigger confirmado. Não improvisar migrations reversas: estes incrementos não alteram schema/dados. Registrar SHA/version, motivo e resultados sem tokens/identificadores privados.

## Escopo dos pilotos futuros

FE-45: duas contas de teste, guest→conta, logout/expiração, dois dispositivos, negativos cruzados A/B, ownership/RLS, remoção do escopo antigo; escrita somente no escopo autorizado. FE-47: cinco vocações, exports consentidos dos quatro blocos, setup Main/BP, mãos/amuletos/ammo/imbuements/proficiency, fact vs Tier C separados; divergências rastreadas, nunca preenchidas por suposição.
