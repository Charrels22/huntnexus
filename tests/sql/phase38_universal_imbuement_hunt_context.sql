-- Focused regression for universal contextual Imbuement layer.

do $$
declare
  v_cobra jsonb;
  v_lion jsonb;
  v_ed jsonb;
  v_rp jsonb;
  v_em jsonb;
  v_none jsonb;
  v_invalid jsonb;
  v_audit jsonb;
begin
  v_cobra := huntnexus_imbuement_hunt_context_universal('cobra-bastion','EK');

  if v_cobra #>> '{methodology,stage}' <> 'imbuement_hunt_context_universal_v1'
     or coalesce((v_cobra #>> '{incoming_damage,available}')::boolean,false) is not true
     or (v_cobra #>> '{incoming_damage,total_observed_damage}')::numeric <> 5734100
     or (v_cobra #>> '{incoming_damage,protectable_observed_damage}')::numeric <> 2853813 then
    raise exception 'Cobra Bastion hunt context regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_cobra->'defensive_priority') x
    where x->>'imbuement_key'='snake-skin'
      and (x->>'observed_damage')::numeric=1945719
  ) or not exists (
    select 1 from jsonb_array_elements(v_cobra->'defensive_priority') x
    where x->>'imbuement_key'='lich-shroud'
      and (x->>'observed_damage')::numeric=908094
  ) then
    raise exception 'Cobra defensive priority regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_cobra->'community_observed_usage') x
    where x->>'imbuement_key'='vampirism'
      and coalesce((x->>'affects_priority')::boolean,true) is false
  ) then
    raise exception 'Community usage must remain non-prioritizing Tier C evidence';
  end if;

  v_lion := huntnexus_item_imbuement_context_universal(
    'lion-plate','cobra-bastion','EK'
  );

  if v_lion #>> '{methodology,stage}' <> 'item_imbuement_context_universal_v1'
     or jsonb_array_length(v_lion->'defensive_priority_for_item') <> 2
     or not exists (
       select 1 from jsonb_array_elements(v_lion->'eligible_nondefensive_candidates') x
       where x->>'imbuement_key'='vampirism'
     )
     or not exists (
       select 1 from jsonb_array_elements(v_lion->'community_evidence_for_eligible_candidates') x
       where x->>'imbuement_key'='snake-skin'
         and coalesce((x->>'affects_priority')::boolean,true) is false
     ) then
    raise exception 'Item contextual Imbuement regression';
  end if;

  v_ed := huntnexus_item_imbuement_context_universal(
    'lion-spellbook','gloom-pillars','ED'
  );
  if coalesce((v_ed #>> '{hunt_context,incoming_damage,available}')::boolean,false) is not true
     or jsonb_array_length(v_ed->'defensive_priority_for_item') <> 5
     or (v_ed #>> '{defensive_priority_for_item,0,imbuement_key}') <> 'dragon-hide' then
    raise exception 'ED contextual protection regression';
  end if;

  v_rp := huntnexus_imbuement_hunt_context_universal(
    'nimmersatts-breeding-ground','RP'
  );
  if coalesce((v_rp #>> '{incoming_damage,available}')::boolean,false) is not true
     or (v_rp #>> '{incoming_damage,total_observed_damage}')::numeric <> 3402947 then
    raise exception 'RP contextual damage regression';
  end if;

  v_em := huntnexus_item_imbuement_context_universal(
    'grand-sanguine-claws','grounds-of-undeath','EM'
  );
  if not exists (
    select 1 from jsonb_array_elements(v_em->'eligible_nondefensive_candidates') x
    where x->>'imbuement_key'='punch'
  ) or not exists (
    select 1 from jsonb_array_elements(v_em->'community_evidence_for_eligible_candidates') x
    where x->>'imbuement_key'='punch'
      and coalesce((x->>'affects_priority')::boolean,true) is false
  ) then
    raise exception 'EM/Fist contextual evidence regression';
  end if;

  v_none := huntnexus_imbuement_hunt_context_universal('does-not-exist','MS');
  if coalesce((v_none #>> '{incoming_damage,available}')::boolean,true) is not false
     or (v_none #>> '{incoming_damage,total_observed_damage}')::numeric <> 0
     or jsonb_array_length(v_none->'defensive_priority') <> 0 then
    raise exception 'No-observation context regression';
  end if;

  v_invalid := huntnexus_imbuement_hunt_context_universal('cobra-bastion','UNKNOWN');
  if v_invalid->>'error' <> 'unsupported_vocation' then
    raise exception 'Unsupported vocation regression';
  end if;

  v_audit := huntnexus_imbuement_category_audit();
  if v_audit #>> '{methodology,stage}' <> 'imbuement_category_audit_v2'
     or coalesce((v_audit #>> '{summary,hunt_context_priority_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,defensive_hunt_context_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,cross_type_priority_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_assignment_ready}')::boolean,true) is not false
     or (v_audit #>> '{summary,observed_damage_contexts}')::int <> 29
     or (v_audit #>> '{summary,community_usage_contexts}')::int <> 28 then
    raise exception 'Imbuement contextual audit regression';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_imbuement_hunt_context',
  'damage_contexts',(huntnexus_imbuement_category_audit() #>> '{summary,observed_damage_contexts}')::int,
  'usage_contexts',(huntnexus_imbuement_category_audit() #>> '{summary,community_usage_contexts}')::int,
  'defensive_context_ready',(huntnexus_imbuement_category_audit() #>> '{summary,defensive_hunt_context_ready}')::boolean,
  'final_assignment_ready',(huntnexus_imbuement_category_audit() #>> '{summary,final_assignment_ready}')::boolean
) as regression_summary;
