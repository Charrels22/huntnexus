import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const moduleRoot = process.env.PGLITE_MODULE;
assert.ok(moduleRoot, "PGLITE_MODULE must point to an installed @electric-sql/pglite package");
const { PGlite } = await import(pathToFileURL(resolve(moduleRoot, "dist/index.js")).href);
const root = resolve(import.meta.dirname, "..");
const migration = readFileSync(resolve(root, "db/migrations/0162_account_character_domain.sql"), "utf8");
const regression = readFileSync(resolve(root, "tests/sql/topic04_account_character_model.sql"), "utf8");

const base = String.raw`
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create schema extensions;

create table public.player_account_bindings(
  auth_user_id uuid primary key,
  client_id uuid not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create table public.player_character_profiles(
  client_id uuid primary key,
  character_name text,world_name text,vocation text,level integer,online boolean,
  former_names text[] not null default '{}',official_lookup_at timestamptz,
  official_lookup_status text,manual_stats jsonb not null default '{}',
  proficiency_selections jsonb not null default '{}',defaults jsonb not null default '{}',
  created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.player_character_inventory(
  id uuid primary key default gen_random_uuid(),client_id uuid not null,
  storage_kind text not null,selection_key text not null,item_key text not null,item_name text not null,
  quantity integer not null default 1,notes text,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.player_hunt_build_choices(
  client_id uuid not null,hunt_key text not null,vocation text not null,
  selection jsonb not null default '{}',option_type text,replacements jsonb not null default '[]',
  updated_at timestamptz not null default now(),primary key(client_id,hunt_key,vocation)
);
create table public.player_hunt_sessions(
  id uuid primary key default gen_random_uuid(),client_id uuid not null,
  created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.player_session_parse_revisions(
  id uuid primary key default gen_random_uuid(),client_id uuid not null,
  session_id uuid not null,revised_at timestamptz not null default now()
);

create or replace function public.huntnexus_player_profile_save(p_client_id uuid,p_profile jsonb)
returns jsonb language plpgsql security definer set search_path to 'public','extensions' as $f$
begin
  insert into public.player_character_profiles(client_id,character_name,world_name,vocation,level,updated_at)
  values(p_client_id,nullif(trim(p_profile->>'character_name'),''),nullif(trim(p_profile->>'world_name'),''),
    nullif(trim(p_profile->>'vocation'),''),case when coalesce(p_profile->>'level','')~'^\d+$' then (p_profile->>'level')::int end,now())
  on conflict(client_id) do update set character_name=excluded.character_name,world_name=excluded.world_name,
    vocation=excluded.vocation,level=excluded.level,updated_at=now();
  return jsonb_build_object('saved',true,'client_id',p_client_id);
end $f$;

create or replace function public.huntnexus_account_resolve(p_auth_user_id uuid,p_local_client_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public','extensions' as $f$
declare v_client uuid;
begin
  select client_id into v_client from public.player_account_bindings where auth_user_id=p_auth_user_id;
  if v_client is not null then
    return jsonb_build_object('resolved',true,'created',false,'canonical_client_id',v_client);
  end if;
  if exists(select 1 from public.player_account_bindings where client_id=p_local_client_id) then
    return jsonb_build_object('error','client_id_already_bound','resolved',false);
  end if;
  insert into public.player_account_bindings(auth_user_id,client_id) values(p_auth_user_id,p_local_client_id);
  return jsonb_build_object('resolved',true,'created',true,'canonical_client_id',p_local_client_id);
end $f$;
`;

const db = new PGlite();
await db.exec(base);
await db.exec(migration);
await db.exec(migration); // retry safety: no duplicate constraint/trigger failure
const result = await db.exec(regression);
const summary = result.at(-1)?.rows?.[0]?.regression_summary;
assert.equal(summary?.status, "ok");
assert.equal(summary?.fixture, "SYNTHETIC");
assert.equal(summary?.scope_mismatch_blocked, true);

const post = await db.query(`
  select
    (select count(*)::int from public.huntnexus_accounts) accounts,
    (select count(*)::int from public.player_characters) characters,
    (select count(*)::int from public.player_account_bindings) bindings
`);
assert.deepEqual(post.rows[0], { accounts: 0, characters: 0, bindings: 0 });
await db.close();
console.log("PASS topic 4 PGlite: migration applied twice, 1:N isolation exercised, fixture cleaned");
