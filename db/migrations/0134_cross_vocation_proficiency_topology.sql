-- HuntNexus FE-19 — source-backed Weapon Proficiency topology across vocations.
-- Applies only strong archetype mappings where family/hands/perk count align with the
-- structured canonical profile in zimbadev/crystalserver.
-- Divergent catalog entries are intentionally left flattened for later investigation.

with mappings(item_key,profile_name,proficiency_id,profile_version,level_counts) as (
  values
    ('grand-sanguine-battleaxe','Grand Sanguine 2H Axe',22,5,'[1,3,3,2,3,2,1]'::jsonb),
    ('grand-sanguine-hatchet','Grand Sanguine 1H Axe',17,5,'[1,3,3,2,3,2,1]'::jsonb),
    ('grand-sanguine-bludgeon','Grand Sanguine 2H Club',21,5,'[1,3,3,2,3,2,1]'::jsonb),
    ('grand-sanguine-cudgel','Grand Sanguine 1H Club',18,5,'[1,3,3,2,3,2,1]'::jsonb),
    ('grand-sanguine-blade','Grand Sanguine 1H Sword',19,5,'[1,3,3,2,3,2,1]'::jsonb),
    ('grand-sanguine-razor','Grand Sanguine 2H Sword',20,5,'[1,3,3,2,3,2,1]'::jsonb),
    ('grand-sanguine-bow','Grand Sanguine 2H Bow',23,7,'[1,3,3,2,3,2,1]'::jsonb),
    ('grand-sanguine-crossbow','Grand Sanguine 2H Crossbow',450,1,'[1,3,2,3,3,2,1]'::jsonb),
    ('grand-sanguine-claws','Grand Sanguine 2H Fist',24,6,'[1,3,3,2,3,2,1]'::jsonb),
    ('grand-sanguine-rod','Grand Sanguine 1H Rod',25,12,'[1,3,3,2,3,3,1]'::jsonb),

    ('soulbleeder','Soul 2H Bow',34,6,'[1,3,3,2,3,2,1]'::jsonb),
    ('soulpiercer','Soul 2H Crossbow',448,3,'[1,3,3,2,3,2,1]'::jsonb),
    ('soulkamas','Soul 2H Fist',33,6,'[1,3,3,2,3,2,1]'::jsonb),
    ('soulhexer','Soul 1H Rod',35,8,'[1,2,3,3,2,3,1]'::jsonb),
    ('soulshredder','Soul 2H Sword',30,7,'[1,3,3,3,3,2,1]'::jsonb),

    ('amber-kusarigama','Amber 2H Fist',43,4,'[1,2,1,2,3,2,1]'::jsonb),
    ('amber-rod','Amber 1H Rod',45,4,'[1,2,2,2,2,1,1]'::jsonb),

    ('eldritch-bow','Eldritch 2H Distance',91,3,'[1,3,1,2,3]'::jsonb),
    ('gilded-eldritch-bow','Gilded Eldritch 2H Distance',98,4,'[1,3,1,2,3]'::jsonb),
    ('eldritch-crescent-moon-spade','Eldritch 2H Fist',90,4,'[1,1,1,2,1]'::jsonb),
    ('eldritch-rod','Eldritch 1H Rod',92,9,'[1,2,3,2,1]'::jsonb),
    ('eldritch-claymore','Eldritch 2H Sword',89,6,'[1,1,2,3,1]'::jsonb),

    ('bow-of-destruction','Destruction 2H Distance',215,3,'[1,1,2,1,1]'::jsonb),
    ('crossbow-of-destruction','Destruction 2H Distance',215,3,'[1,1,2,1,1]'::jsonb),
    ('nunchaku-of-destruction','Destruction 2H Fist',213,3,'[1,1,2,1,1]'::jsonb),

    ('naga-sword','Naga 1H Sword',254,4,'[1,2,1,2,1]'::jsonb),
    ('assassin-star','Throw - Assassin Star',149,1,'[1,1,1,1,1]'::jsonb)
),
verified as (
  select
    m.*,
    t.perk_count,
    jsonb_array_length(m.level_counts) as level_count,
    (
      select sum((x.value)::int)
      from jsonb_array_elements_text(m.level_counts) x(value)
    ) as mapped_perk_count
  from mappings m
  join public.weapon_proficiency_trees t on t.item_key=m.item_key
),
safe as (
  select *
  from verified
  where perk_count=mapped_perk_count
)
insert into public.weapon_proficiency_topology_sources(
  item_key,source_kind,source_repository,source_revision,source_path,
  source_profile_name,source_proficiency_id,source_profile_version,
  confidence,validation_status,levels_json,notes
)
select
  item_key,
  'canonical_tibia_compatible',
  'zimbadev/crystalserver',
  '96d13eff5a1afef17b11b9abc7d574020381cc53',
  'data/json/proficiencies.json',
  profile_name,
  proficiency_id,
  profile_version,
  'high',
  'archetype_family_hands_perk_count_match',
  level_counts,
  'Topology mapped only where HuntNexus item family/hands/perk count align with the structured canonical archetype. Effect descriptions remain sourced independently.'
