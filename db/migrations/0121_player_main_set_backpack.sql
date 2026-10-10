-- HuntNexus FE-06 — player-owned main set and backpack inventory.
-- Main set is the player's baseline. Backpack items are owned alternatives.
-- External catalog items remain advisory and are never auto-added to owned inventory.

create table if not exists public.player_character_inventory (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null,
  storage_kind text not null check (storage_kind in ('main','backpack')),
  selection_key text not null,
  item_key text not null,
  item_name text not null,
  quantity integer not null default 1 check (quantity >= 1 and quantity <= 9999),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists player_character_inventory_main_slot_uq
  on public.player_character_inventory(client_id,selection_key)
  where storage_kind='main';

create unique index if not exists player_character_inventory_backpack_item_uq
  on public.player_character_inventory(client_id,selection_key,item_key)
  where storage_kind='backpack';

create index if not exists player_character_inventory_client_idx
  on public.player_character_inventory(client_id,storage_kind,selection_key);

alter table public.player_character_inventory enable row level security;

create or replace function public.huntnexus_player_inventory_get(
  p_client_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with rows as (
  select
    i.id,
    i.storage_kind,
    i.selection_key,
    i.item_key,
    i.item_name,
    i.quantity,
    i.notes,
    i.updated_at,
    c.item_domain,
    c.item_family,
    c.level_required,
    c.vocation_scope,
    c.vocation_keys,
    c.hands,
    c.weapon_class,
    c.imbue_slots,
    c.wiki_url
  from public.player_character_inventory i
  left join public.vw_loadout_item_catalog_universal c
    on c.item_key=i.item_key and c.selection_key=i.selection_key
  where i.client_id=p_client_id
)
select jsonb_build_object(
  'main_set',coalesce((
    select jsonb_object_agg(
      selection_key,
      jsonb_build_object(
        'inventory_id',id,
        'selection_key',selection_key,
        'item_key',item_key,
        'item_name',item_name,
        'quantity',quantity,
        'notes',notes,
        'item_domain',item_domain,
        'item_family',item_family,
        'level_required',level_required,
        'vocation_scope',vocation_scope,
        'vocation_keys',to_jsonb(vocation_keys),
        'hands',hands,
        'weapon_class',weapon_class,
        'imbue_slots',imbue_slots,
        'wiki_url',wiki_url
      )
      order by selection_key
    )
    from rows where storage_kind='main'
  ),'{}'::jsonb),
  'backpack',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'inventory_id',id,
        'selection_key',selection_key,
        'item_key',item_key,
        'item_name',item_name,
        'quantity',quantity,
        'notes',notes,
        'item_domain',item_domain,
        'item_family',item_family,
        'level_required',level_required,
        'vocation_scope',vocation_scope,
        'vocation_keys',to_jsonb(vocation_keys),
        'hands',hands,
        'weapon_class',weapon_class,
        'imbue_slots',imbue_slots,
        'wiki_url',wiki_url
      )
      order by selection_key,item_name,item_key
    )
    from rows where storage_kind='backpack'
  ),'[]'::jsonb),
  'summary',jsonb_build_object(
    'main_slots',(select count(*) from rows where storage_kind='main'),
    'backpack_items',(select count(*) from rows where storage_kind='backpack')
  ),
  'methodology',jsonb_build_object(
    'stage','player_inventory_v1',
    'main_set_is_baseline',true,
    'backpack_is_owned_alternative_pool',true,
    'external_catalog_items_are_owned',false,
    'automatic_main_replacement',false
  )
);
$function$;

