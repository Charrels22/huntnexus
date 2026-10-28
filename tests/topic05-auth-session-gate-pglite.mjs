import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const moduleRoot = process.env.PGLITE_MODULE;
assert.ok(moduleRoot, "PGLITE_MODULE must point to an installed @electric-sql/pglite package");
const { PGlite } = await import(pathToFileURL(resolve(moduleRoot, "dist/index.js")).href);
const root = resolve(import.meta.dirname, "..");
const migration = readFileSync(resolve(root, "db/migrations/0164_topic05_auth_session_gate.sql"), "utf8");
const rollback = readFileSync(resolve(root, "db/rollback/0164_topic05_auth_session_gate_rollback.sql"), "utf8");
const verification = readFileSync(resolve(root, "docs/evidence/2026-10-14-topic05-post-migration-verification.sql"), "utf8");
const rollbackVerification = readFileSync(resolve(root, "docs/evidence/2026-10-28-topic05-post-rollback-verification.sql"), "utf8");

const db = new PGlite();
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;
  create schema auth;
  create schema extensions;
  create table auth.users(
    id uuid primary key
  );
  create table auth.sessions(
    id uuid primary key,
    user_id uuid not null,
    not_after timestamptz
  );
  create table auth.mfa_factors(
    id uuid primary key,
    user_id uuid not null,
    factor_type text not null,
    status text not null
  );
`);
await db.exec(migration);
await db.exec(migration);

const functionConfig = await db.query(`select p.proconfig
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='huntnexus_auth_session_gate'
    and p.proargtypes='2950 2950'::oidvector`);
assert.deepEqual(functionConfig.rows, [{ proconfig: ['search_path=""'] }]);

const userId = "11111111-1111-4111-8111-111111111111";
const otherUserId = "22222222-2222-4222-8222-222222222222";
const activeSessionId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const expiredSessionId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
await db.query("insert into auth.sessions(id,user_id,not_after) values($1,$2,now()+interval '1 hour'),($3,$2,now()-interval '1 hour')", [activeSessionId, userId, expiredSessionId]);
await db.query("insert into auth.mfa_factors(id,user_id,factor_type,status) values(gen_random_uuid(),$1,'totp','verified'),(gen_random_uuid(),$1,'totp','unverified'),(gen_random_uuid(),$2,'totp','verified')", [userId, otherUserId]);

const active = await db.query("select public.huntnexus_auth_session_gate($1,$2) gate", [userId, activeSessionId]);
assert.deepEqual(active.rows[0].gate, { active_session: true, verified_factor_count: 1, requires_aal2: true });
const expired = await db.query("select public.huntnexus_auth_session_gate($1,$2) gate", [userId, expiredSessionId]);
assert.equal(expired.rows[0].gate.active_session, false);
const foreign = await db.query("select public.huntnexus_auth_session_gate($1,$2) gate", [otherUserId, activeSessionId]);
assert.equal(foreign.rows[0].gate.active_session, false);
assert.equal(foreign.rows[0].gate.verified_factor_count, 1);

const privileges = await db.query(`select
  has_function_privilege('anon','public.huntnexus_auth_session_gate(uuid,uuid)','execute') anon,
  has_function_privilege('authenticated','public.huntnexus_auth_session_gate(uuid,uuid)','execute') authenticated,
  has_function_privilege('service_role','public.huntnexus_auth_session_gate(uuid,uuid)','execute') service_role`);
assert.deepEqual(privileges.rows[0], { anon: false, authenticated: false, service_role: true });

const verificationResults = await db.exec(verification);
assert.equal(verificationResults.length, 3);
for (const result of verificationResults) {
  assert.equal(result.rows.length, 1);
  assert.equal(result.rows[0].verification_pass, true);
}

await db.exec(rollback);
await db.exec(rollback);
const rolledBack = await db.query(`select
  to_regprocedure('public.huntnexus_auth_session_gate(uuid,uuid)') is null function_absent,
  (select count(*)::int from auth.sessions) session_rows,
  (select count(*)::int from auth.mfa_factors) factor_rows`);
assert.deepEqual(rolledBack.rows[0], { function_absent: true, session_rows: 2, factor_rows: 3 });
const rollbackVerificationResults = await db.exec(rollbackVerification);
assert.equal(rollbackVerificationResults.length, 1);
assert.deepEqual(rollbackVerificationResults[0].rows[0], {
  function_absent: true,
  sessions_table: "auth.sessions",
  factors_table: "auth.mfa_factors",
  auth_user_rows: 0,
  auth_session_rows: 2,
  auth_factor_rows: 3,
  verification_pass: true,
});

await db.close();
console.log("PASS topic 5 PGlite: idempotent migration, active/expired/foreign sessions, factor count, server-only grant, executable apply/rollback verification, idempotent rollback without Auth data loss");
