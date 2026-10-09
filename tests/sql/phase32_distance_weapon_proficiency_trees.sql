-- Focused regression for normalized Bow/Crossbow Weapon Proficiency trees.

do $$
declare
  v_bow jsonb;
  v_cross jsonb;
begin
  if (select count(*) from weapon_proficiency_trees
      where item_key in (
        'grand-sanguine-bow','grand-sanguine-crossbow','soulbleeder','soulpiercer',
        'eldritch-bow','gilded-eldritch-bow','bow-of-destruction','crossbow-of-destruction'
      )) <> 8 then
    raise exception 'Distance proficiency tree count regression';
  end if;

  if (select count(*) from weapon_proficiency_perks
      where item_key in (
        'grand-sanguine-bow','grand-sanguine-crossbow','soulbleeder','soulpiercer',
        'eldritch-bow','gilded-eldritch-bow','bow-of-destruction','crossbow-of-destruction'
      )) <> 92 then
    raise exception 'Distance proficiency perk count regression';
  end if;

  if exists (
    select 1 from weapon_proficiency_perks
    where item_key in (
      'grand-sanguine-bow','grand-sanguine-crossbow','soulbleeder','soulpiercer',
      'eldritch-bow','gilded-eldritch-bow','bow-of-destruction','crossbow-of-destruction'
    )
      and level_number is not null
  ) then
    raise exception 'Flattened distance source must not infer level_number';
  end if;

  if not exists (
    select 1 from weapon_proficiency_perks
    where item_key='grand-sanguine-bow'
      and perk_order=10
      and effect_key='skill_spell_extra_damage_percent'
      and numeric_value=10
      and source_stat_key='distance_fighting'
  ) then
    raise exception 'Grand Sanguine Bow distance spell perk regression';
  end if;

  if not exists (
    select 1 from weapon_proficiency_perks
    where item_key='soulpiercer'
      and perk_order=2
      and effect_key='life_on_hit'
      and numeric_value=10
  ) then
    raise exception 'Soulpiercer life-on-hit regression';
  end if;

  if not exists (
    select 1 from weapon_proficiency_perks
    where item_key='eldritch-bow'
      and perk_order=1
      and effect_key='magic_level_auto_attack_extra_damage_percent'
      and numeric_value=10
  ) or not exists (
    select 1 from weapon_proficiency_perks
    where item_key='gilded-eldritch-bow'
      and perk_order=1
      and effect_key='magic_level_auto_attack_extra_damage_percent'
      and numeric_value=15
  ) then
    raise exception 'Eldritch Bow proficiency difference regression';
  end if;

  if not exists (
    select 1 from weapon_proficiency_perks
    where item_key='bow-of-destruction'
      and perk_order=4
      and effect_key='auto_attack_critical_chance'
      and numeric_value=3.5
  ) or not exists (
    select 1 from weapon_proficiency_perks
    where item_key='crossbow-of-destruction'
      and perk_order=4
      and effect_key='auto_attack_critical_chance'
      and numeric_value=3.5
  ) then
    raise exception 'Destruction distance tree regression';
  end if;

  if not exists (
    select 1 from vw_weapon_proficiency_family_audit
    where weapon_family='bow' and normalized_trees=5
  ) or not exists (
    select 1 from vw_weapon_proficiency_family_audit
    where weapon_family='crossbow' and normalized_trees=3
  ) then
    raise exception 'Distance family audit coverage regression';
  end if;

  v_bow := huntnexus_weapon_proficiency_preview(
    'grand-sanguine-bow','[1,3,10,12,15]'::jsonb
  );
  v_cross := huntnexus_weapon_proficiency_preview(
    'soulpiercer','[1,2,9,12,15]'::jsonb
  );

  if v_bow #>> '{methodology,stage}' <> 'weapon_proficiency_preview_v1'
     or (v_bow #>> '{selection,active_perk_count}')::int <> 5
     or v_cross #>> '{methodology,stage}' <> 'weapon_proficiency_preview_v1'
     or (v_cross #>> '{selection,active_perk_count}')::int <> 5 then
    raise exception 'Distance proficiency preview regression';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','distance_weapon_proficiency_trees',
  'normalized_distance_trees',(
    select count(*) from weapon_proficiency_trees t
    join vw_weapon_catalog_universal w on w.item_key=t.item_key
    where w.weapon_family in ('bow','crossbow')
  ),
  'bow_trees',(
    select normalized_trees from vw_weapon_proficiency_family_audit where weapon_family='bow'
  ),
  'crossbow_trees',(
    select normalized_trees from vw_weapon_proficiency_family_audit where weapon_family='crossbow'
  ),
  'all_normalized_trees',(select count(*) from weapon_proficiency_trees)
) as regression_summary;