from safe
on conflict (item_key) do update set
  source_kind=excluded.source_kind,
  source_repository=excluded.source_repository,
  source_revision=excluded.source_revision,
  source_path=excluded.source_path,
  source_profile_name=excluded.source_profile_name,
  source_proficiency_id=excluded.source_proficiency_id,
  source_profile_version=excluded.source_profile_version,
  confidence=excluded.confidence,
  validation_status=excluded.validation_status,
  levels_json=excluded.levels_json,
  observed_at=now(),
  notes=excluded.notes;

-- Derive level and position from the source-backed level counts.
with topo as (
  select
    s.item_key,
    level.ordinality::int as level_number,
    perk_position::int as position_in_level,
    (
      coalesce((
        select sum((prior.value)::int)
        from jsonb_array_elements_text(s.levels_json) with ordinality prior(value, ord)
        where prior.ord < level.ordinality
      ),0)
      + perk_position
    )::int as perk_order
  from public.weapon_proficiency_topology_sources s
  cross join lateral jsonb_array_elements_text(s.levels_json)
    with ordinality level(value, ordinality)
  cross join lateral generate_series(1,(level.value)::int) perk_position
  where s.source_revision='96d13eff5a1afef17b11b9abc7d574020381cc53'
),
eligible as (
  select topo.*
  from topo
  join public.weapon_proficiency_trees t using(item_key)
  where t.perk_count=(
    select count(*) from topo z where z.item_key=topo.item_key
  )
)
update public.weapon_proficiency_perks p
set
  level_number=e.level_number,
  position_in_level=e.position_in_level,
  metadata=p.metadata || jsonb_build_object(
    'topology_status','source_backed_level_position',
    'level_assignment_known',true,
    'topology_source','zimbadev/crystalserver',
    'topology_source_revision','96d13eff5a1afef17b11b9abc7d574020381cc53'
  )
from eligible e
where p.item_key=e.item_key
  and p.perk_order=e.perk_order;

update public.weapon_proficiency_trees t
set
  levels_declared=jsonb_array_length(s.levels_json),
  topology_status='source_backed_level_position',
  notes=concat_ws(
    ' ',
    t.notes,
    'Level/position topology mapped from structured canonical profile',
    s.source_profile_name,
    'at zimbadev/crystalserver @ 96d13eff5a1afef17b11b9abc7d574020381cc53.'
  )
from public.weapon_proficiency_topology_sources s
where s.item_key=t.item_key
  and s.source_revision='96d13eff5a1afef17b11b9abc7d574020381cc53'
  and (
    select count(*)
    from public.weapon_proficiency_perks p
    where p.item_key=t.item_key
      and p.level_number is not null
      and p.position_in_level is not null
  )=t.perk_count;
