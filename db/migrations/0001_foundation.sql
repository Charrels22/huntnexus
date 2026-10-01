create extension if not exists pgcrypto;

create type trust_tier as enum ('A','B','C','D');
create type data_layer as enum (
  'tibia_factual',
  'rubinot_overlay',
  'community_observations',
  'editorial'
);

create table sources (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  tier trust_tier not null,
  layer data_layer not null,
  url text,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

create table raw_snapshots (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references sources(id),
  fetched_at timestamptz not null,
  locator text not null,
  content_hash text not null,
  payload jsonb not null,
  unique (source_id, content_hash)
);

create table tibia_entities (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_key text not null,
  name text not null,
  attributes jsonb not null default '{}',
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  observed_at timestamptz not null,
  unique (entity_type, entity_key)
);

create table rubinot_overrides (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_key text not null,
  field text not null,
  value jsonb not null,
  source_id uuid not null references sources(id),
  observed_at timestamptz not null,
  valid_from timestamptz not null,
  valid_to timestamptz,
  patch_version text,
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from)
);

create table incoming_damage (
  id uuid primary key default gen_random_uuid(),
  hunt_key text,
  monster_key text,
  element text not null,
  min_damage numeric,
  max_damage numeric,
  source_id uuid not null references sources(id),
  observed_at timestamptz not null,
  valid_from timestamptz,
  valid_to timestamptz,
  patch_version text
);

create table monster_vulnerability (
  id uuid primary key default gen_random_uuid(),
  monster_key text not null,
  element text not null,
  modifier_percent numeric not null,
  source_id uuid not null references sources(id),
  observed_at timestamptz not null,
  valid_from timestamptz,
  valid_to timestamptz,
  patch_version text
);

create table community_sessions (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  external_id text,
  source_url text,
  server_name text,
  hunt_key text,
  session_started_at timestamptz,
  observed_at timestamptz not null,
  duration_seconds int,
  party_size int,
  xp_gain numeric,
  xp_per_hour numeric,
  raw_xp_per_hour numeric,
  loot_value numeric,
  supplies_value numeric,
  balance_value numeric,
  total_damage numeric,
  total_healing numeric,
  quality_score numeric check (quality_score between 0 and 1),
  raw_payload jsonb
);

create table session_players (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references community_sessions(id) on delete cascade,
  vocation text,
  level int,
  damage numeric,
  healing numeric,
  loot numeric,
  supplies numeric,
  metadata jsonb not null default '{}'
);

create table session_creatures (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references community_sessions(id) on delete cascade,
  monster_key text,
  kills int,
  damage_received numeric,
  loot_value numeric
);

create table session_modifiers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references community_sessions(id) on delete cascade,
  player_id uuid references session_players(id) on delete cascade,
  modifier_type text not null,
  target text,
  value numeric,
  unit text,
  metadata jsonb not null default '{}'
);

create table editorial_notes (
  id uuid primary key default gen_random_uuid(),
  topic text not null,
  body text not null,
  source_id uuid not null references sources(id),
  observed_at timestamptz not null
);

create table recommendation_evidence (
  id uuid primary key default gen_random_uuid(),
  recommendation_key text not null,
  evidence_table text not null,
  evidence_id uuid not null,
  source_id uuid not null references sources(id)
);

create index idx_override_lookup
  on rubinot_overrides(entity_type, entity_key, field, valid_from, valid_to);

create index idx_sessions_hunt
  on community_sessions(hunt_key, session_started_at);

create function guard_rubinot_override_update()
returns trigger language plpgsql as $$
begin
  if (
    new.entity_type,
    new.entity_key,
    new.field,
    new.value,
    new.source_id,
    new.observed_at,
    new.valid_from,
    new.patch_version
  ) is distinct from (
    old.entity_type,
    old.entity_key,
    old.field,
    old.value,
    old.source_id,
    old.observed_at,
    old.valid_from,
    old.patch_version
  ) then
    raise exception 'rubinot_overrides is append-only; insert a new version';
  end if;

  return new;
end $$;

create trigger rubinot_overrides_append_only
before update on rubinot_overrides
for each row execute function guard_rubinot_override_update();
