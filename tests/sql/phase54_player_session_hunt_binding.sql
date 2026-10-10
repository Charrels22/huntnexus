-- Phase 54 — private player session canonical hunt binding regression.

do $$
declare
  v_client uuid := '55555555-5555-4555-8555-555555555555'::uuid;
  v_saved jsonb;
  v_id uuid;
  v_list jsonb;
  v_detail jsonb;
begin
  delete from player_hunt_sessions where client_id=v_client;

  v_saved := huntnexus_player_session_save(
    v_client,
    '{"hunt":"Session: 00:30h\nXP Gain: 3,000,000"}'::jsonb,
    '{
      "hunt_analyse":{"duration_seconds":1800,"xp_gain":3000000,"xp_per_hour":6000000},
      "misc":{"creatures":[],"combat_stats":[],"looted_items":[]},
      "damage":{"incoming_by_element":[],"incoming_by_source":[],"charm_damage":[],"charm_damage_available":false},
      "party_hunt":{"party_size":1,"players":[]},
      "availability":{"hunt_analyse":true,"misc":false,"damage":false,"party_hunt":false,"charm_damage":false},
      "validation":{"has_primary_hunt_analyzer":true,"recognized_metric_count":3,"warnings":[]}
    }'::jsonb,
    '{"character":"Binding Regression","vocation":"EK","level":"700","location":"Cobra Bastion","hunt_key":"cobra-bastion","tags":[],"type":"normal","favorite":false,"publishHighscores":false}'::jsonb
  );

  v_id := (v_saved->>'session_id')::uuid;
  if v_saved->>'hunt_key' <> 'cobra-bastion' then
    raise exception 'Save hunt_key regression';
  end if;

  v_list := huntnexus_player_session_list(v_client,5);
  if v_list #>> '{sessions,0,hunt_key}' <> 'cobra-bastion' then
    raise exception 'List hunt_key regression';
  end if;

  v_detail := huntnexus_player_session_detail(v_client,v_id);
  if v_detail #>> '{session,hunt_key}' <> 'cobra-bastion' then
    raise exception 'Detail hunt_key regression';
  end if;

  delete from player_hunt_sessions where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_session_hunt_binding',
  'community_evidence_written',false
) as regression_summary;
