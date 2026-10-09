-- HuntNexus — universal factual weapon attribute vectors and comparison.
-- Dimensions remain separated by scope/metric/unit. No score or winner is inferred.

CREATE OR REPLACE FUNCTION public.huntnexus_weapon_attribute_vector(p_item_key text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with w as (
  select *
  from vw_weapon_catalog_universal
  where item_key=p_item_key
),
core_metrics as (
  select metric_key,scope,metric,unit,value
  from w
  cross join lateral (
    values
      ('core/base_attack/points'::text,'core'::text,'base_attack'::text,'points'::text,base_attack::numeric),
      ('core/defense/points','core','defense','points',defense::numeric),
      ('core/defense_mod/points','core','defense_mod','points',defense_mod::numeric),
      ('core/range/tiles','core','range','tiles',range_value::numeric),
      ('core/imbue_slots/slots','core','imbue_slots','slots',imbue_slots::numeric)
  ) v(metric_key,scope,metric,unit,value)
  where value is not null
),
attack_metrics as (
  select
    'attack_component/'||e.key||'/points' as metric_key,
    'attack_component'::text as scope,
    e.key as metric,
    'points'::text as unit,
    (e.value #>> '{}')::numeric as value
  from w
  cross join lateral jsonb_each(attack_components) e
  where jsonb_typeof(e.value)='number'
),
effect_metrics as (
  select
    'effect/'||ie.effect_type||'/'||ie.effect_key||'/'||coalesce(nullif(ie.unit,''),'unknown') as metric_key,
    'effect/'||ie.effect_type as scope,
    ie.effect_key as metric,
    coalesce(nullif(ie.unit,''),'unknown') as unit,
    sum(ie.numeric_value)::numeric as value
  from w
  join item_effects ie on ie.item_id=w.item_id
  where ie.numeric_value is not null
  group by ie.effect_type,ie.effect_key,coalesce(nullif(ie.unit,''),'unknown')
),
metrics as (
  select * from core_metrics
  union all
  select * from attack_metrics
  union all
  select * from effect_metrics
)
select coalesce((
  select jsonb_build_object(
    'item',jsonb_build_object(
      'item_key',w.item_key,
      'name',w.name,
      'weapon_class',w.weapon_class,
      'weapon_family',w.weapon_family,
      'primary_skill_key',w.primary_skill_key,
      'hands',w.hands,
      'level_required',w.level_required,
      'vocation_scope',w.vocation_scope,
      'vocation_keys',to_jsonb(w.vocation_keys),
      'damage_type',w.damage_type
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
    'coverage',jsonb_build_object(
      'proficiency_tree_available',w.proficiency_tree_available,
      'proficiency_perk_count',w.proficiency_perk_count
    ),
    'methodology',jsonb_build_object(
      'stage','weapon_attribute_vector_v1',
      'combat_formula_applied',false,
      'cross_metric_sum_applied',false,
      'higher_is_better_inferred',false,
      'raw_fact_vector_only',true
    )
  )
  from w
),jsonb_build_object(
  'error','weapon_not_found',
  'item_key',p_item_key,
  'methodology',jsonb_build_object(
    'stage','weapon_attribute_vector_v1',
    'combat_formula_applied',false
  )
));
$function$
;

revoke all on function public.huntnexus_weapon_attribute_vector(text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_weapon_attribute_vector(text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_compare_weapons_universal(p_item_keys jsonb)
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
  select i.item_key,huntnexus_weapon_attribute_vector(i.item_key) as vector
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
    where vector->>'error'='weapon_not_found'
  ),'[]'::jsonb),
  'comparison',jsonb_build_object(
    'item_count',(select n from item_count),
    'same_weapon_class',coalesce((
      select count(distinct vector #>> '{item,weapon_class}')=1 from valid
    ),false),
    'same_weapon_family',coalesce((
      select count(distinct vector #>> '{item,weapon_family}')=1 from valid
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
    'stage','weapon_comparison_universal_v1',
    'category_first',true,
    'combat_score_applied',false,
    'winner_selected',false,
    'pareto_applied',false,
    'cross_metric_sum_applied',false,
    'missing_values_imputed',false,
    'note','Dimensions remain separate by scope, metric and unit. Missing values remain missing; no final winner or combat score is inferred.'
  )
);
$function$
;

revoke all on function public.huntnexus_compare_weapons_universal(jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_compare_weapons_universal(jsonb)
  to service_role;