create or replace function public.huntnexus_player_inventory_search(
  p_vocation text,
  p_level integer,
  p_query text,
  p_selection_key text default null,
  p_limit integer default 20
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    lower(nullif(trim(coalesce(p_selection_key,'')),'')) as slot_filter,
    trim(coalesce(p_query,'')) as query_text,
    least(greatest(coalesce(p_limit,20),1),50) as limit_value
),
mapped as (
  select *,
    case vocation_code
      when 'EK' then 'knight'
      when 'RP' then 'paladin'
      when 'ED' then 'druid'
      when 'MS' then 'sorcerer'
      when 'EM' then 'monk'
      else null
    end as vocation_key
  from p
),
matches as (
  select
    c.*,
    m.vocation_code,
    m.vocation_key,
    m.level_value,
    m.query_text,
    (c.level_required > m.level_value) as blocked_by_level,
    (
      c.vocation_scope='explicit'
      and m.vocation_key is not null
      and not (m.vocation_key=any(c.vocation_keys))
    ) as blocked_by_vocation
  from public.vw_loadout_item_catalog_universal c
  cross join mapped m
  where
    length(m.query_text)>=2
    and c.name ilike '%'||m.query_text||'%'
    and (m.slot_filter is null or c.selection_key=m.slot_filter)
),
limited as (
  select *
  from matches
  order by
    case when not blocked_by_level and not blocked_by_vocation then 0 else 1 end,
    case
      when lower(name)=lower(query_text) then 0
      when lower(name) like lower(query_text)||'%' then 1
      else 2
    end,
    level_required desc,
    name,
    item_key
  limit (select limit_value from mapped)
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'vocation',(select vocation_code from mapped),
    'level',(select level_value from mapped),
    'selection_key',(select slot_filter from mapped),
    'text',(select query_text from mapped)
  ),
  'items',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'item_key',item_key,
        'name',name,
        'selection_key',selection_key,
        'item_domain',item_domain,
        'item_family',item_family,
        'level_required',level_required,
        'vocation_scope',vocation_scope,
        'vocation_keys',to_jsonb(vocation_keys),
        'hands',hands,
        'weapon_class',weapon_class,
        'imbue_slots',imbue_slots,
        'wiki_url',wiki_url,
        'eligible',not blocked_by_level and not blocked_by_vocation,
        'blocking_reasons',to_jsonb(array_remove(array[
          case when blocked_by_level then 'level_requirement' end,
          case when blocked_by_vocation then 'vocation_restriction' end
        ],null))
      )
      order by
        case when not blocked_by_level and not blocked_by_vocation then 0 else 1 end,
        case
          when lower(name)=lower(query_text) then 0
          when lower(name) like lower(query_text)||'%' then 1
          else 2
        end,
        level_required desc,
        name,
        item_key
    )
    from limited
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','player_inventory_search_v1',
    'catalog_only',true,
    'ownership_not_inferred',true,
    'ranking_is_search_relevance_not_combat_score',true
  )
);
$function$;

create or replace function public.huntnexus_player_inventory_put(
  p_client_id uuid,
  p_storage_kind text,
  p_item_key text,
  p_quantity integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_kind text := lower(trim(coalesce(p_storage_kind,'')));
  v_item record;
  v_id uuid;
begin
  if p_client_id is null then
    return jsonb_build_object('error','client_id_required');
  end if;

  if v_kind not in ('main','backpack') then
    return jsonb_build_object('error','invalid_storage_kind');
  end if;

  select *
  into v_item
  from public.vw_loadout_item_catalog_universal
  where item_key=p_item_key
  order by selection_key
  limit 1;

  if v_item.item_key is null then
    return jsonb_build_object('error','item_not_found','item_key',p_item_key);
  end if;

  if v_kind='main' then
    delete from public.player_character_inventory
    where client_id=p_client_id
      and storage_kind='main'
      and selection_key=v_item.selection_key;

    insert into public.player_character_inventory(
      client_id,storage_kind,selection_key,item_key,item_name,quantity,updated_at
    )
    values(
      p_client_id,'main',v_item.selection_key,v_item.item_key,v_item.name,1,now()
    )
    returning id into v_id;
  else
    insert into public.player_character_inventory(
      client_id,storage_kind,selection_key,item_key,item_name,quantity,updated_at
    )
    values(
      p_client_id,'backpack',v_item.selection_key,v_item.item_key,v_item.name,
      least(greatest(coalesce(p_quantity,1),1),9999),now()
    )
    on conflict (client_id,selection_key,item_key)
      where storage_kind='backpack'
    do update set
      quantity=excluded.quantity,
      item_name=excluded.item_name,
      updated_at=now()
    returning id into v_id;
  end if;

  return jsonb_build_object(
    'saved',true,
    'inventory_id',v_id,
    'storage_kind',v_kind,
    'selection_key',v_item.selection_key,
    'item_key',v_item.item_key,
    'item_name',v_item.name
  );
end;
$function$;

create or replace function public.huntnexus_player_inventory_remove(
  p_client_id uuid,
  p_inventory_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_count integer;
begin
  delete from public.player_character_inventory
  where id=p_inventory_id and client_id=p_client_id;

  get diagnostics v_count = row_count;

  return jsonb_build_object(
    'deleted',v_count=1,
    'inventory_id',p_inventory_id
  );
end;
$function$;

revoke all on table public.player_character_inventory from public,anon,authenticated;
revoke all on function public.huntnexus_player_inventory_get(uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_player_inventory_search(text,integer,text,text,integer) from public,anon,authenticated;
revoke all on function public.huntnexus_player_inventory_put(uuid,text,text,integer) from public,anon,authenticated;
revoke all on function public.huntnexus_player_inventory_remove(uuid,uuid) from public,anon,authenticated;

grant execute on function public.huntnexus_player_inventory_get(uuid) to service_role;
grant execute on function public.huntnexus_player_inventory_search(text,integer,text,text,integer) to service_role;
grant execute on function public.huntnexus_player_inventory_put(uuid,text,text,integer) to service_role;
grant execute on function public.huntnexus_player_inventory_remove(uuid,uuid) to service_role;
