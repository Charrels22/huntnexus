import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const moduleRoot = process.env.PGLITE_MODULE;
assert.ok(moduleRoot, "PGLITE_MODULE must point to an installed @electric-sql/pglite package");
const { PGlite } = await import(pathToFileURL(resolve(moduleRoot, "dist/index.js")).href);
const root = resolve(import.meta.dirname, "..");
const migration = readFileSync(resolve(root, "db/migrations/0164_topic05_auth_session_gate.sql"), "utf8");

const db = new PGlite();
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;
  create schema auth;
  create schema extensions;
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

await db.close();
console.log("PASS topic 5 PGlite: idempotent migration, active/expired/foreign sessions, factor count, server-only grant");
