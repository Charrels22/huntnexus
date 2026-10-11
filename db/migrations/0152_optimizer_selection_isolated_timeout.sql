-- PERF-05: Isolate the expensive, user-triggered universal setup call.
-- The regular PostgREST request timeout is 8s. Full candidate enumeration
-- runs around 10s for EK700/Cobra Bastion at 100 sets even after PERF-01..04.
-- This extends only this explicitly triggered RPC, NOT all public API calls.
-- Source: https://supabase.com/docs/guides/database/postgres/timeouts#function-level
-- Candidate limits and all structural Pareto constraints remain unchanged.
CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_set_selection_universal(p_hunt_key text, p_vocation text, p_level integer, p_set_objective text DEFAULT 'balanced'::text, p_hand_per_source integer DEFAULT 3, p_per_body_slot integer DEFAULT 2, p_set_limit integer DEFAULT 200, p_frontier_limit integer DEFAULT 200, p_selection_limit integer DEFAULT 50, p_proficiency_selections jsonb DEFAULT '{}'::jsonb, p_character_profile jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
 SET statement_timeout TO '25s'
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
$function$;

revoke all on function public.huntnexus_optimizer_set_selection_universal(
  text,text,integer,text,integer,integer,integer,integer,integer,jsonb,jsonb
) from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_set_selection_universal(
  text,text,integer,text,integer,integer,integer,integer,integer,jsonb,jsonb
) to service_role;
