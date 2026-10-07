-- HuntNexus Brain — Phase 23 post-load hunt creature alias reconciliation.
-- Re-applies alias/split rules after a fresh factual catalog load.

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
on conflict(hunting_place_id,monster_slug) do update
set metadata = hunting_place_creatures.metadata || excluded.metadata;

delete from hunting_place_creatures hpc
using entity_aliases a
where a.entity_type='creature'
  and a.alias_key=hpc.monster_slug
  and a.alias_key <> a.canonical_key;

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
on conflict(hunting_place_id,monster_slug) do update
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
on conflict(hunting_place_id,monster_slug) do update
set metadata = hunting_place_creatures.metadata || excluded.metadata;

delete from hunting_place_creatures
where monster_slug='quara-mantassin-scout-quara-pincher-scout';
