-- HuntNexus Brain — Phase 16.1 canonical boss synchronization.
-- Derives canonical boss identities from the fully detailed TibiaData creature catalogue.

create or replace function huntnexus_sync_canonical_boss_profiles()
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_upserted int := 0;
begin
  select id into strict v_source
  from sources
  where name='ByteWizards TibiaData';

  insert into boss_profiles(
    boss_key,name,canonical_monster_key,encounter_type,
    source_id,source_url,observed_at,notes
  )
  select
    e.entity_key,
    e.name,
    e.entity_key,
    'boss_room',
    v_source,
    case
      when nullif(e.attributes->>'id','') is not null
        then 'https://tibiadata.bytewizards.de/api/v1/creatures/'||(e.attributes->>'id')
      else 'https://tibiadata.bytewizards.de/api/v1/creatures'
    end,
    e.observed_at,
    'Automatically synchronized from TibiaData combatProperties.isBoss=true.'
  from tibia_entities e
  where e.entity_type='creature'
    and lower(coalesce(
      e.attributes #>> '{structuredData,combatProperties,isBoss}',
      'false'
    ))='true'
  on conflict(boss_key) do update set
    name=excluded.name,
    canonical_monster_key=excluded.canonical_monster_key,
    source_id=excluded.source_id,
    source_url=excluded.source_url,
    observed_at=excluded.observed_at,
    notes=excluded.notes;

  get diagnostics v_upserted=row_count;

  return jsonb_build_object(
    'upserted',v_upserted,
    'canonical_boss_profiles',(select count(*) from boss_profiles where canonical_monster_key is not null)
  );
end;
$$;

create or replace view vw_boss_rubinot_reconciliation_queue as
select
  c.id as candidate_id,
  c.patch_version,
  c.released_on,
  c.entity_type,
  c.entity_key,
  c.change_kind,
  c.summary,
  c.reconciliation_status,
  c.notes,
  bp.boss_key,
  bp.name as canonical_boss_name
from rubinot_change_candidates c
left join boss_profiles bp
  on bp.boss_key=c.entity_key
where c.entity_type in ('boss','boss_group');

revoke all on function huntnexus_sync_canonical_boss_profiles()
  from public,anon,authenticated;
grant execute on function huntnexus_sync_canonical_boss_profiles()
  to service_role;
