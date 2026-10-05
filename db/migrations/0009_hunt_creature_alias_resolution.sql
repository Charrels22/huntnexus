-- HuntNexus Brain — Phase 5.1 hunt-creature link resolution.
-- Preserves original source strings in metadata and records explicit alias decisions.

create table if not exists entity_aliases (
  entity_type text not null,
  alias_key text not null,
  canonical_key text not null,
  reason text not null,
  confidence numeric not null check (confidence >= 0 and confidence <= 1),
  source_note text,
  created_at timestamptz not null default now(),
  primary key (entity_type, alias_key)
);

insert into entity_aliases(entity_type,alias_key,canonical_key,reason,confidence,source_note)
values
  ('creature','crystal-crusher','crystalcrusher','spacing/name variant',1.0,'Hunting-place source uses Crystal Crusher; creature catalog uses Crystalcrusher'),
  ('creature','blood-crab-underwater','blood-crab','context suffix',1.0,'Underwater is hunt context, not a separate creature in the catalog'),
  ('creature','crypt-shambler-appears-while-digging','crypt-shambler','HTML/comment contamination',1.0,'Source name contains an inline comment'),
  ('creature','bone-beast','bonebeast','spacing/name variant',1.0,'Hunting-place source uses Bone Beast; creature catalog uses Bonebeast'),
  ('creature','carniphilia','carniphila','source spelling variant',0.99,'Closest exact catalog entity is Carniphila'),
  ('creature','overcharged-energy-elemental','overcharged-energy-element','source naming variant',0.95,'Closest catalog entity is Overcharged Energy Element')
on conflict (entity_type,alias_key) do update set
  canonical_key=excluded.canonical_key,
  reason=excluded.reason,
  confidence=excluded.confidence,
  source_note=excluded.source_note;

-- Resolve simple aliases while preserving provenance in metadata.
with mapped as (
  select hpc.hunting_place_id,
         hpc.monster_slug as old_slug,
         a.canonical_key as new_slug,
         hpc.metadata
  from hunting_place_creatures hpc
  join entity_aliases a
    on a.entity_type='creature'
   and a.alias_key=hpc.monster_slug
)
insert into hunting_place_creatures(hunting_place_id,monster_slug,metadata)
select
  hunting_place_id,
  new_slug,
  metadata || jsonb_build_object(
    'resolution',
    jsonb_build_object(
      'original_monster_slug',old_slug,
      'canonical_monster_slug',new_slug,
      'method','entity_alias'
    )
  )
from mapped
on conflict (hunting_place_id,monster_slug) do update
set metadata = hunting_place_creatures.metadata || excluded.metadata;

delete from hunting_place_creatures hpc
using entity_aliases a
where a.entity_type='creature'
  and a.alias_key=hpc.monster_slug
  and a.alias_key <> a.canonical_key;

-- Split malformed multi-creature source values.
with src as (
  select hunting_place_id,metadata
  from hunting_place_creatures
  where monster_slug='stalker-green-djinn-efreet'
)
insert into hunting_place_creatures(hunting_place_id,monster_slug,metadata)
select
  hunting_place_id,
  x.monster_slug,
  metadata || jsonb_build_object(
    'resolution',
    jsonb_build_object(
      'original_monster_slug','stalker-green-djinn-efreet',
      'canonical_monster_slug',x.monster_slug,
      'method','split_source_list'
    )
  )
from src
cross join (values ('stalker'),('green-djinn'),('efreet')) x(monster_slug)
on conflict (hunting_place_id,monster_slug) do update
set metadata = hunting_place_creatures.metadata || excluded.metadata;

delete from hunting_place_creatures
where monster_slug='stalker-green-djinn-efreet';

with src as (
  select hunting_place_id,metadata
  from hunting_place_creatures
  where monster_slug='quara-mantassin-scout-quara-pincher-scout'
)
insert into hunting_place_creatures(hunting_place_id,monster_slug,metadata)
select
  hunting_place_id,
  x.monster_slug,
  metadata || jsonb_build_object(
    'resolution',
    jsonb_build_object(
      'original_monster_slug','quara-mantassin-scout-quara-pincher-scout',
      'canonical_monster_slug',x.monster_slug,
      'method','split_source_list'
    )
  )
from src
cross join (values ('quara-mantassin-scout'),('quara-pincher-scout')) x(monster_slug)
on conflict (hunting_place_id,monster_slug) do update
set metadata = hunting_place_creatures.metadata || excluded.metadata;

delete from hunting_place_creatures
where monster_slug='quara-mantassin-scout-quara-pincher-scout';
