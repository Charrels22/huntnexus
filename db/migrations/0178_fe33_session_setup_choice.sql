-- HuntNexus FE-33 — player-chosen immutable setup at session import.
-- Backwards-compatible: setupMode absent means prior automatic behavior.
-- Only server-owned Main / saved hunt builds can be captured.
-- No session data is updated by this migration.

create or replace function public.huntnexus_player_session_loadout_snapshot_selected(
  p_client_id uuid,
  p_hunt_key text,
  p_vocation text,
  p_mode text
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
    and p_mode <> 'main'
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

revoke all on function public.huntnexus_player_session_loadout_snapshot_selected(uuid,text,text,text)
from public,anon,authenticated;
grant execute on function public.huntnexus_player_session_loadout_snapshot_selected(uuid,text,text,text)
to service_role;

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
  v_setup_mode text := coalesce(nullif(trim(p_metadata->>'setupMode'),''),'auto');
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

  if v_setup_mode not in ('auto','main','hunt','none') then
    return jsonb_build_object('error','session_setup_mode_invalid');
  end if;

  if v_setup_mode = 'none' then
    v_loadout := jsonb_build_object(
      'source','not_recorded',
      'option_type',null,
      'selection','{}'::jsonb,
      'replacements','[]'::jsonb,
      'items','[]'::jsonb,
      'main_set_mutated',false
    );
  elsif v_setup_mode = 'auto' then
    -- Preserve the pre-FE33 behavior for every old client/draft.
    if v_hunt_key is not null and v_vocation is not null then
      v_loadout := huntnexus_player_session_loadout_snapshot(
        p_client_id,v_hunt_key,v_vocation
      );
    else
      v_loadout := jsonb_build_object(
        'source','not_available',
        'option_type',null,
        'selection','{}'::jsonb,
        'replacements','[]'::jsonb,
        'items','[]'::jsonb,
        'main_set_mutated',false
      );
    end if;
  else
    if v_vocation is null then
      return jsonb_build_object('error','session_setup_vocation_required');
    end if;
    if v_setup_mode = 'hunt' and v_hunt_key is null then
      return jsonb_build_object('error','session_setup_hunt_required');
    end if;

    -- Read the authoritative inventory/build choice on the server at save
    -- time; never accept a client-supplied item list or stale visual preview.
    v_loadout := huntnexus_player_session_loadout_snapshot_selected(
      p_client_id,v_hunt_key,v_vocation,v_setup_mode
    );
    if v_setup_mode = 'main' and
       coalesce(v_loadout->>'source','') <> 'main_default' then
      return jsonb_build_object('error','session_setup_main_unavailable');
    end if;
    if v_setup_mode = 'hunt' and
       coalesce(v_loadout->>'source','') <> 'saved_hunt_choice' then
      return jsonb_build_object('error','session_setup_hunt_unavailable');
    end if;
  end if;
  v_loadout := v_loadout || jsonb_build_object(
    'setup_mode',v_setup_mode,
    'captured_at',now()
  );

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
