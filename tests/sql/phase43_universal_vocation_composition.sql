-- Focused regression for universal vocation composition.

do $$
declare
  v_ek jsonb;
  v_rp jsonb;
  v_ed jsonb;
  v_ms jsonb;
  v_em jsonb;
  v_em_profile jsonb;
  v_audit jsonb;
begin
  if (select count(*) from vocation_composition_rules) <> 5 then
    raise exception 'Vocation composition rule count regression';
  end if;

  v_em_profile := huntnexus_vocation_profile_contract_universal('EM');

  if v_em_profile #>> '{vocation,code}' <> 'EM'
     or v_em_profile #>> '{identity,primary_skill_mode}' <> 'fist_melee'
     or v_em_profile #>> '{identity,resource_key}' <> 'harmony'
     or v_em_profile #>> '{vocation_specific,effective_fist_skill,type}' <> 'integer'
     or v_em_profile #>> '{vocation_specific,effective_magic_level,type}' <> 'integer' then
    raise exception 'Monk universal profile contract regression';
  end if;

  if huntnexus_vocation_profile_contract_universal('UNKNOWN')->>'error'
     <> 'unsupported_vocation' then
    raise exception 'Unsupported vocation profile regression';
  end if;

  v_ek := huntnexus_vocation_composition_universal('EK',700,'[]'::jsonb,'cobra-bastion');
  v_rp := huntnexus_vocation_composition_universal('RP',700,'[]'::jsonb,null);
  v_ed := huntnexus_vocation_composition_universal('ED',700,'[]'::jsonb,'gloom-pillars');
  v_ms := huntnexus_vocation_composition_universal('MS',700,'[]'::jsonb,null);
  v_em := huntnexus_vocation_composition_universal('EM',700,'[]'::jsonb,'grounds-of-undeath');

  if v_ek #> '{weapons,canonical_families}' <> '["sword","axe","club"]'::jsonb
     or v_rp #> '{weapons,canonical_families}' <> '["bow","crossbow"]'::jsonb
     or v_ed #> '{weapons,canonical_families}' <> '["rod"]'::jsonb
     or v_ms #> '{weapons,canonical_families}' <> '["wand"]'::jsonb
     or v_em #> '{weapons,canonical_families}' <> '["fist"]'::jsonb then
    raise exception 'Canonical weapon family regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_ed #> '{weapons,explicit_vocation_families}') x
    where x->>'weapon_family'='wand'
      and (x->>'level_eligible_items')::int=4
  ) then
    raise exception 'Explicit Druid Wand compatibility regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_em #> '{weapons,explicit_vocation_families}') x
    where x->>'weapon_family'='fist'
      and (x->>'level_eligible_items')::int=34
  ) then
    raise exception 'Monk explicit Fist compatibility regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_em #> '{weapons,unrestricted_catalog_families}') x
    where x->>'weapon_family'='sword'
  ) then
    raise exception 'Unrestricted catalog-family separation regression';
  end if;

  if v_em #>> '{spells,resource_key}' <> 'harmony'
     or (v_em #>> '{spells,summary,catalog_spells}')::int <> 16
     or (v_em #>> '{spells,summary,eligible}')::int <> 11
     or (v_em #>> '{spells,summary,incomplete}')::int <> 5 then
    raise exception 'Monk spell/unlock composition regression';
  end if;

  if (v_ek #>> '{spells,summary,catalog_spells}')::int <> 11
     or (v_ed #>> '{spells,summary,catalog_spells}')::int <> 14
     or (v_ms #>> '{spells,summary,catalog_spells}')::int <> 13
     or (v_rp #>> '{spells,summary,catalog_spells}')::int <> 6 then
    raise exception 'Per-vocation spell composition count regression';
  end if;

  if (v_ek #>> '{community_evidence,observed_players}')::int <> 54
     or (v_ed #>> '{community_evidence,observed_players}')::int <> 53
     or (v_em #>> '{community_evidence,observed_players}')::int <> 16
     or (v_ms #>> '{community_evidence,observed_players}')::int <> 31
     or (v_rp #>> '{community_evidence,observed_players}')::int <> 47 then
    raise exception 'Community evidence count regression';
  end if;

  if coalesce((v_ek #>> '{hunt_observation,incoming_damage,available}')::boolean,false) is not true
     or coalesce((v_ed #>> '{hunt_observation,incoming_damage,available}')::boolean,false) is not true
     or coalesce((v_em #>> '{hunt_observation,incoming_damage,available}')::boolean,false) is not true
     or coalesce((v_ms #>> '{hunt_observation,provided}')::boolean,true) is not false
     or coalesce((v_rp #>> '{hunt_observation,provided}')::boolean,true) is not false then
    raise exception 'Hunt observation hook regression';
  end if;

  if coalesce((v_em #>> '{methodology,ranking_applied}')::boolean,true) is not false
     or coalesce((v_em #>> '{methodology,final_optimizer_applied}')::boolean,true) is not false
     or coalesce((v_em #>> '{methodology,cross_vocation_score_applied}')::boolean,true) is not false
     or coalesce((v_em #>> '{methodology,explicit_and_unrestricted_weapon_families_separate}')::boolean,false) is not true then
    raise exception 'Vocation composition methodology regression';
  end if;

  if huntnexus_vocation_composition_universal('UNKNOWN',700,'[]'::jsonb,null)->>'error'
     <> 'unsupported_vocation' then
    raise exception 'Unsupported vocation composition regression';
  end if;

  v_audit := huntnexus_vocation_composition_audit();

  if v_audit #>> '{methodology,stage}' <> 'vocation_composition_audit_v1'
     or (v_audit #>> '{summary,vocation_rules}')::int <> 5
     or (v_audit #>> '{summary,represented_vocations}')::int <> 5
     or coalesce((v_audit #>> '{summary,monk_profile_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,profile_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,weapon_identity_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,spell_unlock_composition_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,cross_vocation_ranking_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_optimizer_ready}')::boolean,true) is not false then
    raise exception 'Vocation composition audit semantics regression';
  end if;

  if has_table_privilege('anon','public.vocation_composition_rules','SELECT')
     or has_table_privilege('authenticated','public.vocation_composition_rules','SELECT') then
    raise exception 'Vocation composition rules must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_vocation_composition',
  'vocation_rules',(select count(*) from vocation_composition_rules),
  'represented_vocations',(select count(distinct vocation_code) from vocation_composition_rules),
  'monk_profile_ready',(huntnexus_vocation_composition_audit() #>> '{summary,monk_profile_contract_ready}')::boolean,
  'final_optimizer_ready',(huntnexus_vocation_composition_audit() #>> '{summary,final_optimizer_ready}')::boolean
) as regression_summary;
