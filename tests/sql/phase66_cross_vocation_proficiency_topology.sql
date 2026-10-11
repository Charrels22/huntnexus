-- Phase 66 — cross-vocation source-backed proficiency topology regression.

do $$
declare
  v_catalog jsonb;
  v_valid jsonb;
  v_invalid jsonb;
begin
  if exists (
    select 1
    from public.weapon_proficiency_trees t
    where t.topology_status='source_backed_level_position'
      and exists (
        select 1
        from public.weapon_proficiency_perks p
        where p.item_key=t.item_key
        group by p.item_key
        having count(*) <> count(p.level_number)
            or count(*) <> count(p.position_in_level)
      )
  ) then
    raise exception 'Source-backed tree has missing level/position';
  end if;

  if (
    select count(*)
    from public.weapon_proficiency_trees
    where topology_status='source_backed_level_position'
  ) <> 31 then
    raise exception 'Expected 31 source-backed proficiency trees';
  end if;

  if (
    select count(*)
    from public.weapon_proficiency_trees
    where topology_status<>'source_backed_level_position'
  ) <> 3 then
    raise exception 'Expected exactly 3 pending proficiency trees';
  end if;

  -- MS catalog must expose exact source-backed topology.
  v_catalog := huntnexus_player_profile_proficiency_catalog('MS',655,'wand');

  if v_catalog #>> '{methodology,stage}' <> 'player_profile_proficiency_catalog_v2'
     or (v_catalog #>> '{summary,source_backed_topology_count}')::int <> 4 then
    raise exception 'MS proficiency catalog topology regression';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_catalog->'trees') t
    cross join lateral jsonb_array_elements(t->'perks') p
    where t->>'item_key'='soultainter'
      and (p->>'perk_order')::int=14
      and (p->>'level_number')::int=7
      and (p->>'position_in_level')::int=1
      and t #>> '{topology_source,profile_name}'='Soul 1H Wand'
  ) then
    raise exception 'Soultainter topology regression';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_catalog->'trees') t
    where t->>'item_key'='eldritch-wand'
      and (t->>'levels_declared')::int=5
      and t #>> '{topology_source,profile_name}'='Eldritch 1H Wand'
  ) then
    raise exception 'Eldritch Wand 5-level correction regression';
  end if;

  -- One perk per known level is valid.
  v_valid := huntnexus_validate_proficiency_selections(
    '{"soultainter":[1,2,4,7,10,12,14]}'::jsonb
  );

  if coalesce((v_valid->>'valid')::boolean,false) is not true then
    raise exception 'Valid one-per-level selection rejected';
  end if;

  -- Perks 2 and 3 both belong to Soultainter level 2 and must be rejected.
  v_invalid := huntnexus_validate_proficiency_selections(
    '{"soultainter":[2,3]}'::jsonb
  );

  if coalesce((v_invalid->>'valid')::boolean,true) is not false then
    raise exception 'Invalid same-level selection accepted';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','cross_vocation_proficiency_topology',
  'source_backed_trees',31,
  'pending_trees',3,
  'one_per_known_level_enforced',true
) as regression_summary;
