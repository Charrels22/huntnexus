-- HuntNexus Brain: detailed creature and hunting place ingestion.
-- Tier B only. Does not apply RubinOT overrides.

create table if not exists creature_detail_state (
  monster_slug text primary key,
  external_id int,
  source_id uuid not null references sources(id),
  detail_snapshot_id uuid references raw_snapshots(id),
  source_last_updated timestamptz,
  fetched_at timestamptz,
  status text not null default 'pending',
  error_text text
);

create table if not exists creature_abilities (
  id uuid primary key default gen_random_uuid(),
  monster_slug text not null,
  attack_type text,
  abilities_raw text,
  max_damage int,
  uses_spells boolean,
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  observed_at timestamptz not null,
  unique (monster_slug, source_id)
);

create table if not exists creature_loot (
  id uuid primary key default gen_random_uuid(),
  monster_slug text not null,
  item_name text,
  chance text,
  rarity text,
  raw_text text,
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  observed_at timestamptz not null,
  unique (monster_slug, item_name, chance, rarity, raw_text)
);

create index if not exists idx_monster_vulnerability_slug
  on monster_vulnerability(monster_slug);

create index if not exists idx_creature_loot_slug
  on creature_loot(monster_slug);

create index if not exists idx_creature_detail_status
  on creature_detail_state(status);

create index if not exists idx_hunting_place_creatures_monster
  on hunting_place_creatures(monster_slug);
