-- Phase 56 — profile proficiency catalog + exact selection persistence.

do $$
declare
  v_catalog jsonb;
  v_client uuid := '77777777-7777-4777-8777-777777777777'::uuid;
  v_saved jsonb;
  v_get jsonb;
begin
  v_catalog := huntnexus_player_profile_proficiency_catalog('MS',655,'wand');

  if v_catalog #>> '{methodology,stage}' <> 'player_profile_proficiency_catalog_v1'
     or coalesce((v_catalog #>> '{summary,eligible_tree_count}')::int,0) < 1
     or jsonb_array_length(coalesce(v_catalog->'trees','[]'::jsonb)) < 1 then
    raise exception 'Proficiency catalog regression';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_catalog->'trees') t
    where t->>'item_key'='amber-wand'
      and coalesce((t->>'eligible')::boolean,false)=true
      and jsonb_array_length(coalesce(t->'perks','[]'::jsonb)) > 0
  ) then
    raise exception 'Amber Wand proficiency tree missing';
  end if;

  delete from player_character_profiles where client_id=v_client;

  v_saved := huntnexus_player_profile_save(
    v_client,
    '{
      "character_name":"Proficiency Regression",
      "world_name":"Elysian",
      "vocation":"MS",
      "level":"655",
      "manual_stats":{"weapon_family":"wand","magic_level":110},
      "proficiency_selections":{"amber-wand":[1,3,9]},
      "defaults":{"hunt_objective":"balanced","set_objective":"offense","party_size":1}
    }'::jsonb
  );

  v_get := huntnexus_player_profile_get(v_client);

  if v_get #> '{profile,proficiency_selections,amber-wand}' <> '[1,3,9]'::jsonb then
    raise exception 'Exact proficiency selection persistence regression';
  end if;

  delete from player_character_profiles where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_profile_proficiency'
) as regression_summary;
