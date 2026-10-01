-- HuntNexus Brain: ingestion entities and official source seed.

create table if not exists game_versions (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references sources(id),
  scope text not null check (scope in ('rubinot_server','rubinot_client','tibia')),
  version_label text not null,
  released_on date,
  change_count int,
  source_url text,
  observed_at timestamptz not null default now(),
  unique (scope, version_label)
);

create table if not exists changelog_entries (
  id uuid primary key default gen_random_uuid(),
  version_id uuid not null references game_versions(id),
  source_id uuid not null references sources(id),
  ordinal int,
  summary text not null,
  source_url text not null,
  observed_at timestamptz not null default now(),
  unique (version_id, ordinal)
);

create table if not exists tibia_items (
  id uuid primary key default gen_random_uuid(),
  external_id int,
  slug text not null unique,
  name text not null,
  category text,
  primary_type text,
  secondary_type text,
  weapon_type text,
  vocation text,
  level_required text,
  attack text,
  defense text,
  armor text,
  damage_type text,
  structured_data jsonb not null default '{}',
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  source_last_updated timestamptz,
  observed_at timestamptz not null
);

create table if not exists tibia_hunting_places (
  id uuid primary key default gen_random_uuid(),
  external_id int,
  slug text not null unique,
  name text not null,
  title text,
  city text,
  location text,
  vocation text,
  level_knights text,
  level_paladins text,
  level_mages text,
  loot_rating text,
  experience_rating text,
  structured_data jsonb not null default '{}',
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  source_last_updated timestamptz,
  observed_at timestamptz not null
);

create table if not exists hunting_place_creatures (
  hunting_place_id uuid not null references tibia_hunting_places(id) on delete cascade,
  monster_slug text not null,
  metadata jsonb not null default '{}',
  primary key (hunting_place_id, monster_slug)
);

create table if not exists rubinot_wiki_pages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  category text,
  source_url text not null,
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  observed_at timestamptz not null,
  content_hash text,
  extracted jsonb not null default '{}'
);

insert into sources (name,tier,layer,url,status)
values
  ('RubinOT Changelog','A','rubinot_overlay','https://rubinot.com.br/changelog','active'),
  ('RubinOT Wiki','A','rubinot_overlay','https://wiki.rubinot.com/pt-BR','active'),
  ('RubinOT News','A','rubinot_overlay','https://rubinot.com.br/news','active'),
  ('RubinOT Tools','C','community_observations','https://www.rubinottools.com','review'),
  ('TibiaWiki BR','B','tibia_factual','https://www.tibiawiki.com.br','active'),
  ('ByteWizards TibiaData','B','tibia_factual','https://tibiadata.bytewizards.de','active'),
  ('TibiaMaps','B','tibia_factual','https://github.com/tibiamaps/tibia-map-data','active')
on conflict (name) do update set
  tier=excluded.tier,
  layer=excluded.layer,
  url=excluded.url,
  status=excluded.status;
