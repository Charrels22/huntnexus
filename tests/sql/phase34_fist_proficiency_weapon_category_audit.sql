-- Focused regression for Fist proficiency and weapon-category core readiness.

do $$
declare
  v_audit jsonb;
  v_pair jsonb;
  v_assassin jsonb;
begin
  if (select count(*) from vw_weapon_catalog_universal) <> 854 then
    raise exception 'Universal weapon catalog count regression';
  end if;

  if exists (
    select 1 from vw_weapon_catalog_universal
    where hands is null
       or level_required is null
       or vocation_scope='unknown'
       or (vocation_scope='explicit' and cardinality(vocation_keys)=0)
  ) then
    raise exception 'Structural weapon normalization regression';
  end if;

  if (select count(*) from weapon_proficiency_trees) <> 34 then
    raise exception 'Expected 34 normalized proficiency trees';
  end if;

  if not exists (
    select 1 from vw_weapon_proficiency_family_audit
    where weapon_family='fist' and normalized_trees=7
  ) then
    raise exception 'Fist proficiency coverage regression';
  end if;

  if not exists (
    select 1 from vw_weapon_proficiency_family_audit
    where weapon_family='throwing'
      and system_status='supported'
      and normalized_trees=1
  ) then
    raise exception 'Throwing proficiency evidence regression';
  end if;

  if (select count(*) from weapon_proficiency_perks
      where item_key in (
        'pair-of-monk-fists','nunchaku-of-destruction','eldritch-crescent-moon-spade',
        'amber-kusarigama','soulkamas','grand-sanguine-claws','moonsilver-katar',
        'assassin-star'
      )) <> 80 then
    raise exception 'Fist/throwing perk count regression';
  end if;

  if exists (
    select 1 from weapon_proficiency_perks
    where item_key in (
      'pair-of-monk-fists','nunchaku-of-destruction','eldritch-crescent-moon-spade',
      'amber-kusarigama','soulkamas','grand-sanguine-claws','moonsilver-katar',
      'assassin-star'
    )
      and level_number is not null
  ) then
    raise exception 'Flattened source must not infer level_number';
  end if;

  if not exists (
    select 1 from weapon_proficiency_perks
    where item_key='moonsilver-katar'
      and effect_key='energy_homing_missile_proc'
      and numeric_value=1
      and metadata #>> '{level_damage_percent}'='200'
  ) then
    raise exception 'Moonsilver Katar homing missile regression';
  end if;

  if not exists (
    select 1 from weapon_proficiency_perks
    where item_key='moonsilver-katar'
      and effect_key='element_pierce_energy'
      and numeric_value=4
  ) or not exists (
    select 1 from weapon_proficiency_perks
    where item_key='moonsilver-katar'
      and effect_key='omega_damage'
      and numeric_value=6
      and metadata #>> '{threshold_hp_percent}'='30'
  ) then
    raise exception 'Moonsilver Katar late perk regression';
  end if;

  v_pair := huntnexus_weapon_proficiency_impact_preview(
    'pair-of-monk-fists','[1,2]'::jsonb,100,null
  );
  if (v_pair #>> '{impact_vector,flat_defense_bonus}')::numeric <> 1
     or (v_pair #>> '{impact_vector,auto_attack_skill_derived_damage_term}')::numeric <> 4 then
    raise exception 'Fist generic impact regression';
  end if;

  v_assassin := huntnexus_weapon_candidates_universal('RP',80,'distance','throwing',50);
  if not exists (
    select 1 from jsonb_array_elements(v_assassin->'items') x
    where x->>'item_key'='assassin-star'
      and x->>'eligibility_status'='eligible'
  ) then
    raise exception 'Assassin Star unrestricted-player semantics regression';
  end if;

  v_audit := huntnexus_weapon_category_audit();
  if coalesce((v_audit #>> '{summary,core_contract_ready}')::boolean,false) is not true
     or (v_audit #>> '{summary,structural_gaps,missing_hands}')::int <> 0
     or (v_audit #>> '{summary,structural_gaps,missing_level}')::int <> 0
     or (v_audit #>> '{summary,structural_gaps,unknown_vocation}')::int <> 0
     or coalesce((v_audit #>> '{dependencies,quivers,ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{dependencies,ammunition,ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,proficiency_exhaustive}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,proficiency_backfill_pending}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,final_combat_formula_ready}')::boolean,true) is not false then
    raise exception 'Weapon category audit semantics regression';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','fist_proficiency_weapon_category_audit',
  'catalog_weapons',(select count(*) from vw_weapon_catalog_universal),
  'fist_trees',(select normalized_trees from vw_weapon_proficiency_family_audit where weapon_family='fist'),
  'throwing_trees',(select normalized_trees from vw_weapon_proficiency_family_audit where weapon_family='throwing'),
  'all_normalized_trees',(select count(*) from weapon_proficiency_trees),
  'core_contract_ready',(huntnexus_weapon_category_audit() #>> '{summary,core_contract_ready}')::boolean
) as regression_summary;
