-- FE-20 / Phase 73: canonical identity really recovers private Profile/Main/BP.
-- Synthetic isolated fixture, NOT real Magic Link delivery or browser login.
-- No existing player data is modified and no guest data is silently merged.
do $$
declare
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
  v_device_a uuid := gen_random_uuid();
  v_device_b uuid := gen_random_uuid();
  v_save jsonb;
  v_first jsonb;
  v_second jsonb;
  v_lookup jsonb;
  v_other jsonb;
  v_status jsonb;
begin
  v_save := public.huntnexus_player_profile_save(v_device_a, '{
    "character_name":"FE20 Isolated Fixture",
    "world_name":"RubinOT",
    "vocation":"EK",
    "level":700,
    "manual_stats":{"weapon_family":"sword","effective_weapon_skill":120},
    "defaults":{"hunt_objective":"xp","set_objective":"balanced","party_size":1}
  }'::jsonb);
  if v_save->>'saved' <> 'true' then
    raise exception 'Fixture profile failed to save: %',v_save;
  end if;

  v_save := public.huntnexus_player_inventory_put(v_device_a,'main','soulshredder',1);
  if v_save->>'saved' <> 'true' then
    raise exception 'Fixture Main item failed to save';
  end if;
  v_save := public.huntnexus_player_inventory_put(v_device_a,'backpack','falcon-longsword',1);
  if v_save->>'saved' <> 'true' then
    raise exception 'Fixture BP item failed to save';
  end if;

  v_first := public.huntnexus_account_resolve(v_user_a,v_device_a);
  v_second := public.huntnexus_account_resolve(v_user_a,v_device_b);
  if v_first->>'resolved' <> 'true'
     or v_first->>'created' <> 'true'
     or v_second->>'resolved' <> 'true'
     or v_second->>'created' <> 'false'
     or v_second->>'client_id_changed' <> 'true'
     or v_second->>'canonical_client_id' <> v_device_a::text
     or v_second->>'guest_data_merge_applied' <> 'false' then
    raise exception 'Cross-device canonical resolution mismatch: % / %',v_first,v_second;
  end if;

  v_lookup := public.huntnexus_player_profile_get(
    (v_second->>'canonical_client_id')::uuid
  );
  if v_lookup #>> '{profile,character_name}' <> 'FE20 Isolated Fixture'
     or v_lookup #>> '{profile,vocation}' <> 'EK' then
    raise exception 'Canonical profile recovery failed';
  end if;

  v_lookup := public.huntnexus_player_inventory_get(
    (v_second->>'canonical_client_id')::uuid
  );
  if v_lookup #>> '{main_set,weapon,item_key}' <> 'soulshredder'
     or (v_lookup #>> '{summary,backpack_items}')::integer <> 1
     or v_lookup #>> '{backpack,0,item_key}' <> 'falcon-longsword' then
    raise exception 'Canonical Main/BP recovery failed';
  end if;

  v_lookup := public.huntnexus_player_profile_get(v_device_b);
  if coalesce((v_lookup->>'exists')::boolean,false) then
    raise exception 'Guest device must not automatically adopt private profile';
  end if;

  v_other := public.huntnexus_account_resolve(v_user_b,v_device_a);
  if v_other->>'error' <> 'client_id_already_bound' then
    raise exception 'Another user can claim a canonical client ID';
  end if;

  v_status := public.huntnexus_account_binding_status(v_user_a);
  if v_status->>'canonical_client_id' <> v_device_a::text then
    raise exception 'Account status mismatches canonical client';
  end if;

  perform public.huntnexus_account_unbind(v_user_a);
  v_lookup := public.huntnexus_player_profile_get(v_device_a);
  if v_lookup #>> '{profile,character_name}' <> 'FE20 Isolated Fixture' then
    raise exception 'Unbinding account incorrectly deleted private data';
  end if;

  delete from public.player_character_inventory where client_id in (v_device_a,v_device_b);
  delete from public.player_character_profiles where client_id in (v_device_a,v_device_b);
  delete from public.player_account_bindings where auth_user_id in (v_user_a,v_user_b);
end $$;

select jsonb_build_object(
 'status','ok','stage','canonical_private_profile_main_bp_cross_device_v1',
 'two_device_resolution',true,
 'account_collision_rejected',true,
 'guest_data_merge_applied',false,
 'private_data_deleted_on_unbind',false,
 'real_magic_link_email_delivery_tested',false
) as result;
