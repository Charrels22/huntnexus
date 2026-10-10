-- Phase 55 — private character profile persistence regression.

do $$
declare
  v_client uuid := '66666666-6666-4666-8666-666666666666'::uuid;
  v_saved jsonb;
  v_get jsonb;
begin
  delete from player_character_profiles where client_id=v_client;

  v_saved := huntnexus_player_profile_save(
    v_client,
    '{
      "character_name":"Profile Regression",
      "world_name":"RubinOT",
      "vocation":"EK",
      "level":"700",
      "online":false,
      "former_names":["Old Name"],
      "official_lookup_at":"2026-10-10T12:00:00Z",
      "official_lookup_status":"found",
      "manual_stats":{
        "weapon_family":"sword",
        "effective_weapon_skill":130,
        "effective_magic_level":15
      },
      "proficiency_selections":{"sample-sword":[1,2]},
      "defaults":{
        "hunt_objective":"xp",
        "set_objective":"offense",
        "party_size":1
      }
    }'::jsonb
  );

  if coalesce((v_saved->>'saved')::boolean,false) is not true then
    raise exception 'Profile save regression';
  end if;

  v_get := huntnexus_player_profile_get(v_client);

  if coalesce((v_get->>'exists')::boolean,false) is not true
     or v_get #>> '{profile,character_name}' <> 'Profile Regression'
     or v_get #>> '{profile,vocation}' <> 'EK'
     or v_get #>> '{profile,level}' <> '700'
     or v_get #>> '{profile,manual_stats,weapon_family}' <> 'sword'
     or v_get #>> '{profile,manual_stats,effective_weapon_skill}' <> '130'
     or v_get #>> '{profile,defaults,hunt_objective}' <> 'xp'
     or v_get #>> '{profile,defaults,set_objective}' <> 'offense' then
    raise exception 'Profile get regression';
  end if;

  if has_function_privilege('anon','public.huntnexus_player_profile_get(uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.huntnexus_player_profile_save(uuid,jsonb)','EXECUTE') then
    raise exception 'Profile RPCs must remain server-only';
  end if;

  delete from player_character_profiles where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_character_profile'
) as regression_summary;
