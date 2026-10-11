-- PERF-04: identical per-item Weapon Proficiency selections and character
-- stats are evaluated once per unique weapon, never once per set.
-- This retains item_key isolation, unmodified set order and all summaries.
CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_concrete_sets_with_proficiency_universal(
  p_hunt_key text,
  p_vocation text,
  p_level integer,
  p_hand_per_source integer DEFAULT 3,
  p_per_body_slot integer DEFAULT 2,
  p_set_limit integer DEFAULT 200,
  p_proficiency_selections jsonb DEFAULT '{}'::jsonb,
  p_character_profile jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO 'public', 'extensions'
AS $function$
with base as (
  select huntnexus_optimizer_concrete_sets_universal(
    p_hunt_key,p_vocation,p_level,p_hand_per_source,p_per_body_slot,p_set_limit
  ) as j
),
profile as (
  select
    huntnexus_first_int(coalesce(p_character_profile,'{}'::jsonb)->>'effective_weapon_skill') as effective_weapon_skill,
    huntnexus_first_int(coalesce(p_character_profile,'{}'::jsonb)->>'effective_magic_level') as effective_magic_level,
    case
      when jsonb_typeof(coalesce(p_proficiency_selections,'{}'::jsonb))='object'
        then coalesce(p_proficiency_selections,'{}'::jsonb)
      else '{}'::jsonb
    end as selections
),
expanded as (
  select
    (x->>'set_order')::int as set_order,
    x as set_json,
    x->'selection'->>'weapon' as weapon_key
  from base
  cross join lateral jsonb_array_elements(coalesce(j->'sets','[]'::jsonb)) x
),
bound as (
  select
    e.*,
    exists(select 1 from weapon_proficiency_trees t where t.item_key=e.weapon_key) as tree_available,
    case
      when jsonb_typeof(p.selections->e.weapon_key)='array'
        then p.selections->e.weapon_key
      else '[]'::jsonb
    end as active_perk_orders,
    p.effective_weapon_skill,
    p.effective_magic_level
  from expanded e
  cross join profile p
),
weapon_context as (
  select distinct weapon_key,tree_available,active_perk_orders,
    effective_weapon_skill,effective_magic_level
  from bound
),
impact_by_weapon as materialized (
  select w.weapon_key,
    case
      when w.tree_available then huntnexus_weapon_proficiency_impact_preview(
        w.weapon_key,
        w.active_perk_orders,
        w.effective_weapon_skill,
        w.effective_magic_level
      )
      else null
    end as proficiency
  from weapon_context w
),
decorated as (
  select b.*,w.proficiency
  from bound b
  join impact_by_weapon w on w.weapon_key is not distinct from b.weapon_key
),
sets_out as (
  select
    set_order,
    set_json || jsonb_build_object(
      'weapon_proficiency',
      jsonb_build_object(
        'weapon_key',weapon_key,
        'tree_available',tree_available,
        'selection_source',case
          when jsonb_array_length(active_perk_orders)>0 then 'item_key'
          else 'none'
        end,
        'active_perk_orders',active_perk_orders,
        'impact',proficiency
      )
    ) as set_json
  from decorated
)
select case
  when (select j ? 'error' from base) then
    (select j from base) || jsonb_build_object(
      'methodology',
      coalesce((select j->'methodology' from base),'{}'::jsonb)
      || jsonb_build_object(
        'proficiency_context_stage','optimizer_concrete_sets_with_proficiency_universal_v1'
      )
    )
  else
    (select j - 'sets' from base)
    || jsonb_build_object(
      'sets',coalesce((
        select jsonb_agg(set_json order by set_order) from sets_out
      ),'[]'::jsonb),
      'proficiency_summary',jsonb_build_object(
        'sets_with_weapon_tree',(select count(*) from decorated where tree_available),
        'sets_with_explicit_selection',(select count(*) from decorated where jsonb_array_length(active_perk_orders)>0),
        'sets_with_active_perks',(select count(*) from decorated where coalesce((proficiency->>'active_perk_count')::int,0)>0),
        'sets_with_unresolved_inputs',(select count(*) from decorated where coalesce(jsonb_array_length(proficiency->'unresolved_inputs'),0)>0)
      ),
      'methodology',
      coalesce((select j->'methodology' from base),'{}'::jsonb)
      || jsonb_build_object(
        'stage','optimizer_concrete_sets_with_proficiency_universal_v1',
        'base_stage',(select j #>> '{methodology,stage}' from base),
        'proficiency_item_key_binding_required',true,
        'proficiency_selection_inheritance_applied',false,
        'proficiency_context_applied',true,
        'proficiency_changes_set_validation',false,
        'proficiency_changes_set_order',false,
        'set_score_applied',false,
        'set_ranking_applied',false,
        'winner_selected',false,
        'final_optimizer_applied',false
      )
    )
end;
$function$;

revoke all on function public.huntnexus_optimizer_concrete_sets_with_proficiency_universal(
  text,text,integer,integer,integer,integer,jsonb,jsonb
) from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_concrete_sets_with_proficiency_universal(
  text,text,integer,integer,integer,integer,jsonb,jsonb
) to service_role;
