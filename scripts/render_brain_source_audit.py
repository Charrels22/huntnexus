from __future__ import annotations

import html
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / "docs" / "evidence" / "2026-10-14-brain-source-audit.json"
MARKDOWN = ROOT / "docs" / "BRAIN_SOURCE_AUDIT.md"
HTML = ROOT / "docs" / "brain-source-audit.html"


LABELS = {
    "partial_verified": "Parcial verificada",
    "registered_empty": "Registrada sem dados",
    "curated_partial": "Curadoria parcial",
    "catalog_only": "Somente catálogo",
    "connected_manual": "Ingestão manual comprovada",
    "connected_sample_manual": "Amostra manual comprovada",
    "database_only_curated_partial": "Só no banco, parcial",
}


def yes(value: bool) -> str:
    return "Sim" if value else "Não"


def render_markdown(payload: dict) -> str:
    s = payload["summary"]
    rows = [
        "# Auditoria do HuntNexus Brain por fonte",
        "",
        f"**Snapshot:** `{payload['captured_at']}`. Esta página é gerada por `scripts/render_brain_source_audit.py` a partir de [evidence/2026-10-14-brain-source-audit.json](evidence/2026-10-14-brain-source-audit.json).",
        "",
        "> Acesso HTTP, cadastro e presença de código não significam ingestão, automação, permissão ou cobertura atual.",
        "",
        "## Resultado",
        "",
        f"- {s['catalog_registered']}/{s['catalog_sources']} fontes informadas estão registradas no banco.",
        f"- {s['catalog_sources_with_domain_rows']}/{s['catalog_sources']} têm alguma linha de domínio comprovada; {s['catalog_sources_with_raw_snapshots']}/{s['catalog_sources']} preservam snapshots brutos no banco.",
        f"- {s['collectors_implemented']}/{s['catalog_sources']} têm coletor no repositório; {s['scheduled_source_refreshes']} atualização de fonte está agendada.",
        f"- {s['terms_reviewed_or_approved']} fonte tem termos revisados/aprovados; {s['probe_reachable']}/{s['catalog_sources']} responderam ao probe HTTP limitado.",
        "",
        f"**Conclusão:** {payload['conclusion']}",
        "",
        "## Matriz",
        "",
        "| Fonte | Tier | Catálogo | Banco | Acesso | Coletor | Dados | Snapshot | Automação | Termos | Estado |",
        "|---|:---:|:---:|:---:|:---:|:---:|:---:|---:|:---:|---|---|",
    ]
    for row in payload["sources"]:
        access = row["access"]["http_status"] if row["access"]["http_status"] is not None else "falhou"
        rows.append(
            "| {name} | {tier} | {catalog} | {db} | {access} | {collector} | {data} | {raw} | Não | {terms} | {status} |".format(
                name=f"[{row['name']}]({row['url']})",
                tier=row["tier"],
                catalog=yes(row["cataloged"]),
                db=yes(row["database_registered"]),
                access=access,
                collector=yes(row["collector"]["implemented"]),
                data=yes(row["ingestion"]["has_domain_rows"]),
                raw=row["provenance"]["raw_snapshot_count"],
                terms=row["terms"],
                status=LABELS[row["audit_status"]],
            )
        )
    rows.extend([
        "",
        "## Cobertura factual atual",
        "",
        "O catálogo tem 459 hunts; 454 possuem core factual suficiente para o contrato atual do Planner, 26 têm alguma sessão observada e 22 têm incoming damage. Isso mede contratos e presença de evidência, não prova recomendação correta, gameplay real ou Brain completo.",
        "",
        "## Como atualizar",
        "",
        "1. Execute as consultas somente leitura em `docs/evidence/2026-10-14-brain-source-audit.sql` e atualize o snapshot do banco.",
        "2. Execute o probe limitado somente quando uma nova observação externa for necessária.",
        "3. Atualize os fatos fixos em `scripts/build_brain_source_audit.py` com a nova evidência.",
        "4. Rode `python scripts/build_brain_source_audit.py` e `python scripts/render_brain_source_audit.py`.",
        "",
    ])
    return "\n".join(rows)


