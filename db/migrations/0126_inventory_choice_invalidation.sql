-- HuntNexus FE-11 — invalidate per-hunt build choices when owned inventory changes.
-- A saved hunt choice must never reference an item the player no longer owns.

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
  v_previous_item_key text;
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
    select item_key
    into v_previous_item_key
    from public.player_character_inventory
    where client_id=p_client_id
      and storage_kind='main'
      and selection_key=v_item.selection_key
    limit 1;

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

    if v_previous_item_key is not null
       and v_previous_item_key <> v_item.item_key
       and not exists (
         select 1
         from public.player_character_inventory
         where client_id=p_client_id
           and item_key=v_previous_item_key
       ) then
      delete from public.player_hunt_build_choices c
      where c.client_id=p_client_id
        and exists (
          select 1
          from jsonb_each_text(c.selection) s
          where s.value=v_previous_item_key
        );
    end if;
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
    'item_name',v_item.name,
    'invalidated_stale_hunt_choices',
      case
        when v_kind='main'
         and v_previous_item_key is not null
         and v_previous_item_key <> v_item.item_key
         and not exists (
           select 1
           from public.player_character_inventory
           where client_id=p_client_id
             and item_key=v_previous_item_key
         )
        then true
        else false
      end
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
  v_item_key text;
  v_invalidated integer := 0;
begin
  select item_key
  into v_item_key
  from public.player_character_inventory
  where id=p_inventory_id and client_id=p_client_id;

  delete from public.player_character_inventory
  where id=p_inventory_id and client_id=p_client_id;

  get diagnostics v_count = row_count;

  if v_count=1
     and v_item_key is not null
     and not exists (
       select 1
       from public.player_character_inventory
       where client_id=p_client_id
         and item_key=v_item_key
     ) then
    delete from public.player_hunt_build_choices c
    where c.client_id=p_client_id
      and exists (
        select 1
        from jsonb_each_text(c.selection) s
        where s.value=v_item_key
      );

    get diagnostics v_invalidated = row_count;
  end if;

  return jsonb_build_object(
    'deleted',v_count=1,
    'inventory_id',p_inventory_id,
    'invalidated_hunt_choices',v_invalidated
  );
end;
$function$;

revoke all on function public.huntnexus_player_inventory_put(uuid,text,text,integer)
from public,anon,authenticated;
revoke all on function public.huntnexus_player_inventory_remove(uuid,uuid)
from public,anon,authenticated;

grant execute on function public.huntnexus_player_inventory_put(uuid,text,text,integer)
to service_role;
grant execute on function public.huntnexus_player_inventory_remove(uuid,uuid)
to service_role;
