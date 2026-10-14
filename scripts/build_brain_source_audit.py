from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "data" / "source_catalog.json"
ACCESS_PATH = ROOT / "docs" / "evidence" / "2026-10-13-source-access-probe.json"
AUDIT_PATH = ROOT / "docs" / "evidence" / "2026-10-14-brain-source-audit.json"
DB_PATH = ROOT / "docs" / "evidence" / "2026-10-14-brain-database-snapshot.json"
CAPTURED_AT = "2026-10-14T00:18:00-03:00"


REGISTERED = {
    "RubinOT Changelog": {"tier": "A", "status": "active", "method": "browser/web fetch", "checked": "2026-10-07", "terms": "pending"},
    "RubinOT News": {"tier": "A", "status": "active", "method": "browser/web fetch", "checked": "2026-10-07", "terms": "pending"},
    "RubinOT Wiki": {"tier": "A", "status": "active", "method": "browser/web fetch", "checked": "2026-10-07", "terms": "pending"},
    "RubinOT Tools": {"tier": "C", "status": "review", "method": "browser/web fetch", "checked": "2026-10-07", "terms": "pending"},
    "TibiaWiki BR": {"tier": "B", "status": "active", "method": "curated SQL", "checked": "2026-10-07", "terms": "pending"},
    "ByteWizards TibiaData": {"tier": "B", "status": "active", "method": "structured API", "checked": "2026-10-07", "terms": "pending"},
    "TibiaMaps": {"tier": "B", "status": "active", "method": "repository/export", "checked": "2026-10-07", "terms": "pending"},
    "HuntAnalyser Public Hunts": {"tier": "C", "status": "review", "method": "bounded public-page smoke", "checked": "2026-10-07", "terms": "pending"},
    "RubinOT Website": {"tier": "A", "status": "active", "method": "browser/web fetch", "checked": "2026-10-07T17:30:34Z", "terms": "pending"},
}


EVIDENCE = {
    "RubinOT Changelog": {"game_versions": 2, "rubinot_system_facts": 2, "rubinot_change_candidates": 14},
    "RubinOT News": {},
    "RubinOT Wiki": {"rubinot_modifier_definitions": 13, "rubinot_system_facts": 5},
    "RubinOT Tools": {},
    "TibiaWiki BR": {"spell_definitions": 60, "imbuement_definitions": 24, "weapon_proficiency_trees": 34},
    "ByteWizards TibiaData": {
        "raw_snapshots": 4340,
        "tibia_entities": 2193,
        "tibia_items": 6470,
        "tibia_hunting_places": 459,
        "monster_vulnerability": 21831,
        "creature_abilities": 2193,
        "creature_loot": 18675,
        "item_effects": 1658,
        "boss_profiles": 548,
    },
    "TibiaMaps": {},
    "HuntAnalyser Public Hunts": {"raw_snapshots": 105, "community_sessions": 100, "community_detail_states": 100},
    "RubinOT Website": {"rubinot_modifier_definitions": 1, "rubinot_system_facts": 5},
}


COLLECTORS = {
    "RubinOT Changelog": ["collectors/rubinot_changelog.py"],
    "RubinOT Wiki": ["collectors/rubinot_wiki.py"],
    "ByteWizards TibiaData": ["collectors/tibiadata_sync.py"],
}


