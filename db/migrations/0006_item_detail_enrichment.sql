-- HuntNexus Brain — Phase 4 item detail enrichment.
-- Prioritizes combat/equipment-relevant Tier B items from ByteWizards TibiaData.

alter table tibia_items add column if not exists actual_name text;
alter table tibia_items add column if not exists object_class text;
alter table tibia_items add column if not exists hands text;
alter table tibia_items add column if not exists defense_mod text;
alter table tibia_items add column if not exists range_value text;
alter table tibia_items add column if not exists imbue_slots text;
alter table tibia_items add column if not exists damage_range text;
alter table tibia_items add column if not exists energy_attack text;
alter table tibia_items add column if not exists fire_attack text;
alter table tibia_items add column if not exists earth_attack text;
alter table tibia_items add column if not exists ice_attack text;
alter table tibia_items add column if not exists death_attack text;
alter table tibia_items add column if not exists holy_attack text;
alter table tibia_items add column if not exists npc_price text;
alter table tibia_items add column if not exists npc_value text;
alter table tibia_items add column if not exists item_value text;
alter table tibia_items add column if not exists weight text;
alter table tibia_items add column if not exists attrib text;
alter table tibia_items add column if not exists upgrade_class text;
alter table tibia_items add column if not exists wiki_url text;

create table if not exists item_detail_state (
  item_id uuid primary key references tibia_items(id) on delete cascade,
  external_id int,
  source_id uuid not null references sources(id),
  detail_snapshot_id uuid references raw_snapshots(id),
  source_last_updated timestamptz,
  fetched_at timestamptz,
  status text not null default 'pending',
  error_text text
);

create index if not exists idx_item_detail_status
  on item_detail_state(status);

create table if not exists item_attribute_entries (
  item_id uuid not null references tibia_items(id) on delete cascade,
  attribute_key text not null,
  attribute_value text,
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  observed_at timestamptz not null,
  primary key (item_id, attribute_key)
);

create index if not exists idx_item_attribute_key
  on item_attribute_entries(attribute_key);

create or replace function huntnexus_ingest_item_details(
  p_limit int default 50,
  p_combat_only boolean default true
) returns jsonb
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
    select i.id, i.slug, i.name, i.external_id, i.category
    from tibia_items i
    left join item_detail_state s on s.item_id=i.id
    where coalesce(s.status,'pending') <> 'completed'
      and i.external_id is not null
      and (
        not p_combat_only
        or i.category in (
          'Club Weapons','Sword Weapons','Axe Weapons','Armors','Helmets','Shields',
          'Amulets and Necklaces','Wands','Boots','Legs','Bows','Rods','Rings',
          'Crossbows','Fist Fighting Weapons','Throwing Weapons','Quivers','Spellbooks',
          'Clothing Accessories','Enchanted Items','Magical Items'
        )
      )
    order by i.category, i.name
    limit greatest(1, least(coalesce(p_limit,50),100))
  loop
    begin
      insert into item_detail_state(
        item_id,external_id,source_id,fetched_at,status,error_text
      ) values (
        v_row.id,v_row.external_id,v_source,clock_timestamp(),'running',null
      )
      on conflict (item_id) do update set
        external_id=excluded.external_id,
        source_id=excluded.source_id,
        fetched_at=excluded.fetched_at,
        status='running',
        error_text=null;

      select *
      into v_resp
      from extensions.http_get(
        format('https://tibiadata.bytewizards.de/api/v1/items/%s',v_row.external_id)
      );

      if v_resp.status <> 200 then
        raise exception 'HTTP % for item %', v_resp.status, v_row.external_id;
      end if;

      v_json := v_resp.content::jsonb;
      v_hash := encode(extensions.digest(v_resp.content, 'sha256'), 'hex');

      insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
      values (
        v_source,
        clock_timestamp(),
        format('https://tibiadata.bytewizards.de/api/v1/items/%s',v_row.external_id),
        v_hash,
        v_json
      )
      on conflict (source_id,content_hash) do nothing;

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
      where id=v_row.id;

      delete from item_attribute_entries
      where item_id=v_row.id
        and source_id=v_source;

      insert into item_attribute_entries(
        item_id,attribute_key,attribute_value,source_id,snapshot_id,observed_at
      )
      select
        v_row.id,
        e->>'key',
        e->>'value',
        v_source,
        v_snapshot,
        clock_timestamp()
      from jsonb_array_elements(
        coalesce(v_json #> '{additionalAttributes,entries}','[]'::jsonb)
      ) e
      where nullif(e->>'key','') is not null
      on conflict (item_id,attribute_key) do update set
        attribute_value=excluded.attribute_value,
        source_id=excluded.source_id,
        snapshot_id=excluded.snapshot_id,
        observed_at=excluded.observed_at;

      update item_detail_state
      set detail_snapshot_id=v_snapshot,
          source_last_updated=nullif(v_json->>'lastUpdated','')::timestamptz,
          fetched_at=clock_timestamp(),
          status='completed',
          error_text=null
      where item_id=v_row.id;

      v_completed := v_completed + 1;
    exception when others then
      v_errors := v_errors + 1;
      insert into item_detail_state(
        item_id,external_id,source_id,fetched_at,status,error_text
      ) values (
        v_row.id,v_row.external_id,v_source,clock_timestamp(),'error',sqlerrm
      )
      on conflict (item_id) do update set
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
    'errors',v_errors,
    'combat_only',p_combat_only,
    'remaining_combat',(
      select count(*)
      from tibia_items i
      left join item_detail_state s on s.item_id=i.id
      where coalesce(s.status,'pending') <> 'completed'
        and i.external_id is not null
        and i.category in (
          'Club Weapons','Sword Weapons','Axe Weapons','Armors','Helmets','Shields',
          'Amulets and Necklaces','Wands','Boots','Legs','Bows','Rods','Rings',
          'Crossbows','Fist Fighting Weapons','Throwing Weapons','Quivers','Spellbooks',
          'Clothing Accessories','Enchanted Items','Magical Items'
        )
    ),
    'totals',jsonb_build_object(
      'items_completed',(select count(*) from item_detail_state where status='completed'),
      'items_error',(select count(*) from item_detail_state where status='error'),
      'attribute_rows',(select count(*) from item_attribute_entries),
      'raw_snapshots',(select count(*) from raw_snapshots)
    )
  );
end;
$$;

revoke all on function huntnexus_ingest_item_details(integer,boolean)
  from public, anon, authenticated;
grant execute on function huntnexus_ingest_item_details(integer,boolean)
  to service_role;
