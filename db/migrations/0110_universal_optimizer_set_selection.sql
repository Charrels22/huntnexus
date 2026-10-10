-- HuntNexus — objective-aware selection over the universal set Pareto frontier.
-- Set objectives are independent from hunt xp/profit objectives.
-- No weighted score, no cross-category sum, and no forced single winner.

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_set_selection_universal(p_hunt_key text, p_vocation text, p_level integer, p_set_objective text DEFAULT 'balanced'::text, p_hand_per_source integer DEFAULT 3, p_per_body_slot integer DEFAULT 2, p_set_limit integer DEFAULT 200, p_frontier_limit integer DEFAULT 200, p_selection_limit integer DEFAULT 50, p_proficiency_selections jsonb DEFAULT '{}'::jsonb, p_character_profile jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    case lower(trim(coalesce(p_set_objective,'balanced')))
      when 'offense' then 'offense'
      when 'defense' then 'defense'
      when 'sustain' then 'sustain'
      when 'utility' then 'utility'
      else 'balanced'
    end as objective,
    least(greatest(coalesce(p_selection_limit,50),1),200) as selection_limit
),
base as (
  select huntnexus_optimizer_set_frontier_universal(
    p_hunt_key,p_vocation,p_level,p_hand_per_source,p_per_body_slot,p_set_limit,
    p_frontier_limit,p_proficiency_selections,p_character_profile
  ) as j
),
sets as (
  select
    (x->>'set_order')::int as set_order,
    x as set_json,
    x #> '{set_vector,comparison_key}' as comparison_key,
    x #> '{set_vector,dimensions}' as all_dims,
    coalesce((x #>> '{set_vector,comparison_ready}')::boolean,false) as comparison_ready
  from base
  cross join lateral jsonb_array_elements(coalesce(j->'frontier','[]'::jsonb)) x
),
objective_dims as (
  select
    s.set_order,
    coalesce(jsonb_object_agg(d.key,d.value order by d.key)
      filter (
        where
          (select objective from p)='balanced'
          or (
            (select objective from p)='offense'
            and (
              d.key like '%/attack/%'
              or d.key like '%/effect/offense/%'
              or d.key like 'effect/skill/%'
              or (
                d.key like 'proficiency/%'
                and (
                  d.key ilike '%attack%'
                  or d.key ilike '%damage%'
                  or d.key ilike '%critical%'
                  or d.key ilike '%skill%'
                )
              )
            )
          )
          or (
            (select objective from p)='defense'
            and (
              d.key='core/armor'
              or d.key like '%/core/defense%'
              or d.key like '%/protection/%'
              or d.key like '%/effect/defense/%'
            )
          )
          or (
            (select objective from p)='sustain'
            and (
              d.key like '%/effect/leech/%'
              or d.key ilike 'proficiency/%leech%'
              or d.key ilike 'proficiency/%healing%'
            )
          )
          or (
            (select objective from p)='utility'
            and (
              d.key='core/imbue_slots'
              or d.key like '%/effect/movement/%'
            )
          )
      ),
      '{}'::jsonb
    ) as dims
  from sets s
  cross join lateral jsonb_each(s.all_dims) d
  group by s.set_order
),
prepared as (
  select
    s.*,
    o.dims,
    array(select k from jsonb_object_keys(o.dims) k order by k) as dim_keys,
    exists(select 1 from jsonb_object_keys(o.dims)) as objective_dimensions_available,
    (select count(*) from jsonb_object_keys(o.dims))::int as objective_dimension_count
  from sets s
  join objective_dims o using(set_order)
),
dominance as (
  select
    b.set_order as dominated_set_order,
    a.set_order as dominator_set_order
  from prepared a
  join prepared b
    on a.set_order<>b.set_order
   and a.comparison_ready
   and b.comparison_ready
   and a.objective_dimensions_available
   and b.objective_dimensions_available
   and a.comparison_key=b.comparison_key
   and a.dim_keys=b.dim_keys
  where (select objective from p)<>'balanced'
    and not exists (
      select 1
      from jsonb_each_text(b.dims) bd
      join jsonb_each_text(a.dims) ad on ad.key=bd.key
      where ad.value::numeric < bd.value::numeric
    )
    and exists (
      select 1
      from jsonb_each_text(b.dims) bd
      join jsonb_each_text(a.dims) ad on ad.key=bd.key
      where ad.value::numeric > bd.value::numeric
    )
),
selected as (
  select pp.*
  from prepared pp
  where (select objective from p)='balanced'
     or not exists(
       select 1 from dominance d where d.dominated_set_order=pp.set_order
     )
),
limited as (
  select *
  from selected
  order by set_order
  limit (select selection_limit from p)
)
select case
  when (select j ? 'error' from base) then (select j from base)
  else jsonb_build_object(
    'query',jsonb_build_object(
      'hunt_key',p_hunt_key,
      'vocation',huntnexus_normalize_vocation(p_vocation),
      'level',greatest(coalesce(p_level,1),1),
      'set_objective',(select objective from p),
      'selection_limit',(select selection_limit from p)
    ),
    'source_summary',(select j->'summary' from base),
    'summary',jsonb_build_object(
      'frontier_sets_considered',(select count(*) from prepared),
      'sets_with_objective_dimensions',(select count(*) from prepared where objective_dimensions_available),
      'objective_dominated_sets',(select count(distinct dominated_set_order) from dominance),
      'co_winners',(select count(*) from selected),
      'returned',(select count(*) from limited),
      'truncated',(select count(*) from selected)>(select selection_limit from p)
    ),
    'selected_sets',coalesce((
      select jsonb_agg(
        l.set_json || jsonb_build_object(
          'selection_policy',jsonb_build_object(
            'set_objective',(select objective from p),
            'objective_dimensions',l.dims,
            'objective_dimension_count',l.objective_dimension_count,
            'dominates_count',(
              select count(distinct d.dominated_set_order)
              from dominance d
              where d.dominator_set_order=l.set_order
            )
          )
        )
        order by l.set_order
      )
      from limited l
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','optimizer_set_selection_universal_v1',
      'source_is_set_pareto_frontier',true,
      'objective_filter_only',true,
      'objective_dimensions_not_summed',true,
      'objective_dimensions_not_weighted',true,
      'same_structural_comparison_key_required',true,
      'balanced_means_preserve_universal_frontier',true,
      'xp_profit_not_inferred_from_loadout',true,
      'single_winner_forced',false,
      'co_winners_allowed',true,
      'winner_selected',(select count(*) from selected)>0,
      'final_optimizer_applied',false
    )
  )
end;
$function$
;

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_audit()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select jsonb_build_object(
  'summary',jsonb_build_object(
    'weapon_contract_ready',
      coalesce((huntnexus_slot_compatibility_audit() #>> '{summary,weapon_offhand_dependency_ready}')::boolean,false),
    'equipment_contract_ready',
      coalesce((huntnexus_vocation_composition_audit() #>> '{summary,equipment_slot_summary_ready}')::boolean,false),
    'imbuement_contract_ready',
      coalesce((huntnexus_imbuement_category_audit() #>> '{summary,defensive_hunt_context_ready}')::boolean,false),
    'effect_contract_ready',
      coalesce((huntnexus_effect_category_audit() #>> '{summary,hunt_protection_alignment_ready}')::boolean,false),
    'slot_contract_ready',
      coalesce((huntnexus_slot_compatibility_audit() #>> '{summary,slot_contract_ready}')::boolean,false),
    'spell_contract_ready',
      coalesce((huntnexus_spell_category_audit() #>> '{summary,special_unlock_rules_ready}')::boolean,false),
    'vocation_contract_ready',
      coalesce((huntnexus_vocation_composition_audit() #>> '{summary,profile_contract_ready}')::boolean,false),
    'candidate_envelope_ready',true,
    'item_vector_ready',true,
    'pareto_frontier_ready',true,
    'frontier_envelope_ready',true,
    'hand_package_generation_ready',true,
    'concrete_set_generation_ready',true,
    'set_validation_ready',true,
    'proficiency_context_ready',true,
    'set_vector_ready',true,
    'set_frontier_ready',true,
    'set_selection_ready',true,
    'final_optimizer_ready',false
  ),
  'known_blockers',jsonb_build_array(
    jsonb_build_object(
      'key','hunt_and_set_objective_composition',
      'status','next',
      'note','Hunt objectives (xp/profit/balanced) and loadout objectives (offense/defense/sustain/utility/balanced) are intentionally separate and still need a final orchestration envelope.'
    ),
    jsonb_build_object(
      'key','cross_type_imbuement_priority',
      'status','pending',
      'note','Defensive Imbuement context is ready; offense/sustain/skill Imbuements remain unranked across types.'
    ),
    jsonb_build_object(
      'key','final_formula',
      'status','pending',
      'note','No invented DPS/healing or universal cross-metric scalar is allowed.'
    )
  ),
  'methodology',jsonb_build_object(
    'stage','optimizer_audit_v6',
    'category_first',true,
    'legacy_ek_optimizer_not_used_as_universal_selector',true,
    'cross_metric_score_applied',false,
    'pareto_only_for_item_pruning',true,
    'concrete_sets_universally_validated',true,
    'proficiency_item_key_binding_required',true,
    'proficiency_selection_inheritance_applied',false,
    'set_pareto_frontier_applied',true,
    'set_objective_selection_applied',true,
    'set_objective_weights_applied',false,
    'xp_profit_not_inferred_from_loadout',true,
    'protection_stacking_formula_applied',false
  )
);
$function$
;

revoke all on function public.huntnexus_optimizer_set_selection_universal(
  text,text,integer,text,integer,integer,integer,integer,integer,jsonb,jsonb
) from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_set_selection_universal(
  text,text,integer,text,integer,integer,integer,integer,integer,jsonb,jsonb
) to service_role;

revoke all on function public.huntnexus_optimizer_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_audit()
to service_role;