STATUS = {
    "RubinOT Changelog": ("partial_verified", "Versões, fatos e 14 candidatos de mudança; faltam snapshot bruto no banco, reconciliação e agenda."),
    "RubinOT News": ("registered_empty", "Registrada e acessível, sem coletor, snapshot ou linha de domínio comprovada."),
    "RubinOT Wiki": ("partial_verified", "Fatos e modificadores curados; zero páginas/snapshots persistidos e sem agenda."),
    "RubinOT Tools": ("registered_empty", "Registrada como Tier C em revisão, sem dado ingerido comprovado."),
    "TibiaWiki BR": ("curated_partial", "Spells, imbuements e árvores de proficiência curados; sem coletor ou snapshot bruto."),
    "TibiaWikiApi": ("catalog_only", "Somente catálogo; nenhuma configuração, coleta ou ingestão comprovada."),
    "ByteWizards TibiaData": ("connected_manual", "Núcleo factual amplo e snapshots presentes; última coleta observada em 2026-10-07 e sem agenda."),
    "TibiaMaps": ("registered_empty", "Registrada, sem mapas/markers ingeridos ou snapshot comprovado."),
    "PT Finder": ("catalog_only", "Somente catálogo; probe DNS falhou nesta observação."),
    "OberonGG": ("catalog_only", "Acessível no probe, sem registro, coletor ou ingestão."),
    "Hunts.RubinOT": ("catalog_only", "Acessível no probe, sem registro, coletor ou ingestão comprovada."),
    "HuntAnalyser": ("connected_sample_manual", "Amostra limitada de 100 sessões/100 detalhes e 105 snapshots; sem agenda e termos pendentes."),
    "Hunt Tracker RubinOT Community": ("catalog_only", "Somente catálogo; endpoint observado respondeu 404."),
    "Tibia Watch": ("catalog_only", "Acessível no probe, sem registro, coletor ou ingestão."),
    "Tibialytics": ("catalog_only", "Acessível no probe, sem registro, coletor ou ingestão."),
    "Vigia das Estatísticas": ("catalog_only", "Somente catálogo; endpoint observado respondeu 530."),
    "Keke de Patinete": ("catalog_only", "Acessível no probe, mas sem notas editoriais ingeridas."),
    "Vatoz Lokoz": ("catalog_only", "Acessível no probe, mas sem notas editoriais ingeridas."),
    "RubinOT Website": ("database_only_curated_partial", "Fonte extra do banco com fatos/modificador curados; não está no catálogo e não possui snapshot bruto."),
}


ALIASES = {"HuntAnalyser": "HuntAnalyser Public Hunts"}


def has_domain_rows(counts: dict[str, int]) -> bool:
    return any(key != "raw_snapshots" and value > 0 for key, value in counts.items())


