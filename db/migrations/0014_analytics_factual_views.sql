-- HuntNexus Analytics — Phase 7 factual hunt/equipment views.
-- These views do NOT use community performance data and do NOT claim final recommendations.

create or replace view vw_hunt_monster_element_profile as
select
  h.id as hunting_place_id,
  h.slug as hunt_key,
  h.name as hunt_name,
  hpc.monster_slug as monster_key,
  e.name as monster_name,
  v.element,
  v.modifier_percent,
  case
    when v.modifier_percent = 0 then 'immune'
    when v.modifier_percent < 100 then 'resistant'
    when v.modifier_percent = 100 then 'neutral'
    when v.modifier_percent > 100 then 'weak'
    else 'unknown'
  end as response_class,
  v.source_id,
  v.observed_at
from tibia_hunting_places h
join hunting_place_creatures hpc
  on hpc.hunting_place_id=h.id
join tibia_entities e
  on e.entity_type='creature'
 and e.entity_key=hpc.monster_slug
join monster_vulnerability v
  on v.monster_key=e.entity_key;

create or replace view vw_hunt_element_summary as
select
  hunting_place_id,
  hunt_key,
  hunt_name,
  element,
  count(distinct monster_key)::int as monster_count,
  round(avg(modifier_percent),2) as avg_modifier_percent,
  min(modifier_percent) as min_modifier_percent,
  max(modifier_percent) as max_modifier_percent,
  count(distinct monster_key) filter (where modifier_percent > 100)::int as weak_monsters,
  count(distinct monster_key) filter (where modifier_percent = 100)::int as neutral_monsters,
  count(distinct monster_key) filter (where modifier_percent > 0 and modifier_percent < 100)::int as resistant_monsters,
  count(distinct monster_key) filter (where modifier_percent = 0)::int as immune_monsters
from vw_hunt_monster_element_profile
group by hunting_place_id,hunt_key,hunt_name,element;

comment on view vw_hunt_element_summary is
'Unweighted species-level elemental profile. Useful as factual evidence only; not a final hunt recommendation because spawn frequency/session kill weights are not included.';

create or replace view vw_equipment_protection_catalog as
select
  i.id as item_id,
  i.slug as item_key,
  i.name,
  i.category,
  i.vocation,
  nullif(regexp_replace(coalesce(i.level_required,''),'[^0-9]','','g'),'')::int as level_required_numeric,
  i.imbue_slots,
  e.effect_key as element,
  e.numeric_value as protection_percent,
  e.raw_value,
  e.source_id,
  e.snapshot_id
from tibia_items i
join item_effects e
  on e.item_id=i.id
where e.effect_type='protection'
  and e.unit='percent';

create or replace view vw_equipment_combat_effects as
select
  i.id as item_id,
  i.slug as item_key,
  i.name,
  i.category,
  i.vocation,
  nullif(regexp_replace(coalesce(i.level_required,''),'[^0-9]','','g'),'')::int as level_required_numeric,
  i.attack,
  i.defense,
  i.armor,
  i.imbue_slots,
  i.damage_type,
  e.effect_type,
  e.effect_key,
  e.numeric_value,
  e.unit,
  e.context,
  e.raw_value
from tibia_items i
join item_effects e
  on e.item_id=i.id;

create or replace function huntnexus_hunt_factual_profile(p_hunt_key text)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'hunt',
      (select jsonb_build_object(
         'key',h.slug,
         'name',h.name,
         'city',h.city,
         'location',h.location,
         'vocation',h.vocation,
         'level_knights',h.level_knights,
         'level_paladins',h.level_paladins,
         'level_mages',h.level_mages
       )
       from tibia_hunting_places h
       where h.slug=p_hunt_key),
    'monsters',
      coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'key',x.monster_key,
            'name',x.monster_name
          )
          order by x.monster_name
        )
        from (
          select distinct monster_key,monster_name
          from vw_hunt_monster_element_profile
          where hunt_key=p_hunt_key
        ) x
      ),'[]'::jsonb),
    'elements',
      coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'element',element,
            'monster_count',monster_count,
            'avg_modifier_percent',avg_modifier_percent,
            'min_modifier_percent',min_modifier_percent,
            'max_modifier_percent',max_modifier_percent,
            'weak_monsters',weak_monsters,
            'neutral_monsters',neutral_monsters,
            'resistant_monsters',resistant_monsters,
            'immune_monsters',immune_monsters
          )
          order by element
        )
        from vw_hunt_element_summary
        where hunt_key=p_hunt_key
      ),'[]'::jsonb),
    'methodology',
      jsonb_build_object(
        'layer','tibia_factual',
        'weighted_by_kills',false,
        'final_recommendation',false,
        'note','Species-level elemental profile only. Community sessions are required before performance ranking.'
      )
  );
$$;

revoke all on function huntnexus_hunt_factual_profile(text)
  from public, anon, authenticated;
grant execute on function huntnexus_hunt_factual_profile(text)
  to service_role;
