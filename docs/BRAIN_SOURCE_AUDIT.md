# Auditoria do HuntNexus Brain por fonte

**Snapshot:** `2026-10-14T00:18:00-03:00`. Esta página é gerada por `scripts/render_brain_source_audit.py` a partir de [evidence/2026-10-14-brain-source-audit.json](evidence/2026-10-14-brain-source-audit.json).

> Acesso HTTP, cadastro e presença de código não significam ingestão, automação, permissão ou cobertura atual.

## Resultado

- 8/18 fontes informadas estão registradas no banco.
- 5/18 têm alguma linha de domínio comprovada; 2/18 preservam snapshots brutos no banco.
- 3/18 têm coletor no repositório; 0 atualização de fonte está agendada.
- 0 fonte tem termos revisados/aprovados; 15/18 responderam ao probe HTTP limitado.

**Conclusão:** O núcleo factual TibiaData é amplo, porém o Brain completo não está montado: 10/18 fontes não estão registradas, 13/18 não têm dado de domínio, nenhuma atualização de fonte está agendada e nenhum termo está aprovado/revisado.

## Matriz

| Fonte | Tier | Catálogo | Banco | Acesso | Coletor | Dados | Snapshot | Automação | Termos | Estado |
|---|:---:|:---:|:---:|:---:|:---:|:---:|---:|:---:|---|---|
| [RubinOT Changelog](https://rubinot.com.br/changelog) | A | Sim | Sim | 200 | Sim | Sim | 0 | Não | pending | Parcial verificada |
| [RubinOT News](https://rubinot.com.br/news) | A | Sim | Sim | 200 | Não | Não | 0 | Não | pending | Registrada sem dados |
| [RubinOT Wiki](https://wiki.rubinot.com/pt-BR) | A | Sim | Sim | 200 | Sim | Sim | 0 | Não | pending | Parcial verificada |
| [RubinOT Tools](https://www.rubinottools.com) | C | Sim | Sim | 206 | Não | Não | 0 | Não | pending | Registrada sem dados |
| [TibiaWiki BR](https://www.tibiawiki.com.br) | B | Sim | Sim | 200 | Não | Sim | 0 | Não | pending | Curadoria parcial |
| [TibiaWikiApi](https://github.com/benjaminkomen/TibiaWikiApi) | B | Sim | Não | 206 | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [ByteWizards TibiaData](https://github.com/ByteWizards-de/tibiadata) | B | Sim | Sim | 206 | Sim | Sim | 4340 | Não | pending | Ingestão manual comprovada |
| [TibiaMaps](https://github.com/tibiamaps/tibia-map-data) | B | Sim | Sim | 206 | Não | Não | 0 | Não | pending | Registrada sem dados |
| [PT Finder](https://pt-finder.com.br/) | C | Sim | Não | falhou | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [OberonGG](https://oberongg.com/) | C | Sim | Não | 200 | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [Hunts.RubinOT](https://hunts.rubinot.app/) | C | Sim | Não | 200 | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [HuntAnalyser](https://www.hunt-analyser.com/) | C | Sim | Sim | 200 | Não | Sim | 105 | Não | pending | Amostra manual comprovada |
| [Hunt Tracker RubinOT Community](https://hunt-tracker-rubinot.lovable.app/community) | C | Sim | Não | 404 | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [Tibia Watch](https://tibiawatch.com/respawns) | C | Sim | Não | 200 | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [Tibialytics](https://tibialytics.com.br/hunt) | C | Sim | Não | 200 | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [Vigia das Estatísticas](https://www.vigiadasestatisticas.com/) | C | Sim | Não | 530 | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [Keke de Patinete](https://kekedepatinete.com.br/) | D | Sim | Não | 206 | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [Vatoz Lokoz](https://vatozlokoz.com/ferramentas/hunts) | D | Sim | Não | 200 | Não | Não | 0 | Não | not_tracked | Somente catálogo |
| [RubinOT Website](https://rubinot.com.br) | A | Não | Sim | falhou | Não | Sim | 0 | Não | pending | Só no banco, parcial |

## Cobertura factual atual

O catálogo tem 459 hunts; 454 possuem core factual suficiente para o contrato atual do Planner, 26 têm alguma sessão observada e 22 têm incoming damage. Isso mede contratos e presença de evidência, não prova recomendação correta, gameplay real ou Brain completo.

## Como atualizar

1. Execute as consultas somente leitura em `docs/evidence/2026-10-14-brain-source-audit.sql` e atualize o snapshot do banco.
2. Execute o probe limitado somente quando uma nova observação externa for necessária.
3. Atualize os fatos fixos em `scripts/build_brain_source_audit.py` com a nova evidência.
4. Rode `python scripts/build_brain_source_audit.py` e `python scripts/render_brain_source_audit.py`.
