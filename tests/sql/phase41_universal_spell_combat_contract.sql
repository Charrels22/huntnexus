-- Focused regression for universal spell/combat contract.

do $$
declare
  v_em jsonb;
  v_ek jsonb;
  v_ms jsonb;
  v_audit jsonb;
begin
  if (select count(*) from vw_spell_catalog_universal) <> 50 then
    raise exception 'Universal spell catalog count regression';
  end if;

  if (select count(distinct vocation) from vw_spell_catalog_universal) <> 5 then
    raise exception 'Expected all five vocations in spell catalog';
  end if;

  if (select count(*) from vw_spell_catalog_universal where vocation='EM') <> 11 then
    raise exception 'Monk spell coverage regression';
  end if;

  if (select count(*) from spell_resource_mechanics where resource_key='harmony') <> 9 then
    raise exception 'Harmony mechanic row count regression';
  end if;

  if not exists (
    select 1 from spell_resource_mechanics
    where spell_key='swift-jab'
      and resource_action='builder'
      and amount_mode='source_unspecified'
  ) or not exists (
    select 1 from spell_resource_mechanics
    where spell_key='devastating-knockout'
      and resource_action='spender_all'
      and amount_mode='all'
  ) or not exists (
    select 1 from spell_resource_mechanics
    where spell_key='mass-spirit-mend'
      and resource_action='none'
      and amount_mode='none'
  ) then
    raise exception 'Harmony builder/spender/current-heal regression';
  end if;

  if not exists (
    select 1 from vw_spell_catalog_universal
    where spell_key='thousand-fist-blows'
      and min_level=120
      and mana_cost=145
      and cooldown_seconds=8
      and group_cooldown_seconds=2
      and base_power=62
      and scaling='weapon + fist fighting'
      and element='physical'
      and jsonb_array_length(resource_mechanics)=1
  ) then
    raise exception 'Thousand Fist Blows current factual regression';
  end if;

  if not exists (
    select 1 from vw_spell_catalog_universal
    where spell_key='mass-spirit-mend'
      and min_level=150
      and mana_cost=400
      and cooldown_seconds=12
      and group_cooldown_seconds=1
      and base_power=800
      and scaling='magic level'
  ) then
    raise exception 'Mass Spirit Mend current 2026 regression';
  end if;

  if exists (
    select 1 from vw_spell_catalog_universal
    where spell_group in ('attack','healing')
      and base_power is not null
      and base_power_semantics not like 'Base Power is a relative spell power reference%'
  ) then
    raise exception 'Base Power semantics regression';
  end if;

  v_em := huntnexus_spell_candidates_universal('EM',60,'attack',null,50);
  if v_em #>> '{methodology,stage}' <> 'spell_candidates_universal_v1'
     or (v_em #>> '{summary,catalog_spells}')::int <> 8
     or (v_em #>> '{summary,eligible}')::int <> 5
     or (v_em #>> '{summary,blocked}')::int <> 3
     or coalesce((v_em #>> '{methodology,dps_formula_applied}')::boolean,true) is not false
     or coalesce((v_em #>> '{methodology,rotation_score_applied}')::boolean,true) is not false then
    raise exception 'Monk level-filtered candidate regression';
  end if;

  v_ek := huntnexus_spell_candidates_universal('EK',100,'attack',null,50);
  if (v_ek #>> '{summary,catalog_spells}')::int <> 4
     or (v_ek #>> '{summary,eligible}')::int <> 3
     or (v_ek #>> '{summary,blocked}')::int <> 1
     or not exists (
       select 1 from jsonb_array_elements(v_ek->'spells') x
       where x->>'spell_key'='annihilation'
         and x->>'eligibility_status'='blocked'
         and (x->'blocking_reasons') ? 'level_requirement'
     ) then
    raise exception 'EK spell candidate regression';
  end if;

  v_ms := huntnexus_spell_candidates_universal('MS',100,'attack','fire',50);
  if (v_ms #>> '{summary,catalog_spells}')::int <> 4
     or (v_ms #>> '{summary,eligible}')::int <> 4
     or exists (
       select 1 from jsonb_array_elements(v_ms->'spells') x
       where x->>'element'<>'fire'
     ) then
    raise exception 'MS elemental spell filtering regression';
  end if;

  if huntnexus_spell_candidates_universal('UNKNOWN',100,null,null,10)->>'error'
     <> 'unsupported_vocation' then
    raise exception 'Unsupported vocation regression';
  end if;

  v_audit := huntnexus_spell_category_audit();
  if v_audit #>> '{methodology,stage}' <> 'spell_category_audit_v1'
     or (v_audit #>> '{summary,represented_vocations}')::int <> 5
     or (v_audit #>> '{summary,monk_spells}')::int <> 11
     or coalesce((v_audit #>> '{summary,vocation_level_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,base_power_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,catalog_exhaustive}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,additional_unlock_rules_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,rotation_model_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_damage_formula_ready}')::boolean,true) is not false then
    raise exception 'Spell category audit semantics regression';
  end if;

  if has_table_privilege('anon','public.spell_resource_mechanics','SELECT')
     or has_table_privilege('authenticated','public.spell_resource_mechanics','SELECT')
     or has_table_privilege('anon','public.vw_spell_catalog_universal','SELECT')
     or has_table_privilege('authenticated','public.vw_spell_catalog_universal','SELECT') then
    raise exception 'Universal spell objects must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_spell_combat_contract',
  'catalog_spells',(select count(*) from vw_spell_catalog_universal),
  'represented_vocations',(select count(distinct vocation) from vw_spell_catalog_universal),
  'monk_spells',(select count(*) from vw_spell_catalog_universal where vocation='EM'),
  'harmony_mechanics',(select count(*) from spell_resource_mechanics where resource_key='harmony'),
  'catalog_exhaustive',(huntnexus_spell_category_audit() #>> '{summary,catalog_exhaustive}')::boolean
) as regression_summary;
