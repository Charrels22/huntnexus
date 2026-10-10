-- Phase 53 — private player session import persistence regression.

do $$
declare
  v_client uuid := '33333333-3333-4333-8333-333333333333'::uuid;
  v_saved jsonb;
  v_id uuid;
  v_list jsonb;
  v_detail jsonb;
begin
  delete from player_hunt_sessions where client_id=v_client;

  v_saved := huntnexus_player_session_save(
    v_client,
    '{"hunt":"Session: 01:30h\nXP Gain: 12,000,000"}'::jsonb,
    '{
      "hunt_analyse":{
        "duration_seconds":5400,
        "xp_gain":12000000,
        "xp_per_hour":8000000,
        "loot_value":1500000,
        "supplies_value":500000,
        "balance_value":1000000,
        "total_damage":6000000,
        "total_healing":1200000,
        "total_kills":0
      },
      "misc":{"creatures":[],"combat_stats":[]},
      "damage":{"total_damage":6000000,"incoming_by_element":[],"incoming_by_source":[],"charm_damage":[],"charm_damage_available":false},
      "party_hunt":{"party_size":1,"players":[]},
      "availability":{"hunt_analyse":true,"misc":false,"damage":true,"party_hunt":false,"charm_damage":false},
      "validation":{"has_primary_hunt_analyzer":true,"recognized_metric_count":8,"warnings":[]}
    }'::jsonb,
    '{"character":"Regression","server":"RubinOT","vocation":"EK","level":"700","location":"Cobra Bastion","tags":["phase53"],"type":"normal","favorite":true,"publishHighscores":false}'::jsonb
  );

  v_id := (v_saved->>'session_id')::uuid;
  if v_id is null or v_saved->>'status' <> 'parsed'
     or coalesce((v_saved->>'community_evidence_written')::boolean,true) is not false then
    raise exception 'Player session save regression';
  end if;

  v_list := huntnexus_player_session_list(v_client,10);
  if (v_list #>> '{summary,returned}')::int <> 1
     or v_list #>> '{sessions,0,hunt_name}' <> 'Cobra Bastion' then
    raise exception 'Player session list regression';
  end if;

  v_detail := huntnexus_player_session_detail(v_client,v_id);
  if v_detail #>> '{hunt_analyse,xp_gain}' <> '12000000'
     or v_detail #>> '{parser,version}' <> 'session_parser_v1'
     or coalesce((v_detail #>> '{parser,community_evidence_written}')::boolean,true) is not false then
    raise exception 'Player session detail regression';
  end if;

  if huntnexus_player_session_detail('44444444-4444-4444-8444-444444444444'::uuid,v_id)->>'error' <> 'session_not_found' then
    raise exception 'Client isolation regression';
  end if;

  if has_function_privilege('anon','public.huntnexus_player_session_save(uuid,jsonb,jsonb,jsonb)','EXECUTE')
     or has_function_privilege('authenticated','public.huntnexus_player_session_list(uuid,integer)','EXECUTE')
     or has_function_privilege('authenticated','public.huntnexus_player_session_detail(uuid,uuid)','EXECUTE') then
    raise exception 'Player session RPCs must remain server-only';
  end if;

  delete from player_hunt_sessions where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_session_import_persistence',
  'community_evidence_written',false
) as regression_summary;
