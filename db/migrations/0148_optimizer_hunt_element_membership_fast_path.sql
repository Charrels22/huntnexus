-- HuntNexus FE-18 / PERF-01: eliminate expensive incoming-damage
-- aggregate view work when only its distinct element keys are required.
-- Evidence: five vocation/hunt membership comparisons before DDL all matched.
-- No candidate pruning, scoring, vocation filters or vector dimensions changed.
--
CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_item_vector_universal(p_item_key text, p_hunt_key text, p_vocation text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code
),
vr as (
  select *
  from vocation_composition_rules
  where vocation_code=(select vocation_code from p)
),
item as (
  select
    w.item_id,w.item_key,w.name,'weapon'::text as item_domain,
    w.weapon_family as item_family,null::text as slot_key,
    w.defense,w.defense_mod,w.range_value,w.imbue_slots,
    null::integer as armor,w.attack_components
  from vw_weapon_catalog_universal w
  where w.item_key=p_item_key
  union all
  select
    e.item_id,e.item_key,e.name,'equipment'::text as item_domain,
    e.equipment_family as item_family,e.slot_key,
    e.defense,e.defense_mod,null::integer as range_value,e.imbue_slots,
    e.armor,'{}'::jsonb as attack_components
  from vw_equipment_catalog_universal e
  where e.item_key=p_item_key
  limit 1
),
observed_elements as (
  -- Same factual inclusion as vw_hunt_observed_incoming_damage, without
  -- materializing per-session median, totals or damage shares for membership.
  -- Its subject_totals join excludes NULL player_name_hash entries.
  select distinct d.element
  from session_incoming_damage d
  join community_sessions cs on cs.id=d.session_id
  join tibia_hunting_places h on h.slug=cs.hunt_key
  join session_players sp on sp.id=d.player_id
  where cs.hunt_key=p_hunt_key
    and sp.vocation=(select vocation_code from p)
    and d.player_name_hash is not null
),
relevant_skills as (
  select value as effect_key
  from vr
  cross join lateral jsonb_array_elements_text(
    coalesce(vr.primary_skill_keys,'[]'::jsonb) ||
    coalesce(vr.secondary_skill_keys,'[]'::jsonb)
  )
  union
  select x.effect_key
  from (values
    ('ED'::text,'fire_magic_level'::text),
    ('ED','ice_magic_level'),
    ('ED','earth_magic_level'),
    ('ED','energy_magic_level'),
    ('ED','death_magic_level'),
    ('ED','holy_magic_level'),
    ('ED','healing_magic_level'),
    ('MS','fire_magic_level'),
    ('MS','ice_magic_level'),
    ('MS','earth_magic_level'),
    ('MS','energy_magic_level'),
    ('MS','death_magic_level'),
    ('MS','holy_magic_level'),
    ('MS','healing_magic_level'),
    ('EM','healing_magic_level')
  ) x(vocation_code,effect_key)
  where x.vocation_code=(select vocation_code from p)
),
core_dims as (
  select k,v
  from item
  cross join lateral (values
    ('core/armor'::text,armor::numeric),
    ('core/defense',defense::numeric),
    ('core/defense_mod',defense_mod::numeric),
    ('core/range',range_value::numeric),
    ('core/imbue_slots',coalesce(imbue_slots,0)::numeric)
  ) d(k,v)
  where v is not null
),
attack_dims as (
  select 'attack/'||e.element as k,
         coalesce((i.attack_components->>e.element)::numeric,0) as v
  from item i
  cross join (values
    ('physical'::text),('fire'),('ice'),('earth'),('energy'),('death'),('holy')
  ) e(element)
  where i.item_domain='weapon'
    and (
      exists(select 1 from jsonb_object_keys(i.attack_components))
      or i.item_family in ('sword','axe','club','fist','throwing')
    )
),
skill_dims as (
  select 'effect/skill/'||s.effect_key as k,
         coalesce((
           select sum(ie.numeric_value)
           from item_effects ie
           join item i2 on i2.item_id=ie.item_id
           where ie.effect_type in ('skill','magic_skill')
             and ie.effect_key=s.effect_key
         ),0)::numeric as v
  from relevant_skills s
),
directional_effect_keys as (
  select * from (values
    ('effect/defense/damage_reflection'::text,'defense'::text,'damage_reflection'::text),
    ('effect/defense/magic_shield_capacity_flat','defense','magic_shield_capacity_flat'),
    ('effect/defense/magic_shield_capacity_percent','defense','magic_shield_capacity_percent'),
    ('effect/leech/life_leech','leech','life_leech'),
    ('effect/movement/speed','movement','speed'),
    ('effect/offense/attack_modifier','offense','attack_modifier'),
    ('effect/offense/cleave','offense','cleave'),
    ('effect/offense/critical_extra_damage','offense','critical_extra_damage'),
    ('effect/offense/critical_hit_chance','offense','critical_hit_chance'),
    ('effect/offense/hit_modifier','offense','hit_modifier'),
    ('effect/offense/perfect_shot','offense','perfect_shot')
  ) x(k,effect_type,effect_key)
),
utility_dims as (
  select d.k,
         coalesce((
           select sum(ie.numeric_value)
           from item_effects ie
           join item i2 on i2.item_id=ie.item_id
           where ie.effect_type=d.effect_type
             and ie.effect_key=d.effect_key
         ),0)::numeric as v
  from directional_effect_keys d
),
protection_dims as (
  select 'protection/'||oe.element as k,
         coalesce((
           select sum(ie.numeric_value)
           from item_effects ie
           join item i2 on i2.item_id=ie.item_id
           where ie.effect_type='protection'
             and ie.effect_key=oe.element
         ),0)::numeric as v
  from observed_elements oe
),
dims as (
  select * from core_dims
  union all select * from attack_dims
  union all select * from skill_dims
  union all select * from utility_dims
  union all select * from protection_dims
),
dimension_json as (
  select coalesce(jsonb_object_agg(k,v order by k),'{}'::jsonb) as j
  from dims
)
select coalesce((
  select jsonb_build_object(
    'item',jsonb_build_object(
      'item_key',i.item_key,'name',i.name,'item_domain',i.item_domain,
      'item_family',i.item_family,'slot_key',i.slot_key
    ),
    'dimensions',(select j from dimension_json),
    'dimension_count',(select count(*) from dims),
    'direction','higher_is_better',
    'excluded_from_dominance',jsonb_build_array(
      'special effects without universal direction',
      'Weapon Proficiency perks unless explicitly activated',
      'community usage frequency',
      'price/economy',
      'final DPS/healing'
    ),
    'methodology',jsonb_build_object(
      'stage','optimizer_item_vector_universal_v1',
      'category_first',true,
      'cross_metric_sum_applied',false,
      'observed_hunt_elements_only_for_protection',true,
      'absent_listed_effect_means_zero',true,
      'unknown_core_value_imputed',false
    )
  )
  from item i
),jsonb_build_object(
  'error','item_not_found',
  'item_key',p_item_key,
  'methodology',jsonb_build_object('stage','optimizer_item_vector_universal_v1')
));
$function$;

revoke all on function public.huntnexus_optimizer_item_vector_universal(text,text,text)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_item_vector_universal(text,text,text)
to service_role;
