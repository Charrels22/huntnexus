-- FE-20: account identity concurrent-login guard.
-- Preserve canonical client ID deterministically when two devices authenticate
-- simultaneously. The lock is user-scoped and lasts only one SQL transaction.
-- Unbind takes the same lock to avoid interleaving with a concurrent resolve.
create or replace function public.huntnexus_account_resolve(
  p_auth_user_id uuid,
  p_local_client_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_existing_client uuid;
  v_other_auth uuid;
begin
  if p_auth_user_id is null then
    return jsonb_build_object('error','auth_user_id_required');
  end if;

  if p_local_client_id is null then
    return jsonb_build_object('error','local_client_id_required');
  end if;

  -- Serialize the initial canonical-client choice for this auth user.
  -- Otherwise simultaneous sign-ins from two devices can both observe
  -- "not bound" and one throws a unique_constraint/HTTP 502.
  perform pg_advisory_xact_lock(20261011,hashtext(p_auth_user_id::text));

  select client_id
    into v_existing_client
  from public.player_account_bindings
  where auth_user_id=p_auth_user_id
  limit 1;

  if v_existing_client is not null then
    update public.player_account_bindings
    set last_seen_at=now(),updated_at=now()
    where auth_user_id=p_auth_user_id;

    return jsonb_build_object(
      'resolved',true,
      'created',false,
      'canonical_client_id',v_existing_client,
      'local_client_id',p_local_client_id,
      'client_id_changed',v_existing_client<>p_local_client_id,
      'guest_data_merge_applied',false
    );
  end if;

  select auth_user_id
    into v_other_auth
  from public.player_account_bindings
  where client_id=p_local_client_id
  limit 1;

  if v_other_auth is not null and v_other_auth<>p_auth_user_id then
    return jsonb_build_object(
      'error','client_id_already_bound',
      'resolved',false
    );
  end if;

  insert into public.player_account_bindings(
    auth_user_id,client_id,created_at,updated_at,last_seen_at
  )
  values(
    p_auth_user_id,p_local_client_id,now(),now(),now()
  );

  return jsonb_build_object(
    'resolved',true,
    'created',true,
    'canonical_client_id',p_local_client_id,
    'local_client_id',p_local_client_id,
    'client_id_changed',false,
    'guest_data_merge_applied',false
  );
end;
$function$;

create or replace function public.huntnexus_account_unbind(
  p_auth_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_count integer;
begin
  if p_auth_user_id is null then
    return jsonb_build_object('unbound',false,'error','auth_user_id_required','private_data_deleted',false);
  end if;
  perform pg_advisory_xact_lock(20261011,hashtext(p_auth_user_id::text));
  delete from public.player_account_bindings
  where auth_user_id=p_auth_user_id;

  get diagnostics v_count=row_count;

  return jsonb_build_object(
    'unbound',v_count=1,
    'private_data_deleted',false
  );
end;
$function$;

revoke all on function public.huntnexus_account_resolve(uuid,uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_account_unbind(uuid) from public,anon,authenticated;
grant execute on function public.huntnexus_account_resolve(uuid,uuid) to service_role;
grant execute on function public.huntnexus_account_unbind(uuid) to service_role;
