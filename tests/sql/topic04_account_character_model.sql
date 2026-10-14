-- Topic 4 — account 1:N character isolation regression.
-- All identities, profiles and inventory below are SYNTHETIC and removed.
-- Run only after migration 0162 in a disposable/approved database.

do $$
declare
  v_auth_a uuid:=gen_random_uuid();
  v_auth_b uuid:=gen_random_uuid();
  v_client_a uuid:=gen_random_uuid();
  v_guest_profile jsonb;
  v_resolved jsonb;
  v_characters jsonb;
  v_character_a uuid;
  v_created_b jsonb;
  v_character_b uuid;
  v_scope_b jsonb;
  v_client_b uuid;
  v_wrong_owner jsonb;
  v_active jsonb;
  v_mismatch_blocked boolean:=false;
begin
  v_guest_profile:=public.huntnexus_player_profile_save(v_client_a,jsonb_build_object(
    'character_name','TOPIC04 SYNTHETIC EK',
    'world_name','SYNTHETIC',
    'vocation','EK',
    'level',700
  ));
  if v_guest_profile->>'saved'<>'true' then
    raise exception 'synthetic guest profile setup failed';
  end if;
  if (select character_id from public.player_character_profiles where client_id=v_client_a) is not null then
    raise exception 'unbound legacy guest data must remain unmapped';
  end if;

  v_resolved:=public.huntnexus_account_resolve(v_auth_a,v_client_a);
  if coalesce((v_resolved->>'resolved')::boolean,false) is not true then
    raise exception 'account resolve failed: %',v_resolved;
  end if;

  v_characters:=public.huntnexus_account_characters(v_auth_a);
  if jsonb_array_length(v_characters->'characters')<>1 then
    raise exception 'default character backfill failed: %',v_characters;
  end if;
  v_character_a:=(v_characters->>'active_character_id')::uuid;
  if (select character_id from public.player_character_profiles where client_id=v_client_a)<>v_character_a then
    raise exception 'guest profile was not attached to default character';
  end if;

  v_created_b:=public.huntnexus_character_create(v_auth_a,jsonb_build_object(
    'character_name','TOPIC04 SYNTHETIC MS',
    'world_name','SYNTHETIC',
    'vocation','MS',
    'level',650
  ));
  if coalesce((v_created_b->>'created')::boolean,false) is not true then
    raise exception 'second character creation failed: %',v_created_b;
  end if;
  v_character_b:=(v_created_b->>'character_id')::uuid;
  v_scope_b:=public.huntnexus_character_scope(v_auth_a,v_character_b);
  v_client_b:=(v_scope_b->>'legacy_client_id')::uuid;

  if v_character_a=v_character_b or v_client_a=v_client_b then
    raise exception 'character scopes were reused';
  end if;

  v_wrong_owner:=public.huntnexus_character_scope(v_auth_b,v_character_b);
  if v_wrong_owner->>'error'<>'character_not_found_or_not_owned' then
    raise exception 'foreign account resolved another character';
  end if;

  begin
    insert into public.player_character_inventory(
      client_id,character_id,storage_kind,selection_key,item_key,item_name,notes
    ) values(
      v_client_a,v_character_b,'backpack','weapon','topic04-mismatch','TOPIC04 SYNTHETIC','SYNTHETIC mismatch must fail'
    );
  exception when foreign_key_violation then
    v_mismatch_blocked:=true;
  end;
  if not v_mismatch_blocked then
    raise exception 'client_id/character_id mismatch was accepted';
  end if;

  insert into public.player_character_inventory(
    client_id,storage_kind,selection_key,item_key,item_name,notes
  ) values
    (v_client_a,'backpack','weapon','topic04-ek-item','TOPIC04 SYNTHETIC EK ITEM','SYNTHETIC'),
    (v_client_b,'backpack','weapon','topic04-ms-item','TOPIC04 SYNTHETIC MS ITEM','SYNTHETIC');

  if (select count(distinct character_id) from public.player_character_inventory
      where client_id in(v_client_a,v_client_b))<>2 then
    raise exception 'legacy inserts were not mapped to separate characters';
  end if;

  v_active:=public.huntnexus_character_set_active(v_auth_a,v_character_b);
  if coalesce((v_active->>'updated')::boolean,false) is not true then
    raise exception 'active character switch failed: %',v_active;
  end if;
  if (public.huntnexus_character_scope(v_auth_a,null)->>'character_id')::uuid<>v_character_b then
    raise exception 'active character scope did not switch';
  end if;

  if public.huntnexus_account_unbind(v_auth_a)->>'error'<>'private_data_present_unbind_blocked' then
    raise exception 'unbind did not protect multi-character private data';
  end if;

  delete from public.player_character_inventory where client_id in(v_client_a,v_client_b);
  delete from public.player_character_profiles where client_id in(v_client_a,v_client_b);

  if coalesce((public.huntnexus_account_unbind(v_auth_a)->>'unbound')::boolean,false) is not true then
    raise exception 'empty synthetic account did not unlink';
  end if;
  if exists(select 1 from public.huntnexus_accounts where auth_user_id=v_auth_a)
     or exists(select 1 from public.player_characters where id in(v_character_a,v_character_b)) then
    raise exception 'synthetic account cleanup left domain rows';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','topic04_account_character_model',
  'fixture','SYNTHETIC',
  'account_to_characters','1:N',
  'scope_mismatch_blocked',true,
  'authentication_changed',false
) as regression_summary;
