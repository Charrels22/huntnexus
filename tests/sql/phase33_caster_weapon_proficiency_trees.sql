-- Focused regression for normalized Wand/Rod Weapon Proficiency trees.

do $$
declare
  v_ms jsonb;
  v_ed jsonb;
  v_missing jsonb;
begin
  if (select count(*) from weapon_proficiency_trees
      where item_key in (
        'soulhexer','soultainter','grand-sanguine-rod','grand-sanguine-coil',
        'amber-rod','amber-wand','eldritch-rod','eldritch-wand'
      )) <> 8 then
    raise exception 'Caster proficiency tree count regression';
  end if;

  if (select count(*) from weapon_proficiency_perks
      where item_key in (
        'soulhexer','soultainter','grand-sanguine-rod','grand-sanguine-coil',
        'amber-rod','amber-wand','eldritch-rod','eldritch-wand'
      )) <> 100 then
    raise exception 'Caster proficiency perk count regression';
  end if;

  if exists (
    select 1 from weapon_proficiency_perks
    where item_key in (
      'soulhexer','soultainter','grand-sanguine-rod','grand-sanguine-coil',
      'amber-rod','amber-wand','eldritch-rod','eldritch-wand'
    )
      and level_number is not null
  ) then
    raise exception 'Flattened caster source must not infer level_number';
  end if;

  if not exists (
    select 1 from weapon_proficiency_perks
    where item_key='grand-sanguine-coil'
      and perk_order=10
      and effect_key='energy_magic_level_bonus'
      and numeric_value=2
  ) or not exists (
    select 1 from weapon_proficiency_perks
    where item_key='grand-sanguine-coil'
      and perk_order=11
      and effect_key='fire_magic_level_bonus'
      and numeric_value=2
  ) then
    raise exception 'Grand Sanguine Coil elemental ML regression';
  end if;

  if not exists (
    select 1 from weapon_proficiency_perks
    where item_key='grand-sanguine-rod'
      and perk_order=12
      and effect_key='healing_magic_level_bonus'
      and numeric_value=3
  ) then
    raise exception 'Grand Sanguine Rod healing ML regression';
  end if;

  if not exists (
    select 1 from weapon_proficiency_perks
    where item_key='soultainter'
      and effect_key='offensive_rune_critical_extra_damage'
      and numeric_value=12
  ) or not exists (
    select 1 from weapon_proficiency_perks
    where item_key='soulhexer'
      and effect_key='ice_burst_life_leech'
      and numeric_value=10
  ) then
    raise exception 'Soul caster proficiency regression';
  end if;

  if not exists (
    select 1 from vw_weapon_proficiency_family_audit
    where weapon_family='wand' and normalized_trees=4
  ) or not exists (
    select 1 from vw_weapon_proficiency_family_audit
    where weapon_family='rod' and normalized_trees=4
  ) then
    raise exception 'Caster family audit coverage regression';
  end if;

  v_ms := huntnexus_weapon_proficiency_impact_preview(
    'grand-sanguine-coil','[1,8,10,11,15]'::jsonb,null,20
  );
  if v_ms #>> '{methodology,stage}' <> 'weapon_proficiency_impact_preview_v2'
     or (v_ms #>> '{impact_vector,flat_magic_level_bonus}')::numeric <> 1
     or (v_ms #>> '{impact_vector,elemental_magic_level_bonuses,energy}')::numeric <> 2
     or (v_ms #>> '{impact_vector,elemental_magic_level_bonuses,fire}')::numeric <> 2
     or (v_ms #>> '{impact_vector,spell_magic_level_derived_damage_term}')::numeric <> 1.6 then
    raise exception 'MS caster impact vector regression';
  end if;

  v_ed := huntnexus_weapon_proficiency_impact_preview(
    'grand-sanguine-rod','[1,8,10,11,12,16]'::jsonb,null,20
  );
  if (v_ed #>> '{impact_vector,flat_magic_level_bonus}')::numeric <> 1
     or (v_ed #>> '{impact_vector,elemental_magic_level_bonuses,earth}')::numeric <> 2
     or (v_ed #>> '{impact_vector,elemental_magic_level_bonuses,ice}')::numeric <> 2
     or (v_ed #>> '{impact_vector,healing_magic_level_bonus}')::numeric <> 3 then
    raise exception 'ED caster impact vector regression';
  end if;

  v_missing := huntnexus_weapon_proficiency_impact_preview(
    'grand-sanguine-coil','[8]'::jsonb,null,null
  );
  if v_missing #>> '{impact_vector,displayed_effective_weapon_skill}' is not null
     or v_missing #>> '{impact_vector,spell_magic_level_derived_damage_term}' is not null
     or not ((v_missing->'unresolved_inputs') ? 'effective_magic_level') then
    raise exception 'Null input preservation regression';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','caster_weapon_proficiency_trees',
  'wand_trees',(select normalized_trees from vw_weapon_proficiency_family_audit where weapon_family='wand'),
  'rod_trees',(select normalized_trees from vw_weapon_proficiency_family_audit where weapon_family='rod'),
  'normalized_caster_trees',(
    select count(*) from weapon_proficiency_trees t
    join vw_weapon_catalog_universal w on w.item_key=t.item_key
    where w.weapon_family in ('wand','rod')
  ),
  'all_normalized_trees',(select count(*) from weapon_proficiency_trees)
) as regression_summary;
