-- HuntNexus FE-15 — session parser v2 provenance.
-- Persist the parser stage reported by parsed_data instead of hardcoding v1.

alter table public.player_hunt_sessions
  alter column parser_version set default 'session_parser_v2';

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
  v_hunt_key text := nullif(trim(p_metadata->>'hunt_key'),'');
  v_vocation text := nullif(trim(p_metadata->>'vocation'),'');
  v_loadout jsonb := '{}'::jsonb;
  v_parser_version text := coalesce(
    nullif(trim(p_parsed_data #>> '{methodology,stage}'),''),
    'session_parser_v2'
  );
  v_status text := case
    when coalesce((p_parsed_data #>> '{validation,has_primary_hunt_analyzer}')::boolean,false) = false then 'needs_review'
    when coalesce((p_parsed_data #>> '{validation,recognized_metric_count}')::int,0) = 0 then 'needs_review'
    else 'parsed'
  end;
begin
  if p_client_id is null then
    return jsonb_build_object('error','client_id_required');
  end if;

  if v_hunt_key is not null and v_vocation is not null then
    v_loadout := huntnexus_player_session_loadout_snapshot(
      p_client_id,
      v_hunt_key,
      v_vocation
    ) || jsonb_build_object('captured_at',now());
  else
    v_loadout := jsonb_build_object(
      'source','not_available',
      'option_type',null,
      'selection','{}'::jsonb,
      'replacements','[]'::jsonb,
      'items','[]'::jsonb,
      'captured_at',now(),
      'main_set_mutated',false
    );
  end if;

  insert into public.player_hunt_sessions(
    client_id,status,character_name,server_name,vocation,level,hunt_key,hunt_name,observation,
    tags,hunt_type,favorite,publish_highscores,raw_blocks,parsed_data,parser_version,loadout_snapshot
  )
  values(
    p_client_id,
    v_status,
    nullif(trim(p_metadata->>'character'),''),
    nullif(trim(p_metadata->>'server'),''),
    v_vocation,
    case when coalesce(p_metadata->>'level','') ~ '^\d+$' then (p_metadata->>'level')::int else null end,
    v_hunt_key,
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
    v_parser_version,
    v_loadout
  )
  returning id into v_id;

  return jsonb_build_object(
    'session_id',v_id,
    'status',v_status,
    'parser_version',v_parser_version,
    'hunt_key',v_hunt_key,
    'loadout_snapshot_source',v_loadout->>'source',
    'community_evidence_written',false
  );
end;
$function$;

revoke all on function public.huntnexus_player_session_save(uuid,jsonb,jsonb,jsonb)
from public,anon,authenticated;
grant execute on function public.huntnexus_player_session_save(uuid,jsonb,jsonb,jsonb)
to service_role;
