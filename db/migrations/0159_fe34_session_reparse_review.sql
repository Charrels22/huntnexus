-- HuntNexus FE-34: owner-scoped, opt-in reparse, atomic revision preservation.
-- No existing sessions are changed by this migration. No real player data
-- returned publicly: only the server-side service role can execute these RPCs.

create table if not exists public.player_session_parse_revisions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null,
  session_id uuid not null references public.player_hunt_sessions(id) on delete cascade,
  revised_at timestamptz not null default now(),
  previous_parser_version text not null,
  previous_parsed_data jsonb not null,
  next_parser_version text not null,
  expected_fingerprint text not null
);
create index if not exists player_session_parse_revisions_owner_session_idx
  on public.player_session_parse_revisions(client_id,session_id,revised_at desc);
alter table public.player_session_parse_revisions enable row level security;
revoke all on public.player_session_parse_revisions from public,anon,authenticated;
grant select,insert on public.player_session_parse_revisions to service_role;

-- A concurrency fingerprint, NOT an authentication token. The existing API
-- authenticates bound client scopes before it invokes these service-only RPCs.
create or replace function public.huntnexus_player_session_reparse_source(
  p_client_id uuid,
  p_session_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
  select coalesce((
    select jsonb_build_object(
      'raw_blocks',s.raw_blocks,
      'parsed_data',s.parsed_data,
      'parser_version',s.parser_version,
      'status',s.status,
      'snapshot_source',s.loadout_snapshot->>'source',
      'fingerprint',md5(s.raw_blocks::text || chr(10) ||
         s.parsed_data::text || chr(10) || s.parser_version)
    )
    from public.player_hunt_sessions s
    where s.id=p_session_id and s.client_id=p_client_id
    limit 1
  ), jsonb_build_object('error','session_not_found'));
$function$;

create or replace function public.huntnexus_player_session_reparse_apply(
  p_client_id uuid,
  p_session_id uuid,
  p_expected_fingerprint text,
  p_parsed_data jsonb,
  p_confirm boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_row public.player_hunt_sessions%rowtype;
  v_fingerprint text;
  v_next_version text;
  v_next_status text;
  v_revision uuid;
begin
  if p_confirm is distinct from true then
    return jsonb_build_object('error','reparse_confirmation_required');
  end if;
  if p_client_id is null or p_session_id is null then
    return jsonb_build_object('error','session_not_found');
  end if;
  if p_expected_fingerprint is null or
      p_expected_fingerprint !~ '^[a-f0-9]{32}$' then
    return jsonb_build_object('error','reparse_fingerprint_invalid');
  end if;

  -- Serialize concurrent reparse requests and compare the source+prior
  -- parsed representation under the same row lock.
  select * into v_row
  from public.player_hunt_sessions
  where id=p_session_id and client_id=p_client_id
  for update;
  if not found then
    return jsonb_build_object('error','session_not_found');
  end if;
  v_fingerprint := md5(v_row.raw_blocks::text || chr(10) ||
    v_row.parsed_data::text || chr(10) || v_row.parser_version);
  if v_fingerprint <> p_expected_fingerprint then
    return jsonb_build_object('error','reparse_preview_stale');
  end if;

  if jsonb_typeof(p_parsed_data) <> 'object' or
     jsonb_typeof(p_parsed_data->'hunt_analyse') <> 'object' or
     jsonb_typeof(p_parsed_data->'validation') <> 'object' or
     jsonb_typeof(p_parsed_data->'methodology') <> 'object' then
    return jsonb_build_object('error','reparse_invalid_payload');
  end if;
  v_next_version := nullif(trim(p_parsed_data #>> '{methodology,stage}'),'');
  if v_next_version is null or v_next_version <> 'session_parser_v2' then
    return jsonb_build_object('error','reparse_invalid_parser_version');
  end if;
  if coalesce((p_parsed_data #>> '{validation,recognized_metric_count}')::integer,0) < 1
     or coalesce((p_parsed_data #>> '{validation,has_primary_hunt_analyzer}')::boolean,false) = false then
    return jsonb_build_object('error','reparse_invalid_primary_metrics');
  end if;

  if v_row.parsed_data = p_parsed_data and v_row.parser_version = v_next_version then
    return jsonb_build_object('error','reparse_no_changes');
  end if;
  v_next_status := 'parsed';

  insert into public.player_session_parse_revisions(
    client_id,session_id,previous_parser_version,previous_parsed_data,
    next_parser_version,expected_fingerprint
  ) values(
    p_client_id,p_session_id,v_row.parser_version,v_row.parsed_data,
    v_next_version,v_fingerprint
  ) returning id into v_revision;

  -- Deliberately NEVER update raw_blocks, loadout_snapshot, hunt_key,
  -- metadata, ownership or timestamps of the actual gameplay session.
  update public.player_hunt_sessions
  set parsed_data=p_parsed_data,parser_version=v_next_version,
      status=v_next_status,updated_at=now()
  where id=p_session_id and client_id=p_client_id;

  return jsonb_build_object(
    'updated',true,
    'session_id',p_session_id,
    'new_parser_version',v_next_version,
    'revision_id',v_revision,
    'raw_blocks_preserved',true,
    'loadout_snapshot_preserved',true,
    'community_evidence_written',false
  );
end;
$function$;

revoke all on function public.huntnexus_player_session_reparse_source(uuid,uuid)
  from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_reparse_apply(uuid,uuid,text,jsonb,boolean)
  from public,anon,authenticated;
grant execute on function public.huntnexus_player_session_reparse_source(uuid,uuid) to service_role;
grant execute on function public.huntnexus_player_session_reparse_apply(uuid,uuid,text,jsonb,boolean) to service_role;