def main() -> None:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    access_payload = json.loads(ACCESS_PATH.read_text(encoding="utf-8"))
    access_by_name = {row["name"]: row for row in access_payload["results"]}
    sources = []

    for source in catalog["sources"]:
        name = source["name"]
        db_name = ALIASES.get(name, name)
        registration = REGISTERED.get(db_name)
        counts = EVIDENCE.get(db_name, {})
        probe = access_by_name[name]
        status, gap = STATUS[name]
        collector_paths = COLLECTORS.get(name, [])
        raw_count = counts.get("raw_snapshots", 0)
        sources.append({
            "name": name,
            "tier": source["tier"],
            "url": source["url"],
            "cataloged": True,
            "database_registered": registration is not None,
            "db_source_name": db_name if registration else None,
            "registry_status": registration["status"] if registration else None,
            "access": {
                "observed_at": access_payload["observed_at"],
                "reachable_by_bounded_http_probe": probe["reachable_by_bounded_http_probe"],
                "http_status": probe["http_status"],
                "final_url": probe["final_url"],
                "error": probe["error"],
            },
            "collector": {"implemented": bool(collector_paths), "paths": collector_paths},
            "ingestion": {"has_domain_rows": has_domain_rows(counts), "counts": counts},
            "normalization": "strong_core" if name == "ByteWizards TibiaData" else ("partial" if has_domain_rows(counts) else "none"),
            "provenance": {
                "source_registry": registration is not None,
                "raw_snapshot_count": raw_count,
                "assessment": "strong" if raw_count > 0 else ("partial_without_raw_snapshot" if has_domain_rows(counts) else "none"),
            },
            "automated_update": {"scheduled": False, "evidence": "Nenhum pg_cron/job ou workflow de coleta; funções/coletores são acionáveis manualmente."},
            "terms": registration["terms"] if registration else "not_tracked",
            "audit_status": status,
            "coverage_and_gaps": gap,
        })

    extra_name = "RubinOT Website"
    extra_registration = REGISTERED[extra_name]
    extra_counts = EVIDENCE[extra_name]
    sources.append({
        "name": extra_name,
        "tier": extra_registration["tier"],
        "url": "https://rubinot.com.br",
        "cataloged": False,
        "database_registered": True,
        "db_source_name": extra_name,
        "registry_status": extra_registration["status"],
        "access": {"observed_at": None, "reachable_by_bounded_http_probe": None, "http_status": None, "final_url": None, "error": "Não incluída no probe do catálogo."},
        "collector": {"implemented": False, "paths": []},
        "ingestion": {"has_domain_rows": True, "counts": extra_counts},
        "normalization": "partial",
        "provenance": {"source_registry": True, "raw_snapshot_count": 0, "assessment": "partial_without_raw_snapshot"},
        "automated_update": {"scheduled": False, "evidence": "Nenhum pg_cron/job ou workflow de coleta comprovado."},
        "terms": extra_registration["terms"],
        "audit_status": STATUS[extra_name][0],
        "coverage_and_gaps": STATUS[extra_name][1],
    })

    catalog_sources = [row for row in sources if row["cataloged"]]
    summary = {
        "catalog_sources": len(catalog_sources),
        "database_sources": len(REGISTERED),
        "catalog_registered": sum(row["database_registered"] for row in catalog_sources),
        "catalog_unregistered": sum(not row["database_registered"] for row in catalog_sources),
        "database_only": sum(not row["cataloged"] for row in sources),
        "probe_reachable": sum(row["access"]["reachable_by_bounded_http_probe"] is True for row in catalog_sources),
        "probe_failed": sum(row["access"]["reachable_by_bounded_http_probe"] is False for row in catalog_sources),
        "collectors_implemented": sum(row["collector"]["implemented"] for row in catalog_sources),
        "catalog_sources_with_domain_rows": sum(row["ingestion"]["has_domain_rows"] for row in catalog_sources),
        "catalog_sources_with_raw_snapshots": sum(row["provenance"]["raw_snapshot_count"] > 0 for row in catalog_sources),
        "scheduled_source_refreshes": 0,
        "terms_reviewed_or_approved": 0,
    }
    audit = {
        "schema_version": 1,
        "captured_at": CAPTURED_AT,
        "scope": "Point-in-time, read-only audit of the informed source catalog, live Supabase registry/evidence and repository collectors/jobs.",
        "rules": [
            "Reachability is not connection, permission, ingestion or current coverage.",
            "A callable collector/function is not an automated update without a proven schedule.",
            "Counts measure presence, not correctness or completeness.",
        ],
        "summary": summary,
        "brain_totals": {
            "sources": 9,
            "raw_snapshots": 4445,
            "creatures": 2193,
            "items": 6470,
            "hunts": 459,
            "bosses": 548,
            "spells": 60,
            "community_sessions": 100,
            "private_sessions": 0,
            "recommendation_evidence": 0,
            "editorial_notes": 0,
            "rubinot_system_facts": 12,
            "rubinot_modifier_definitions": 14,
            "rubinot_wiki_pages": 0,
            "changelog_entries": 0,
            "rubinot_change_candidates": 14,
            "active_rubinot_overrides": 0,
        },
        "hunt_readiness": {
            "catalog": 459,
            "fixed_spawn": 455,
            "planner_eligible": 454,
            "source_core_complete": 454,
            "source_core_incomplete": 1,
            "nonfixed": 4,
            "with_observed_sessions": 26,
            "with_incoming_damage": 22,
        },
        "automation": {
            "pg_cron_installed": False,
            "scheduled_collectors": 0,
            "github_daily_smoke": ".github/workflows/huntnexus-public-smoke.yml runs API smoke only; it does not refresh sources.",
            "callable_ingestion_functions": 11,
        },
        "conclusion": "O núcleo factual TibiaData é amplo, porém o Brain completo não está montado: 10/18 fontes não estão registradas, 13/18 não têm dado de domínio, nenhuma atualização de fonte está agendada e nenhum termo está aprovado/revisado.",
        "sources": sources,
    }
    db_snapshot = {
        "schema_version": 1,
        "captured_at": CAPTURED_AT,
        "project_ref": "urbncbjapasnjqjqicjv",
        "read_only": True,
        "source_registry": [dict(name=name, **values, counts=EVIDENCE.get(name, {})) for name, values in REGISTERED.items()],
        "brain_totals": audit["brain_totals"],
        "hunt_readiness": audit["hunt_readiness"],
        "automation": audit["automation"],
        "product_readiness_interpretation": {
            "backend_contracts_reported_ready": "9/9",
            "backend_contracts_only": True,
            "external_pilot_included": False,
            "real_class_playtest_included": False,
            "frontend_visual_validation_included": False,
        },
    }
    AUDIT_PATH.parent.mkdir(parents=True, exist_ok=True)
    AUDIT_PATH.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    DB_PATH.write_text(json.dumps(db_snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
