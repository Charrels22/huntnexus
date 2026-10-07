-- HuntNexus Brain — Phase 20 native TibiaData catalog ingestion.
-- Replaces the old Lovable/Bun catalog bootstrap with reproducible PostgreSQL/Supabase functions.

create or replace function huntnexus_tibiadata_slug(p_name text)
returns text
language sql
immutable
as $$
  select trim(both '-' from lower(
    regexp_replace(
      translate(
        coalesce(p_name,''),
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'
      ),
      '[^a-zA-Z0-9]+','-','g'
    )
  ));
$$;

create or replace function huntnexus_ingest_tibiadata_creature_page(
  p_page int,
  p_page_size int default 100
)
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_resp record;
  v_json jsonb;
  v_hash text;
  v_snapshot uuid;
  v_rec jsonb;
  v_id int;
  v_name text;
  v_base text;
  v_slug text;
  v_upserted int := 0;
  v_total int := 0;
begin
  select id into strict v_source from sources where name='ByteWizards TibiaData';

  select * into v_resp
  from extensions.http_get(
    format(
      'https://tibiadata.bytewizards.de/api/v1/creatures?page=%s&pageSize=%s',
      greatest(p_page,1),
      greatest(1,least(coalesce(p_page_size,100),100))
    )
  );

  if v_resp.status <> 200 then
    raise exception 'TibiaData creatures page % returned HTTP %', p_page, v_resp.status;
  end if;

  v_json := v_resp.content::jsonb;
  v_total := coalesce(nullif(v_json->>'totalCount','')::int,0);
  v_hash := encode(extensions.digest(v_resp.content,'sha256'),'hex');

  insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
  values(
    v_source,clock_timestamp(),
    format('https://tibiadata.bytewizards.de/api/v1/creatures?page=%s&pageSize=%s',p_page,p_page_size),
    v_hash,v_json
  )
  on conflict(source_id,content_hash) do nothing;

  select id into v_snapshot
  from raw_snapshots
  where source_id=v_source and content_hash=v_hash
  limit 1;

  for v_rec in
    select value from jsonb_array_elements(coalesce(v_json->'items','[]'::jsonb))
  loop
    v_id := nullif(v_rec->>'id','')::int;
    v_name := nullif(v_rec->>'name','');
    if v_id is null or v_name is null then
      continue;
    end if;

    select entity_key into v_slug
    from tibia_entities
    where entity_type='creature'
      and nullif(attributes->>'id','')::int=v_id
    limit 1;

    if v_slug is null then
      v_base := huntnexus_tibiadata_slug(v_name);
      v_slug := v_base;

      if exists(
        select 1 from tibia_entities
        where entity_type='creature'
          and entity_key=v_slug
          and coalesce(nullif(attributes->>'id','')::int,-1)<>v_id
      ) then
        v_slug := v_base||'-'||v_id::text;
      end if;
    end if;

    insert into tibia_entities(
      entity_type,entity_key,name,attributes,source_id,snapshot_id,observed_at
    )
    values(
      'creature',v_slug,v_name,v_rec,v_source,v_snapshot,clock_timestamp()
    )
    on conflict(entity_type,entity_key) do update set
      name=excluded.name,
      attributes=excluded.attributes,
      source_id=excluded.source_id,
      snapshot_id=excluded.snapshot_id,
      observed_at=excluded.observed_at;

    v_upserted := v_upserted+1;
  end loop;

  return jsonb_build_object(
    'page',p_page,
    'page_size',p_page_size,
    'total_count',v_total,
    'upserted',v_upserted
  );
end;
$$;

create or replace function huntnexus_ingest_tibiadata_item_page(
  p_page int,
  p_page_size int default 100
)
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_resp record;
  v_json jsonb;
  v_hash text;
  v_snapshot uuid;
  v_rec jsonb;
  v_id int;
  v_name text;
  v_base text;
  v_slug text;
  v_upserted int := 0;
  v_total int := 0;
