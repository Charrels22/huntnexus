-- Phase 59 — owned build options regression.

do $$
declare
  v_client uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid;
  v_result jsonb;
begin
  delete from player_character_inventory where client_id=v_client;

  perform huntnexus_player_inventory_put(v_client,'main','soultainter',1);
  perform huntnexus_player_inventory_put(v_client,'backpack','amber-wand',1);
  perform huntnexus_player_inventory_put(v_client,'backpack','spellbook-of-ancient-arcana',1);

  v_result := huntnexus_player_owned_build_options(
    v_client,
    'podzilla',
    'MS',
    655,
    '{"soultainter":[1,3],"amber-wand":[1]}'::jsonb,
    '{"effective_magic_level":110}'::jsonb,
    3
  );

  if v_result #>> '{methodology,stage}' <> 'player_owned_build_options_v1'
     or coalesce((v_result #>> '{methodology,main_set_is_option_1}')::boolean,false) is not true
     or coalesce((v_result #>> '{methodology,owned_backpack_priority}')::boolean,false) is not true
     or coalesce((v_result #>> '{methodology,external_items_used_in_owned_options}')::boolean,true) is not false
     or coalesce((v_result #>> '{methodology,cross_metric_score_applied}')::boolean,true) is not false then
    raise exception 'Owned build options methodology regression';
  end if;

  if v_result #>> '{options,0,option_type}' <> 'main'
     or v_result #>> '{options,0,selection,weapon}' <> 'soultainter' then
    raise exception 'Main Set must remain option 1';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_result->'options') o
    cross join lateral jsonb_each_text(o->'selection') s
    where (o->>'option_type')='owned_variant'
      and not exists (
        select 1 from player_character_inventory i
        where i.client_id=v_client
          and i.item_key=s.value
          and i.storage_kind in ('main','backpack')
      )
  ) then
    raise exception 'Owned build option contains non-owned external item';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_result->'options') o
    where (o->>'option_type')='owned_variant'
      and coalesce((o->>'dominated_by_main')::boolean,false)=true
  ) then
    raise exception 'Main-dominated BP variant must be removed';
  end if;

  delete from player_character_inventory where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_owned_build_options',
  'main_is_option_1',true,
  'external_items_used',false
) as regression_summary;
