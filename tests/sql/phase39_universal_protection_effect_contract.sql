-- Focused regression for universal protection/effect contract.

do $$
declare
  v_dragon jsonb;
  v_katar_cond jsonb;
  v_katar_active jsonb;
  v_context jsonb;
  v_audit jsonb;
begin
  if (select count(*) from vw_combat_item_effects_universal) <> 1655 then
    raise exception 'Static universal effect row count regression';
  end if;

  if (select count(distinct item_key) from vw_combat_item_effects_universal) <> 692 then
    raise exception 'Universal items-with-effects count regression';
  end if;

  if (select count(*) from vw_combat_item_effects_universal where semantic_group='protection') <> 657 then
    raise exception 'Protection row count regression';
  end if;

  if (select count(*) from vw_combat_item_effects_universal
      where semantic_group='protection' and numeric_value<0) <> 95 then
    raise exception 'Negative protection row count regression';
  end if;

  v_dragon := huntnexus_item_effect_profile_universal('dragon-robe',null);

  if (v_dragon #>> '{groups,protection,fire}')::numeric <> 12
     or (v_dragon #>> '{groups,protection,ice}')::numeric <> -12
     or jsonb_array_length(v_dragon #> '{groups,vulnerabilities}') <> 1
     or coalesce((v_dragon #>> '{proficiency,selection_applied}')::boolean,true) is not false then
    raise exception 'Signed protection/vulnerability regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_dragon->'static_effects') x
    where x->>'effect_key'='ice'
      and x->>'value_semantics'='positive=protection; negative=vulnerability'
      and coalesce((x->>'is_negative_value')::boolean,false) is true
  ) then
    raise exception 'Protection value semantics regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(
      huntnexus_item_effect_profile_universal('eldritch-shield',null) #> '{groups,reflection}'
    ) x
    where x->>'effect_key'='damage_reflection'
      and (x->>'value')::numeric=42
  ) then
    raise exception 'Reflection regression';
  end if;

  if jsonb_array_length(
    huntnexus_item_effect_profile_universal('cocoa-grimoire',null) #> '{groups,magic_shield}'
  ) <> 2 then
    raise exception 'Magic shield effect grouping regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(
      huntnexus_item_effect_profile_universal('depth-calcei',null) #> '{groups,movement}'
    ) x
    where x->>'effect_key'='speed'
      and (x->>'value')::numeric=-5
      and coalesce((x->>'is_negative_value')::boolean,false) is true
  ) then
    raise exception 'Signed movement regression';
  end if;

  v_katar_cond := huntnexus_item_effect_profile_universal('moonsilver-katar',null);
  if jsonb_array_length(v_katar_cond #> '{proficiency,conditional_pierce_perks}') <> 1
     or jsonb_array_length(v_katar_cond #> '{proficiency,active_pierce_effects}') <> 0 then
    raise exception 'Conditional pierce inventory regression';
  end if;

  v_katar_active := huntnexus_item_effect_profile_universal(
    'moonsilver-katar','[16,17]'::jsonb
  );
  if coalesce((v_katar_active #>> '{proficiency,selection_applied}')::boolean,false) is not true
     or jsonb_array_length(v_katar_active #> '{proficiency,active_pierce_effects}') <> 1
     or (v_katar_active #>> '{proficiency,active_pierce_effects,0,value}')::numeric <> 4 then
    raise exception 'Active pierce selection regression';
  end if;

  v_context := huntnexus_item_effect_hunt_context_universal(
    'dragon-robe','nimmersatts-breeding-ground','RP',null
  );

  if v_context #>> '{methodology,stage}' <> 'item_effect_hunt_context_universal_v1'
     or coalesce((v_context #>> '{methodology,final_damage_reduction_calculated}')::boolean,true) is not false
     or jsonb_array_length(v_context->'protection_alignment') <> 2 then
    raise exception 'Effect hunt-context contract regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_context->'protection_alignment') x
    where x->>'element'='fire'
      and x->>'interpretation'='protection'
      and (x->>'item_protection_percent')::numeric=12
  ) or not exists (
    select 1 from jsonb_array_elements(v_context->'protection_alignment') x
    where x->>'element'='ice'
      and x->>'interpretation'='vulnerability'
      and (x->>'item_protection_percent')::numeric=-12
      and (x->>'signed_alignment_proxy')::numeric<0
  ) then
    raise exception 'Signed hunt-alignment regression';
  end if;

  v_audit := huntnexus_effect_category_audit();
  if v_audit #>> '{methodology,stage}' <> 'effect_category_audit_v1'
     or coalesce((v_audit #>> '{summary,static_effect_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,hunt_protection_alignment_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,proficiency_pierce_inventory_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,pierce_target_context_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,stacking_formula_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,cross_effect_utility_score_ready}')::boolean,true) is not false then
    raise exception 'Effect category audit semantics regression';
  end if;

  if has_table_privilege('anon','public.vw_combat_item_effects_universal','SELECT')
     or has_table_privilege('authenticated','public.vw_combat_item_effects_universal','SELECT') then
    raise exception 'Universal effect view must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_protection_effect_contract',
  'static_effect_rows',(huntnexus_effect_category_audit() #>> '{summary,static_effect_rows}')::int,
  'items_with_effects',(huntnexus_effect_category_audit() #>> '{summary,items_with_static_effects}')::int,
  'negative_protection_rows',(huntnexus_effect_category_audit() #>> '{summary,negative_protection_rows}')::int,
  'pierce_perks',(huntnexus_effect_category_audit() #>> '{summary,proficiency_pierce_perks}')::int
) as regression_summary;