begin
  select id into strict v_source from sources where name='ByteWizards TibiaData';

  select * into v_resp
  from extensions.http_get(
    format(
      'https://tibiadata.bytewizards.de/api/v1/items?page=%s&pageSize=%s',
      greatest(p_page,1),
      greatest(1,least(coalesce(p_page_size,100),100))
    )
  );

  if v_resp.status <> 200 then
    raise exception 'TibiaData items page % returned HTTP %', p_page, v_resp.status;
  end if;

  v_json := v_resp.content::jsonb;
  v_total := coalesce(nullif(v_json->>'totalCount','')::int,0);
  v_hash := encode(extensions.digest(v_resp.content,'sha256'),'hex');

  insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
  values(
    v_source,clock_timestamp(),
    format('https://tibiadata.bytewizards.de/api/v1/items?page=%s&pageSize=%s',p_page,p_page_size),
    v_hash,v_json
  )
  on conflict(source_id,content_hash) do nothing;

  select id into v_snapshot
  from raw_snapshots
  where source_id=v_source and content_hash=v_hash
  limit 1;

  for v_rec in
    select value from jsonb_array_elements(coalesce(v_json->'items','[]'::jsonb))
  loop
    v_id := nullif(v_rec->>'id','')::int;
    v_name := nullif(v_rec->>'name','');
    if v_id is null or v_name is null then
      continue;
    end if;

    select slug into v_slug
    from tibia_items
    where external_id=v_id
    limit 1;

    if v_slug is null then
      v_base := huntnexus_tibiadata_slug(v_name);
      v_slug := v_base;

      if exists(
        select 1 from tibia_items
        where slug=v_slug
          and coalesce(external_id,-1)<>v_id
      ) then
        v_slug := v_base||'-'||v_id::text;
      end if;
    end if;

    insert into tibia_items(
      external_id,slug,name,category,primary_type,secondary_type,
      weapon_type,vocation,level_required,attack,defense,armor,damage_type,
      structured_data,source_id,snapshot_id,source_last_updated,observed_at
    )
    values(
      v_id,v_slug,v_name,
      nullif(v_rec->>'categoryName',''),
      nullif(v_rec->>'primaryType',''),
      nullif(v_rec->>'secondaryType',''),
      nullif(v_rec->>'weaponType',''),
      nullif(v_rec->>'vocation',''),
      nullif(v_rec->>'levelRequired',''),
      nullif(v_rec->>'attack',''),
      nullif(v_rec->>'defense',''),
      nullif(v_rec->>'armor',''),
      nullif(v_rec->>'damageType',''),
      v_rec,v_source,v_snapshot,
      nullif(v_rec->>'lastUpdated','')::timestamptz,
      clock_timestamp()
    )
    on conflict(slug) do update set
      external_id=excluded.external_id,
      name=excluded.name,
      category=excluded.category,
      primary_type=excluded.primary_type,
      secondary_type=excluded.secondary_type,
      weapon_type=excluded.weapon_type,
      vocation=excluded.vocation,
      level_required=excluded.level_required,
      attack=excluded.attack,
      defense=excluded.defense,
      armor=excluded.armor,
      damage_type=excluded.damage_type,
      structured_data=excluded.structured_data,
      source_id=excluded.source_id,
      snapshot_id=excluded.snapshot_id,
      source_last_updated=excluded.source_last_updated,
      observed_at=excluded.observed_at;

    v_upserted := v_upserted+1;
  end loop;

  return jsonb_build_object(
    'page',p_page,
    'page_size',p_page_size,
    'total_count',v_total,
    'upserted',v_upserted
  );
end;
$$;

create or replace function huntnexus_ingest_tibiadata_hunting_places()
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_resp record;
  v_json jsonb;
  v_list jsonb;
  v_hash text;
  v_snapshot uuid;
  v_rec jsonb;
  v_id int;
  v_name text;
  v_base text;
  v_slug text;
  v_upserted int := 0;
