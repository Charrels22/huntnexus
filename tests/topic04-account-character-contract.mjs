import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const migration = readFileSync(resolve(root, "db/migrations/0162_account_character_domain.sql"), "utf8");
const regression = readFileSync(resolve(root, "tests/sql/topic04_account_character_model.sql"), "utf8");
const evidence = JSON.parse(readFileSync(resolve(root, "docs/evidence/2026-10-14-client-id-dependency-audit.json"), "utf8"));

for (const table of [
  "huntnexus_accounts",
  "player_characters",
  "player_character_profiles",
  "player_character_inventory",
  "player_hunt_build_choices",
  "player_hunt_sessions",
  "player_session_parse_revisions",
]) assert.match(migration, new RegExp(`public\\.${table}`), `${table} ausente`);

for (const fn of [
  "huntnexus_account_characters",
  "huntnexus_character_create",
  "huntnexus_character_set_active",
  "huntnexus_character_scope",
]) {
  assert.match(migration, new RegExp(`function public\\.${fn}`));
  assert.match(migration, new RegExp(`grant execute on function public\\.${fn}`));
  assert.match(migration, new RegExp(`revoke all on function public\\.${fn}`));
}

assert.match(migration, /foreign key \(id,active_character_id\)[\s\S]*references public\.player_characters\(account_id,id\)/i);
assert.equal((migration.match(/foreign key \(client_id,character_id\)/g) ?? []).length, 5);
assert.equal((migration.match(/execute function public\.huntnexus_private_character_scope\(\)/g) ?? []).length, 5);
assert.match(migration, /NULL character_id remains valid only for legacy guest data/i);
assert.match(migration, /client_id remains a compatibility scope/i);
assert.doesNotMatch(migration, /alter table auth\.|update auth\.|insert into auth\.|delete from auth\./i);
assert.match(regression, /SYNTHETIC/g);
assert.match(regression, /foreign_key_violation/);
assert.match(regression, /character_not_found_or_not_owned/);

assert.equal(evidence.live_database.private_client_count, 2);
assert.equal(evidence.live_database.orphan_private_clients, 0);
assert.equal(evidence.live_database.tables_with_client_id.length, 6);
assert.equal(evidence.live_database.routines_with_client_id.length, 28);
assert.equal(evidence.target.authentication_changed, false);
assert.equal(evidence.target.production_migration_applied, false);

console.log("PASS topic 4 contract: additive 1:N model, five scoped private tables, auth unchanged");
