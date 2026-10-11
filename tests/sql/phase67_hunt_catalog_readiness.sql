-- Phase 67 — canonical hunt catalog readiness regression.

do $$
declare
  v_audit jsonb;
begin
  v_audit := huntnexus_hunt_catalog_readiness_audit();

  if v_audit #>> '{methodology,stage}' <> 'hunt_catalog_readiness_audit_v1'
     or coalesce((v_audit #>> '{methodology,opaque_score_used}')::boolean,true) is not false then
    raise exception 'Hunt catalog readiness methodology regression';
  end if;

  if (v_audit #>> '{summary,planner_eligible_entries}')::int <> 454 then
    raise exception 'Planner eligible hunt count regression';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_audit->'entries') e
    where coalesce((e->>'planner_eligible')::boolean,false)
      and not coalesce((e->>'source_core_complete')::boolean,false)
  ) then
    raise exception 'Planner eligible hunt with incomplete source core';
  end if;

  if not exists (
    select 1
    from public.hunting_place_creature_recovery_audit
    where hunt_key='forest-of-life'
      and resolution_status='resolved_exact'
  ) then
    raise exception 'Forest of Life CreatureList recovery regression';
  end if;

  if not exists (
    select 1
    from public.hunting_place_prose_creature_recovery_audit
    where hunt_key='roshamuul-mines'
      and monster_slug='terrorsleep'
  ) then
    raise exception 'Roshamuul Mines prose recovery regression';
  end if;

  if not exists (
    select 1
    from public.hunting_place_external_creature_recovery_audit
    where hunt_key='mount-sternum-dragon-cave'
      and monster_slug='dragon'
  ) then
    raise exception 'Mount Sternum external creature evidence regression';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(huntnexus_search_hunts('hunting places',20)) x
    where x->>'hunt_key'='hunting-places'
  ) then
    raise exception 'Directory leaked into canonical hunt search';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(huntnexus_search_hunts('forsaken mine',20)) x
    where x->>'hunt_key'='forsaken-mine'
  ) then
    raise exception 'Dynamic container leaked into canonical hunt search';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','canonical_hunt_catalog_readiness',
  'planner_eligible_hunts',454,
  'planner_eligible_core_complete',454
) as regression_summary;