def render_html(payload: dict) -> str:
    data = json.dumps(payload, ensure_ascii=False).replace("</", "<\\/")
    return f"""<!doctype html>
<html lang=\"pt-BR\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
<title>Auditoria HuntNexus Brain</title>
<style>
:root{{--bg:#050916;--panel:#0b1328;--line:#203052;--text:#edf6ff;--muted:#9fb0cc;--cyan:#20d9ff;--green:#48e5b5;--amber:#ffcc66;--red:#ff7185}}*{{box-sizing:border-box}}body{{margin:0;background:radial-gradient(circle at 80% 0,#092a38 0,transparent 35%),var(--bg);color:var(--text);font:15px/1.5 system-ui,sans-serif}}main{{max-width:1260px;margin:auto;padding:32px 20px 56px}}h1{{font-size:clamp(2rem,5vw,4.4rem);line-height:.95;margin:.15em 0}}.eyebrow{{color:var(--cyan);letter-spacing:.16em;text-transform:uppercase;font-weight:800}}.muted{{color:var(--muted)}}.metrics{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin:28px 0}}.metric,.card,.notice{{background:color-mix(in srgb,var(--panel) 88%,transparent);border:1px solid var(--line);border-radius:16px;padding:18px}}.metric strong{{display:block;color:var(--cyan);font-size:2rem}}.notice{{border-color:#68552b;background:#1c1720}}.controls{{display:flex;gap:10px;flex-wrap:wrap;margin:24px 0}}button{{background:#101b35;border:1px solid var(--line);color:var(--text);padding:9px 14px;border-radius:999px;cursor:pointer}}button[aria-pressed=true]{{background:var(--cyan);color:#00131b;border-color:var(--cyan);font-weight:800}}#grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:14px}}.card h2{{margin:0;font-size:1.05rem}}.top{{display:flex;justify-content:space-between;gap:10px}}.tier{{color:var(--cyan);font-weight:800}}.status{{display:inline-block;margin:10px 0;padding:4px 9px;border-radius:99px;background:#172442;color:var(--green);font-size:.78rem}}dl{{display:grid;grid-template-columns:1fr auto;gap:5px 12px;margin:12px 0}}dt{{color:var(--muted)}}dd{{margin:0;font-weight:700}}a{{color:var(--cyan)}}.gap{{border-top:1px solid var(--line);padding-top:10px;color:var(--muted)}}.none{{display:none}}@media(max-width:600px){{main{{padding:22px 14px}}.metrics{{grid-template-columns:1fr 1fr}}}}
</style></head><body><main>
<p class=\"eyebrow\">HuntNexus Brain · evidência por fonte</p><h1>Conectado é uma palavra que precisa de prova.</h1>
<p class=\"muted\">Snapshot {html.escape(payload['captured_at'])}. Acesso, cadastro, ingestão, proveniência e automação são avaliados separadamente.</p>
<section class=\"metrics\" aria-label=\"Resumo\"><div class=\"metric\"><strong id=\"registered\"></strong>registradas / 18</div><div class=\"metric\"><strong id=\"ingested\"></strong>com dados / 18</div><div class=\"metric\"><strong id=\"snapshots\"></strong>com snapshots / 18</div><div class=\"metric\"><strong id=\"scheduled\"></strong>atualizações agendadas</div></section>
<p class=\"notice\"><strong>Resultado:</strong> {html.escape(payload['conclusion'])}</p>
<nav class=\"controls\" aria-label=\"Filtros\"><button data-filter=\"all\" aria-pressed=\"true\">Todas</button><button data-filter=\"A\">Tier A</button><button data-filter=\"B\">Tier B</button><button data-filter=\"C\">Tier C</button><button data-filter=\"D\">Tier D</button><button data-filter=\"with-data\">Com dados</button><button data-filter=\"gap\">Somente catálogo</button></nav>
<section id=\"grid\" aria-live=\"polite\"></section>
</main><script id=\"audit-data\" type=\"application/json\">{data}</script><script>
const audit=JSON.parse(document.getElementById('audit-data').textContent);const labels={json.dumps(LABELS, ensure_ascii=False)};const summary=audit.summary;
document.getElementById('registered').textContent=summary.catalog_registered;document.getElementById('ingested').textContent=summary.catalog_sources_with_domain_rows;document.getElementById('snapshots').textContent=summary.catalog_sources_with_raw_snapshots;document.getElementById('scheduled').textContent=summary.scheduled_source_refreshes;
const grid=document.getElementById('grid');function esc(s){{return String(s??'').replace(/[&<>\"']/g,c=>({{'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',\"'\":'&#39;'}}[c]))}}
function render(filter='all'){{grid.innerHTML='';audit.sources.filter(s=>filter==='all'||s.tier===filter||(filter==='with-data'&&s.ingestion.has_domain_rows)||(filter==='gap'&&s.audit_status==='catalog_only')).forEach(s=>{{const c=document.createElement('article');c.className='card';c.innerHTML=`<div class=\"top\"><h2>${{esc(s.name)}}</h2><span class=\"tier\">Tier ${{esc(s.tier)}}</span></div><span class=\"status\">${{esc(labels[s.audit_status])}}</span><dl><dt>Catálogo</dt><dd>${{s.cataloged?'sim':'não'}}</dd><dt>Banco</dt><dd>${{s.database_registered?'sim':'não'}}</dd><dt>HTTP observado</dt><dd>${{esc(s.access.http_status??'falhou')}}</dd><dt>Coletor</dt><dd>${{s.collector.implemented?'sim':'não'}}</dd><dt>Dados de domínio</dt><dd>${{s.ingestion.has_domain_rows?'sim':'não'}}</dd><dt>Snapshots</dt><dd>${{s.provenance.raw_snapshot_count}}</dd><dt>Automação</dt><dd>não</dd><dt>Termos</dt><dd>${{esc(s.terms)}}</dd></dl><p class=\"gap\">${{esc(s.coverage_and_gaps)}}</p><a href=\"${{esc(s.url)}}\" rel=\"noreferrer\">Abrir fonte</a>`;grid.appendChild(c)}})}}
document.querySelectorAll('button[data-filter]').forEach(b=>b.addEventListener('click',()=>{{document.querySelectorAll('button[data-filter]').forEach(x=>x.setAttribute('aria-pressed','false'));b.setAttribute('aria-pressed','true');render(b.dataset.filter)}}));render();
</script></body></html>"""


def main() -> None:
    payload = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    MARKDOWN.write_text(render_markdown(payload), encoding="utf-8")
    HTML.write_text(render_html(payload), encoding="utf-8")


if __name__ == "__main__":
    main()