begin
  select id into strict v_source from sources where name='ByteWizards TibiaData';

  select * into v_resp
  from extensions.http_get('https://tibiadata.bytewizards.de/api/v1/hunting-places/list');

  if v_resp.status <> 200 then
    raise exception 'TibiaData hunting places returned HTTP %', v_resp.status;
  end if;

  v_json := v_resp.content::jsonb;
  v_list := case
    when jsonb_typeof(v_json)='array' then v_json
    else coalesce(v_json->'items','[]'::jsonb)
  end;
  v_hash := encode(extensions.digest(v_resp.content,'sha256'),'hex');

  insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
  values(
    v_source,clock_timestamp(),
    'https://tibiadata.bytewizards.de/api/v1/hunting-places/list',
    v_hash,v_json
  )
  on conflict(source_id,content_hash) do nothing;

  select id into v_snapshot
  from raw_snapshots
  where source_id=v_source and content_hash=v_hash
  limit 1;

  for v_rec in
    select value from jsonb_array_elements(v_list)
  loop
    v_id := nullif(v_rec->>'id','')::int;
    v_name := nullif(v_rec->>'name','');
    if v_id is null or v_name is null then
      continue;
    end if;

    select slug into v_slug
    from tibia_hunting_places
    where external_id=v_id
    limit 1;

    if v_slug is null then
      v_base := huntnexus_tibiadata_slug(v_name);
      v_slug := v_base;

      if exists(
        select 1 from tibia_hunting_places
        where slug=v_slug
          and coalesce(external_id,-1)<>v_id
      ) then
        v_slug := v_base||'-'||v_id::text;
      end if;
    end if;

    insert into tibia_hunting_places(
      external_id,slug,name,title,city,location,vocation,
      structured_data,source_id,snapshot_id,source_last_updated,observed_at
    )
    values(
      v_id,v_slug,v_name,
      nullif(v_rec->>'title',''),
      nullif(v_rec->>'city',''),
      nullif(v_rec->>'location',''),
      nullif(v_rec->>'vocation',''),
      v_rec,v_source,v_snapshot,
      nullif(v_rec->>'lastUpdated','')::timestamptz,
      clock_timestamp()
    )
    on conflict(slug) do update set
      external_id=excluded.external_id,
      name=excluded.name,
      title=excluded.title,
      city=excluded.city,
      location=excluded.location,
      vocation=excluded.vocation,
      structured_data=excluded.structured_data,
      source_id=excluded.source_id,
      snapshot_id=excluded.snapshot_id,
      source_last_updated=excluded.source_last_updated,
      observed_at=excluded.observed_at;

    v_upserted := v_upserted+1;
  end loop;

  return jsonb_build_object(
    'total_count',jsonb_array_length(v_list),
    'upserted',v_upserted
  );
end;
$$;

create or replace function huntnexus_ingest_tibiadata_catalog_batch(
  p_creature_start_page int default 1,
  p_creature_pages int default 0,
  p_item_start_page int default 1,
  p_item_pages int default 0,
  p_include_hunts boolean default false
)
returns jsonb
language plpgsql
as $$
declare
  v_i int;
  v_creatures jsonb := '[]'::jsonb;
  v_items jsonb := '[]'::jsonb;
  v_hunts jsonb := null;
begin
  if p_creature_pages>0 then
    for v_i in p_creature_start_page..(p_creature_start_page+p_creature_pages-1) loop
      v_creatures := v_creatures || jsonb_build_array(
        huntnexus_ingest_tibiadata_creature_page(v_i,100)
      );
      perform pg_sleep(0.20);
    end loop;
  end if;

  if p_item_pages>0 then
    for v_i in p_item_start_page..(p_item_start_page+p_item_pages-1) loop
      v_items := v_items || jsonb_build_array(
        huntnexus_ingest_tibiadata_item_page(v_i,100)
      );
      perform pg_sleep(0.20);
    end loop;
  end if;

  if p_include_hunts then
    v_hunts := huntnexus_ingest_tibiadata_hunting_places();
  end if;

  return jsonb_build_object(
    'creature_pages',v_creatures,
    'item_pages',v_items,
    'hunting_places',v_hunts
  );
end;
$$;

revoke all on function huntnexus_ingest_tibiadata_creature_page(integer,integer)
  from public,anon,authenticated;
revoke all on function huntnexus_ingest_tibiadata_item_page(integer,integer)
  from public,anon,authenticated;
revoke all on function huntnexus_ingest_tibiadata_hunting_places()
  from public,anon,authenticated;
revoke all on function huntnexus_ingest_tibiadata_catalog_batch(integer,integer,integer,integer,boolean)
  from public,anon,authenticated;

grant execute on function huntnexus_ingest_tibiadata_creature_page(integer,integer)
  to service_role;
grant execute on function huntnexus_ingest_tibiadata_item_page(integer,integer)
  to service_role;
grant execute on function huntnexus_ingest_tibiadata_hunting_places()
  to service_role;
grant execute on function huntnexus_ingest_tibiadata_catalog_batch(integer,integer,integer,integer,boolean)
  to service_role;
