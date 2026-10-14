import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const audit = JSON.parse(readFileSync(resolve(root, "docs/evidence/2026-10-14-brain-source-audit.json"), "utf8"));
const catalog = JSON.parse(readFileSync(resolve(root, "data/source_catalog.json"), "utf8"));
const markdown = readFileSync(resolve(root, "docs/BRAIN_SOURCE_AUDIT.md"), "utf8");
const html = readFileSync(resolve(root, "docs/brain-source-audit.html"), "utf8");

const catalogRows = audit.sources.filter((source) => source.cataloged);
const dbOnlyRows = audit.sources.filter((source) => !source.cataloged);
assert.equal(catalogRows.length, 18);
assert.equal(dbOnlyRows.length, 1);
assert.deepEqual(catalogRows.map((source) => source.name), catalog.sources.map((source) => source.name));
assert.equal(audit.summary.catalog_sources, 18);
assert.equal(audit.summary.database_sources, 9);
assert.equal(audit.summary.catalog_registered, catalogRows.filter((source) => source.database_registered).length);
assert.equal(audit.summary.catalog_unregistered, catalogRows.filter((source) => !source.database_registered).length);
assert.equal(audit.summary.probe_reachable, catalogRows.filter((source) => source.access.reachable_by_bounded_http_probe === true).length);
assert.equal(audit.summary.probe_failed, catalogRows.filter((source) => source.access.reachable_by_bounded_http_probe === false).length);
assert.equal(audit.summary.collectors_implemented, catalogRows.filter((source) => source.collector.implemented).length);
assert.equal(audit.summary.catalog_sources_with_domain_rows, catalogRows.filter((source) => source.ingestion.has_domain_rows).length);
assert.equal(audit.summary.catalog_sources_with_raw_snapshots, catalogRows.filter((source) => source.provenance.raw_snapshot_count > 0).length);
assert.equal(audit.summary.scheduled_source_refreshes, 0);
assert.equal(audit.summary.terms_reviewed_or_approved, 0);

for (const source of audit.sources) {
  for (const key of ["name", "tier", "url", "cataloged", "database_registered", "access", "collector", "ingestion", "provenance", "automated_update", "terms", "audit_status", "coverage_and_gaps"]) {
    assert.ok(Object.hasOwn(source, key), `${source.name}: campo obrigatório ausente: ${key}`);
  }
  if (source.audit_status.startsWith("connected")) {
    assert.equal(source.database_registered, true, `${source.name}: conectado sem registro`);
    assert.ok(source.ingestion.has_domain_rows, `${source.name}: conectado sem linhas de domínio`);
    assert.ok(source.provenance.raw_snapshot_count > 0, `${source.name}: conectado sem snapshot bruto`);
  }
  assert.equal(source.automated_update.scheduled, false, `${source.name}: automação não comprovada`);
  assert.match(markdown, new RegExp(source.name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(html, new RegExp(source.name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
}

assert.match(html, /data-filter="with-data"/);
assert.match(html, /application\/json/);
console.log(`PASS brain source audit contract: ${catalogRows.length} catalog sources + ${dbOnlyRows.length} DB-only source`);
