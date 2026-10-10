-- HuntNexus FE-02 — private/browser-scoped player hunt imports.
-- Keeps player submissions separate from community evidence.

create table if not exists public.player_hunt_sessions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status text not null default 'parsed'
    check (status in ('draft','parsed','needs_review','error')),
  character_name text,
  server_name text,
  vocation text,
  level integer,
  hunt_name text,
  observation text,
  tags text[] not null default '{}',
  hunt_type text not null default 'normal'
    check (hunt_type in ('normal','bounty')),
  favorite boolean not null default false,
  publish_highscores boolean not null default false,
  raw_blocks jsonb not null default '{}'::jsonb,
  parsed_data jsonb not null default '{}'::jsonb,
  parser_version text not null default 'session_parser_v1'
);

create index if not exists player_hunt_sessions_client_created_idx
  on public.player_hunt_sessions(client_id, created_at desc);

alter table public.player_hunt_sessions enable row level security;

create or replace function public.huntnexus_player_session_save(
  p_client_id uuid,
  p_raw_blocks jsonb,
  p_parsed_data jsonb,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_id uuid;
  v_status text := case
    when coalesce((p_parsed_data #>> '{validation,has_primary_hunt_analyzer}')::boolean,false) = false then 'needs_review'
    when coalesce((p_parsed_data #>> '{validation,recognized_metric_count}')::int,0) = 0 then 'needs_review'
    else 'parsed'
  end;
begin
  if p_client_id is null then
    return jsonb_build_object('error','client_id_required');
  end if;

  insert into public.player_hunt_sessions(
    client_id,status,character_name,server_name,vocation,level,hunt_name,observation,
    tags,hunt_type,favorite,publish_highscores,raw_blocks,parsed_data,parser_version
  )
  values(
    p_client_id,
    v_status,
    nullif(trim(p_metadata->>'character'),''),
    nullif(trim(p_metadata->>'server'),''),
    nullif(trim(p_metadata->>'vocation'),''),
    case when coalesce(p_metadata->>'level','') ~ '^\d+$' then (p_metadata->>'level')::int else null end,
    nullif(trim(p_metadata->>'location'),''),
    nullif(trim(p_metadata->>'observation'),''),
    case when jsonb_typeof(p_metadata->'tags')='array'
      then array(select jsonb_array_elements_text(p_metadata->'tags'))
      else '{}'::text[] end,
    case when p_metadata->>'type'='bounty' then 'bounty' else 'normal' end,
    coalesce((p_metadata->>'favorite')::boolean,false),
    coalesce((p_metadata->>'publishHighscores')::boolean,false),
    coalesce(p_raw_blocks,'{}'::jsonb),
    coalesce(p_parsed_data,'{}'::jsonb),
    'session_parser_v1'
  )
  returning id into v_id;

  return jsonb_build_object(
    'session_id',v_id,
    'status',v_status,
    'parser_version','session_parser_v1',
    'community_evidence_written',false
  );
end;
$function$;

create or replace function public.huntnexus_player_session_list(
  p_client_id uuid,
  p_limit integer default 30
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with rows as (
  select
    id as session_id,
    created_at,
    status,
    character_name,
    server_name,
    vocation,
    level,
    hunt_name,
    hunt_type,
    favorite,
    parsed_data #>> '{hunt_analyse,duration_seconds}' as duration_seconds,
    parsed_data #>> '{hunt_analyse,xp_gain}' as xp_gain,
    parsed_data #>> '{hunt_analyse,xp_per_hour}' as xp_per_hour,
    parsed_data #>> '{hunt_analyse,balance_value}' as balance_value,
    parsed_data #>> '{hunt_analyse,total_damage}' as total_damage,
    parsed_data #>> '{hunt_analyse,total_healing}' as total_healing
  from public.player_hunt_sessions
  where client_id=p_client_id
  order by created_at desc
  limit least(greatest(coalesce(p_limit,30),1),100)
)
select jsonb_build_object(
  'sessions',coalesce(jsonb_agg(to_jsonb(rows) order by created_at desc),'[]'::jsonb),
  'summary',jsonb_build_object('returned',(select count(*) from rows)),
  'methodology',jsonb_build_object(
    'stage','player_session_list_v1',
    'community_evidence',false
  )
)
from rows;
$function$;

create or replace function public.huntnexus_player_session_detail(
  p_client_id uuid,
  p_session_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
select case
  when s.id is null then jsonb_build_object('error','session_not_found')
  else jsonb_build_object(
    'session',jsonb_build_object(
      'session_id',s.id,
      'created_at',s.created_at,
      'status',s.status,
      'character_name',s.character_name,
      'server_name',s.server_name,
      'vocation',s.vocation,
      'level',s.level,
      'hunt_name_raw',s.hunt_name,
      'hunt_type',s.hunt_type,
      'favorite',s.favorite
    ),
    'hunt_analyse',coalesce(s.parsed_data->'hunt_analyse','{}'::jsonb),
    'misc',coalesce(s.parsed_data->'misc','{}'::jsonb),
    'damage',coalesce(s.parsed_data->'damage','{}'::jsonb),
    'party_hunt',coalesce(s.parsed_data->'party_hunt','{}'::jsonb),
    'availability',coalesce(s.parsed_data->'availability','{}'::jsonb),
    'validation',coalesce(s.parsed_data->'validation','{}'::jsonb),
    'parser',jsonb_build_object(
      'version',s.parser_version,
      'raw_blocks_preserved',true,
      'community_evidence_written',false
    )
  )
end
from (
  select *
  from public.player_hunt_sessions
  where id=p_session_id and client_id=p_client_id
  limit 1
) s
right join (select 1 as anchor) a on true;
$function$;

revoke all on table public.player_hunt_sessions from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_save(uuid,jsonb,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_list(uuid,integer) from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_detail(uuid,uuid) from public,anon,authenticated;
grant execute on function public.huntnexus_player_session_save(uuid,jsonb,jsonb,jsonb) to service_role;
grant execute on function public.huntnexus_player_session_list(uuid,integer) to service_role;
grant execute on function public.huntnexus_player_session_detail(uuid,uuid) to service_role;
