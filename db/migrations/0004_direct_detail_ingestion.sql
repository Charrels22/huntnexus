-- HuntNexus Brain — Phase 3 direct database ingestion helpers.
-- Fetches public ByteWizards TibiaData detail endpoints from PostgreSQL/Supabase.
-- Functions are not exposed to anon/authenticated roles.

create extension if not exists http with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists hunting_place_detail_state (
  hunting_place_id uuid primary key references tibia_hunting_places(id) on delete cascade,
  external_id int,
  source_id uuid not null references sources(id),
  detail_snapshot_id uuid references raw_snapshots(id),
  source_last_updated timestamptz,
  fetched_at timestamptz,
  status text not null default 'pending',
  error_text text
);

create index if not exists idx_hunting_place_detail_status
  on hunting_place_detail_state(status);

create or replace function huntnexus_resolve_monster_key(
  p_creature_id int,
  p_name text
) returns text
language sql
stable
as $$
  select coalesce(
    (
      select entity_key
      from tibia_entities
      where entity_type='creature'
        and nullif(attributes->>'id','')::int = p_creature_id
      limit 1
    ),
    (
      select entity_key
      from tibia_entities
      where entity_type='creature'
        and lower(name)=lower(p_name)
      limit 1
    ),
    trim(both '-' from lower(regexp_replace(coalesce(p_name,''), '[^a-zA-Z0-9]+', '-', 'g')))
  );
$$;

create or replace function huntnexus_ingest_creature_details(p_limit int default 10)
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_row record;
  v_resp record;
  v_json jsonb;
  v_hash text;
  v_snapshot uuid;
  v_completed int := 0;
  v_errors int := 0;
  v_started timestamptz := clock_timestamp();
