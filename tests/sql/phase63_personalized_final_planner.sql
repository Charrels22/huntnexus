-- Phase 63 — personalized planner envelope regression.

do $$
declare
  v_client uuid := 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid;
  v_base jsonb;
  v_personal jsonb;
begin
  delete from player_hunt_build_choices where client_id=v_client;
  delete from player_character_inventory where client_id=v_client;

  perform huntnexus_player_inventory_put(v_client,'main','soultainter',1);
  perform huntnexus_player_inventory_put(v_client,'backpack','amber-wand',1);

  v_base := huntnexus_optimizer_final_universal(
    'MS',655,'balanced','offense',1,
    1,2,1,30,30,8,
    '[]'::jsonb,
    '{"soultainter":[1],"amber-wand":[1]}'::jsonb,
    '{"weapon_family":"wand","effective_magic_level":110}'::jsonb
  );

  v_personal := huntnexus_optimizer_final_personalized(
    v_client,
    'MS',655,'balanced','offense',1,
    1,2,1,30,30,8,
    '[]'::jsonb,
    '{"soultainter":[1],"amber-wand":[1]}'::jsonb,
    '{"weapon_family":"wand","effective_magic_level":110}'::jsonb
  );

  if v_personal #>> '{methodology,stage}' <> 'optimizer_final_personalized_v1'
     or coalesce((v_personal #>> '{methodology,hunt_ranking_reordered_by_inventory}')::boolean,true) is not false
     or coalesce((v_personal #>> '{methodology,ownership_affects_hunt_rank}')::boolean,true) is not false then
    raise exception 'Personalized planner methodology regression';
  end if;

  if v_personal #>> '{results,0,hunt,hunt_key}' <> v_base #>> '{results,0,hunt,hunt_key}'
     or v_personal #>> '{results,0,hunt,ranking_score}' <> v_base #>> '{results,0,hunt,ranking_score}' then
    raise exception 'Inventory must not reorder or rescore hunt ranking';
  end if;

  if v_personal #>> '{results,0,owned_builds,methodology,stage}' <> 'player_owned_build_options_v2'
     or coalesce((v_personal #>> '{personalization_summary,hunts_with_registered_main_set}')::int,0) <> 1 then
    raise exception 'Owned build enrichment regression';
  end if;

  if v_personal #>> '{results,0,owned_builds,options,0,option_type}' <> 'main'
     or v_personal #>> '{results,0,owned_builds,options,0,selection,weapon}' <> 'soultainter' then
    raise exception 'Personalized planner Main option regression';
  end if;

  delete from player_hunt_build_choices where client_id=v_client;
  delete from player_character_inventory where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','personalized_final_planner',
  'hunt_ranking_reordered_by_inventory',false
) as regression_summary;
