-- Focused regression for the vocation-agnostic universal weapon catalog.

do $$
declare
  v_total int;
begin
  select count(*) into v_total from public.vw_weapon_catalog_universal;

  if v_total <> 855 then
    raise exception 'Universal weapon catalog count regression: expected 855, got %', v_total;
  end if;

  if not exists (
    select 1 from public.vw_weapon_catalog_universal
    where item_key='moonsilver-claymore'
      and weapon_class='melee'
      and weapon_family='sword'
      and 'knight'=any(vocation_keys)
  ) then
    raise exception 'Knight melee normalization regression';
  end if;

  if not exists (
    select 1 from public.vw_weapon_catalog_universal
    where item_key='moonsilver-bow'
      and weapon_class='distance'
      and weapon_family='bow'
      and 'paladin'=any(vocation_keys)
  ) then
    raise exception 'Paladin bow normalization regression';
  end if;

  if not exists (
    select 1 from public.vw_weapon_catalog_universal
    where item_key='moonsilver-sceptre'
      and weapon_class='caster'
      and weapon_family='rod'
      and primary_skill_key='magic_level'
      and 'druid'=any(vocation_keys)
  ) then
    raise exception 'Druid rod normalization regression';
  end if;

  if not exists (
    select 1 from public.vw_weapon_catalog_universal
    where item_key='moonsilver-channeler'
      and weapon_class='caster'
      and weapon_family='wand'
      and primary_skill_key='magic_level'
      and 'sorcerer'=any(vocation_keys)
  ) then
    raise exception 'Sorcerer wand normalization regression';
  end if;

  if has_table_privilege('anon','public.vw_weapon_catalog_universal','SELECT')
     or has_table_privilege('authenticated','public.vw_weapon_catalog_universal','SELECT') then
    raise exception 'Universal weapon catalog must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_weapon_catalog',
  'weapons',(select count(*) from public.vw_weapon_catalog_universal),
  'classes',(select count(distinct weapon_class) from public.vw_weapon_catalog_universal),
  'families',(select count(distinct weapon_family) from public.vw_weapon_catalog_universal)
) as regression_summary;
