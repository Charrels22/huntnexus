-- Focused regression for universal equipment catalog/candidates.

do $$
declare
  v_ed jsonb;
  v_ms jsonb;
  v_ek jsonb;
begin
  if (select count(*) from vw_equipment_catalog_universal) <> 689 then
    raise exception 'Universal equipment catalog count regression';
  end if;

  if (select count(*) from vw_equipment_catalog_universal where equipment_family='spellbook') <> 29 then
    raise exception 'Spellbook classification regression';
  end if;

  if exists (
    select 1 from vw_equipment_catalog_universal
    where item_key in ('helmets','armors','legs','boots','shields','rings','spellbooks','quivers')
  ) then
    raise exception 'Aggregate category pseudo-item regression';
  end if;

  if not exists (
    select 1 from vw_equipment_catalog_universal
    where item_key='lion-spellbook'
      and slot_key='offhand'
      and equipment_family='spellbook'
  ) then
    raise exception 'Real spellbook normalization regression';
  end if;

  v_ed := huntnexus_equipment_candidates_universal('ED',700,'offhand','spellbook',true,50);
  v_ms := huntnexus_equipment_candidates_universal('MS',700,'offhand','spellbook',true,50);
  v_ek := huntnexus_equipment_candidates_universal('EK',700,'body',null,true,50);

  if v_ed #>> '{methodology,stage}' <> 'equipment_candidates_universal_v1'
     or v_ms #>> '{methodology,stage}' <> 'equipment_candidates_universal_v1'
     or v_ek #>> '{methodology,stage}' <> 'equipment_candidates_universal_v1' then
    raise exception 'Equipment candidate stage regression';
  end if;

  if (v_ed #>> '{summary,eligible}')::int <= 0
     or (v_ms #>> '{summary,eligible}')::int <= 0
     or (v_ek #>> '{summary,eligible}')::int <= 0 then
    raise exception 'Expected eligible equipment candidates';
  end if;

  if huntnexus_equipment_candidates_universal('UNKNOWN',700,null,null,true,10) #>> '{error}'
     <> 'unsupported_vocation' then
    raise exception 'Unsupported vocation regression';
  end if;

  if has_table_privilege('anon','public.vw_equipment_catalog_universal','SELECT')
     or has_table_privilege('authenticated','public.vw_equipment_catalog_universal','SELECT') then
    raise exception 'Universal equipment view must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_equipment_catalog_candidates',
  'equipment_items',(select count(*) from vw_equipment_catalog_universal),
  'combat_relevant',(select count(*) from vw_equipment_catalog_universal where combat_relevance='combat_relevant'),
  'spellbooks',(select count(*) from vw_equipment_catalog_universal where equipment_family='spellbook'),
  'slots',(select count(distinct slot_key) from vw_equipment_catalog_universal),
  'families',(select count(distinct equipment_family) from vw_equipment_catalog_universal)
) as regression_summary;
