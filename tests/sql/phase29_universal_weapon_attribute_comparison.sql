-- Focused regression for universal weapon attribute vectors/comparison.

do $$
declare
  v_melee jsonb;
  v_cross jsonb;
  v_bow jsonb;
  v_rod jsonb;
  v_wand jsonb;
begin
  v_melee := huntnexus_compare_weapons_universal(
    '["grand-sanguine-blade","naga-sword","gnome-sword"]'::jsonb
  );

  if v_melee #>> '{methodology,stage}' <> 'weapon_comparison_universal_v1' then
    raise exception 'Universal weapon comparison stage regression';
  end if;

  if coalesce((v_melee #>> '{comparison,same_weapon_class}')::boolean,false) is not true
     or coalesce((v_melee #>> '{comparison,same_weapon_family}')::boolean,false) is not true then
    raise exception 'Sword same-class/family comparison regression';
  end if;

  if coalesce((v_melee #>> '{methodology,winner_selected}')::boolean,true) is not false
     or coalesce((v_melee #>> '{methodology,combat_score_applied}')::boolean,true) is not false
     or coalesce((v_melee #>> '{methodology,cross_metric_sum_applied}')::boolean,true) is not false then
    raise exception 'Universal comparison must not infer winner/score';
  end if;

  v_cross := huntnexus_compare_weapons_universal(
    '["grand-sanguine-blade","moonsilver-bow","moonsilver-sceptre","moonsilver-channeler"]'::jsonb
  );

  if coalesce((v_cross #>> '{comparison,same_weapon_class}')::boolean,true) is not false then
    raise exception 'Cross-class comparison classification regression';
  end if;

  v_bow := huntnexus_weapon_attribute_vector('moonsilver-bow');
  if not exists (
    select 1 from jsonb_array_elements(v_bow->'metrics') m
    where m->>'metric_key'='effect/offense/attack_modifier/points'
      and (m->>'value')::numeric=10
  ) or not exists (
    select 1 from jsonb_array_elements(v_bow->'metrics') m
    where m->>'metric_key'='effect/offense/hit_modifier/points'
      and (m->>'value')::numeric=7
  ) or not exists (
    select 1 from jsonb_array_elements(v_bow->'metrics') m
    where m->>'metric_key'='effect/skill/distance_fighting/levels'
      and (m->>'value')::numeric=5
  ) then
    raise exception 'Distance weapon metric regression';
  end if;

  v_rod := huntnexus_weapon_attribute_vector('moonsilver-sceptre');
  if not exists (
    select 1 from jsonb_array_elements(v_rod->'metrics') m
    where m->>'metric_key'='effect/magic_skill/magic_level/levels'
      and (m->>'value')::numeric=6
  ) or not exists (
    select 1 from jsonb_array_elements(v_rod->'metrics') m
    where m->>'metric_key'='effect/magic_skill/healing_magic_level/levels'
      and (m->>'value')::numeric=2
  ) then
    raise exception 'Rod metric regression';
  end if;

  v_wand := huntnexus_weapon_attribute_vector('moonsilver-channeler');
  if not exists (
    select 1 from jsonb_array_elements(v_wand->'metrics') m
    where m->>'metric_key'='effect/magic_skill/magic_level/levels'
      and (m->>'value')::numeric=6
  ) or not exists (
    select 1 from jsonb_array_elements(v_wand->'metrics') m
    where m->>'metric_key'='effect/magic_skill/death_magic_level/levels'
      and (m->>'value')::numeric=1
  ) then
    raise exception 'Wand metric regression';
  end if;

  if huntnexus_weapon_attribute_vector('does-not-exist') #>> '{error}' <> 'weapon_not_found' then
    raise exception 'Missing weapon regression';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_weapon_attribute_comparison',
  'cross_class_dimensions',jsonb_array_length(
    huntnexus_compare_weapons_universal(
      '["grand-sanguine-blade","moonsilver-bow","moonsilver-sceptre","moonsilver-channeler"]'::jsonb
    ) #> '{comparison,dimensions}'
  )
) as regression_summary;
