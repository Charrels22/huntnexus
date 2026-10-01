# Collectors

Primeiro pipeline de ingestão da HuntNexus Brain.

## Fontes implementadas

- `rubinot_changelog.py`: captura snapshot do changelog oficial e extrai blocos de versão.
- `rubinot_wiki.py`: captura a home oficial da Wiki e cria índice de páginas conhecidas.
- `tibiadata_sync.py`: consome os endpoints oficiais do projeto ByteWizards TibiaData para estados de sincronização de criaturas, itens e hunting places.

Todo coletor grava primeiro o payload bruto em `data/raw/` com SHA-256 e timestamp. A normalização é gravada separadamente em `data/normalized/`.

## Execução

```bash
python -m venv .venv
.venv/Scripts/activate
pip install -r collectors/requirements.txt

python collectors/rubinot_changelog.py
python collectors/rubinot_wiki.py
python collectors/tibiadata_sync.py
```

Os coletores usam User-Agent próprio e pausas entre chamadas. Não devem ser convertidos em crawler paralelo/agressivo.