begin
  select id into strict v_source
  from sources
  where name='ByteWizards TibiaData';

  for v_row in
    select e.entity_key,
           e.name,
           nullif(e.attributes->>'id','')::int as external_id
    from tibia_entities e
    left join creature_detail_state s on s.monster_key=e.entity_key
    where e.entity_type='creature'
      and coalesce(s.status,'pending') <> 'completed'
    order by e.name
    limit greatest(1, least(p_limit, 100))
  loop
    begin
      if v_row.external_id is null then
        raise exception 'missing external id';
      end if;

      insert into creature_detail_state(
        monster_key, external_id, source_id, fetched_at, status, error_text
      ) values (
        v_row.entity_key, v_row.external_id, v_source, clock_timestamp(), 'running', null
      )
      on conflict (monster_key) do update set
        external_id=excluded.external_id,
        source_id=excluded.source_id,
        fetched_at=excluded.fetched_at,
        status='running',
        error_text=null;

      select *
      into v_resp
      from extensions.http_get(
        format('https://tibiadata.bytewizards.de/api/v1/creatures/%s', v_row.external_id)
      );

      if v_resp.status <> 200 then
        raise exception 'HTTP % for creature %', v_resp.status, v_row.external_id;
      end if;

      v_json := v_resp.content::jsonb;
      v_hash := encode(extensions.digest(v_resp.content, 'sha256'), 'hex');

      insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
      values (
        v_source,
        clock_timestamp(),
        format('https://tibiadata.bytewizards.de/api/v1/creatures/%s', v_row.external_id),
        v_hash,
        v_json
      )
      on conflict (source_id,content_hash) do nothing;

      select id into v_snapshot
      from raw_snapshots
      where source_id=v_source and content_hash=v_hash
      limit 1;

      update tibia_entities
      set attributes=v_json,
          snapshot_id=v_snapshot,
          observed_at=clock_timestamp()
      where entity_type='creature'
        and entity_key=v_row.entity_key;

      delete from monster_vulnerability
      where monster_key=v_row.entity_key
        and source_id=v_source;

      insert into monster_vulnerability(
        monster_key,element,modifier_percent,source_id,observed_at
      )
      select v_row.entity_key, x.element, x.modifier, v_source, clock_timestamp()
      from (
        values
          ('physical',   nullif(v_json #>> '{structuredData,resistanceSummary,physicalPercent}','')::numeric),
          ('earth',      nullif(v_json #>> '{structuredData,resistanceSummary,earthPercent}','')::numeric),
          ('fire',       nullif(v_json #>> '{structuredData,resistanceSummary,firePercent}','')::numeric),
          ('death',      nullif(v_json #>> '{structuredData,resistanceSummary,deathPercent}','')::numeric),
          ('energy',     nullif(v_json #>> '{structuredData,resistanceSummary,energyPercent}','')::numeric),
          ('holy',       nullif(v_json #>> '{structuredData,resistanceSummary,holyPercent}','')::numeric),
          ('ice',        nullif(v_json #>> '{structuredData,resistanceSummary,icePercent}','')::numeric),
          ('life_drain', nullif(v_json #>> '{structuredData,resistanceSummary,lifeDrainPercent}','')::numeric),
          ('drown',      nullif(v_json #>> '{structuredData,resistanceSummary,drownPercent}','')::numeric),
          ('healing',    nullif(v_json #>> '{structuredData,resistanceSummary,healingPercent}','')::numeric)
      ) as x(element,modifier)
      where x.modifier is not null;

      insert into creature_abilities(
        monster_key,attack_type,abilities_raw,max_damage,uses_spells,
        source_id,snapshot_id,observed_at
      )
      values (
        v_row.entity_key,
        nullif(v_json #>> '{structuredData,infobox,attackType}',''),
        nullif(v_json #>> '{structuredData,infobox,abilities}',''),
        nullif(v_json #>> '{structuredData,combatProperties,maxDamage}','')::int,
        case
          when lower(coalesce(v_json #>> '{structuredData,combatProperties,usesSpells}',''))='true' then true
          when lower(coalesce(v_json #>> '{structuredData,combatProperties,usesSpells}',''))='false' then false
          else null
        end,
        v_source,
        v_snapshot,
        clock_timestamp()
      )
      on conflict (monster_key,source_id) do update set
        attack_type=excluded.attack_type,
        abilities_raw=excluded.abilities_raw,
        max_damage=excluded.max_damage,
        uses_spells=excluded.uses_spells,
        snapshot_id=excluded.snapshot_id,
        observed_at=excluded.observed_at;

      delete from creature_loot
      where monster_key=v_row.entity_key
        and source_id=v_source;

      insert into creature_loot(
        monster_key,item_name,chance,rarity,raw_text,
        source_id,snapshot_id,observed_at
      )
      select
        v_row.entity_key,
        nullif(l->>'itemName',''),
        nullif(l->>'chance',''),
        nullif(l->>'rarity',''),
        nullif(l->>'raw',''),
        v_source,
        v_snapshot,
        clock_timestamp()
      from jsonb_array_elements(coalesce(v_json->'lootStatistics','[]'::jsonb)) l;

      update creature_detail_state
      set detail_snapshot_id=v_snapshot,
          source_last_updated=nullif(v_json->>'lastUpdated','')::timestamptz,
          fetched_at=clock_timestamp(),
          status='completed',
          error_text=null
      where monster_key=v_row.entity_key;

      v_completed := v_completed + 1;
    exception when others then
      v_errors := v_errors + 1;
      insert into creature_detail_state(
        monster_key, external_id, source_id, fetched_at, status, error_text
      ) values (
        v_row.entity_key, v_row.external_id, v_source, clock_timestamp(), 'error', sqlerrm
      )
      on conflict (monster_key) do update set
        external_id=excluded.external_id,
        source_id=excluded.source_id,
        fetched_at=excluded.fetched_at,
        status='error',
        error_text=excluded.error_text;
    end;

    perform pg_sleep(0.25);
  end loop;

  return jsonb_build_object(
    'started_at',v_started,
    'finished_at',clock_timestamp(),
    'completed',v_completed,
    'errors',v_errors
  );
end;
$$;

create or replace function huntnexus_ingest_hunting_place_details(p_limit int default 5)
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_row record;
  v_resp record;
  v_json jsonb;
  v_hash text;
  v_snapshot uuid;
  v_completed int := 0;
  v_errors int := 0;
  v_started timestamptz := clock_timestamp();
begin
  select id into strict v_source
  from sources
  where name='ByteWizards TibiaData';

  for v_row in
    select h.id, h.slug, h.name, h.external_id
    from tibia_hunting_places h
    left join hunting_place_detail_state s on s.hunting_place_id=h.id
    where coalesce(s.status,'pending') <> 'completed'
    order by h.name
    limit greatest(1, least(p_limit, 50))
  loop
    begin
      if v_row.external_id is null then
        raise exception 'missing external id';
      end if;

      insert into hunting_place_detail_state(
        hunting_place_id,external_id,source_id,fetched_at,status,error_text
      ) values (
        v_row.id,v_row.external_id,v_source,clock_timestamp(),'running',null
      )
      on conflict (hunting_place_id) do update set
        external_id=excluded.external_id,
        source_id=excluded.source_id,
        fetched_at=excluded.fetched_at,
        status='running',
        error_text=null;

      select *
      into v_resp
      from extensions.http_get(
        format('https://tibiadata.bytewizards.de/api/v1/hunting-places/%s',v_row.external_id)
      );

      if v_resp.status <> 200 then
        raise exception 'HTTP % for hunting place %', v_resp.status, v_row.external_id;
      end if;

      v_json := v_resp.content::jsonb;
      v_hash := encode(extensions.digest(v_resp.content, 'sha256'), 'hex');

      insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
      values (
        v_source,
        clock_timestamp(),
        format('https://tibiadata.bytewizards.de/api/v1/hunting-places/%s',v_row.external_id),
        v_hash,
        v_json
      )
      on conflict (source_id,content_hash) do nothing;

      select id into v_snapshot
      from raw_snapshots
      where source_id=v_source and content_hash=v_hash
      limit 1;

      update tibia_hunting_places
      set name=coalesce(nullif(v_json->>'name',''),name),
          title=coalesce(nullif(v_json->>'title',''),title),
          city=nullif(v_json->>'city',''),
          location=nullif(v_json->>'location',''),
          vocation=nullif(v_json->>'vocation',''),
          level_knights=nullif(v_json->>'levelKnights',''),
          level_paladins=nullif(v_json->>'levelPaladins',''),
          level_mages=nullif(v_json->>'levelMages',''),
          loot_rating=coalesce(nullif(v_json->>'lootStar',''),nullif(v_json->>'loot','')),
          experience_rating=coalesce(nullif(v_json->>'experienceStar',''),nullif(v_json->>'experience','')),
          structured_data=v_json,
          snapshot_id=v_snapshot,
          source_last_updated=nullif(v_json->>'lastUpdated','')::timestamptz,
          observed_at=clock_timestamp()
      where id=v_row.id;

      delete from hunting_place_creatures
      where hunting_place_id=v_row.id;

      with flattened as (
        select
          huntnexus_resolve_monster_key(
            nullif(c->>'creatureId','')::int,
            c->>'name'
          ) as monster_slug,
          jsonb_build_object(
            'kind','flattened',
            'creature',c
          ) as metadata
        from jsonb_array_elements(coalesce(v_json->'creatures','[]'::jsonb)) c
      ),
      areas as (
        select
          huntnexus_resolve_monster_key(
            nullif(c->>'creatureId','')::int,
            c->>'name'
          ) as monster_slug,
          jsonb_build_object(
            'kind','area',
            'areaName',a->>'areaName',
            'sectionName',a->>'sectionName',
            'recommendedLevels',a->'recommendedLevels',
            'recommendedSkills',a->'recommendedSkills',
            'recommendedDefense',a->'recommendedDefense',
            'creature',c
          ) as metadata
        from jsonb_array_elements(
          coalesce(v_json #> '{structuredData,areaCreatureSummaries}','[]'::jsonb)
        ) a
        cross join lateral jsonb_array_elements(coalesce(a->'creatures','[]'::jsonb)) c
      ),
      all_rows as (
        select * from flattened
        union all
        select * from areas
      )
      insert into hunting_place_creatures(hunting_place_id,monster_slug,metadata)
      select
        v_row.id,
        monster_slug,
        jsonb_build_object('occurrences',jsonb_agg(metadata))
      from all_rows
      where monster_slug is not null and monster_slug <> ''
      group by monster_slug;

      update hunting_place_detail_state
      set detail_snapshot_id=v_snapshot,
          source_last_updated=nullif(v_json->>'lastUpdated','')::timestamptz,
          fetched_at=clock_timestamp(),
          status='completed',
          error_text=null
      where hunting_place_id=v_row.id;

      v_completed := v_completed + 1;
    exception when others then
      v_errors := v_errors + 1;
      insert into hunting_place_detail_state(
        hunting_place_id,external_id,source_id,fetched_at,status,error_text
      ) values (
        v_row.id,v_row.external_id,v_source,clock_timestamp(),'error',sqlerrm
      )
      on conflict (hunting_place_id) do update set
        external_id=excluded.external_id,
        source_id=excluded.source_id,
        fetched_at=excluded.fetched_at,
        status='error',
        error_text=excluded.error_text;
    end;

    perform pg_sleep(0.25);
  end loop;

  return jsonb_build_object(
    'started_at',v_started,
    'finished_at',clock_timestamp(),
    'completed',v_completed,
    'errors',v_errors
  );
end;
$$;

revoke all on function huntnexus_ingest_creature_details(integer) from public, anon, authenticated;
revoke all on function huntnexus_ingest_hunting_place_details(integer) from public, anon, authenticated;
revoke all on function huntnexus_resolve_monster_key(integer,text) from public, anon, authenticated;

grant execute on function huntnexus_ingest_creature_details(integer) to service_role;
grant execute on function huntnexus_ingest_hunting_place_details(integer) to service_role;
grant execute on function huntnexus_resolve_monster_key(integer,text) to service_role;
