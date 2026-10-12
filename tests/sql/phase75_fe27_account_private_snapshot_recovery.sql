-- FE-27: purely synthetic SQL regression of account canonical ID and
-- historical session snapshots. No valid Supabase Auth JWT/email is exercised.
-- All fixtures are scoped to fresh UUIDs and deleted in this transaction.
do $$
declare
  v_auth_a uuid := gen_random_uuid();
  v_auth_b uuid := gen_random_uuid();
  v_device_a uuid := gen_random_uuid();
  v_device_b uuid := gen_random_uuid();
  v_profile jsonb;
  v_saved jsonb;
  v_choice jsonb;
  v_session jsonb;
  v_session_id uuid;
  v_original_snapshot jsonb;
  v_read jsonb;
  v_first jsonb;
  v_second jsonb;
  v_conflict jsonb;
  v_removed_id uuid;
begin
  v_profile := public.huntnexus_player_profile_save(v_device_a,'{
    "character_name":"FE27 Isolated Canonical Snapshot",
    "world_name":"RubinOT","vocation":"EK","level":700,
    "manual_stats":{"weapon_family":"sword"},
    "proficiency_selections":{},
    "defaults":{"hunt_objective":"balanced","set_objective":"balanced","party_size":1}
  }'::jsonb);
  if v_profile->>'saved' <> 'true' then
    raise exception 'FE27 failed to save initial profile: %',v_profile;
  end if;

  v_saved:=public.huntnexus_player_inventory_put(v_device_a,'main','soulshredder',1);
  if v_saved->>'saved'<>'true' then raise exception 'FE27 Main save failed'; end if;
  v_saved:=public.huntnexus_player_inventory_put(v_device_a,'backpack','gnome-sword',1);
  if v_saved->>'saved'<>'true' then raise exception 'FE27 BP save failed'; end if;
  v_removed_id:=(v_saved->>'inventory_id')::uuid;

  v_choice:=public.huntnexus_player_hunt_build_choice_save(
    v_device_a,'cobra-bastion','EK',700,
    '{"weapon":"gnome-sword"}'::jsonb,
    'owned_variant',
    '[{"selection_key":"weapon","item_key":"gnome-sword","item_name":"Gnome Sword"}]'::jsonb
  );
  if v_choice->>'saved'<>'true' then
    raise exception 'FE27 BP choice save failed: %',v_choice;
  end if;

  v_session:=public.huntnexus_player_session_save(
    v_device_a,
    '{"hunt":"FE27 SYNTHETIC; not an actual game Analyzer"}'::jsonb,
    '{"methodology":{"stage":"session_parser_v2"},
      "validation":{"has_primary_hunt_analyzer":true,"recognized_metric_count":2},
      "hunt_analyse":{"duration_seconds":3600,"xp_gain":123456,"balance_value":7890}
    }'::jsonb,
    '{"character":"FE27 Isolated Canonical Snapshot","server":"RubinOT",
      "vocation":"EK","level":"700","hunt_key":"cobra-bastion",
      "location":"SYNTHETIC FE27 regression",
      "observation":"FE27 synthetic cross-device session; NOT gameplay",
      "publishHighscores":false}'::jsonb
  );
  v_session_id:=(v_session->>'session_id')::uuid;
  if v_session->>'status'<>'parsed'
     or v_session->>'community_evidence_written'<>'false'
     or v_session->>'loadout_snapshot_source'<>'saved_hunt_choice' then
    raise exception 'FE27 private session fixture failed: %',v_session;
  end if;
  v_read:=public.huntnexus_player_session_detail(v_device_a,v_session_id);
  v_original_snapshot:=v_read->'loadout_snapshot';
  if v_original_snapshot #>> '{selection,weapon}'<>'gnome-sword' then
    raise exception 'FE27 session snapshot did not pin BP';
  end if;

  v_first:=public.huntnexus_account_resolve(v_auth_a,v_device_a);
  v_second:=public.huntnexus_account_resolve(v_auth_a,v_device_b);
  if v_first->>'created'<>'true'
     or v_second->>'created'<>'false'
     or v_second->>'canonical_client_id'<>v_device_a::text
     or v_second->>'guest_data_merge_applied'<>'false' then
    raise exception 'FE27 canonical resolve mismatch: % / %',v_first,v_second;
  end if;
  v_conflict:=public.huntnexus_account_resolve(v_auth_b,v_device_a);
  if v_conflict->>'error'<>'client_id_already_bound' then
    raise exception 'FE27 collision guard did not reject other auth: %',v_conflict;
  end if;

  v_read:=public.huntnexus_player_profile_get(v_device_a);
  if v_read #>> '{profile,character_name}'<>'FE27 Isolated Canonical Snapshot' then
    raise exception 'FE27 canonical Profile recovery failed';
  end if;
  v_read:=public.huntnexus_player_inventory_get(v_device_a);
  if v_read #>> '{main_set,weapon,item_key}'<>'soulshredder'
     or v_read #>> '{backpack,0,item_key}'<>'gnome-sword' then
    raise exception 'FE27 canonical Main/BP recovery failed';
  end if;
  v_read:=public.huntnexus_player_hunt_build_choice_get(v_device_a,'cobra-bastion','EK');
  if v_read #>> '{choice,selection,weapon}'<>'gnome-sword' then
    raise exception 'FE27 canonical hunt choice recovery failed';
  end if;
  v_read:=public.huntnexus_player_session_detail(v_device_a,v_session_id);
  if v_read->'loadout_snapshot' <> v_original_snapshot then
    raise exception 'FE27 canonical private session snapshot changed after sign-in';
  end if;

  v_read:=public.huntnexus_player_profile_get(v_device_b);
  if v_read->>'exists'<>'false' then
    raise exception 'FE27 device B should not auto-merge guest Profile';
  end if;
  v_read:=public.huntnexus_player_inventory_get(v_device_b);
  if v_read #>> '{summary,main_slots}'<>'0' then
    raise exception 'FE27 device B guest Main leak';
  end if;
  v_read:=public.huntnexus_player_hunt_build_choice_get(v_device_b,'cobra-bastion','EK');
  if v_read->>'exists'<>'false' then
    raise exception 'FE27 device B guest choice leak';
  end if;
  v_read:=public.huntnexus_player_session_detail(v_device_b,v_session_id);
  if v_read->>'error'<>'session_not_found' then
    raise exception 'FE27 device B guest session leak';
  end if;

  v_saved:=public.huntnexus_player_inventory_remove(v_device_a,v_removed_id);
  if v_saved->>'deleted'<>'true' then
    raise exception 'FE27 delete BP did not succeed';
  end if;
  v_read:=public.huntnexus_player_hunt_build_choice_get(v_device_a,'cobra-bastion','EK');
  if v_read->>'exists'<>'false' then
    raise exception 'FE27 removed BP did not invalidate stale choice';
  end if;
  v_read:=public.huntnexus_player_session_detail(v_device_a,v_session_id);
  if v_read->'loadout_snapshot' <> v_original_snapshot then
    raise exception 'FE27 old snapshot changed after removing BP';
  end if;

  -- FE-27: do not allow unbind to turn existing private data into an
  -- anonymously retrievable guest UUID. Auth binding must survive.
  v_saved:=public.huntnexus_account_unbind(v_auth_a);
  if v_saved->>'error'<>'private_data_present_unbind_blocked'
     or v_saved->>'unbound'<>'false' then
    raise exception 'FE27 unbind exposed private session or Profile: %',v_saved;
  end if;
  v_read:=public.huntnexus_account_binding_status(v_auth_a);
  if v_read->>'bound'<>'true' then
    raise exception 'FE27 protected canonical binding disappeared';
  end if;

  -- Explicit cleanup, never touch IDs outside this DO fixture.
  delete from public.player_hunt_sessions where client_id in (v_device_a,v_device_b);
  delete from public.player_hunt_build_choices where client_id in (v_device_a,v_device_b);
  delete from public.player_character_inventory where client_id in (v_device_a,v_device_b);
  delete from public.player_character_profiles where client_id in (v_device_a,v_device_b);

  -- Only now is the account empty enough to unlink safely.
  v_saved:=public.huntnexus_account_unbind(v_auth_a);
  if v_saved->>'unbound'<>'true' then
    raise exception 'FE27 empty-account unbind unexpectedly blocked: %',v_saved;
  end if;
  delete from public.player_account_bindings where auth_user_id in (v_auth_a,v_auth_b);
end $$;

select jsonb_build_object(
 'status','ok','stage','fe27_canonical_private_history_cross_device_sql_v1',
 'auth_users','synthetic UUIDs, no valid tokens',
 'profile_and_inventory_recovered',true,
 'hunt_choice_recovered',true,
 'private_session_snapshot_immutable',true,
 'second_guest_isolated',true,
 'collision_rejected',true,
 'guest_merge_applied',false,
 'private_data_unbind_blocked',true,
 'empty_account_unbind_succeeds',true,
 'real_magic_link_verified',false,
 'fixture_residue_expected',0
) result;
