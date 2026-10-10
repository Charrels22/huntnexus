-- Focused regression for universal optimizer candidate envelope.

do $$
declare
  v_ek jsonb;
  v_rp jsonb;
  v_ed jsonb;
  v_ms jsonb;
  v_em jsonb;
  v_audit jsonb;
begin
  v_ek := huntnexus_optimizer_candidate_envelope_universal('EK',700,'balanced',1,1,3,'[]'::jsonb);
  v_rp := huntnexus_optimizer_candidate_envelope_universal('RP',700,'balanced',1,1,3,'[]'::jsonb);
  v_ed := huntnexus_optimizer_candidate_envelope_universal('ED',700,'balanced',1,1,3,'[]'::jsonb);
  v_ms := huntnexus_optimizer_candidate_envelope_universal('MS',700,'balanced',1,1,3,'[]'::jsonb);
  v_em := huntnexus_optimizer_candidate_envelope_universal('EM',700,'balanced',1,1,3,'[]'::jsonb);

  if v_ek #>> '{methodology,stage}' <> 'optimizer_candidate_envelope_universal_v1'
     or coalesce((v_ek #>> '{methodology,cross_metric_loadout_score_applied}')::boolean,true) is not false
     or coalesce((v_ek #>> '{methodology,set_selected}')::boolean,true) is not false
     or coalesce((v_ek #>> '{methodology,final_optimizer_applied}')::boolean,true) is not false then
    raise exception 'Optimizer candidate envelope methodology regression';
  end if;

  if v_ek #>> '{results,0,hunt,hunt_key}' <> 'cobra-bastion'
     or v_rp #>> '{results,0,hunt,hunt_key}' <> 'iksupan-last-stand'
     or v_em #>> '{results,0,hunt,hunt_key}' <> 'grounds-of-undeath' then
    raise exception 'Observed hunt ranking integration regression';
  end if;

  if v_ek #> '{results,0,vocation_composition,weapons,canonical_families}'
       <> '["sword","axe","club"]'::jsonb
     or v_rp #> '{results,0,vocation_composition,weapons,canonical_families}'
       <> '["bow","crossbow"]'::jsonb
     or v_ed #> '{results,0,vocation_composition,weapons,canonical_families}'
       <> '["rod"]'::jsonb
     or v_ms #> '{results,0,vocation_composition,weapons,canonical_families}'
       <> '["wand"]'::jsonb
     or v_em #> '{results,0,vocation_composition,weapons,canonical_families}'
       <> '["fist"]'::jsonb then
    raise exception 'Optimizer canonical weapon family regression';
  end if;

  if jsonb_array_length(v_ek #> '{results,0,weapon_candidates}') <> 3
     or jsonb_array_length(v_rp #> '{results,0,weapon_candidates}') <> 2
     or jsonb_array_length(v_ed #> '{results,0,weapon_candidates}') <> 1
     or jsonb_array_length(v_ms #> '{results,0,weapon_candidates}') <> 1
     or jsonb_array_length(v_em #> '{results,0,weapon_candidates}') <> 1 then
    raise exception 'Optimizer canonical weapon candidate pool regression';
  end if;

  if (select count(*) from jsonb_object_keys(v_ek #> '{results,0,equipment_candidates}')) <> 7
     or (select count(*) from jsonb_object_keys(v_em #> '{results,0,equipment_candidates}')) <> 7 then
    raise exception 'Optimizer equipment slot pool regression';
  end if;

  if (v_ek #>> '{results,0,spell_candidates,summary,catalog_spells}')::int <> 11
     or (v_rp #>> '{results,0,spell_candidates,summary,catalog_spells}')::int <> 6
     or (v_ed #>> '{results,0,spell_candidates,summary,catalog_spells}')::int <> 14
     or (v_ms #>> '{results,0,spell_candidates,summary,catalog_spells}')::int <> 13
     or (v_em #>> '{results,0,spell_candidates,summary,catalog_spells}')::int <> 16 then
    raise exception 'Optimizer spell envelope regression';
  end if;

  if coalesce((v_ek #>> '{results,0,decision_state,set_selected}')::boolean,true) is not false
     or coalesce((v_ek #>> '{results,0,decision_state,pareto_frontier_applied}')::boolean,true) is not false
     or coalesce((v_ek #>> '{results,0,decision_state,final_optimizer_applied}')::boolean,true) is not false then
    raise exception 'Optimizer decision-state regression';
  end if;

  if coalesce((v_ek #>> '{results,0,imbuement_hunt_context,incoming_damage,available}')::boolean,false) is not true
     or coalesce((v_em #>> '{results,0,imbuement_hunt_context,incoming_damage,available}')::boolean,false) is not true
     or coalesce((v_ms #>> '{results,0,imbuement_hunt_context,incoming_damage,available}')::boolean,true) is not false then
    raise exception 'Optimizer observed-damage availability regression';
  end if;

  if huntnexus_optimizer_candidate_envelope_universal(
       'UNKNOWN',700,'balanced',1,1,3,'[]'::jsonb
     )->>'error' <> 'unsupported_vocation' then
    raise exception 'Optimizer unsupported vocation regression';
  end if;

  v_audit := huntnexus_optimizer_audit();

  if v_audit #>> '{methodology,stage}' <> 'optimizer_audit_v1'
     or coalesce((v_audit #>> '{summary,candidate_envelope_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,weapon_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,equipment_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,imbuement_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,effect_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,slot_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,spell_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,vocation_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,pareto_frontier_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,set_selection_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_optimizer_ready}')::boolean,true) is not false then
    raise exception 'Optimizer readiness audit regression';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_optimizer_candidate_envelope',
  'candidate_envelope_ready',(huntnexus_optimizer_audit() #>> '{summary,candidate_envelope_ready}')::boolean,
  'pareto_frontier_ready',(huntnexus_optimizer_audit() #>> '{summary,pareto_frontier_ready}')::boolean,
  'set_selection_ready',(huntnexus_optimizer_audit() #>> '{summary,set_selection_ready}')::boolean,
  'final_optimizer_ready',(huntnexus_optimizer_audit() #>> '{summary,final_optimizer_ready}')::boolean
) as regression_summary;
