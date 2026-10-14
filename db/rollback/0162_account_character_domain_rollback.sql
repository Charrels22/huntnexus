-- EMERGENCY ROLLBACK PLAN for migration 0162.
-- Destructive: execute only with explicit approval and a verified backup.
-- It refuses to run after true multi-character data exists because dropping
-- character_id would collapse ownership back to legacy client_id.

do $$
begin
  if exists(
    select 1
    from public.huntnexus_accounts a
    left join public.player_account_bindings b on b.account_id=a.id
    left join public.player_characters c on c.account_id=a.id
    group by a.id
    having count(distinct b.auth_user_id)<>1
       or count(distinct c.id)<>1
       or bool_or(c.legacy_client_id is distinct from b.client_id)
  ) then
    raise exception 'topic04_rollback_refused_multi_character_or_unbound_account_data';
  end if;

  if exists(
    select 1 from public.player_character_profiles p
    join public.player_characters c on c.id=p.character_id
    where p.client_id<>c.legacy_client_id
  ) or exists(
    select 1 from public.player_character_inventory i
    join public.player_characters c on c.id=i.character_id
    where i.client_id<>c.legacy_client_id
  ) or exists(
    select 1 from public.player_hunt_build_choices b
    join public.player_characters c on c.id=b.character_id
    where b.client_id<>c.legacy_client_id
  ) or exists(
    select 1 from public.player_hunt_sessions s
    join public.player_characters c on c.id=s.character_id
    where s.client_id<>c.legacy_client_id
  ) or exists(
    select 1 from public.player_session_parse_revisions r
    join public.player_characters c on c.id=r.character_id
    where r.client_id<>c.legacy_client_id
  ) then
    raise exception 'topic04_rollback_refused_scope_mismatch';
  end if;
end $$;

drop trigger if exists player_account_bindings_cleanup on public.player_account_bindings;
drop trigger if exists player_account_bindings_provision on public.player_account_bindings;
drop trigger if exists player_character_profiles_identity_sync on public.player_character_profiles;
drop trigger if exists player_character_profiles_character_scope on public.player_character_profiles;
drop trigger if exists player_character_inventory_character_scope on public.player_character_inventory;
drop trigger if exists player_hunt_build_choices_character_scope on public.player_hunt_build_choices;
drop trigger if exists player_hunt_sessions_character_scope on public.player_hunt_sessions;
drop trigger if exists player_session_parse_revisions_character_scope on public.player_session_parse_revisions;

drop function if exists public.huntnexus_account_characters(uuid);
drop function if exists public.huntnexus_character_create(uuid,jsonb);
drop function if exists public.huntnexus_character_set_active(uuid,uuid);
drop function if exists public.huntnexus_character_scope(uuid,uuid);
drop function if exists public.huntnexus_account_binding_cleanup();
drop function if exists public.huntnexus_account_binding_provision();
drop function if exists public.huntnexus_profile_character_identity_sync();
drop function if exists public.huntnexus_private_character_scope();

alter table public.player_character_profiles drop constraint if exists player_character_profiles_scope_fk;
alter table public.player_character_inventory drop constraint if exists player_character_inventory_scope_fk;
alter table public.player_hunt_build_choices drop constraint if exists player_hunt_build_choices_scope_fk;
alter table public.player_hunt_sessions drop constraint if exists player_hunt_sessions_scope_fk;
alter table public.player_session_parse_revisions drop constraint if exists player_session_parse_revisions_scope_fk;

drop index if exists public.player_character_profiles_character_uq;
drop index if exists public.player_character_inventory_character_main_slot_uq;
drop index if exists public.player_character_inventory_character_backpack_item_uq;
drop index if exists public.player_character_inventory_character_idx;
drop index if exists public.player_hunt_build_choices_character_uq;
drop index if exists public.player_hunt_sessions_character_created_idx;
drop index if exists public.player_session_parse_revisions_character_session_idx;

alter table public.player_character_profiles drop column if exists character_id;
alter table public.player_character_inventory drop column if exists character_id;
alter table public.player_hunt_build_choices drop column if exists character_id;
alter table public.player_hunt_sessions drop column if exists character_id;
alter table public.player_session_parse_revisions drop column if exists character_id;

alter table public.player_account_bindings drop constraint if exists player_account_bindings_account_uq;
alter table public.player_account_bindings drop constraint if exists player_account_bindings_account_fk;
alter table public.player_account_bindings drop column if exists account_id;

alter table public.huntnexus_accounts drop constraint if exists huntnexus_accounts_active_character_owner_fk;
drop table if exists public.player_characters;
drop table if exists public.huntnexus_accounts;

-- Restore the pre-0162 FE-27 unbind guard exactly at legacy client scope.
create or replace function public.huntnexus_account_unbind(p_auth_user_id uuid)
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
    return jsonb_build_object('unbound',false,'error','auth_user_id_required','private_data_deleted',false);
  end if;
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
      'unbound',false,'error','private_data_present_unbind_blocked',
      'private_data_deleted',false,'canonical_client_id_still_protected',true
    );
  end if;
  delete from public.player_account_bindings where auth_user_id=p_auth_user_id and client_id=v_client;
  get diagnostics v_count=row_count;
  return jsonb_build_object('unbound',v_count=1,'private_data_deleted',false);
end;
$function$;

revoke all on function public.huntnexus_account_unbind(uuid) from public,anon,authenticated;
grant execute on function public.huntnexus_account_unbind(uuid) to service_role;
