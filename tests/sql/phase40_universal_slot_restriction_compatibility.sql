-- Focused regression for universal slot/restriction compatibility.

do $$
declare
  v_ek_one jsonb;
  v_ek_two jsonb;
  v_rp_bow jsonb;
  v_rp_missing jsonb;
  v_rp_wrong_ammo jsonb;
  v_ed jsonb;
  v_wrong_slot jsonb;
  v_wrong_voc jsonb;
  v_container jsonb;
  v_audit jsonb;
begin
  if (select count(*) from loadout_slot_rules) <> 10 then
    raise exception 'Loadout slot rule count regression';
  end if;

  if (select count(*) from vw_loadout_item_catalog_universal) <> 1570 then
    raise exception 'Universal loadout item catalog count regression';
  end if;

  v_ek_one := huntnexus_loadout_compatibility_universal(
    'EK',700,
    '{"weapon":"grand-sanguine-blade","offhand":"shield-of-corruption","body":"lion-plate"}'::jsonb
  );
  if v_ek_one->>'status' <> 'valid'
     or coalesce((v_ek_one #>> '{weapon_dependency_summary,complete}')::boolean,false) is not true then
    raise exception 'EK one-hand loadout regression';
  end if;

  v_ek_two := huntnexus_loadout_compatibility_universal(
    'EK',700,
    '{"weapon":"soulshredder","offhand":"shield-of-corruption"}'::jsonb
  );
  if v_ek_two->>'status' <> 'blocked'
     or not exists (
       select 1 from jsonb_array_elements(v_ek_two->'combination_issues') x
       where x->>'issue'='two_handed_weapon_blocks_offhand'
         and x->>'severity'='blocked'
     ) then
    raise exception 'Two-handed offhand blocking regression';
  end if;

  v_rp_bow := huntnexus_loadout_compatibility_universal(
    'RP',1000,
    '{"weapon":"moonsilver-bow","offhand":"alicorn-quiver","ammunition":"crystalline-arrow","head":"falcon-coif"}'::jsonb
  );
  if v_rp_bow->>'status' <> 'valid'
     or (v_rp_bow #>> '{weapon_dependency_summary,weapon_family}') <> 'bow'
     or (v_rp_bow #>> '{weapon_dependency_summary,offhand_family}') <> 'quiver'
     or (v_rp_bow #>> '{weapon_dependency_summary,ammunition_family}') <> 'arrow' then
    raise exception 'Bow/quiver/ammunition exception regression';
  end if;

  v_rp_missing := huntnexus_loadout_compatibility_universal(
    'RP',1000,'{"weapon":"moonsilver-bow"}'::jsonb
  );
  if v_rp_missing->>'status' <> 'incomplete'
     or not exists (
       select 1 from jsonb_array_elements(v_rp_missing->'combination_issues') x
       where x->>'issue'='required_quiver_missing'
     )
     or not exists (
       select 1 from jsonb_array_elements(v_rp_missing->'combination_issues') x
       where x->>'issue'='required_ammunition_missing'
     ) then
    raise exception 'Missing Bow dependency regression';
  end if;

  v_rp_wrong_ammo := huntnexus_loadout_compatibility_universal(
    'RP',1000,
    '{"weapon":"moonsilver-bow","offhand":"alicorn-quiver","ammunition":"spectral-bolt"}'::jsonb
  );
  if v_rp_wrong_ammo->>'status' <> 'blocked'
     or not exists (
       select 1 from jsonb_array_elements(v_rp_wrong_ammo->'combination_issues') x
       where x->>'issue'='ammunition_family_mismatch'
     ) then
    raise exception 'Ammunition family mismatch regression';
  end if;

  v_ed := huntnexus_loadout_compatibility_universal(
    'ED',700,
    '{"weapon":"soulhexer","offhand":"lion-spellbook"}'::jsonb
  );
  if v_ed->>'status' <> 'valid' then
    raise exception 'Caster one-hand + spellbook regression';
  end if;

  v_wrong_slot := huntnexus_loadout_compatibility_universal(
    'EK',700,'{"head":"lion-plate"}'::jsonb
  );
  if v_wrong_slot->>'status' <> 'blocked'
     or not exists (
       select 1 from jsonb_array_elements(v_wrong_slot->'slot_evaluations') x
       where (x->'issues') ? 'wrong_slot'
     ) then
    raise exception 'Wrong slot regression';
  end if;

  v_wrong_voc := huntnexus_loadout_compatibility_universal(
    'RP',700,'{"body":"lion-plate"}'::jsonb
  );
  if v_wrong_voc->>'status' <> 'blocked'
     or not exists (
       select 1 from jsonb_array_elements(v_wrong_voc->'slot_evaluations') x
       where (x->'issues') ? 'vocation_restriction'
     ) then
    raise exception 'Vocation restriction regression';
  end if;

  if huntnexus_loadout_compatibility_universal(
       'RP',700,'{"weapon":"moonsilver-bow"}'::jsonb
     )->>'status' <> 'blocked' then
    raise exception 'Level restriction regression';
  end if;

  v_container := huntnexus_loadout_compatibility_universal(
    'EK',700,'{"container":"backpack"}'::jsonb
  );
  if v_container->>'status' <> 'incomplete'
     or not exists (
       select 1 from jsonb_array_elements(v_container->'slot_evaluations') x
       where (x->'issues') ? 'catalog_out_of_scope'
     ) then
    raise exception 'Container scope regression';
  end if;

  if huntnexus_loadout_compatibility_universal(
       'UNKNOWN',700,'{}'::jsonb
     )->>'error' <> 'unsupported_vocation' then
    raise exception 'Unsupported vocation regression';
  end if;

  if huntnexus_loadout_compatibility_universal(
       'EK',700,'[]'::jsonb
     )->>'error' <> 'selection_must_be_object' then
    raise exception 'Selection input contract regression';
  end if;

  v_audit := huntnexus_slot_compatibility_audit();
  if v_audit #>> '{methodology,stage}' <> 'slot_compatibility_audit_v1'
     or coalesce((v_audit #>> '{summary,slot_contract_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,weapon_offhand_dependency_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,vocation_level_restriction_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,container_catalog_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_loadout_optimizer_ready}')::boolean,true) is not false then
    raise exception 'Slot compatibility audit semantics regression';
  end if;

  if has_table_privilege('anon','public.loadout_slot_rules','SELECT')
     or has_table_privilege('authenticated','public.loadout_slot_rules','SELECT')
     or has_table_privilege('anon','public.vw_loadout_item_catalog_universal','SELECT')
     or has_table_privilege('authenticated','public.vw_loadout_item_catalog_universal','SELECT') then
    raise exception 'Slot compatibility objects must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_slot_restriction_compatibility',
  'selection_rules',(select count(*) from loadout_slot_rules),
  'catalog_items',(select count(*) from vw_loadout_item_catalog_universal),
  'supported_selection_keys',(huntnexus_slot_compatibility_audit() #>> '{summary,supported_selection_keys}')::int,
  'slot_contract_ready',(huntnexus_slot_compatibility_audit() #>> '{summary,slot_contract_ready}')::boolean
) as regression_summary;
