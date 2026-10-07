-- HuntNexus Brain — Phase 21 async detail ingestion with pg_net.
-- Removes the need for slow sequential detail HTTP calls during bootstrap/refresh.

create extension if not exists pg_net;

create table if not exists huntnexus_async_detail_jobs (
  kind text not null check (kind in ('creature','hunt','item')),
  external_id int not null,
  entity_key text not null,
  request_id bigint,
  status text not null default 'queued'
    check (status in ('queued','processed','error')),
  queued_at timestamptz not null default now(),
  processed_at timestamptz,
  error_text text,
  primary key(kind,external_id)
);

create index if not exists idx_huntnexus_async_detail_jobs_status
  on huntnexus_async_detail_jobs(kind,status,queued_at);

create or replace function huntnexus_apply_creature_detail_json(
  p_entity_key text,
  p_external_id int,
  p_content text
)
returns void
language plpgsql
as $$
declare
  v_source uuid;
  v_json jsonb;
  v_hash text;
  v_snapshot uuid;
begin
  select id into strict v_source from sources where name='ByteWizards TibiaData';
  v_json := p_content::jsonb;
  v_hash := encode(extensions.digest(p_content,'sha256'),'hex');

  insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
  values(
    v_source,clock_timestamp(),
    format('https://tibiadata.bytewizards.de/api/v1/creatures/%s',p_external_id),
    v_hash,v_json
  )
  on conflict(source_id,content_hash) do nothing;

  select id into v_snapshot
  from raw_snapshots
  where source_id=v_source and content_hash=v_hash
  limit 1;

  update tibia_entities
  set name=coalesce(nullif(v_json->>'name',''),name),
      attributes=v_json,
      snapshot_id=v_snapshot,
      observed_at=clock_timestamp()
  where entity_type='creature' and entity_key=p_entity_key;

  delete from monster_vulnerability
  where monster_key=p_entity_key and source_id=v_source;

  insert into monster_vulnerability(
    monster_key,element,modifier_percent,source_id,observed_at
  )
  select p_entity_key,x.element,x.modifier,v_source,clock_timestamp()
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
  values(
    p_entity_key,
    nullif(v_json #>> '{structuredData,infobox,attackType}',''),
    nullif(v_json #>> '{structuredData,infobox,abilities}',''),
    nullif(v_json #>> '{structuredData,combatProperties,maxDamage}','')::int,
    case
      when lower(coalesce(v_json #>> '{structuredData,combatProperties,usesSpells}',''))='true' then true
      when lower(coalesce(v_json #>> '{structuredData,combatProperties,usesSpells}',''))='false' then false
      else null
    end,
    v_source,v_snapshot,clock_timestamp()
  )
  on conflict(monster_key,source_id) do update set
    attack_type=excluded.attack_type,
    abilities_raw=excluded.abilities_raw,
    max_damage=excluded.max_damage,
    uses_spells=excluded.uses_spells,
    snapshot_id=excluded.snapshot_id,
    observed_at=excluded.observed_at;

  delete from creature_loot
  where monster_key=p_entity_key and source_id=v_source;

  insert into creature_loot(
    monster_key,item_name,chance,rarity,raw_text,
    source_id,snapshot_id,observed_at
  )
  select
    p_entity_key,
    nullif(l->>'itemName',''),
    nullif(l->>'chance',''),
    nullif(l->>'rarity',''),
    nullif(l->>'raw',''),
    v_source,v_snapshot,clock_timestamp()
  from jsonb_array_elements(coalesce(v_json->'lootStatistics','[]'::jsonb)) l;

  insert into creature_detail_state(
    monster_key,external_id,source_id,detail_snapshot_id,
    source_last_updated,fetched_at,status,error_text
  )
  values(
    p_entity_key,p_external_id,v_source,v_snapshot,
    nullif(v_json->>'lastUpdated','')::timestamptz,
    clock_timestamp(),'completed',null
  )
  on conflict(monster_key) do update set
    external_id=excluded.external_id,
    source_id=excluded.source_id,
    detail_snapshot_id=excluded.detail_snapshot_id,
    source_last_updated=excluded.source_last_updated,
    fetched_at=excluded.fetched_at,
    status='completed',
    error_text=null;
end;
$$;

create or replace function huntnexus_apply_hunt_detail_json(
  p_slug text,
  p_external_id int,
  p_content text
)
returns void
language plpgsql
as $$
declare
  v_source uuid;
  v_json jsonb;
  v_hash text;
  v_snapshot uuid;
  v_hunt_id uuid;
begin
  select id into strict v_source from sources where name='ByteWizards TibiaData';
  select id into strict v_hunt_id from tibia_hunting_places where slug=p_slug;
  v_json := p_content::jsonb;
  v_hash := encode(extensions.digest(p_content,'sha256'),'hex');

  insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
  values(
    v_source,clock_timestamp(),
    format('https://tibiadata.bytewizards.de/api/v1/hunting-places/%s',p_external_id),
    v_hash,v_json
  )
  on conflict(source_id,content_hash) do nothing;

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
  where id=v_hunt_id;

  delete from hunting_place_creatures where hunting_place_id=v_hunt_id;

  with flattened as (
    select
      huntnexus_resolve_monster_key(
        nullif(c->>'creatureId','')::int,
        c->>'name'
      ) as monster_slug,
      jsonb_build_object('kind','flattened','creature',c) as metadata
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
    v_hunt_id,
    monster_slug,
    jsonb_build_object('occurrences',jsonb_agg(metadata))
  from all_rows
  where monster_slug is not null and monster_slug<>''
  group by monster_slug;

  insert into hunting_place_detail_state(
    hunting_place_id,external_id,source_id,detail_snapshot_id,
    source_last_updated,fetched_at,status,error_text
  )
  values(
    v_hunt_id,p_external_id,v_source,v_snapshot,
    nullif(v_json->>'lastUpdated','')::timestamptz,
    clock_timestamp(),'completed',null
  )
  on conflict(hunting_place_id) do update set
    external_id=excluded.external_id,
    source_id=excluded.source_id,
    detail_snapshot_id=excluded.detail_snapshot_id,
    source_last_updated=excluded.source_last_updated,
    fetched_at=excluded.fetched_at,
    status='completed',
    error_text=null;
end;
$$;

create or replace function huntnexus_apply_item_detail_json(
  p_slug text,
  p_external_id int,
  p_content text
)
returns void
language plpgsql
as $$
declare
  v_source uuid;
  v_json jsonb;
  v_hash text;
  v_snapshot uuid;
  v_item_id uuid;
begin
  select id into strict v_source from sources where name='ByteWizards TibiaData';
  select id into strict v_item_id from tibia_items where slug=p_slug;
  v_json := p_content::jsonb;
  v_hash := encode(extensions.digest(p_content,'sha256'),'hex');

  insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
  values(
    v_source,clock_timestamp(),
    format('https://tibiadata.bytewizards.de/api/v1/items/%s',p_external_id),
    v_hash,v_json
  )
  on conflict(source_id,content_hash) do nothing;

  select id into v_snapshot
  from raw_snapshots
  where source_id=v_source and content_hash=v_hash
  limit 1;

  update tibia_items
  set name=coalesce(nullif(v_json->>'name',''),name),
      actual_name=nullif(v_json->>'actualName',''),
      category=coalesce(nullif(v_json->>'categoryName',''),category),
      object_class=nullif(v_json->>'objectClass',''),
      primary_type=nullif(v_json->>'primaryType',''),
      secondary_type=nullif(v_json->>'secondaryType',''),
      weapon_type=nullif(v_json->>'weaponType',''),
      hands=nullif(v_json->>'hands',''),
      attack=nullif(v_json->>'attack',''),
      defense=nullif(v_json->>'defense',''),
      defense_mod=nullif(v_json->>'defenseMod',''),
      armor=nullif(v_json->>'armor',''),
      range_value=nullif(v_json->>'range',''),
      level_required=nullif(v_json->>'levelRequired',''),
      imbue_slots=nullif(v_json->>'imbueSlots',''),
      vocation=nullif(v_json->>'vocation',''),
      damage_type=nullif(v_json->>'damageType',''),
      damage_range=nullif(v_json->>'damageRange',''),
      energy_attack=nullif(v_json->>'energyAttack',''),
      fire_attack=nullif(v_json->>'fireAttack',''),
      earth_attack=nullif(v_json->>'earthAttack',''),
      ice_attack=nullif(v_json->>'iceAttack',''),
      death_attack=nullif(v_json->>'deathAttack',''),
      holy_attack=nullif(v_json->>'holyAttack',''),
      npc_price=nullif(v_json->>'npcPrice',''),
      npc_value=nullif(v_json->>'npcValue',''),
      item_value=nullif(v_json->>'value',''),
      weight=nullif(v_json->>'weight',''),
      attrib=nullif(v_json->>'attrib',''),
      upgrade_class=nullif(v_json->>'upgradeClass',''),
      wiki_url=nullif(v_json->>'wikiUrl',''),
      structured_data=v_json,
      snapshot_id=v_snapshot,
      source_last_updated=nullif(v_json->>'lastUpdated','')::timestamptz,
      observed_at=clock_timestamp()
  where id=v_item_id;

  delete from item_attribute_entries
  where item_id=v_item_id and source_id=v_source;

  insert into item_attribute_entries(
    item_id,attribute_key,attribute_value,source_id,snapshot_id,observed_at
  )
  select
    v_item_id,
    e->>'key',
    e->>'value',
    v_source,v_snapshot,clock_timestamp()
  from jsonb_array_elements(
    coalesce(v_json #> '{additionalAttributes,entries}','[]'::jsonb)
  ) e
  where nullif(e->>'key','') is not null
  on conflict(item_id,attribute_key) do update set
    attribute_value=excluded.attribute_value,
    source_id=excluded.source_id,
    snapshot_id=excluded.snapshot_id,
    observed_at=excluded.observed_at;

  insert into item_detail_state(
    item_id,external_id,source_id,detail_snapshot_id,
    source_last_updated,fetched_at,status,error_text
  )
  values(
    v_item_id,p_external_id,v_source,v_snapshot,
    nullif(v_json->>'lastUpdated','')::timestamptz,
    clock_timestamp(),'completed',null
  )
  on conflict(item_id) do update set
    external_id=excluded.external_id,
    source_id=excluded.source_id,
    detail_snapshot_id=excluded.detail_snapshot_id,
    source_last_updated=excluded.source_last_updated,
    fetched_at=excluded.fetched_at,
    status='completed',
    error_text=null;
end;
$$;

create or replace function huntnexus_enqueue_detail_requests(
  p_kind text,
  p_limit int default 100
)
returns jsonb
language plpgsql
as $$
declare
  v_row record;
  v_request bigint;
  v_queued int := 0;
  v_url text;
begin
  if p_kind not in ('creature','hunt','item') then
    raise exception 'unsupported kind %',p_kind;
  end if;

  if p_kind='creature' then
    for v_row in
      select
        nullif(e.attributes->>'id','')::int as external_id,
        e.entity_key
      from tibia_entities e
      left join creature_detail_state s on s.monster_key=e.entity_key
      where e.entity_type='creature'
        and nullif(e.attributes->>'id','') is not null
        and coalesce(s.status,'pending')<>'completed'
        and not exists(
          select 1 from huntnexus_async_detail_jobs j
          where j.kind='creature'
            and j.external_id=nullif(e.attributes->>'id','')::int
            and j.status='queued'
        )
      order by nullif(e.attributes->>'id','')::int
      limit greatest(1,least(coalesce(p_limit,100),500))
    loop
      v_url := format('https://tibiadata.bytewizards.de/api/v1/creatures/%s',v_row.external_id);
      v_request := net.http_get(
        url:=v_url,
        headers:='{"Accept":"application/json","User-Agent":"HuntNexusBrain/0.3 async-ingestion"}'::jsonb,
        timeout_milliseconds:=15000
      );
      insert into huntnexus_async_detail_jobs(
        kind,external_id,entity_key,request_id,status,queued_at,processed_at,error_text
      )
      values('creature',v_row.external_id,v_row.entity_key,v_request,'queued',now(),null,null)
      on conflict(kind,external_id) do update set
        entity_key=excluded.entity_key,
        request_id=excluded.request_id,
        status='queued',
        queued_at=now(),
        processed_at=null,
        error_text=null;
      v_queued:=v_queued+1;
    end loop;

  elsif p_kind='hunt' then
    for v_row in
      select h.external_id,h.slug as entity_key
      from tibia_hunting_places h
      left join hunting_place_detail_state s on s.hunting_place_id=h.id
      where h.external_id is not null
        and coalesce(s.status,'pending')<>'completed'
        and not exists(
          select 1 from huntnexus_async_detail_jobs j
          where j.kind='hunt' and j.external_id=h.external_id and j.status='queued'
        )
      order by h.external_id
      limit greatest(1,least(coalesce(p_limit,100),500))
    loop
      v_url := format('https://tibiadata.bytewizards.de/api/v1/hunting-places/%s',v_row.external_id);
      v_request := net.http_get(
        url:=v_url,
        headers:='{"Accept":"application/json","User-Agent":"HuntNexusBrain/0.3 async-ingestion"}'::jsonb,
        timeout_milliseconds:=15000
      );
      insert into huntnexus_async_detail_jobs(
        kind,external_id,entity_key,request_id,status,queued_at,processed_at,error_text
      )
      values('hunt',v_row.external_id,v_row.entity_key,v_request,'queued',now(),null,null)
      on conflict(kind,external_id) do update set
        entity_key=excluded.entity_key,
        request_id=excluded.request_id,
        status='queued',
        queued_at=now(),
        processed_at=null,
        error_text=null;
      v_queued:=v_queued+1;
    end loop;

  else
    for v_row in
      select i.external_id,i.slug as entity_key
      from tibia_items i
      left join item_detail_state s on s.item_id=i.id
      where i.external_id is not null
        and coalesce(s.status,'pending')<>'completed'
        and i.category in (
          'Club Weapons','Sword Weapons','Axe Weapons','Armors','Helmets','Shields',
          'Amulets and Necklaces','Wands','Boots','Legs','Bows','Rods','Rings',
          'Crossbows','Fist Fighting Weapons','Throwing Weapons','Quivers','Spellbooks',
          'Clothing Accessories','Enchanted Items','Magical Items'
        )
        and not exists(
          select 1 from huntnexus_async_detail_jobs j
          where j.kind='item' and j.external_id=i.external_id and j.status='queued'
        )
      order by i.category,i.name
      limit greatest(1,least(coalesce(p_limit,100),500))
    loop
      v_url := format('https://tibiadata.bytewizards.de/api/v1/items/%s',v_row.external_id);
      v_request := net.http_get(
        url:=v_url,
        headers:='{"Accept":"application/json","User-Agent":"HuntNexusBrain/0.3 async-ingestion"}'::jsonb,
        timeout_milliseconds:=15000
      );
      insert into huntnexus_async_detail_jobs(
        kind,external_id,entity_key,request_id,status,queued_at,processed_at,error_text
      )
      values('item',v_row.external_id,v_row.entity_key,v_request,'queued',now(),null,null)
      on conflict(kind,external_id) do update set
        entity_key=excluded.entity_key,
        request_id=excluded.request_id,
        status='queued',
        queued_at=now(),
        processed_at=null,
        error_text=null;
      v_queued:=v_queued+1;
    end loop;
  end if;

  return jsonb_build_object('kind',p_kind,'queued',v_queued);
end;
$$;

create or replace function huntnexus_process_detail_responses(
  p_kind text,
  p_limit int default 200
)
returns jsonb
language plpgsql
as $$
declare
  v_row record;
  v_processed int := 0;
  v_errors int := 0;
begin
  for v_row in
    select
      j.kind,j.external_id,j.entity_key,j.request_id,
      r.status_code,r.content,r.error_msg,r.timed_out
    from huntnexus_async_detail_jobs j
    join net._http_response r on r.id=j.request_id
    where j.kind=p_kind and j.status='queued'
    order by j.queued_at,j.external_id
    limit greatest(1,least(coalesce(p_limit,200),1000))
  loop
    begin
      if v_row.status_code<>200 or v_row.error_msg is not null or coalesce(v_row.timed_out,false) then
        raise exception 'HTTP %: %',coalesce(v_row.status_code,0),coalesce(v_row.error_msg,'request failed');
      end if;

      case p_kind
        when 'creature' then
          perform huntnexus_apply_creature_detail_json(v_row.entity_key,v_row.external_id,v_row.content);
        when 'hunt' then
          perform huntnexus_apply_hunt_detail_json(v_row.entity_key,v_row.external_id,v_row.content);
        when 'item' then
          perform huntnexus_apply_item_detail_json(v_row.entity_key,v_row.external_id,v_row.content);
        else
          raise exception 'unsupported kind %',p_kind;
      end case;

      update huntnexus_async_detail_jobs
      set status='processed',processed_at=now(),error_text=null
      where kind=v_row.kind and external_id=v_row.external_id;

      v_processed:=v_processed+1;
    exception when others then
      update huntnexus_async_detail_jobs
      set status='error',processed_at=now(),error_text=sqlerrm
      where kind=v_row.kind and external_id=v_row.external_id;
      v_errors:=v_errors+1;
    end;
  end loop;

  return jsonb_build_object(
    'kind',p_kind,
    'processed',v_processed,
    'errors',v_errors,
    'queued_waiting',(
      select count(*) from huntnexus_async_detail_jobs
      where kind=p_kind and status='queued'
    ),
    'error_jobs',(
      select count(*) from huntnexus_async_detail_jobs
      where kind=p_kind and status='error'
    )
  );
end;
$$;

create or replace function huntnexus_retry_async_detail_errors(p_kind text)
returns int
language plpgsql
as $$
declare
  v_count int;
begin
  delete from huntnexus_async_detail_jobs
  where kind=p_kind and status='error';
  get diagnostics v_count=row_count;
  return v_count;
end;
$$;

revoke all on function huntnexus_apply_creature_detail_json(text,integer,text)
  from public,anon,authenticated;
revoke all on function huntnexus_apply_hunt_detail_json(text,integer,text)
  from public,anon,authenticated;
revoke all on function huntnexus_apply_item_detail_json(text,integer,text)
  from public,anon,authenticated;
revoke all on function huntnexus_enqueue_detail_requests(text,integer)
  from public,anon,authenticated;
revoke all on function huntnexus_process_detail_responses(text,integer)
  from public,anon,authenticated;
revoke all on function huntnexus_retry_async_detail_errors(text)
  from public,anon,authenticated;

grant execute on function huntnexus_apply_creature_detail_json(text,integer,text) to service_role;
grant execute on function huntnexus_apply_hunt_detail_json(text,integer,text) to service_role;
grant execute on function huntnexus_apply_item_detail_json(text,integer,text) to service_role;
grant execute on function huntnexus_enqueue_detail_requests(text,integer) to service_role;
grant execute on function huntnexus_process_detail_responses(text,integer) to service_role;
grant execute on function huntnexus_retry_async_detail_errors(text) to service_role;
