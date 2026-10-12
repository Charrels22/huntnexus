-- FE-27: fail closed when unlinking an account would expose orphaned
-- Profile, Main/BP, hunt choices or sessions via an anonymous client_id.
-- Explicit sign-out is distinct from unlinking: logout keeps binding protected.
-- Unbinding an EMPTY account remains supported.
create or replace function public.huntnexus_account_unbind(
  p_auth_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_client uuid;
  v_count integer;
begin
  if p_auth_user_id is null then
    return jsonb_build_object('unbound',false,'error','auth_user_id_required',
      'private_data_deleted',false);
  end if;

  -- Serialize with simultaneous resolve and concurrent unlink for this user.
  perform pg_advisory_xact_lock(20261011,hashtext(p_auth_user_id::text));

  select client_id into v_client
  from public.player_account_bindings
  where auth_user_id=p_auth_user_id
  for update;

  if v_client is null then
    return jsonb_build_object('unbound',false,'private_data_deleted',false);
  end if;

  if exists(select 1 from public.player_character_profiles p where p.client_id=v_client)
     or exists(select 1 from public.player_character_inventory i where i.client_id=v_client)
     or exists(select 1 from public.player_hunt_build_choices c where c.client_id=v_client)
     or exists(select 1 from public.player_hunt_sessions s where s.client_id=v_client)
  then
    return jsonb_build_object(
      'unbound',false,
      'error','private_data_present_unbind_blocked',
      'private_data_deleted',false,
      'canonical_client_id_still_protected',true
    );
  end if;

  delete from public.player_account_bindings
  where auth_user_id=p_auth_user_id and client_id=v_client;
  get diagnostics v_count=row_count;

  return jsonb_build_object(
    'unbound',v_count=1,
    'private_data_deleted',false
  );
end;
$function$;

revoke all on function public.huntnexus_account_unbind(uuid) from public,anon,authenticated;
grant execute on function public.huntnexus_account_unbind(uuid) to service_role;
