-- Phase 60 — owned build option factual explanation regression.

do $$
declare
  v_client uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid;
  v_result jsonb;
begin
  delete from player_character_inventory where client_id=v_client;

  perform huntnexus_player_inventory_put(v_client,'main','soultainter',1);
  perform huntnexus_player_inventory_put(v_client,'backpack','amber-wand',1);

  v_result := huntnexus_player_owned_build_options_v2(
    v_client,
    'podzilla',
    'MS',
    655,
    '{"soultainter":[1,3],"amber-wand":[1]}'::jsonb,
    '{"effective_magic_level":110}'::jsonb,
    3
  );

  if v_result #>> '{methodology,stage}' <> 'player_owned_build_options_v2'
     or coalesce((v_result #>> '{methodology,replacement_context_explanations}')::boolean,false) is not true
     or coalesce((v_result #>> '{methodology,replacement_explanation_is_factual_attributes}')::boolean,false) is not true then
    raise exception 'Owned build explanation methodology regression';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_result->'options') o
    where o->>'option_type'='owned_variant'
      and jsonb_array_length(coalesce(o->'replacement_details','[]'::jsonb)) = 0
  ) then
    raise exception 'Owned variant missing replacement details';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_result->'options') o
    cross join lateral jsonb_array_elements(coalesce(o->'replacement_details','[]'::jsonb)) d
    where d->>'to_item_key'='amber-wand'
      and d #>> '{to_context,item,item_key}'='amber-wand'
      and d #>> '{to_context,effect_profile,groups,protection,ice}'='6'
  ) then
    raise exception 'Amber Wand factual replacement context regression';
  end if;

  delete from player_character_inventory where client_id=v_client;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','player_owned_build_option_explanations'
) as regression_summary;
