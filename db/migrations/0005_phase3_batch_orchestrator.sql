-- HuntNexus Brain — Phase 3 batch orchestrator.
-- Reduces MCP database action usage: one call performs ingestion + validation.

create or replace function huntnexus_phase3_batch(
  p_creatures int default 100,
  p_hunts int default 25
) returns jsonb
language plpgsql
as $$
declare
  v_creatures jsonb;
  v_hunts jsonb;
  v_result jsonb;
begin
  v_creatures := huntnexus_ingest_creature_details(
    greatest(0, least(coalesce(p_creatures,100),100))
  );

  if coalesce(p_hunts,0) > 0 then
    v_hunts := huntnexus_ingest_hunting_place_details(
      greatest(0, least(p_hunts,50))
    );
  else
    v_hunts := jsonb_build_object('completed',0,'errors',0);
  end if;

  select jsonb_build_object(
    'creature_run', v_creatures,
    'hunt_run', v_hunts,
    'totals', jsonb_build_object(
      'creatures_completed',
        (select count(*) from creature_detail_state where status='completed'),
      'creatures_error',
        (select count(*) from creature_detail_state where status='error'),
      'vulnerability_rows',
        (select count(*) from monster_vulnerability),
      'ability_rows',
        (select count(*) from creature_abilities),
      'loot_rows',
        (select count(*) from creature_loot),
      'hunts_completed',
        (select count(*) from hunting_place_detail_state where status='completed'),
      'hunts_error',
        (select count(*) from hunting_place_detail_state where status='error'),
      'hunt_creature_links',
        (select count(*) from hunting_place_creatures),
      'raw_snapshots',
        (select count(*) from raw_snapshots)
    ),
    'remaining', jsonb_build_object(
      'creatures',
        (select count(*)
         from tibia_entities e
         left join creature_detail_state s on s.monster_key=e.entity_key
         where e.entity_type='creature'
           and coalesce(s.status,'pending') <> 'completed'),
      'hunts',
        (select count(*)
         from tibia_hunting_places h
         left join hunting_place_detail_state s on s.hunting_place_id=h.id
         where coalesce(s.status,'pending') <> 'completed')
    )
  )
  into v_result;

  return v_result;
end;
$$;

revoke all on function huntnexus_phase3_batch(integer,integer)
  from public, anon, authenticated;

grant execute on function huntnexus_phase3_batch(integer,integer)
  to service_role;
