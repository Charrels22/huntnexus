-- HuntNexus FE-02 — private session cleanup and list enrichment.

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
    parsed_data #>> '{hunt_analyse,total_healing}' as total_healing,
    parsed_data #>> '{hunt_analyse,party_size}' as party_size
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

create or replace function public.huntnexus_player_session_delete(
  p_client_id uuid,
  p_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_count integer;
begin
  delete from public.player_hunt_sessions
  where id=p_session_id and client_id=p_client_id;

  get diagnostics v_count = row_count;

  return jsonb_build_object(
    'deleted',v_count=1,
    'session_id',p_session_id
  );
end;
$function$;

revoke all on function public.huntnexus_player_session_list(uuid,integer) from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_delete(uuid,uuid) from public,anon,authenticated;
grant execute on function public.huntnexus_player_session_list(uuid,integer) to service_role;
grant execute on function public.huntnexus_player_session_delete(uuid,uuid) to service_role;
