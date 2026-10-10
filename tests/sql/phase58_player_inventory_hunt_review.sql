-- Phase 58 — owned-first hunt inventory review regression.

do $$
declare
  v_client uuid := '99999999-9999-4999-8999-999999999999'::uuid;
  v_review jsonb;
begin
  delete from player_character_inventory where client_id=v_client;

  perform huntnexus_player_inventory_put(v_client,'main','soultainter',1);
  perform huntnexus_player_inventory_put(v_client,'backpack','amber-wand',1);
  perform huntnexus_player_inventory_put(v_client,'backpack','spellbook-of-ancient-arcana',1);

  v_review := huntnexus_player_inventory_hunt_review(
    v_client,'podzilla','MS',655,
    '{"soultainter":[1,3],"amber-wand":[1]}'::jsonb,
    12
  );

  if v_review #>> '{methodology,stage}' <> 'player_inventory_hunt_review_v1'
     or coalesce((v_review #>> '{methodology,main_set_is_baseline}')::boolean,false) is not true
     or coalesce((v_review #>> '{methodology,automatic_main_replacement}')::boolean,true) is not false
     or (v_review #>> '{summary,main_items}')::int <> 1
     or (v_review #>> '{summary,backpack_items}')::int <> 2 then
    raise exception 'Owned-first hunt review contract regression';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_review->'frontier_candidates') x
    where x->>'item_key'='amber-wand'
      and x->>'ownership'='backpack'
  ) then
    raise exception 'Owned backpack frontier classification regression';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_review->'frontier_candidates') x
    where x->>'ownership'='external'
  ) then
    raise exception 'External frontier suggestions regression';
  end if;

  delete from player_character_inventory where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_inventory_hunt_review',
  'main_set_is_baseline',true,
  'automatic_main_replacement',false
) as regression_summary;
