-- Phase 61 — per-hunt owned build choice regression.

do $$
declare
  v_client uuid := 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'::uuid;
  v_saved jsonb;
  v_get jsonb;
  v_bad jsonb;
begin
  delete from player_hunt_build_choices where client_id=v_client;
  delete from player_character_inventory where client_id=v_client;

  perform huntnexus_player_inventory_put(v_client,'main','soultainter',1);
  perform huntnexus_player_inventory_put(v_client,'backpack','amber-wand',1);

  v_saved := huntnexus_player_hunt_build_choice_save(
    v_client,
    'podzilla',
    'MS',
    655,
    '{"weapon":"amber-wand"}'::jsonb,
    'owned_variant',
    '[{"selection_key":"weapon","item_key":"amber-wand","item_name":"Amber Wand"}]'::jsonb
  );

  if coalesce((v_saved->>'saved')::boolean,false) is not true
     or coalesce((v_saved->>'main_set_mutated')::boolean,true) is not false then
    raise exception 'Per-hunt choice save regression';
  end if;

  v_get := huntnexus_player_hunt_build_choice_get(v_client,'podzilla','MS');

  if coalesce((v_get->>'exists')::boolean,false) is not true
     or v_get #>> '{choice,selection,weapon}' <> 'amber-wand'
     or v_get #>> '{choice,option_type}' <> 'owned_variant' then
    raise exception 'Per-hunt choice get regression';
  end if;

  v_bad := huntnexus_player_hunt_build_choice_save(
    v_client,
    'podzilla',
    'MS',
    655,
    '{"weapon":"grand-sanguine-coil"}'::jsonb,
    'owned_variant',
    '[]'::jsonb
  );

  if v_bad->>'error' <> 'selection_contains_non_owned_item' then
    raise exception 'External item ownership guard regression';
  end if;

  perform huntnexus_player_hunt_build_choice_delete(v_client,'podzilla','MS');

  delete from player_character_inventory where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_hunt_build_choice',
  'main_set_mutated',false
) as regression_summary;
