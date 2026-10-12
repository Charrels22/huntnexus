-- HuntNexus FE-35: explicit, auditable restoration of historical parser revisions.
-- Existing rows unchanged. All reads/writes are service_role-only and scoped to
-- the same private client_id + session_id as the earlier session functions.

create or replace function public.huntnexus_player_session_revision_list(
  p_client_id uuid,
  p_session_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_exists boolean;
  v_rows jsonb;
begin
  select exists(
    select 1 from public.player_hunt_sessions
    where id=p_session_id and client_id=p_client_id
  ) into v_exists;
  if not v_exists then
    return jsonb_build_object('error','session_not_found');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'revision_id',r.id,
    'revised_at',r.revised_at,
    'previous_parser_version',r.previous_parser_version,
    'next_parser_version',r.next_parser_version
  ) order by r.revised_at desc,r.id desc),'[]'::jsonb)
  into v_rows
  from (
    select id,revised_at,previous_parser_version,next_parser_version
    from public.player_session_parse_revisions
    where client_id=p_client_id and session_id=p_session_id
    order by revised_at desc,id desc
    limit 30
  ) r;
  return jsonb_build_object('session_id',p_session_id,'revisions',v_rows);
end;
$function$;

create or replace function public.huntnexus_player_session_revision_restore_source(
  p_client_id uuid,
  p_session_id uuid,
  p_revision_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
select coalesce((
  select jsonb_build_object(
    'session_id',s.id,
    'revision_id',r.id,
    'revised_at',r.revised_at,
    'current_parsed_data',s.parsed_data,
    'current_parser_version',s.parser_version,
    'target_parsed_data',r.previous_parsed_data,
    'target_parser_version',r.previous_parser_version,
    'snapshot_source',s.loadout_snapshot->>'source',
    'fingerprint',md5(s.raw_blocks::text || chr(10) ||
      s.parsed_data::text || chr(10) || s.parser_version)
  )
  from public.player_hunt_sessions s
  join public.player_session_parse_revisions r
    on r.session_id=s.id and r.client_id=s.client_id
  where s.id=p_session_id and s.client_id=p_client_id and r.id=p_revision_id
  limit 1
),jsonb_build_object('error','revision_not_found'));
$function$;

create or replace function public.huntnexus_player_session_revision_restore(
  p_client_id uuid,
  p_session_id uuid,
  p_revision_id uuid,
  p_expected_fingerprint text,
  p_confirm boolean default false,
  p_accept_regressions boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_row public.player_hunt_sessions%rowtype;
  v_revision public.player_session_parse_revisions%rowtype;
  v_fingerprint text;
  v_audit_id uuid;
begin
  if p_confirm is distinct from true then
    return jsonb_build_object('error','restore_confirmation_required');
  end if;
  if p_expected_fingerprint is null or
     p_expected_fingerprint !~ '^[a-f0-9]{32}$' then
    return jsonb_build_object('error','restore_fingerprint_invalid');
  end if;

  select * into v_row
  from public.player_hunt_sessions
  where client_id=p_client_id and id=p_session_id
  for update;
  if not found then return jsonb_build_object('error','session_not_found'); end if;

  -- Every restore target must have been recorded before by the server.
  select * into v_revision
  from public.player_session_parse_revisions
  where id=p_revision_id and client_id=p_client_id and session_id=p_session_id;
  if not found then return jsonb_build_object('error','revision_not_found'); end if;

  v_fingerprint := md5(v_row.raw_blocks::text || chr(10) ||
    v_row.parsed_data::text || chr(10) || v_row.parser_version);
  if v_fingerprint <> p_expected_fingerprint then
    return jsonb_build_object('error','restore_preview_stale');
  end if;
  if v_row.parsed_data = v_revision.previous_parsed_data and
     v_row.parser_version = v_revision.previous_parser_version then
    return jsonb_build_object('error','restore_no_changes');
  end if;
  -- The public API recomputes the diff and blocks regressions unless the
  -- player checked the additional explicit warning. Preserve this consent in
  -- the RPC signature, so accidental calls cannot apply without a decision.
  if p_accept_regressions is distinct from true then
    return jsonb_build_object('error','restore_accept_data_loss_required');
  end if;
  if jsonb_typeof(v_revision.previous_parsed_data) <> 'object' or
     jsonb_typeof(v_revision.previous_parsed_data->'hunt_analyse') <> 'object' then
    return jsonb_build_object('error','restore_revision_invalid');
  end if;
  if coalesce(v_revision.previous_parser_version,'') not in
      ('session_parser_v1','session_parser_v2') then
    return jsonb_build_object('error','restore_revision_invalid_version');
  end if;

  -- Append an undoable audit record of the current interpretation before
  -- writing historical data. A restored version can itself be restored later.
  insert into public.player_session_parse_revisions(
    client_id,session_id,previous_parser_version,previous_parsed_data,
    next_parser_version,expected_fingerprint
  )
  values (
    p_client_id,p_session_id,v_row.parser_version,v_row.parsed_data,
    v_revision.previous_parser_version,v_fingerprint
  ) returning id into v_audit_id;

  update public.player_hunt_sessions
  set parsed_data=v_revision.previous_parsed_data,
      parser_version=v_revision.previous_parser_version,
      status=case
        when coalesce((v_revision.previous_parsed_data #>> '{validation,has_primary_hunt_analyzer}')::boolean,false)=false
          or coalesce((v_revision.previous_parsed_data #>> '{validation,recognized_metric_count}')::integer,0)=0
        then 'needs_review'
        else 'parsed'
      end,
      updated_at=now()
  where id=p_session_id and client_id=p_client_id;

  return jsonb_build_object(
    'restored',true,
    'session_id',p_session_id,
    'restored_revision_id',p_revision_id,
    'undo_revision_id',v_audit_id,
    'parser_version',v_revision.previous_parser_version,
    'raw_blocks_preserved',true,
    'loadout_snapshot_preserved',true,
    'community_evidence_written',false
  );
end;
$function$;

revoke all on function public.huntnexus_player_session_revision_list(uuid,uuid)
from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_revision_restore_source(uuid,uuid,uuid)
from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_revision_restore(uuid,uuid,uuid,text,boolean,boolean)
from public,anon,authenticated;
grant execute on function public.huntnexus_player_session_revision_list(uuid,uuid) to service_role;
grant execute on function public.huntnexus_player_session_revision_restore_source(uuid,uuid,uuid) to service_role;
grant execute on function public.huntnexus_player_session_revision_restore(uuid,uuid,uuid,text,boolean,boolean) to service_role;
