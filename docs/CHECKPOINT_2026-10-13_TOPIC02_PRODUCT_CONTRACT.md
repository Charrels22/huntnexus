# Tópico 2 — definição oficial do produto

Checkpoint de 2026-10-13. Objetivo: eliminar conflitos entre produto, Brain, conta, personagem, experiência pública, recomendação e aprendizado antes de alterar banco ou autenticação.

## Decisão

- [ADR-0001](ADR_0001_PRODUCT_DOMAIN_AND_BRAIN.md) é a decisão vinculante.
- HuntNexus é o produto; HuntNexus Brain é conhecimento interno versionado.
- Dashboard, catálogo, fatos, fontes e metodologia são públicos.
- Conta protege personalização e possui vários personagens.
- Perfil, inventário, builds, sessões e snapshots pertencem a `character_id` no modelo alvo.
- `client_id` é legado e não pode ser expandido como modelo final.
- Recomendações apontam versão, entradas, regras, evidências e limitações.
- Aprendizado gera candidatos; promoção de regra é controlada e auditável.

## Documentos reconciliados

| Documento | Resultado |
| --- | --- |
| `AGENTS.md` | ordem de execução e invariantes do realinhamento |
| `CODEX_START_HERE.md` | entrada deixa de mandar iniciar FE-40 |
| `PROJECT_CONTEXT.md` | domínio público/privado e conta 1:N personagens |
| `ROADMAP_EXECUTION.md` | sequência vinculante dos 15 tópicos |
| `docs/ARCHITECTURE.md` | fronteiras do Brain e domínio privado alvo |
| `CURRENT_STATUS.md` | Tópicos 1/2, congelamento e próximo Tópico 3 |
| índice de checkpoints | ADR e checkpoints de realinhamento priorizados |

## Termos históricos

FE-40–48, PRs #3/#4, tabelas atuais por `client_id` e flags locais de readiness permanecem evidência histórica/implementação reutilizável. Eles não prevalecem sobre ADR-0001 e não provam completude, domínio correto ou release.

## Verificação

- busca textual dos documentos de entrada não deve instruir FE-40 como próxima etapa;
- todos os documentos de entrada devem apontar ADR-0001 e Tópico 3;
- nenhuma migration, código de runtime, autenticação, dado ou deploy é alterado;
- links Markdown locais devem resolver no repositório.

## Resultado

| Item | Resultado |
| --- | --- |
| Definição oficial do produto | PASS |
| Conta 1:N personagens e `client_id` legado | PASS documental |
| Brain e ciclo de recomendação/aprendizado | PASS documental |
| Roadmap sem FE-40 como próxima etapa | PASS |
| Implementação do novo domínio | PENDENTE — Tópico 4 |
| Segurança/autenticação definitiva | PENDENTE — Tópicos 5/6 |
