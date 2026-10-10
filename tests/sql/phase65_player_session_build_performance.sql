-- Phase 65 — private performance aggregation by immutable loadout snapshot.

do $$
declare
  v_client uuid := 'abababab-abab-4bab-8bab-abababababab'::uuid;
  v_result jsonb;
begin
  delete from player_hunt_sessions where client_id=v_client;

  insert into player_hunt_sessions(
    client_id,status,character_name,server_name,vocation,level,hunt_key,hunt_name,
    raw_blocks,parsed_data,parser_version,loadout_snapshot
  )
  values
  (
    v_client,'parsed','Perf Regression','Elysian','MS',655,'podzilla','Podzilla',
    '{}'::jsonb,
    '{"hunt_analyse":{"duration_seconds":1800,"xp_per_hour":10000000,"balance_value":500000,"total_damage":4000000,"total_healing":1000000}}'::jsonb,
    'session_parser_v1',
    '{"source":"main_default","option_type":"main","selection":{"weapon":"soultainter"},"items":[{"selection_key":"weapon","item_key":"soultainter","item_name":"Soultainter","storage_kind":"main"}]}'::jsonb
  ),
  (
    v_client,'parsed','Perf Regression','Elysian','MS',655,'podzilla','Podzilla',
    '{}'::jsonb,
    '{"hunt_analyse":{"duration_seconds":1800,"xp_per_hour":12000000,"balance_value":700000,"total_damage":5000000,"total_healing":1200000}}'::jsonb,
    'session_parser_v1',
    '{"source":"main_default","option_type":"main","selection":{"weapon":"soultainter"},"items":[{"selection_key":"weapon","item_key":"soultainter","item_name":"Soultainter","storage_kind":"main"}]}'::jsonb
  ),
  (
    v_client,'parsed','Perf Regression','Elysian','MS',655,'podzilla','Podzilla',
    '{}'::jsonb,
    '{"hunt_analyse":{"duration_seconds":1800,"xp_per_hour":13000000,"balance_value":800000,"total_damage":5500000,"total_healing":1300000}}'::jsonb,
    'session_parser_v1',
    '{"source":"saved_hunt_choice","option_type":"owned_variant","selection":{"weapon":"amber-wand"},"items":[{"selection_key":"weapon","item_key":"amber-wand","item_name":"Amber Wand","storage_kind":"backpack"}]}'::jsonb
  );

  v_result := huntnexus_player_session_build_performance(v_client,'podzilla','MS');

  if v_result #>> '{methodology,stage}' <> 'player_session_build_performance_v1'
     or coalesce((v_result #>> '{methodology,causal_effect_inferred}')::boolean,true) is not false
     or (v_result #>> '{summary,sessions}')::int <> 3
     or (v_result #>> '{summary,distinct_builds}')::int <> 2 then
    raise exception 'Build performance summary regression';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_result->'builds') b
    where b #>> '{selection,weapon}'='soultainter'
      and (b->>'session_count')::int=2
      and round((b->>'median_xp_per_hour')::numeric)=11000000
      and b->>'sample_status'='very_low_sample'
  ) then
    raise exception 'Main build median regression';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_result->'builds') b
    where b #>> '{selection,weapon}'='amber-wand'
      and (b->>'session_count')::int=1
      and b->>'sample_status'='single_session'
  ) then
    raise exception 'Owned variant sample regression';
  end if;

  delete from player_hunt_sessions where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_session_build_performance',
  'causal_effect_inferred',false
) as regression_summary;
