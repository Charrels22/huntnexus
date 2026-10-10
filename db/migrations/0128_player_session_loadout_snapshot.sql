-- HuntNexus FE-13 — immutable owned loadout snapshot on private hunt sessions.

alter table public.player_hunt_sessions
  add column if not exists loadout_snapshot jsonb not null default '{}'::jsonb;

create or replace function public.huntnexus_player_session_loadout_snapshot(
  p_client_id uuid,
  p_hunt_key text,
  p_vocation text
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with choice as (
  select *
  from public.player_hunt_build_choices
  where client_id=p_client_id
    and hunt_key=p_hunt_key
    and vocation=huntnexus_normalize_vocation(p_vocation)
  limit 1
),
main_selection as (
  select coalesce(
    jsonb_object_agg(selection_key,item_key order by selection_key),
    '{}'::jsonb
  ) as selection
  from public.player_character_inventory
  where client_id=p_client_id
    and storage_kind='main'
),
resolved as (
  select
    case
      when exists(select 1 from choice) then (select selection from choice)
      else (select selection from main_selection)
    end as selection,
    case
      when exists(select 1 from choice) then 'saved_hunt_choice'
      when exists(select 1 from jsonb_object_keys((select selection from main_selection))) then 'main_default'
      else 'not_available'
    end as source,
    case
      when exists(select 1 from choice) then (select option_type from choice)
      when exists(select 1 from jsonb_object_keys((select selection from main_selection))) then 'main'
      else null
    end as option_type,
    case
      when exists(select 1 from choice) then (select replacements from choice)
      else '[]'::jsonb
    end as replacements
)
select jsonb_build_object(
  'source',r.source,
  'option_type',r.option_type,
  'selection',coalesce(r.selection,'{}'::jsonb),
  'replacements',coalesce(r.replacements,'[]'::jsonb),
  'items',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'selection_key',s.key,
        'item_key',s.value,
        'item_name',coalesce(i.item_name,c.name,s.value),
        'storage_kind',i.storage_kind
      )
      order by s.key
    )
    from jsonb_each_text(coalesce(r.selection,'{}'::jsonb)) s
    left join public.player_character_inventory i
      on i.client_id=p_client_id
     and i.selection_key=s.key
     and i.item_key=s.value
    left join public.vw_loadout_item_catalog_universal c
      on c.selection_key=s.key
     and c.item_key=s.value
  ),'[]'::jsonb),
  'main_set_mutated',false
)
from resolved r;
$function$;

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
    'session_parser_v1',
    v_loadout
  )
  returning id into v_id;

  return jsonb_build_object(
    'session_id',v_id,
    'status',v_status,
    'parser_version','session_parser_v1',
    'hunt_key',v_hunt_key,
    'loadout_snapshot_source',v_loadout->>'source',
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
    hunt_key,
    hunt_name,
    hunt_type,
    favorite,
    loadout_snapshot->>'source' as loadout_source,
    loadout_snapshot->>'option_type' as loadout_option_type,
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
    'stage','player_session_list_v2',
    'loadout_snapshot_exposed',true,
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
      'hunt_key',s.hunt_key,
      'hunt_name_raw',s.hunt_name,
      'hunt_type',s.hunt_type,
      'favorite',s.favorite
    ),
    'loadout_snapshot',coalesce(s.loadout_snapshot,'{}'::jsonb),
    'hunt_analyse',coalesce(s.parsed_data->'hunt_analyse','{}'::jsonb),
    'misc',coalesce(s.parsed_data->'misc','{}'::jsonb),
    'damage',coalesce(s.parsed_data->'damage','{}'::jsonb),
    'party_hunt',coalesce(s.parsed_data->'party_hunt','{}'::jsonb),
    'availability',coalesce(s.parsed_data->'availability','{}'::jsonb),
    'validation',coalesce(s.parsed_data->'validation','{}'::jsonb),
    'parser',jsonb_build_object(
      'version',s.parser_version,
      'raw_blocks_preserved',true,
      'loadout_snapshot_immutable',true,
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

revoke all on function public.huntnexus_player_session_loadout_snapshot(uuid,text,text)
from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_save(uuid,jsonb,jsonb,jsonb)
from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_list(uuid,integer)
from public,anon,authenticated;
revoke all on function public.huntnexus_player_session_detail(uuid,uuid)
from public,anon,authenticated;

grant execute on function public.huntnexus_player_session_loadout_snapshot(uuid,text,text)
to service_role;
grant execute on function public.huntnexus_player_session_save(uuid,jsonb,jsonb,jsonb)
to service_role;
grant execute on function public.huntnexus_player_session_list(uuid,integer)
to service_role;
grant execute on function public.huntnexus_player_session_detail(uuid,uuid)
to service_role;
