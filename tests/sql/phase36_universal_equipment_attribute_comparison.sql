-- Focused regression for universal equipment attribute vectors/comparison.

do $$
declare
  v_cross jsonb;
  v_boots jsonb;
  v_magic jsonb;
  v_reflect jsonb;
  v_leech jsonb;
begin
  v_cross := huntnexus_compare_equipment_universal(
    '["falcon-coif","lion-plate","soulstrider","lion-spellbook","alicorn-quiver"]'::jsonb
  );

  if v_cross #>> '{methodology,stage}' <> 'equipment_comparison_universal_v1' then
    raise exception 'Equipment comparison stage regression';
  end if;

  if coalesce((v_cross #>> '{comparison,same_slot}')::boolean,true) is not false
     or coalesce((v_cross #>> '{comparison,same_equipment_family}')::boolean,true) is not false then
    raise exception 'Cross-slot/family comparison classification regression';
  end if;

  if coalesce((v_cross #>> '{methodology,winner_selected}')::boolean,true) is not false
     or coalesce((v_cross #>> '{methodology,combat_score_applied}')::boolean,true) is not false
     or coalesce((v_cross #>> '{methodology,cross_metric_sum_applied}')::boolean,true) is not false
     or coalesce((v_cross #>> '{methodology,higher_is_better_inferred}')::boolean,true) is not false then
    raise exception 'Universal equipment comparison must remain neutral';
  end if;

  v_boots := huntnexus_equipment_attribute_vector('depth-calcei');
  if not exists (
    select 1 from jsonb_array_elements(v_boots->'metrics') m
    where m->>'metric_key'='effect/movement/speed/speed_points'
      and (m->>'value')::numeric=-5
  ) then
    raise exception 'Negative speed preservation regression';
  end if;

  v_magic := huntnexus_equipment_attribute_vector('cocoa-grimoire');
  if not exists (
    select 1 from jsonb_array_elements(v_magic->'metrics') m
    where m->>'metric_key'='effect/defense/magic_shield_capacity_flat/capacity'
      and (m->>'value')::numeric=150
  ) or not exists (
    select 1 from jsonb_array_elements(v_magic->'metrics') m
    where m->>'metric_key'='effect/defense/magic_shield_capacity_percent/percent'
      and (m->>'value')::numeric=3
  ) or (v_magic #>> '{profiles,protection,energy}')::numeric <> 5
     or (v_magic #>> '{profiles,magic_skill,magic_level}')::numeric <> 3 then
    raise exception 'Magic shield/spellbook vector regression';
  end if;

  v_reflect := huntnexus_equipment_attribute_vector('eldritch-shield');
  if not exists (
    select 1 from jsonb_array_elements(v_reflect->'metrics') m
    where m->>'metric_key'='effect/defense/damage_reflection/damage'
      and (m->>'value')::numeric=42
  ) then
    raise exception 'Damage reflection regression';
  end if;

  v_leech := huntnexus_equipment_attribute_vector('charged-ethereal-ring');
  if not exists (
    select 1 from jsonb_array_elements(v_leech->'metrics') m
    where m->>'metric_key'='effect/leech/life_leech/percent'
      and (m->>'value')::numeric=2
  ) or (v_leech #>> '{profiles,skill,fist_fighting}')::numeric <> 3
     or (v_leech #>> '{profiles,protection,physical}')::numeric <> 4 then
    raise exception 'Ring leech/skill/protection regression';
  end if;

  if huntnexus_equipment_attribute_vector('does-not-exist') #>> '{error}'
     <> 'equipment_not_found' then
    raise exception 'Missing equipment regression';
  end if;

  if jsonb_array_length(
    huntnexus_compare_equipment_universal(
      '["falcon-coif","lion-plate","soulstrider","lion-spellbook","alicorn-quiver"]'::jsonb
    ) #> '{comparison,dimensions}'
  ) < 10 then
    raise exception 'Expected rich cross-equipment dimension set';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_equipment_attribute_comparison',
  'cross_equipment_dimensions',jsonb_array_length(
    huntnexus_compare_equipment_universal(
      '["falcon-coif","lion-plate","soulstrider","lion-spellbook","alicorn-quiver"]'::jsonb
    ) #> '{comparison,dimensions}'
  )
) as regression_summary;
