-- HuntNexus Guide — private multi-character library.
-- Preserve the existing single Profile/Main/Backpack as the first saved character.

create table if not exists public.player_characters (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null,
  character_name text not null check (length(trim(character_name)) between 1 and 120),
  vocation text check (vocation is null or vocation in ('EK','RP','ED','MS','EM')),
  level integer check (level is null or level between 1 and 5000),
  manual_stats jsonb not null default '{}'::jsonb check (jsonb_typeof(manual_stats)='object'),
  proficiency_selections jsonb not null default '{}'::jsonb check (jsonb_typeof(proficiency_selections)='object'),
  defaults jsonb not null default '{}'::jsonb check (jsonb_typeof(defaults)='object'),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (client_id,id)
);

create unique index if not exists player_characters_one_default_per_client_uq
  on public.player_characters(client_id) where is_default;
create index if not exists player_characters_client_updated_idx
  on public.player_characters(client_id,is_default desc,updated_at desc);

create table if not exists public.player_character_library_inventory (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null,
  character_id uuid not null,
  storage_kind text not null check (storage_kind in ('main','backpack')),
  selection_key text not null,
  item_key text not null,
  item_name text not null,
  quantity integer not null default 1 check (quantity between 1 and 9999),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (client_id,character_id)
    references public.player_characters(client_id,id) on delete cascade
);

create unique index if not exists player_character_library_main_slot_uq
  on public.player_character_library_inventory(character_id,selection_key)
  where storage_kind='main';
create unique index if not exists player_character_library_backpack_item_uq
  on public.player_character_library_inventory(character_id,selection_key,item_key)
  where storage_kind='backpack';
create index if not exists player_character_library_inventory_scope_idx
  on public.player_character_library_inventory(client_id,character_id,storage_kind,selection_key);

alter table public.player_characters enable row level security;
alter table public.player_character_library_inventory enable row level security;

-- One legacy profile per client becomes the default character. Inventory-only clients
-- also receive an editable placeholder instead of losing their saved items.
insert into public.player_characters(
  client_id,character_name,vocation,level,manual_stats,proficiency_selections,defaults,is_default,created_at,updated_at
)
select
  clients.client_id,
  coalesce(nullif(trim(p.character_name),''),'Personagem sem nome'),
  case upper(trim(coalesce(p.vocation,'')))
    when 'EK' then 'EK' when 'KNIGHT' then 'EK'
    when 'RP' then 'RP' when 'PALADIN' then 'RP'
    when 'ED' then 'ED' when 'DRUID' then 'ED'
    when 'MS' then 'MS' when 'SORCERER' then 'MS'
    when 'EM' then 'EM' when 'MONK' then 'EM'
    else null
  end,
  case when p.level between 1 and 5000 then p.level else null end,
  coalesce(p.manual_stats,'{}'::jsonb),
  coalesce(p.proficiency_selections,'{}'::jsonb),
  coalesce(p.defaults,'{}'::jsonb),
  true,
  coalesce(p.created_at,now()),
  coalesce(greatest(p.updated_at,legacy_inventory.inventory_updated_at),p.updated_at,legacy_inventory.inventory_updated_at,now())
from (
  select client_id from public.player_character_profiles
  union
  select client_id from public.player_character_inventory
) clients
left join public.player_character_profiles p on p.client_id=clients.client_id
left join lateral (
  select max(updated_at) as inventory_updated_at
  from public.player_character_inventory i
  where i.client_id=clients.client_id
) legacy_inventory on true
where not exists (
  select 1 from public.player_characters existing where existing.client_id=clients.client_id
);

insert into public.player_character_library_inventory(
  client_id,character_id,storage_kind,selection_key,item_key,item_name,quantity,notes,created_at,updated_at
)
select
  i.client_id,c.id,i.storage_kind,i.selection_key,i.item_key,i.item_name,i.quantity,i.notes,i.created_at,i.updated_at
from public.player_character_inventory i
join public.player_characters c on c.client_id=i.client_id and c.is_default
on conflict do nothing;

create or replace function public.huntnexus_player_characters_get(p_client_id uuid)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
select jsonb_build_object(
  'characters',coalesce(jsonb_agg(
    jsonb_build_object(
      'id',c.id,
      'character_name',c.character_name,
      'vocation',c.vocation,
      'level',c.level,
      'manual_stats',c.manual_stats,
      'proficiency_selections',c.proficiency_selections,
      'defaults',c.defaults,
      'is_default',c.is_default,
      'updated_at',c.updated_at,
      'main_slots',coalesce(inv.main_slots,0),
      'backpack_items',coalesce(inv.backpack_items,0)
    ) order by c.is_default desc,c.updated_at desc,c.character_name
  ),'[]'::jsonb),
  'methodology',jsonb_build_object('stage','private_character_library_v1','account_scoped',true)
)
from public.player_characters c
left join lateral (
  select
    count(*) filter (where storage_kind='main') as main_slots,
    count(*) filter (where storage_kind='backpack') as backpack_items
  from public.player_character_library_inventory i
  where i.client_id=c.client_id and i.character_id=c.id
) inv on true
where c.client_id=p_client_id;
$function$;

