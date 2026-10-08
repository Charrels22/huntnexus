-- Focused regression for full actual-weapon proficiency tree references.

do $$
declare
  v jsonb;
  v_first jsonb;
begin
  v := huntnexus_recommendation_preview_contextual_items(
    'EK',700,'xp',1,1,3,
    '{"weapon_family":"sword","effective_weapon_skill":120,"effective_magic_level":20,"effective_shielding":110}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"grand-sanguine-blade":[1,3],"grand-sanguine-razor":[1,2]}'::jsonb
  );

  v_first := v #> '{results,0}';

  if v_first #>> '{actual_weapon_proficiency,methodology,stage}' <> 'weapon_proficiency_pair_for_items_v2' then
    raise exception 'Expected proficiency pair v2';
  end if;

  if jsonb_array_length(coalesce(v_first #> '{actual_weapon_proficiency,one_handed_reference,perks}','[]'::jsonb)) <> 15
     or jsonb_array_length(coalesce(v_first #> '{actual_weapon_proficiency,two_handed_reference,perks}','[]'::jsonb)) <> 15 then
    raise exception 'Expected 15 normalized perks for Cobra Grand Sanguine pair';
  end if;

  if v_first #>> '{actual_weapon_proficiency,one_handed_reference,selection,active_perk_count}' <> '2'
     or v_first #>> '{actual_weapon_proficiency,two_handed_reference,selection,active_perk_count}' <> '2' then
    raise exception 'Reference active selection regression';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','actual_weapon_full_tree_reference'
) as regression_summary;
