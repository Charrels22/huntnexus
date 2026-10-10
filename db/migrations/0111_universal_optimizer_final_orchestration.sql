-- HuntNexus — final universal optimizer orchestration envelope.
-- Hunt objective and set objective remain separate.
-- No synthetic loadout score and no forced single winner.

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_final_universal(p_vocation text, p_level integer, p_hunt_objective text DEFAULT 'balanced'::text, p_set_objective text DEFAULT 'balanced'::text, p_party_size integer DEFAULT 1, p_hunt_limit integer DEFAULT 3, p_hand_per_source integer DEFAULT 3, p_per_body_slot integer DEFAULT 2, p_set_limit integer DEFAULT 100, p_frontier_limit integer DEFAULT 100, p_selection_limit integer DEFAULT 20, p_unlocked_requirement_keys jsonb DEFAULT '[]'::jsonb, p_proficiency_selections jsonb DEFAULT '{}'::jsonb, p_character_profile jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
  v_level integer := greatest(coalesce(p_level,1),1);
  v_hunt_objective text := case lower(trim(coalesce(p_hunt_objective,'balanced')))
    when 'xp' then 'xp'
    when 'experience' then 'xp'
    when 'profit' then 'profit'
    when 'loot' then 'profit'
    else 'balanced'
  end;
  v_set_objective text := case lower(trim(coalesce(p_set_objective,'balanced')))
    when 'offense' then 'offense'
    when 'defense' then 'defense'
    when 'sustain' then 'sustain'
    when 'utility' then 'utility'
    else 'balanced'
  end;
  v_party integer := greatest(coalesce(p_party_size,1),1);
  v_hunt_limit integer := least(greatest(coalesce(p_hunt_limit,3),1),5);
  v_unlocks jsonb := case
    when jsonb_typeof(coalesce(p_unlocked_requirement_keys,'[]'::jsonb))='array'
      then coalesce(p_unlocked_requirement_keys,'[]'::jsonb)
    else '[]'::jsonb
  end;
  v_rank jsonb;
  v_results jsonb := '[]'::jsonb;
  v_hunt jsonb;
  v_hunt_key text;
  v_selection jsonb;
  v_rank_order integer := 0;
begin
  if v_vocation not in ('EK','RP','ED','MS','EM') then
    return jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'supported_vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
      'methodology',jsonb_build_object('stage','optimizer_final_universal_v1')
    );
  end if;

  v_rank := huntnexus_rank_observed_hunts(
    v_vocation,v_level,v_hunt_objective,v_party,v_hunt_limit
  );

  for v_hunt in
    select value
    from jsonb_array_elements(coalesce(v_rank->'results','[]'::jsonb))
  loop
    v_rank_order := v_rank_order + 1;
    v_hunt_key := v_hunt->>'hunt_key';

    v_selection := huntnexus_optimizer_set_selection_universal(
      v_hunt_key,
      v_vocation,
      v_level,
      v_set_objective,
      p_hand_per_source,
      p_per_body_slot,
      p_set_limit,
      p_frontier_limit,
      p_selection_limit,
      p_proficiency_selections,
      p_character_profile
    );

    v_results := v_results || jsonb_build_array(
      jsonb_build_object(
        'hunt_rank_order',v_rank_order,
        'hunt',v_hunt,
        'set_selection',v_selection,
        'vocation_composition',
          huntnexus_vocation_composition_universal(
            v_vocation,v_level,v_unlocks,v_hunt_key
          ),
        'spell_candidates',
          huntnexus_spell_candidates_with_unlocks_universal(
            v_vocation,v_level,v_unlocks,null,null,250
          ),
        'imbuement_hunt_context',
          huntnexus_imbuement_hunt_context_universal(
            v_hunt_key,v_vocation
          ),
        'decision_state',jsonb_build_object(
          'hunt_ranked',true,
          'concrete_sets_generated',
            coalesce((v_selection #>> '{source_summary,valid_sets_considered}')::int,0)>0,
          'set_validation_applied',true,
          'proficiency_context_applied',true,
          'set_frontier_applied',true,
          'set_objective_selection_applied',true,
          'co_winner_count',
            coalesce((v_selection #>> '{summary,co_winners}')::int,0),
          'single_winner_forced',false,
          'final_optimizer_applied',true
        )
      )
    );
  end loop;

  return jsonb_build_object(
    'query',jsonb_build_object(
      'vocation',v_vocation,
      'level',v_level,
      'hunt_objective',v_hunt_objective,
      'set_objective',v_set_objective,
      'party_size',v_party,
      'hunt_limit',v_hunt_limit,
      'hand_per_source',p_hand_per_source,
      'per_body_slot',p_per_body_slot,
      'set_limit',p_set_limit,
      'frontier_limit',p_frontier_limit,
      'selection_limit',p_selection_limit,
      'unlocked_requirement_keys',v_unlocks
    ),
    'results',v_results,
    'summary',jsonb_build_object(
      'ranked_hunts',jsonb_array_length(v_results),
      'hunts_with_set_selection',(
        select count(*)
        from jsonb_array_elements(v_results) x
        where coalesce((x #>> '{set_selection,summary,co_winners}')::int,0)>0
      ),
      'total_returned_sets',(
        select coalesce(sum((x #>> '{set_selection,summary,returned}')::int),0)
        from jsonb_array_elements(v_results) x
      )
    ),
    'methodology',jsonb_build_object(
      'stage','optimizer_final_universal_v1',
      'hunt_ranking_source_stage',v_rank #>> '{methodology,stage}',
      'hunt_objective_and_set_objective_separate',true,
      'hunt_score_not_reused_as_set_score',true,
      'set_score_applied',false,
      'cross_metric_loadout_score_applied',false,
      'protection_stacking_formula_applied',false,
      'xp_profit_not_inferred_from_loadout',true,
      'co_winners_allowed',true,
      'single_winner_forced',false,
      'final_optimizer_applied',true
    )
  );
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
    'final_optimizer_ready',true
  ),
  'known_blockers',jsonb_build_array(
    jsonb_build_object(
      'key','cross_type_imbuement_priority',
      'status','pending_optional_extension',
      'note','Final optimizer exposes defensive Imbuement context, but offense/sustain/skill Imbuements are not collapsed into one cross-type priority.'
    ),
    jsonb_build_object(
      'key','final_combat_formula',
      'status','pending_optional_extension',
      'note','Final optimizer does not invent DPS/healing/final mitigation formulas; results remain Pareto and evidence based.'
    )
  ),
  'methodology',jsonb_build_object(
    'stage','optimizer_audit_v7',
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
    'hunt_and_set_objectives_separate',true,
    'hunt_score_not_reused_as_set_score',true,
    'xp_profit_not_inferred_from_loadout',true,
    'single_winner_forced',false,
    'co_winners_allowed',true,
    'protection_stacking_formula_applied',false,
    'final_optimizer_applied',true
  )
);
$function$
;

revoke all on function public.huntnexus_optimizer_final_universal(
  text,integer,text,text,integer,integer,integer,integer,integer,integer,integer,jsonb,jsonb,jsonb
) from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_final_universal(
  text,integer,text,text,integer,integer,integer,integer,integer,integer,integer,jsonb,jsonb,jsonb
) to service_role;

revoke all on function public.huntnexus_optimizer_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_audit()
to service_role;
