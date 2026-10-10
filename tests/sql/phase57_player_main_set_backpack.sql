-- Phase 57 — player main set and backpack inventory regression.

do $$
declare
  v_client uuid := '88888888-8888-4888-8888-888888888888'::uuid;
  v_saved jsonb;
  v_get jsonb;
  v_bp jsonb;
  v_main_id uuid;
  v_bp_id uuid;
begin
  delete from player_character_inventory where client_id=v_client;

  v_saved := huntnexus_player_inventory_put(v_client,'main','soultainter',1);
  if coalesce((v_saved->>'saved')::boolean,false) is not true
     or v_saved->>'storage_kind' <> 'main'
     or v_saved->>'selection_key' <> 'weapon' then
    raise exception 'Main weapon save regression';
  end if;

  v_main_id := (v_saved->>'inventory_id')::uuid;

  v_bp := huntnexus_player_inventory_put(v_client,'backpack','spellbook-of-ancient-arcana',1);
  if coalesce((v_bp->>'saved')::boolean,false) is not true
     or v_bp->>'storage_kind' <> 'backpack'
     or v_bp->>'selection_key' <> 'offhand' then
    raise exception 'Backpack item save regression';
  end if;

  v_bp_id := (v_bp->>'inventory_id')::uuid;
  v_get := huntnexus_player_inventory_get(v_client);

  if v_get #>> '{main_set,weapon,item_key}' <> 'soultainter'
     or v_get #>> '{backpack,0,item_key}' <> 'spellbook-of-ancient-arcana'
     or (v_get #>> '{summary,main_slots}')::int <> 1
     or (v_get #>> '{summary,backpack_items}')::int <> 1
     or coalesce((v_get #>> '{methodology,main_set_is_baseline}')::boolean,false) is not true
     or coalesce((v_get #>> '{methodology,automatic_main_replacement}')::boolean,true) is not false then
    raise exception 'Inventory read/baseline regression';
  end if;

  if (huntnexus_player_inventory_search('MS',655,'soultainter','weapon',10) #>> '{items,0,item_key}') <> 'soultainter' then
    raise exception 'Inventory search regression';
  end if;

  if coalesce((huntnexus_player_inventory_remove(v_client,v_bp_id)->>'deleted')::boolean,false) is not true then
    raise exception 'Inventory remove regression';
  end if;

  delete from player_character_inventory where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_main_set_backpack',
  'main_set_is_baseline',true,
  'backpack_owned_alternatives',true
) as regression_summary;
