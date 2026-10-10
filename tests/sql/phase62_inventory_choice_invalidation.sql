-- Phase 62 — invalidate stale per-hunt choices when owned items disappear.

do $$
declare
  v_client uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid;
  v_main jsonb;
  v_bp jsonb;
  v_choice jsonb;
  v_get jsonb;
begin
  delete from player_hunt_build_choices where client_id=v_client;
  delete from player_character_inventory where client_id=v_client;

  v_main := huntnexus_player_inventory_put(v_client,'main','soultainter',1);
  v_bp := huntnexus_player_inventory_put(v_client,'backpack','amber-wand',1);

  v_choice := huntnexus_player_hunt_build_choice_save(
    v_client,
    'podzilla',
    'MS',
    655,
    '{"weapon":"amber-wand"}'::jsonb,
    'owned_variant',
    '[{"selection_key":"weapon","item_key":"amber-wand","item_name":"Amber Wand"}]'::jsonb
  );

  if coalesce((v_choice->>'saved')::boolean,false) is not true then
    raise exception 'choice save regression';
  end if;

  perform huntnexus_player_inventory_remove(
    v_client,
    (v_bp->>'inventory_id')::uuid
  );

  v_get := huntnexus_player_hunt_build_choice_get(v_client,'podzilla','MS');

  if coalesce((v_get->>'exists')::boolean,true) is not false then
    raise exception 'stale hunt choice not invalidated after BP removal';
  end if;

  perform huntnexus_player_inventory_put(v_client,'backpack','amber-wand',1);

  perform huntnexus_player_hunt_build_choice_save(
    v_client,
    'podzilla',
    'MS',
    655,
    '{"weapon":"soultainter"}'::jsonb,
    'main',
    '[]'::jsonb
  );

  perform huntnexus_player_inventory_put(v_client,'main','amber-wand',1);

  v_get := huntnexus_player_hunt_build_choice_get(v_client,'podzilla','MS');

  if coalesce((v_get->>'exists')::boolean,true) is not false then
    raise exception 'stale hunt choice not invalidated after Main replacement';
  end if;

  delete from player_hunt_build_choices where client_id=v_client;
  delete from player_character_inventory where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','inventory_choice_invalidation'
) as regression_summary;
