-- HuntNexus — item-key-bound Weapon Proficiency context for validated concrete sets.
-- Proficiency selections never inherit between weapons and do not change set order,
-- validation, ranking, or winner selection.

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
decorated as (
  select
    b.*,
    case
      when b.tree_available then huntnexus_weapon_proficiency_impact_preview(
        b.weapon_key,
        b.active_perk_orders,
        b.effective_weapon_skill,
        b.effective_magic_level
      )
      else null
    end as proficiency
  from bound b
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
    'set_selection_ready',false,
    'final_optimizer_ready',false
  ),
  'known_blockers',jsonb_build_array(
    jsonb_build_object(
      'key','set_selection_policy',
      'status','next',
      'note','Validated sets now carry item-key-bound Weapon Proficiency context, but no factual policy yet chooses one set over another.'
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
    'stage','optimizer_audit_v4',
    'category_first',true,
    'legacy_ek_optimizer_not_used_as_universal_selector',true,
    'cross_metric_score_applied',false,
    'pareto_only_for_item_pruning',true,
    'concrete_sets_universally_validated',true,
    'proficiency_item_key_binding_required',true,
    'proficiency_selection_inheritance_applied',false
  )
);
$function$;

revoke all on function public.huntnexus_optimizer_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_audit()
to service_role;
