# Tópico 3 — auditoria completa do HuntNexus Brain

Checkpoint de 2026-10-14. Objetivo: substituir a afirmação genérica de “fontes conectadas” por estado mensurável e reproduzível de catálogo, acesso, coletor, ingestão, normalização, proveniência, atualização, termos, cobertura e lacunas.

## Resultado desconfortável

O Brain completo não está montado. O núcleo factual proveniente do TibiaData é amplo, mas a cobertura das fontes informadas e a operação contínua estão incompletas.

| Medida | Resultado |
| --- | ---: |
| Fontes informadas no catálogo | 18 |
| Registradas no banco | 8/18 |
| Com alguma linha de domínio | 5/18 |
| Com snapshots brutos no banco | 2/18 |
| Com coletor no repositório | 3/18 |
| Respondendo ao probe HTTP limitado | 15/18 |
| Atualizações de fonte agendadas | 0 |
| Termos revisados/aprovados | 0 |
| Fonte adicional registrada apenas no banco | 1 (`RubinOT Website`) |

Reachability não foi tratada como conexão, autorização ou ingestão. Função SQL/arquivo de coletor sem agenda não foi tratado como automação.

## Cobertura observada no banco

- 4.445 snapshots brutos, todos atribuídos a TibiaData (4.340) e HuntAnalyser (105);
- 2.193 criaturas, 6.470 itens, 459 hunts, 548 bosses e 60 spells;
- 100 sessões comunitárias, cobrindo alguma observação em 26 hunts;
- 12 fatos RubinOT, 14 definições de modificador, 14 candidatos de mudança e 0 override ativo;
- 0 página da Wiki RubinOT persistida, 0 changelog entry, 0 recommendation evidence e 0 editorial note;
- readiness 9/9 existente é somente contrato de backend: não inclui piloto externo, gameplay real ou validação visual completa.

Contagem prova presença, não correção, atualidade ou completude.

## Artefatos

| Artefato | Finalidade |
| --- | --- |
| [`BRAIN_SOURCE_AUDIT.md`](BRAIN_SOURCE_AUDIT.md) | matriz humana gerada |
| [`brain-source-audit.html`](brain-source-audit.html) | visual navegável e filtrável |
| [`evidence/2026-10-14-brain-source-audit.json`](evidence/2026-10-14-brain-source-audit.json) | snapshot único da matriz e do visual |
| [`evidence/2026-10-14-brain-database-snapshot.json`](evidence/2026-10-14-brain-database-snapshot.json) | fotografia de registro/contagens do Supabase |
| [`evidence/2026-10-14-brain-source-audit.sql`](evidence/2026-10-14-brain-source-audit.sql) | consultas somente leitura para reprodução |
| [`evidence/2026-10-13-source-access-probe.json`](evidence/2026-10-13-source-access-probe.json) | observação HTTP limitada por fonte |
| `scripts/build_brain_source_audit.py` | construção determinística do snapshot |
| `scripts/render_brain_source_audit.py` | geração Markdown/HTML do mesmo snapshot |
| `tests/brain-source-audit-contract.mjs` | contrato entre catálogo, snapshot e visuais |

Commit dos artefatos: `706d03b` (`docs(brain): publish source audit evidence`).

## Verificação

| Verificação | Resultado |
| --- | --- |
| `python -m py_compile` nos três scripts | PASS |
| geração repetida de JSON/Markdown/HTML | PASS |
| `node tests/brain-source-audit-contract.mjs` | PASS — 18 fontes + 1 fonte só no banco |
| filtros do HTML (`Somente catálogo`) | PASS — 10 fontes |
| Browser QA desktop | PASS — métricas, 19 cards e fontes renderizados |
| Browser QA móvel 390×844 | PASS — card 347 px, sem overflow horizontal |
| `git diff --check` | PASS |

## Segurança e operação

- auditoria executada com leitura do banco e probes HTTP limitados;
- nenhuma migration, escrita em fonte, dado privado ou mudança de autenticação;
- PRs #3/#4, merge e produção continuam congelados;
- os quatro arquivos de histórico fornecidos pelo usuário continuam locais, não rastreados e inalterados.

## Estado

| Item | Resultado |
| --- | --- |
| Matriz por fonte | PASS |
| Evidência de acesso/coletor/ingestão/proveniência | PASS |
| Automação e termos distinguidos | PASS |
| Visual derivado do mesmo snapshot | PASS |
| Brain completo | **NÃO** — lacunas acima são entradas dos Tópicos 7–9 |
| Próximo tópico | Tópico 4 — conta e personagens |
