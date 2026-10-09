-- HuntNexus — universal equipment fact vectors and comparison.
-- Keeps armor/defense/protection/skill/ML/speed/leech/special effects separate.
-- No combat score, winner or higher-is-better inference.

CREATE OR REPLACE FUNCTION public.huntnexus_equipment_attribute_vector(p_item_key text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with e as (
  select *
  from vw_equipment_catalog_universal
  where item_key=p_item_key
),
core_metrics as (
  select metric_key,scope,metric,unit,value
  from e
  cross join lateral (
    values
      ('core/armor/points'::text,'core'::text,'armor'::text,'points'::text,armor::numeric),
      ('core/defense/points','core','defense','points',defense::numeric),
      ('core/defense_mod/points','core','defense_mod','points',defense_mod::numeric),
      ('core/imbue_slots/slots','core','imbue_slots','slots',imbue_slots::numeric)
  ) v(metric_key,scope,metric,unit,value)
  where value is not null
),
effect_metrics as (
  select
    'effect/'||ie.effect_type||'/'||ie.effect_key||'/'||coalesce(nullif(ie.unit,''),'unknown') as metric_key,
    'effect/'||ie.effect_type as scope,
    ie.effect_key as metric,
    coalesce(nullif(ie.unit,''),'unknown') as unit,
    sum(ie.numeric_value)::numeric as value
  from e
  join item_effects ie on ie.item_id=e.item_id
  where ie.numeric_value is not null
  group by ie.effect_type,ie.effect_key,coalesce(nullif(ie.unit,''),'unknown')
),
metrics as (
  select * from core_metrics
  union all
  select * from effect_metrics
),
protection_profile as (
  select coalesce(jsonb_object_agg(effect_key,numeric_value order by effect_key),'{}'::jsonb) as j
  from (
    select ie.effect_key,sum(ie.numeric_value)::numeric as numeric_value
    from e
    join item_effects ie on ie.item_id=e.item_id
    where ie.effect_type='protection' and ie.numeric_value is not null
    group by ie.effect_key
  ) x
),
skill_profile as (
  select coalesce(jsonb_object_agg(effect_key,numeric_value order by effect_key),'{}'::jsonb) as j
  from (
    select ie.effect_key,sum(ie.numeric_value)::numeric as numeric_value
    from e
    join item_effects ie on ie.item_id=e.item_id
    where ie.effect_type='skill' and ie.numeric_value is not null
    group by ie.effect_key
  ) x
),
magic_profile as (
  select coalesce(jsonb_object_agg(effect_key,numeric_value order by effect_key),'{}'::jsonb) as j
  from (
    select ie.effect_key,sum(ie.numeric_value)::numeric as numeric_value
    from e
    join item_effects ie on ie.item_id=e.item_id
    where ie.effect_type='magic_skill' and ie.numeric_value is not null
    group by ie.effect_key
  ) x
)
select coalesce((
  select jsonb_build_object(
    'item',jsonb_build_object(
      'item_key',e.item_key,
      'name',e.name,
      'slot_key',e.slot_key,
      'equipment_family',e.equipment_family,
      'level_required',e.level_required,
      'vocation_scope',e.vocation_scope,
      'vocation_keys',to_jsonb(e.vocation_keys),
      'combat_relevance',e.combat_relevance
    ),
    'metrics',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'metric_key',m.metric_key,
          'scope',m.scope,
          'metric',m.metric,
          'unit',m.unit,
          'value',m.value
        )
        order by m.metric_key
      )
      from metrics m
    ),'[]'::jsonb),
    'profiles',jsonb_build_object(
      'protection',(select j from protection_profile),
      'skill',(select j from skill_profile),
      'magic_skill',(select j from magic_profile)
    ),
    'methodology',jsonb_build_object(
      'stage','equipment_attribute_vector_v1',
      'combat_formula_applied',false,
      'cross_metric_sum_applied',false,
      'higher_is_better_inferred',false,
      'missing_values_imputed',false,
      'raw_fact_vector_only',true
    )
  )
  from e
),jsonb_build_object(
  'error','equipment_not_found',
  'item_key',p_item_key,
  'methodology',jsonb_build_object(
    'stage','equipment_attribute_vector_v1',
    'combat_formula_applied',false
  )
));
$function$
;

revoke all on function public.huntnexus_equipment_attribute_vector(text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_equipment_attribute_vector(text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_compare_equipment_universal(p_item_keys jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with input as (
  select distinct value as item_key
  from jsonb_array_elements_text(
    case when jsonb_typeof(coalesce(p_item_keys,'[]'::jsonb))='array'
      then coalesce(p_item_keys,'[]'::jsonb)
      else '[]'::jsonb
    end
  )
  where value <> ''
  limit 10
),
vectors as (
  select i.item_key,huntnexus_equipment_attribute_vector(i.item_key) as vector
  from input i
),
valid as (
  select *
  from vectors
  where vector->>'error' is null
),
item_count as (
  select count(*)::int as n from valid
),
metric_rows as (
  select
    v.item_key,
    m->>'metric_key' as metric_key,
    m->>'scope' as scope,
    m->>'metric' as metric,
    m->>'unit' as unit,
    (m->>'value')::numeric as value
  from valid v
  cross join lateral jsonb_array_elements(v.vector->'metrics') m
),
dimension_keys as (
  select distinct metric_key,scope,metric,unit
  from metric_rows
),
dimensions as (
  select
    d.metric_key,d.scope,d.metric,d.unit,
    jsonb_object_agg(v.item_key,to_jsonb(m.value) order by v.item_key) as values_by_item,
    count(m.value)::int as coverage_count,
    (select n from item_count)-count(m.value)::int as missing_count
  from dimension_keys d
  cross join valid v
  left join metric_rows m
    on m.item_key=v.item_key and m.metric_key=d.metric_key
  group by d.metric_key,d.scope,d.metric,d.unit
)
select jsonb_build_object(
  'items',coalesce((
    select jsonb_agg(vector order by item_key) from valid
  ),'[]'::jsonb),
  'not_found',coalesce((
    select jsonb_agg(item_key order by item_key)
    from vectors
    where vector->>'error'='equipment_not_found'
  ),'[]'::jsonb),
  'comparison',jsonb_build_object(
    'item_count',(select n from item_count),
    'same_slot',coalesce((
      select count(distinct vector #>> '{item,slot_key}')=1 from valid
    ),false),
    'same_equipment_family',coalesce((
      select count(distinct vector #>> '{item,equipment_family}')=1 from valid
    ),false),
    'dimensions',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'metric_key',metric_key,
          'scope',scope,
          'metric',metric,
          'unit',unit,
          'values_by_item',values_by_item,
          'coverage_count',coverage_count,
          'missing_count',missing_count,
          'full_coverage',missing_count=0
        )
        order by metric_key
      )
      from dimensions
    ),'[]'::jsonb)
  ),
  'methodology',jsonb_build_object(
    'stage','equipment_comparison_universal_v1',
    'category_first',true,
    'combat_score_applied',false,
    'winner_selected',false,
    'pareto_applied',false,
    'cross_metric_sum_applied',false,
    'missing_values_imputed',false,
    'higher_is_better_inferred',false,
    'note','Armor, defense, protections, skills, magic skills, movement, leech and special effects remain separate dimensions. Missing values are not treated as zero.'
  )
);
$function$
;

revoke all on function public.huntnexus_compare_equipment_universal(jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_compare_equipment_universal(jsonb)
  to service_role;
