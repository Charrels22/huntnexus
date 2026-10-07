-- HuntNexus Brain — Phase 24 canonical slug compatibility.
-- Restores the exact slug semantics used by the original TypeScript collector:
-- apostrophes are removed, not converted to separators.

create or replace function huntnexus_tibiadata_slug(p_name text)
returns text
language sql
immutable
as $$
  select trim(both '-' from lower(
    regexp_replace(
      translate(
        replace(replace(coalesce(p_name,''),'''',''),'’',''),
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'
      ),
      '[^a-zA-Z0-9]+','-','g'
    )
  ));
$$;

do $$
begin
  if exists(select 1 from boss_room_adds)
     or exists(select 1 from boss_room_mechanics)
     or exists(select 1 from boss_room_spell_guidance)
     or exists(select 1 from boss_room_item_guidance) then
    raise exception 'Refusing canonical rekey: curated boss-room child rows already exist';
  end if;
end;
$$;

create temporary table tmp_creature_rekey on commit drop as
select
  e.entity_key as old_key,
  huntnexus_tibiadata_slug(e.name) as new_key,
  nullif(e.attributes->>'id','')::int as external_id
from tibia_entities e
where e.entity_type='creature';

create temporary table tmp_hunt_rekey on commit drop as
select
  h.slug as old_key,
  huntnexus_tibiadata_slug(h.name) as new_key,
  h.external_id
from tibia_hunting_places h;

create temporary table tmp_item_rekey on commit drop as
with x as (
  select
    i.slug as old_key,
    i.external_id,
    huntnexus_tibiadata_slug(i.name) as base_key,
    count(*) over(partition by huntnexus_tibiadata_slug(i.name)) as base_count
  from tibia_items i
)
select
  old_key,
  case
    when base_count>1 and external_id is not null then base_key||'-'||external_id::text
    else base_key
  end as new_key,
  external_id
from x;

-- Creature-key dependents.
update monster_vulnerability x
set monster_key=m.new_key
from tmp_creature_rekey m
where x.monster_key=m.old_key and m.old_key<>m.new_key;

update creature_abilities x
set monster_key=m.new_key
from tmp_creature_rekey m
where x.monster_key=m.old_key and m.old_key<>m.new_key;

update creature_loot x
set monster_key=m.new_key
from tmp_creature_rekey m
where x.monster_key=m.old_key and m.old_key<>m.new_key;

update creature_detail_state x
set monster_key=m.new_key
from tmp_creature_rekey m
where x.monster_key=m.old_key and m.old_key<>m.new_key;

update hunting_place_creatures x
set monster_slug=m.new_key
from tmp_creature_rekey m
where x.monster_slug=m.old_key and m.old_key<>m.new_key;

update session_creatures x
set monster_key=m.new_key
from tmp_creature_rekey m
where x.monster_key=m.old_key and m.old_key<>m.new_key;

update session_incoming_damage_sources x
set monster_key=m.new_key
from tmp_creature_rekey m
where x.monster_key=m.old_key and m.old_key<>m.new_key;

update incoming_damage x
set monster_key=m.new_key
from tmp_creature_rekey m
where x.monster_key=m.old_key and m.old_key<>m.new_key;

update huntnexus_async_detail_jobs x
set entity_key=m.new_key
from tmp_creature_rekey m
where x.kind='creature'
  and x.external_id=m.external_id
  and x.entity_key<>m.new_key;

update entity_aliases x
set canonical_key=m.new_key
from tmp_creature_rekey m
where x.entity_type='creature'
  and x.canonical_key=m.old_key
  and m.old_key<>m.new_key;

update rubinot_change_candidates x
set entity_key=m.new_key
from tmp_creature_rekey m
where x.entity_key=m.old_key
  and m.old_key<>m.new_key
  and x.entity_type in ('creature','boss');

update rubinot_overrides x
set entity_key=m.new_key
from tmp_creature_rekey m
where x.entity_key=m.old_key
  and m.old_key<>m.new_key;

-- Hunt-key dependents.
update community_sessions x
set hunt_key=m.new_key
from tmp_hunt_rekey m
where x.hunt_key=m.old_key and m.old_key<>m.new_key;

update community_hunt_aliases x
set canonical_hunt_key=m.new_key
from tmp_hunt_rekey m
where x.canonical_hunt_key=m.old_key and m.old_key<>m.new_key;

update incoming_damage x
set hunt_key=m.new_key
from tmp_hunt_rekey m
where x.hunt_key=m.old_key and m.old_key<>m.new_key;

update huntnexus_async_detail_jobs x
set entity_key=m.new_key
from tmp_hunt_rekey m
where x.kind='hunt'
  and x.external_id=m.external_id
  and x.entity_key<>m.new_key;

-- Item-key dependents.
update huntnexus_async_detail_jobs x
set entity_key=m.new_key
from tmp_item_rekey m
where x.kind='item'
  and x.external_id=m.external_id
  and x.entity_key<>m.new_key;

-- Generated boss profiles can be safely regenerated; curated room tables were checked empty above.
delete from boss_group_members;
delete from boss_profiles;

-- Two-phase base-key rename avoids transient unique collisions.
update tibia_entities e
set entity_key='__rekey__creature_'||m.external_id::text
from tmp_creature_rekey m
where e.entity_type='creature'
  and e.entity_key=m.old_key
  and m.old_key<>m.new_key;

update tibia_entities e
set entity_key=m.new_key
from tmp_creature_rekey m
where e.entity_type='creature'
  and e.entity_key='__rekey__creature_'||m.external_id::text
  and m.old_key<>m.new_key;

update tibia_hunting_places h
set slug='__rekey__hunt_'||m.external_id::text
from tmp_hunt_rekey m
where h.slug=m.old_key and m.old_key<>m.new_key;

update tibia_hunting_places h
set slug=m.new_key
from tmp_hunt_rekey m
where h.slug='__rekey__hunt_'||m.external_id::text
  and m.old_key<>m.new_key;

update tibia_items i
set slug='__rekey__item_'||m.external_id::text
from tmp_item_rekey m
where i.slug=m.old_key
  and m.old_key<>m.new_key
  and m.external_id is not null;

update tibia_items i
set slug=m.new_key
from tmp_item_rekey m
where i.slug='__rekey__item_'||m.external_id::text
  and m.old_key<>m.new_key
  and m.external_id is not null;

-- Rebuild generated boss layer and re-run community resolution on canonical hunt keys.
select huntnexus_sync_canonical_boss_profiles();
select huntnexus_refresh_boss_groups();
select huntnexus_resolve_community_hunts_exact('HuntAnalyser Public Hunts');
