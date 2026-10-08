-- HuntNexus — contextual EK one-hand vs two-hand comparison.
-- Combines factual hunt dimensions with explicitly selected proficiency effects.
-- No weighted score or ranking mutation is allowed.

CREATE OR REPLACE FUNCTION public.huntnexus_ek_hand_context_comparison(p_hunt_key text, p_level integer, p_character_profile jsonb, p_one_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_two_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_effective_magic_level integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with h as (
  select huntnexus_ek_hand_options_profiled(
    p_hunt_key,
    greatest(coalesce(p_level,1),1),
    coalesce(p_character_profile,'{}'::jsonb),
    5
  ) as j
),
p as (
  select huntnexus_ek_proficiency_impact_comparison(
    p_character_profile->>'weapon_family',
    coalesce(p_one_hand_active_perk_orders,'[]'::jsonb),
    coalesce(p_two_hand_active_perk_orders,'[]'::jsonb),
    huntnexus_first_int(p_character_profile->>'effective_weapon_skill'),
    coalesce(
      p_effective_magic_level,
      huntnexus_first_int(p_character_profile->>'effective_magic_level')
    )
  ) as j
),
state as (
  select
    h.j as hand_json,
    p.j as prof_json,
    h.j #>> '{one_handed,offense_options,0,weapon,item_key}' as one_item_key,
    h.j #>> '{two_handed,offense_options,0,item_key}' as two_item_key,
    p.j #>> '{one_handed,item_key}' as prof_one_item_key,
    p.j #>> '{two_handed,item_key}' as prof_two_item_key,
    jsonb_array_length(
      case when jsonb_typeof(coalesce(p_one_hand_active_perk_orders,'[]'::jsonb))='array'
        then coalesce(p_one_hand_active_perk_orders,'[]'::jsonb)
        else '[]'::jsonb end
    ) > 0 as one_explicit,
    jsonb_array_length(
      case when jsonb_typeof(coalesce(p_two_hand_active_perk_orders,'[]'::jsonb))='array'
        then coalesce(p_two_hand_active_perk_orders,'[]'::jsonb)
        else '[]'::jsonb end
    ) > 0 as two_explicit
  from h,p
),
flags as (
  select *,
    one_item_key is not null and one_item_key=prof_one_item_key as one_prof_matches,
    two_item_key is not null and two_item_key=prof_two_item_key as two_prof_matches,
    one_explicit and two_explicit
      and one_item_key is not null and one_item_key=prof_one_item_key
      and two_item_key is not null and two_item_key=prof_two_item_key
      as extended_comparison_ready
  from state
),
base_values as (
  select
    'effective_attack_proxy'::text as metric_key,
    'base'::text as scope,
    null::text as spell_key,
    (hand_json #>> '{one_handed,offense_options,0,weapon,effective_attack_proxy}')::numeric as one_value,
    (hand_json #>> '{two_handed,offense_options,0,effective_attack_proxy}')::numeric as two_value,
    'proxy'::text as unit
  from flags
  union all
  select
    'candidate_item_skill_bonus','base',null,
    (hand_json #>> '{one_handed,offense_options,0,matching_weapon_skill_bonus}')::numeric,
    (hand_json #>> '{two_handed,offense_options,0,weapon_skill_bonus}')::numeric,
    'flat'
  from flags
  union all
  select
    'weighted_protection','base',null,
    (hand_json #>> '{one_handed,offense_options,0,weighted_protection}')::numeric,
    (hand_json #>> '{two_handed,offense_options,0,weighted_protection}')::numeric,
    'weighted_percent'
  from flags
  union all
  select
    'imbue_capacity','base',null,
    (hand_json #>> '{one_handed,offense_options,0,imbue_capacity}')::numeric,
    (hand_json #>> '{two_handed,offense_options,0,imbue_capacity}')::numeric,
    'slots'
  from flags
),
one_effects as (
  select
    e->>'scope' as scope,
    e->>'effect_family' as effect_family,
    e->>'spell_key' as spell_key,
    e->>'source_stat_key' as source_stat_key,
    case
      when e->>'derived_stat_contribution' is not null
        then (e->>'derived_stat_contribution')::numeric
      else (e->>'value')::numeric
    end as comparison_value,
    case
      when e->>'derived_stat_contribution' is not null then 'derived_stat_term'
      else coalesce(e->>'unit','number')
    end as comparison_unit
  from flags f
  cross join lateral jsonb_array_elements(
    case when f.one_prof_matches
      then coalesce(f.prof_json #> '{one_handed,resolved_effects}','[]'::jsonb)
      else '[]'::jsonb end
  ) e
),
two_effects as (
  select
    e->>'scope' as scope,
    e->>'effect_family' as effect_family,
    e->>'spell_key' as spell_key,
    e->>'source_stat_key' as source_stat_key,
    case
      when e->>'derived_stat_contribution' is not null
        then (e->>'derived_stat_contribution')::numeric
      else (e->>'value')::numeric
    end as comparison_value,
    case
      when e->>'derived_stat_contribution' is not null then 'derived_stat_term'
      else coalesce(e->>'unit','number')
    end as comparison_unit
  from flags f
  cross join lateral jsonb_array_elements(
    case when f.two_prof_matches
      then coalesce(f.prof_json #> '{two_handed,resolved_effects}','[]'::jsonb)
      else '[]'::jsonb end
  ) e
),
one_grouped as (
  select scope,effect_family,spell_key,source_stat_key,comparison_unit,
         sum(comparison_value) as one_value
  from one_effects
  group by scope,effect_family,spell_key,source_stat_key,comparison_unit
),
two_grouped as (
  select scope,effect_family,spell_key,source_stat_key,comparison_unit,
         sum(comparison_value) as two_value
  from two_effects
  group by scope,effect_family,spell_key,source_stat_key,comparison_unit
),
effect_values as (
  select
    'proficiency/' ||
      coalesce(o.scope,t.scope,'global') || '/' ||
      coalesce(o.effect_family,t.effect_family,'unknown') ||
      case when coalesce(o.spell_key,t.spell_key) is not null
        then '/'||coalesce(o.spell_key,t.spell_key)
        else '' end ||
      case when coalesce(o.source_stat_key,t.source_stat_key) is not null
        then '/'||coalesce(o.source_stat_key,t.source_stat_key)
        else '' end as metric_key,
    coalesce(o.scope,t.scope,'global') as scope,
    coalesce(o.spell_key,t.spell_key) as spell_key,
    coalesce(o.one_value,0)::numeric as one_value,
    coalesce(t.two_value,0)::numeric as two_value,
    coalesce(o.comparison_unit,t.comparison_unit,'number') as unit
  from one_grouped o
  full join two_grouped t
    on coalesce(o.scope,'')=coalesce(t.scope,'')
   and coalesce(o.effect_family,'')=coalesce(t.effect_family,'')
   and coalesce(o.spell_key,'')=coalesce(t.spell_key,'')
   and coalesce(o.source_stat_key,'')=coalesce(t.source_stat_key,'')
   and coalesce(o.comparison_unit,'')=coalesce(t.comparison_unit,'')
),
all_metrics as (
  select * from base_values
  union all
  select e.*
  from effect_values e
  cross join flags f
  where f.extended_comparison_ready
),
summary as (
  select
    count(*) filter(where one_value is not null and two_value is not null) as comparable_dimensions,
    count(*) filter(where one_value>two_value) as one_better,
    count(*) filter(where two_value>one_value) as two_better,
    count(*) filter(where one_value=two_value) as ties,
    bool_and(one_value>=two_value) filter(where one_value is not null and two_value is not null) as one_ge_all,
    bool_or(one_value>two_value) filter(where one_value is not null and two_value is not null) as one_gt_any,
    bool_and(two_value>=one_value) filter(where one_value is not null and two_value is not null) as two_ge_all,
    bool_or(two_value>one_value) filter(where one_value is not null and two_value is not null) as two_gt_any
  from all_metrics
),
resolved as (
  select case
    when coalesce(one_ge_all,false) and coalesce(one_gt_any,false) then 'one_handed'
    when coalesce(two_ge_all,false) and coalesce(two_gt_any,false) then 'two_handed'
    else null
  end as contextual_pareto_dominance
  from summary
)
select jsonb_build_object(
  'hunt_key',p_hunt_key,
  'level',greatest(coalesce(p_level,1),1),
  'weapon_family',p_character_profile->>'weapon_family',
  'profile',jsonb_strip_nulls(jsonb_build_object(
    'effective_weapon_skill',huntnexus_first_int(p_character_profile->>'effective_weapon_skill'),
    'effective_magic_level',coalesce(
      p_effective_magic_level,
      huntnexus_first_int(p_character_profile->>'effective_magic_level')
    ),
    'effective_shielding',huntnexus_first_int(p_character_profile->>'effective_shielding')
  )),
  'one_handed',jsonb_build_object(
    'item_key',(select one_item_key from flags),
    'weapon_name',(select hand_json #>> '{one_handed,offense_options,0,weapon,name}' from flags),
    'offhand_name',(select hand_json #>> '{one_handed,offense_options,0,off_hand,name}' from flags),
    'base_vector',jsonb_build_object(
      'effective_attack_proxy',(select (hand_json #>> '{one_handed,offense_options,0,weapon,effective_attack_proxy}')::numeric from flags),
      'candidate_item_skill_bonus',(select (hand_json #>> '{one_handed,offense_options,0,matching_weapon_skill_bonus}')::numeric from flags),
      'displayed_effective_weapon_skill',(select (hand_json #>> '{one_handed,offense_options,0,displayed_effective_weapon_skill}')::numeric from flags),
      'weighted_protection',(select (hand_json #>> '{one_handed,offense_options,0,weighted_protection}')::numeric from flags),
      'imbue_capacity',(select (hand_json #>> '{one_handed,offense_options,0,imbue_capacity}')::numeric from flags),
      'effective_shielding_context',(select (hand_json #>> '{one_handed,offense_options,0,effective_shielding_with_offhand}')::numeric from flags)
    ),
    'proficiency_item_matches',(select one_prof_matches from flags),
    'proficiency_explicit_selection',(select one_explicit from flags),
    'proficiency_impact',
      case when (select one_prof_matches from flags)
        then (select prof_json->'one_handed' from flags)
        else null end
  ),
  'two_handed',jsonb_build_object(
    'item_key',(select two_item_key from flags),
    'weapon_name',(select hand_json #>> '{two_handed,offense_options,0,name}' from flags),
    'base_vector',jsonb_build_object(
      'effective_attack_proxy',(select (hand_json #>> '{two_handed,offense_options,0,effective_attack_proxy}')::numeric from flags),
      'candidate_item_skill_bonus',(select (hand_json #>> '{two_handed,offense_options,0,weapon_skill_bonus}')::numeric from flags),
      'displayed_effective_weapon_skill',(select (hand_json #>> '{two_handed,offense_options,0,displayed_effective_weapon_skill}')::numeric from flags),
      'weighted_protection',(select (hand_json #>> '{two_handed,offense_options,0,weighted_protection}')::numeric from flags),
      'imbue_capacity',(select (hand_json #>> '{two_handed,offense_options,0,imbue_capacity}')::numeric from flags)
    ),
    'proficiency_item_matches',(select two_prof_matches from flags),
    'proficiency_explicit_selection',(select two_explicit from flags),
    'proficiency_impact',
      case when (select two_prof_matches from flags)
        then (select prof_json->'two_handed' from flags)
        else null end
  ),
  'comparison',jsonb_build_object(
    'status',case
      when not (select one_prof_matches and two_prof_matches from flags)
        then 'proficiency_weapon_mismatch'
      when not (select one_explicit or two_explicit from flags)
        then 'base_only_reference'
      when not (select one_explicit and two_explicit from flags)
        then 'partial_proficiency_selection'
      else 'explicit_proficiency_selection'
    end,
    'extended_comparison_ready',(select extended_comparison_ready from flags),
    'base_pareto_dominance',(select hand_json #>> '{comparison,resolved_configuration}' from flags),
    'contextual_pareto_dominance',(select contextual_pareto_dominance from resolved),
    'dimensions',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'metric_key',metric_key,
          'scope',scope,
          'spell_key',spell_key,
          'unit',unit,
          'one_handed',one_value,
          'two_handed',two_value,
          'delta_two_minus_one',
            case when one_value is not null and two_value is not null
              then round(two_value-one_value,3)
              else null end,
          'better',case
            when one_value is null or two_value is null then 'not_comparable'
            when one_value>two_value then 'one_handed'
            when two_value>one_value then 'two_handed'
            else 'tie'
          end
        )
        order by
          case when scope='base' then 0 else 1 end,
          metric_key
      )
      from all_metrics
    ),'[]'::jsonb),
    'dimension_summary',(
      select jsonb_build_object(
        'comparable_dimensions',comparable_dimensions,
        'one_handed_better',one_better,
        'two_handed_better',two_better,
        'ties',ties
      )
      from summary
    )
  ),
  'methodology',jsonb_build_object(
    'stage','ek_hand_context_comparison_v1',
    'optimizer_effect_applied',false,
    'ranking_changed',false,
    'hand_choice_changed',false,
    'score_combined',false,
    'pareto_only',true,
    'higher_is_better_per_dimension',true,
    'mixed_scopes_not_summed',true,
    'note','Base hunt dimensions and explicitly selected proficiency effects are compared dimension by dimension. No weighted score is produced. Proficiency effects are used only when the proficiency weapon matches the actual best candidate for that hand configuration.'
  )
);
$function$
;

revoke all on function public.huntnexus_ek_hand_context_comparison(text,integer,jsonb,jsonb,jsonb,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_ek_hand_context_comparison(text,integer,jsonb,jsonb,jsonb,integer)
  to service_role;
