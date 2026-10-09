-- Focused regression for ammunition catalog and proficiency family audit.

do $$
declare
  v_arrow100 jsonb;
  v_bolt100 jsonb;
  v_bow100 jsonb;
  v_cross100 jsonb;
begin
  if (select count(*) from public.ammunition_catalog) <> 27
     or (select count(*) from public.ammunition_catalog where ammunition_family='arrow') <> 19
     or (select count(*) from public.ammunition_catalog where ammunition_family='bolt') <> 8 then
    raise exception 'Ammunition catalog count regression';
  end if;

  if not exists (
    select 1 from public.ammunition_catalog
    where item_key='diamond-arrow'
      and level_required=150
      and source_attack=37
      and attack_pattern='area'
  ) then
    raise exception 'Diamond Arrow regression';
  end if;

  if not exists (
    select 1 from public.ammunition_catalog
    where item_key='firestorm-arrow'
      and source_attack=21
      and physical_attack is null
      and elemental_attack=21
      and element='fire'
  ) then
    raise exception 'Pure elemental arrow regression';
  end if;

  if not exists (
    select 1 from public.ammunition_catalog
    where item_key='earth-arrow'
      and source_attack=14
      and physical_attack=14
      and elemental_attack=14
      and element='earth'
  ) then
    raise exception 'Hybrid elemental arrow regression';
  end if;

  v_arrow100 := huntnexus_ammunition_candidates('arrow',100);
  v_bolt100 := huntnexus_ammunition_candidates('bolt',100);

  if (v_arrow100 #>> '{summary,catalog_items}')::int <> 19
     or (v_arrow100 #>> '{summary,eligible}')::int <> 14
     or (v_arrow100 #>> '{summary,blocked}')::int <> 5 then
    raise exception 'Arrow level eligibility regression';
  end if;

  if (v_bolt100 #>> '{summary,catalog_items}')::int <> 8
     or (v_bolt100 #>> '{summary,eligible}')::int <> 6
     or (v_bolt100 #>> '{summary,blocked}')::int <> 2 then
    raise exception 'Bolt level eligibility regression';
  end if;

  v_bow100 := huntnexus_weapon_usage_context('moonsilver-bow','RP',100);
  v_cross100 := huntnexus_weapon_usage_context('moonsilver-crossbow','RP',100);

  if v_bow100 #>> '{methodology,stage}' <> 'weapon_usage_context_v2'
     or v_bow100 #>> '{dependencies,ammunition,catalog_status}' <> 'available'
     or coalesce((v_bow100 #>> '{dependencies,ammunition,candidate_selection_ready}')::boolean,false) is not true
     or (v_bow100 #>> '{dependencies,ammunition,candidates,summary,eligible}')::int <> 14 then
    raise exception 'Bow ammunition integration regression';
  end if;

  if v_cross100 #>> '{dependencies,ammunition,catalog_status}' <> 'available'
     or (v_cross100 #>> '{dependencies,ammunition,candidates,summary,eligible}')::int <> 6 then
    raise exception 'Crossbow ammunition integration regression';
  end if;

  if (select count(*) from public.weapon_proficiency_family_rules where system_status='supported') <> 8
     or (select count(*) from public.weapon_proficiency_family_rules where system_status='not_listed') <> 1 then
    raise exception 'Weapon Proficiency family support regression';
  end if;

  if not exists (
    select 1 from public.weapon_proficiency_family_rules
    where weapon_family='throwing' and system_status='not_listed'
  ) then
    raise exception 'Throwing proficiency ambiguity regression';
  end if;

  if not exists (
    select 1 from public.vw_weapon_proficiency_family_audit
    where weapon_family='sword' and normalized_trees=6
  ) or not exists (
    select 1 from public.vw_weapon_proficiency_family_audit
    where weapon_family='axe' and normalized_trees=2
  ) or not exists (
    select 1 from public.vw_weapon_proficiency_family_audit
    where weapon_family='club' and normalized_trees=2
  ) then
    raise exception 'Existing proficiency tree coverage regression';
  end if;

  if exists (
    select 1 from public.vw_weapon_proficiency_family_audit
    where weapon_family in ('bow','crossbow','fist','rod','wand')
      and normalized_trees <> 0
  ) then
    raise exception 'Unexpected normalized proficiency trees';
  end if;

  if has_table_privilege('anon','public.ammunition_catalog','SELECT')
     or has_table_privilege('authenticated','public.ammunition_catalog','SELECT')
     or has_table_privilege('anon','public.weapon_proficiency_family_rules','SELECT')
     or has_table_privilege('authenticated','public.weapon_proficiency_family_rules','SELECT') then
    raise exception 'New factual catalogs must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','ammunition_and_proficiency_family_audit',
  'ammunition_items',(select count(*) from public.ammunition_catalog),
  'arrows',(select count(*) from public.ammunition_catalog where ammunition_family='arrow'),
  'bolts',(select count(*) from public.ammunition_catalog where ammunition_family='bolt'),
  'proficiency_supported_families',(select count(*) from public.weapon_proficiency_family_rules where system_status='supported'),
  'normalized_proficiency_trees',(select sum(normalized_trees) from public.vw_weapon_proficiency_family_audit)
) as regression_summary;