create or replace function public.huntnexus_player_character_save(
  p_client_id uuid,
  p_character_id uuid,
  p_character jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_id uuid := p_character_id;
  v_name text := nullif(trim(p_character->>'character_name'),'');
  v_vocation text := nullif(upper(trim(p_character->>'vocation')),'');
  v_level integer;
  v_created boolean := p_character_id is null;
begin
  if p_client_id is null then return jsonb_build_object('error','client_id_required'); end if;
  if v_name is null or length(v_name)>120 then return jsonb_build_object('error','character_name_required'); end if;
  if v_vocation is null or v_vocation not in ('EK','RP','ED','MS','EM') then return jsonb_build_object('error','invalid_vocation'); end if;
  if coalesce(p_character->>'level','') !~ '^\d+$' then return jsonb_build_object('error','invalid_level'); end if;
  v_level := (p_character->>'level')::integer;
  if v_level<1 or v_level>5000 then return jsonb_build_object('error','invalid_level'); end if;
  if p_character_id is not null and not exists (
    select 1 from public.player_characters where client_id=p_client_id and id=p_character_id
  ) then return jsonb_build_object('error','character_not_found'); end if;

  if v_created then
    insert into public.player_characters(
      client_id,character_name,vocation,level,manual_stats,proficiency_selections,defaults,is_default,updated_at
    ) values (
      p_client_id,v_name,v_vocation,v_level,
      case when jsonb_typeof(p_character->'manual_stats')='object' then p_character->'manual_stats' else '{}'::jsonb end,
      case when jsonb_typeof(p_character->'proficiency_selections')='object' then p_character->'proficiency_selections' else '{}'::jsonb end,
      case when jsonb_typeof(p_character->'defaults')='object' then p_character->'defaults' else '{}'::jsonb end,
      not exists(select 1 from public.player_characters where client_id=p_client_id and is_default),
      now()
    ) returning id into v_id;
  else
    update public.player_characters set
      character_name=v_name,
      vocation=v_vocation,
      level=v_level,
      manual_stats=case when jsonb_typeof(p_character->'manual_stats')='object' then p_character->'manual_stats' else '{}'::jsonb end,
      proficiency_selections=case when jsonb_typeof(p_character->'proficiency_selections')='object' then p_character->'proficiency_selections' else '{}'::jsonb end,
      defaults=case when jsonb_typeof(p_character->'defaults')='object' then p_character->'defaults' else '{}'::jsonb end,
      updated_at=now()
    where client_id=p_client_id and id=p_character_id;
  end if;

  return jsonb_build_object('saved',true,'character_id',v_id,'created',v_created);
end;
$function$;

create or replace function public.huntnexus_player_character_set_default(p_client_id uuid,p_character_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
begin
  if p_client_id is null then return jsonb_build_object('error','client_id_required'); end if;
  if not exists(select 1 from public.player_characters where client_id=p_client_id and id=p_character_id) then
    return jsonb_build_object('error','character_not_found');
  end if;
  update public.player_characters set is_default=false where client_id=p_client_id and is_default;
  update public.player_characters set is_default=true,updated_at=now() where client_id=p_client_id and id=p_character_id;
  return jsonb_build_object('saved',true,'character_id',p_character_id,'is_default',true);
end;
$function$;

create or replace function public.huntnexus_player_character_delete(p_client_id uuid,p_character_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_deleted integer;
begin
  delete from public.player_characters where client_id=p_client_id and id=p_character_id;
  get diagnostics v_deleted = row_count;
  if v_deleted=0 then return jsonb_build_object('deleted',false,'error','character_not_found'); end if;
  update public.player_characters set is_default=true,updated_at=now()
  where id=(
    select id from public.player_characters
    where client_id=p_client_id and not exists(
      select 1 from public.player_characters d where d.client_id=p_client_id and d.is_default
    )
    order by updated_at desc,character_name limit 1
  );
  return jsonb_build_object('deleted',true,'character_id',p_character_id);
end;
$function$;

create or replace function public.huntnexus_player_character_inventory_get(p_client_id uuid,p_character_id uuid)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with rows as (
  select i.id,i.storage_kind,i.selection_key,i.item_key,i.item_name,i.quantity,i.notes,
    c.item_domain,c.item_family,c.level_required,c.vocation_scope,c.vocation_keys,c.hands,
    c.weapon_class,c.imbue_slots,c.wiki_url
  from public.player_character_library_inventory i
  left join public.vw_loadout_item_catalog_universal c
    on c.item_key=i.item_key and c.selection_key=i.selection_key
  where i.client_id=p_client_id and i.character_id=p_character_id
)
select jsonb_build_object(
  'main_set',coalesce((select jsonb_object_agg(selection_key,jsonb_build_object(
    'inventory_id',id,'selection_key',selection_key,'item_key',item_key,'item_name',item_name,
    'quantity',quantity,'notes',notes,'item_domain',item_domain,'item_family',item_family,
    'level_required',level_required,'vocation_scope',vocation_scope,'vocation_keys',to_jsonb(vocation_keys),
    'hands',hands,'weapon_class',weapon_class,'imbue_slots',imbue_slots,'wiki_url',wiki_url
  ) order by selection_key) from rows where storage_kind='main'),'{}'::jsonb),
  'backpack',coalesce((select jsonb_agg(jsonb_build_object(
    'inventory_id',id,'selection_key',selection_key,'item_key',item_key,'item_name',item_name,
    'quantity',quantity,'notes',notes,'item_domain',item_domain,'item_family',item_family,
    'level_required',level_required,'vocation_scope',vocation_scope,'vocation_keys',to_jsonb(vocation_keys),
    'hands',hands,'weapon_class',weapon_class,'imbue_slots',imbue_slots,'wiki_url',wiki_url
  ) order by selection_key,item_name,item_key) from rows where storage_kind='backpack'),'[]'::jsonb),
  'summary',jsonb_build_object(
    'main_slots',(select count(*) from rows where storage_kind='main'),
    'backpack_items',(select count(*) from rows where storage_kind='backpack')
  )
);
$function$;

create or replace function public.huntnexus_player_character_inventory_put(
  p_client_id uuid,p_character_id uuid,p_storage_kind text,p_item_key text,p_quantity integer default 1
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
  if p_client_id is null then return jsonb_build_object('error','client_id_required'); end if;
  if v_kind not in ('main','backpack') then return jsonb_build_object('error','invalid_storage_kind'); end if;
  if not exists(select 1 from public.player_characters where client_id=p_client_id and id=p_character_id) then
    return jsonb_build_object('error','character_not_found');
  end if;
  select * into v_item from public.vw_loadout_item_catalog_universal
  where item_key=p_item_key order by selection_key limit 1;
  if v_item.item_key is null then return jsonb_build_object('error','item_not_found','item_key',p_item_key); end if;

  if v_kind='main' then
    delete from public.player_character_library_inventory
    where client_id=p_client_id and character_id=p_character_id and storage_kind='main'
      and selection_key=v_item.selection_key;
    insert into public.player_character_library_inventory(
      client_id,character_id,storage_kind,selection_key,item_key,item_name,quantity,updated_at
    ) values (p_client_id,p_character_id,'main',v_item.selection_key,v_item.item_key,v_item.name,1,now())
    returning id into v_id;
  else
    insert into public.player_character_library_inventory(
      client_id,character_id,storage_kind,selection_key,item_key,item_name,quantity,updated_at
    ) values (
      p_client_id,p_character_id,'backpack',v_item.selection_key,v_item.item_key,v_item.name,
      least(greatest(coalesce(p_quantity,1),1),9999),now()
    ) on conflict (character_id,selection_key,item_key) where storage_kind='backpack'
    do update set quantity=excluded.quantity,item_name=excluded.item_name,updated_at=now()
    returning id into v_id;
  end if;
  update public.player_characters set updated_at=now() where client_id=p_client_id and id=p_character_id;
  return jsonb_build_object('saved',true,'inventory_id',v_id,'storage_kind',v_kind,'item_key',v_item.item_key,'item_name',v_item.name);
end;
$function$;

create or replace function public.huntnexus_player_character_inventory_remove(
  p_client_id uuid,p_character_id uuid,p_inventory_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_count integer;
begin
  delete from public.player_character_library_inventory
  where client_id=p_client_id and character_id=p_character_id and id=p_inventory_id;
  get diagnostics v_count = row_count;
  if v_count=1 then
    update public.player_characters set updated_at=now() where client_id=p_client_id and id=p_character_id;
  end if;
  return jsonb_build_object('deleted',v_count=1,'inventory_id',p_inventory_id);
end;
$function$;

revoke all on table public.player_characters from public,anon,authenticated;
revoke all on table public.player_character_library_inventory from public,anon,authenticated;
revoke all on function public.huntnexus_player_characters_get(uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_player_character_save(uuid,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.huntnexus_player_character_set_default(uuid,uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_player_character_delete(uuid,uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_player_character_inventory_get(uuid,uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_player_character_inventory_put(uuid,uuid,text,text,integer) from public,anon,authenticated;
revoke all on function public.huntnexus_player_character_inventory_remove(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.huntnexus_player_characters_get(uuid) to service_role;
grant execute on function public.huntnexus_player_character_save(uuid,uuid,jsonb) to service_role;
grant execute on function public.huntnexus_player_character_set_default(uuid,uuid) to service_role;
grant execute on function public.huntnexus_player_character_delete(uuid,uuid) to service_role;
grant execute on function public.huntnexus_player_character_inventory_get(uuid,uuid) to service_role;
grant execute on function public.huntnexus_player_character_inventory_put(uuid,uuid,text,text,integer) to service_role;
grant execute on function public.huntnexus_player_character_inventory_remove(uuid,uuid,uuid) to service_role;
