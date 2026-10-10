-- HuntNexus — final optimizer foundation: universal candidate envelope.
-- Reuses observed hunt ranking, but keeps hunt score separate from loadout selection.
-- Builds category-first candidate pools for canonical weapons, equipment, spells and Imbuement context.
-- Does not yet select a set or apply Pareto/frontier ranking.

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_candidate_envelope_universal(p_vocation text, p_level integer, p_objective text DEFAULT 'balanced'::text, p_party_size integer DEFAULT 1, p_hunt_limit integer DEFAULT 3, p_per_dimension integer DEFAULT 8, p_unlocked_requirement_keys jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
  v_level integer := greatest(coalesce(p_level,1),1);
  v_objective text := lower(coalesce(p_objective,'balanced'));
  v_hunt_limit integer := least(greatest(coalesce(p_hunt_limit,3),1),10);
  v_per integer := least(greatest(coalesce(p_per_dimension,8),1),20);
  v_unlocks jsonb := case
    when jsonb_typeof(coalesce(p_unlocked_requirement_keys,'[]'::jsonb))='array'
      then coalesce(p_unlocked_requirement_keys,'[]'::jsonb)
    else '[]'::jsonb
  end;
  v_rank jsonb;
  v_result jsonb := '[]'::jsonb;
  v_hunt jsonb;
  v_hunt_key text;
  v_voc_rule record;
  v_family text;
  v_weapons jsonb;
  v_equipment jsonb;
  v_slot text;
  v_spells jsonb;
  v_composition jsonb;
  v_imbues jsonb;
begin
  if v_vocation not in ('EK','RP','ED','MS','EM') then
    return jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'supported_vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
      'methodology',jsonb_build_object('stage','optimizer_candidate_envelope_universal_v1')
    );
  end if;

  if v_objective not in ('xp','profit','balanced') then
    v_objective := 'balanced';
  end if;

  select * into v_voc_rule
  from vocation_composition_rules
  where vocation_code=v_vocation;

  v_rank := huntnexus_rank_observed_hunts(
    v_vocation,v_level,v_objective,greatest(coalesce(p_party_size,1),1),v_hunt_limit
  );

  for v_hunt in
    select value from jsonb_array_elements(coalesce(v_rank->'results','[]'::jsonb))
  loop
    v_hunt_key := v_hunt->>'hunt_key';
    v_weapons := '[]'::jsonb;

    for v_family in
      select value
      from jsonb_array_elements_text(v_voc_rule.canonical_weapon_families)
    loop
      v_weapons := v_weapons || jsonb_build_array(
        jsonb_build_object(
          'weapon_family',v_family,
          'candidates',huntnexus_weapon_candidates_universal(
            v_vocation,v_level,null,v_family,v_per
          )
        )
      );
    end loop;

    v_equipment := '{}'::jsonb;
    foreach v_slot in array array['head','body','legs','feet','neck','ring','offhand']
    loop
      v_equipment := v_equipment || jsonb_build_object(
        v_slot,
        huntnexus_equipment_candidates_universal(
          v_vocation,v_level,v_slot,null,true,v_per
        )
      );
    end loop;

    v_spells := huntnexus_spell_candidates_with_unlocks_universal(
      v_vocation,v_level,v_unlocks,null,null,250
    );

    v_composition := huntnexus_vocation_composition_universal(
      v_vocation,v_level,v_unlocks,v_hunt_key
    );

    v_imbues := huntnexus_imbuement_hunt_context_universal(
      v_hunt_key,v_vocation
    );

    v_result := v_result || jsonb_build_array(
      jsonb_build_object(
        'hunt',v_hunt,
        'vocation_composition',v_composition,
        'weapon_candidates',v_weapons,
        'equipment_candidates',v_equipment,
        'spell_candidates',v_spells,
        'imbuement_hunt_context',v_imbues,
        'loadout_validation_contract',jsonb_build_object(
          'function','huntnexus_loadout_compatibility_universal',
          'stage','loadout_compatibility_universal_v1',
          'applied_to_candidate_pool',false,
          'note','Compatibility is applied to concrete set selections in the next optimizer stage; candidate eligibility/dependencies remain visible here.'
        ),
        'decision_state',jsonb_build_object(
          'hunt_ranked',true,
          'candidate_pool_built',true,
          'set_selected',false,
          'pareto_frontier_applied',false,
          'final_optimizer_applied',false
        )
      )
    );
  end loop;

  return jsonb_build_object(
    'query',jsonb_build_object(
      'vocation',v_vocation,
      'level',v_level,
      'objective',v_objective,
      'party_size',greatest(coalesce(p_party_size,1),1),
      'hunt_limit',v_hunt_limit,
      'per_dimension',v_per,
      'unlocked_requirement_keys',v_unlocks
    ),
    'results',v_result,
    'methodology',jsonb_build_object(
      'stage','optimizer_candidate_envelope_universal_v1',
      'category_first',true,
      'hunt_ranking_source_stage',v_rank #>> '{methodology,stage}',
      'hunt_score_kept_separate_from_loadout',true,
      'canonical_weapon_families_only',true,
      'equipment_eligibility_only',true,
      'spell_unlocks_applied',true,
      'imbuement_defensive_context_applied',true,
      'cross_metric_loadout_score_applied',false,
      'pareto_frontier_applied',false,
      'set_selected',false,
      'final_optimizer_applied',false
    )
  );
end;
$function$
;

revoke all on function public.huntnexus_optimizer_candidate_envelope_universal(text,integer,text,integer,integer,integer,jsonb)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_candidate_envelope_universal(text,integer,text,integer,integer,integer,jsonb)
to service_role;

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
    'pareto_frontier_ready',false,
    'set_selection_ready',false,
    'final_optimizer_ready',false
  ),
  'known_blockers',jsonb_build_array(
    jsonb_build_object(
      'key','loadout_frontier',
      'status','next',
      'note','Candidate pools are universal, but Pareto dominance across explicitly directional factual dimensions is not applied yet.'
    ),
    jsonb_build_object(
      'key','set_validation',
      'status','next',
      'note','Concrete candidate combinations must be passed through universal loadout compatibility before selection.'
    ),
    jsonb_build_object(
      'key','cross_type_imbuement_priority',
      'status','pending',
      'note','Defensive Imbuement context is ready; offense/sustain/skill Imbuements remain intentionally unranked across types.'
    ),
    jsonb_build_object(
      'key','final_formula',
      'status','pending',
      'note','No invented DPS/healing or universal cross-metric scalar is allowed.'
    )
  ),
  'methodology',jsonb_build_object(
    'stage','optimizer_audit_v1',
    'category_first',true,
    'legacy_ek_optimizer_not_used_as_universal_selector',true,
    'cross_metric_score_applied',false
  )
);
$function$
;

revoke all on function public.huntnexus_optimizer_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_audit()
to service_role;
