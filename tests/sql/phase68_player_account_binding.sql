-- Phase 68 — authenticated account binding / canonical client identity regression.

do $$
declare
  v_auth_a uuid := '11111111-aaaa-4aaa-8aaa-111111111111'::uuid;
  v_auth_b uuid := '22222222-bbbb-4bbb-8bbb-222222222222'::uuid;
  v_client_a uuid := 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa'::uuid;
  v_client_b uuid := 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb'::uuid;
  v_first jsonb;
  v_second jsonb;
  v_collision jsonb;
  v_status jsonb;
begin
  delete from public.player_account_bindings
  where auth_user_id in (v_auth_a,v_auth_b)
     or client_id in (v_client_a,v_client_b);

  v_first := public.huntnexus_account_resolve(v_auth_a,v_client_a);

  if coalesce((v_first->>'resolved')::boolean,false) is not true
     or coalesce((v_first->>'created')::boolean,false) is not true
     or v_first->>'canonical_client_id' <> v_client_a::text then
    raise exception 'Initial account binding regression';
  end if;

  -- Same account from another device must resolve to the original canonical client.
  v_second := public.huntnexus_account_resolve(v_auth_a,v_client_b);

  if coalesce((v_second->>'resolved')::boolean,false) is not true
     or coalesce((v_second->>'created')::boolean,true) is not false
     or coalesce((v_second->>'client_id_changed')::boolean,false) is not true
     or v_second->>'canonical_client_id' <> v_client_a::text then
    raise exception 'Cross-device canonical client resolution regression';
  end if;

  -- A second account cannot silently steal the first account's canonical client id.
  v_collision := public.huntnexus_account_resolve(v_auth_b,v_client_a);

  if v_collision->>'error' <> 'client_id_already_bound' then
    raise exception 'Account/client collision guard regression';
  end if;

  v_status := public.huntnexus_account_binding_status(v_auth_a);

  if coalesce((v_status->>'bound')::boolean,false) is not true
     or v_status->>'canonical_client_id' <> v_client_a::text then
    raise exception 'Account binding status regression';
  end if;

  if coalesce((public.huntnexus_account_unbind(v_auth_a)->>'private_data_deleted')::boolean,true) is not false then
    raise exception 'Unbind must not delete private player data';
  end if;

  v_status := public.huntnexus_account_binding_status(v_auth_a);

  if coalesce((v_status->>'bound')::boolean,true) is not false then
    raise exception 'Account unbind regression';
  end if;

  delete from public.player_account_bindings
  where auth_user_id in (v_auth_a,v_auth_b)
     or client_id in (v_client_a,v_client_b);
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_account_binding',
  'cross_device_resolution',true,
  'private_data_deleted_on_unbind',false
) as regression_summary;
