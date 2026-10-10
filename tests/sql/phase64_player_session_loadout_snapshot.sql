-- Phase 64 — private session loadout snapshot regression.

do $$
declare
  v_client uuid := 'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid;
  v_saved jsonb;
  v_session uuid;
  v_detail jsonb;
  v_bp jsonb;
begin
  delete from player_hunt_sessions where client_id=v_client;
  delete from player_hunt_build_choices where client_id=v_client;
  delete from player_character_inventory where client_id=v_client;

  perform huntnexus_player_inventory_put(v_client,'main','soultainter',1);
  v_bp := huntnexus_player_inventory_put(v_client,'backpack','amber-wand',1);

  perform huntnexus_player_hunt_build_choice_save(
    v_client,
    'podzilla',
    'MS',
    655,
    '{"weapon":"amber-wand"}'::jsonb,
    'owned_variant',
    '[{"selection_key":"weapon","item_key":"amber-wand","item_name":"Amber Wand"}]'::jsonb
  );

  v_saved := huntnexus_player_session_save(
    v_client,
    '{"hunt":"Session: 00:30h"}'::jsonb,
    '{
      "hunt_analyse":{"duration_seconds":1800,"xp_gain":3000000,"xp_per_hour":6000000},
      "misc":{"creatures":[],"combat_stats":[],"looted_items":[]},
      "damage":{"incoming_by_element":[],"incoming_by_source":[],"charm_damage":[],"charm_damage_available":false},
      "party_hunt":{"party_size":1,"players":[]},
      "availability":{"hunt_analyse":true,"misc":false,"damage":false,"party_hunt":false,"charm_damage":false},
      "validation":{"has_primary_hunt_analyzer":true,"recognized_metric_count":3,"warnings":[]}
    }'::jsonb,
    '{
      "character":"Snapshot Regression",
      "server":"Elysian",
      "vocation":"MS",
      "level":"655",
      "location":"Podzilla",
      "hunt_key":"podzilla",
      "tags":[],
      "type":"normal",
      "favorite":false,
      "publishHighscores":false
    }'::jsonb
  );

  v_session := (v_saved->>'session_id')::uuid;

  if v_saved->>'loadout_snapshot_source' <> 'saved_hunt_choice' then
    raise exception 'Session did not capture saved hunt choice';
  end if;

  v_detail := huntnexus_player_session_detail(v_client,v_session);

  if v_detail #>> '{loadout_snapshot,selection,weapon}' <> 'amber-wand'
     or v_detail #>> '{loadout_snapshot,source}' <> 'saved_hunt_choice'
     or v_detail #>> '{loadout_snapshot,option_type}' <> 'owned_variant'
     or coalesce((v_detail #>> '{parser,loadout_snapshot_immutable}')::boolean,false) is not true then
    raise exception 'Session loadout snapshot regression';
  end if;

  -- Remove the owned item after the session. Current hunt choice may be invalidated,
  -- but the historical session snapshot must remain unchanged.
  perform huntnexus_player_inventory_remove(v_client,(v_bp->>'inventory_id')::uuid);

  v_detail := huntnexus_player_session_detail(v_client,v_session);

  if v_detail #>> '{loadout_snapshot,selection,weapon}' <> 'amber-wand'
     or v_detail #>> '{loadout_snapshot,items,0,item_key}' <> 'amber-wand' then
    raise exception 'Historical session loadout snapshot mutated';
  end if;

  delete from player_hunt_sessions where client_id=v_client;
  delete from player_hunt_build_choices where client_id=v_client;
  delete from player_character_inventory where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_session_loadout_snapshot',
  'immutable_after_inventory_change',true,
  'community_evidence_written',false
) as regression_summary;
