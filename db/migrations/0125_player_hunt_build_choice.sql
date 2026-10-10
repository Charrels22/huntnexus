-- HuntNexus FE-10 — per-hunt owned build choice.
-- Choosing an owned build for a hunt never mutates the global Main Set.

create table if not exists public.player_hunt_build_choices (
  client_id uuid not null,
  hunt_key text not null,
  vocation text not null,
  selection jsonb not null,
  option_type text not null check (option_type in ('main','owned_variant')),
  replacements jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (client_id,hunt_key,vocation)
);

alter table public.player_hunt_build_choices enable row level security;

create or replace function public.huntnexus_player_hunt_build_choice_get(
  p_client_id uuid,
  p_hunt_key text,
  p_vocation text
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
select case
  when c.client_id is null then jsonb_build_object(
    'exists',false,
    'choice',null
  )
  else jsonb_build_object(
    'exists',true,
    'choice',jsonb_build_object(
      'hunt_key',c.hunt_key,
      'vocation',c.vocation,
      'selection',c.selection,
      'option_type',c.option_type,
      'replacements',c.replacements,
      'updated_at',c.updated_at
    )
  )
end
from (
  select *
  from public.player_hunt_build_choices
  where client_id=p_client_id
    and hunt_key=p_hunt_key
    and vocation=huntnexus_normalize_vocation(p_vocation)
  limit 1
) c
right join (select 1 as anchor) a on true;
$function$;

create or replace function public.huntnexus_player_hunt_build_choice_save(
  p_client_id uuid,
  p_hunt_key text,
  p_vocation text,
  p_level integer,
  p_selection jsonb,
  p_option_type text,
  p_replacements jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
  v_option_type text := lower(trim(coalesce(p_option_type,'')));
  v_validation jsonb;
  v_invalid_count integer;
begin
  if p_client_id is null then
    return jsonb_build_object('error','client_id_required');
  end if;

  if nullif(trim(coalesce(p_hunt_key,'')),'') is null then
    return jsonb_build_object('error','hunt_key_required');
  end if;

  if jsonb_typeof(coalesce(p_selection,'{}'::jsonb)) <> 'object'
     or not exists (select 1 from jsonb_object_keys(coalesce(p_selection,'{}'::jsonb))) then
    return jsonb_build_object('error','selection_required');
  end if;

  if v_option_type not in ('main','owned_variant') then
    return jsonb_build_object('error','invalid_option_type');
  end if;

  select count(*)
  into v_invalid_count
  from jsonb_each_text(p_selection) s
  where not exists (
    select 1
    from public.player_character_inventory i
    where i.client_id=p_client_id
      and i.selection_key=s.key
      and i.item_key=s.value
      and i.storage_kind in ('main','backpack')
  );

  if v_invalid_count > 0 then
    return jsonb_build_object(
      'error','selection_contains_non_owned_item',
      'invalid_item_count',v_invalid_count
    );
  end if;

  v_validation := huntnexus_loadout_compatibility_universal(
    v_vocation,
    greatest(coalesce(p_level,1),1),
    p_selection
  );

  if v_validation->>'status' <> 'valid' then
    return jsonb_build_object(
      'error','invalid_loadout',
      'validation',v_validation
    );
  end if;

  insert into public.player_hunt_build_choices(
    client_id,hunt_key,vocation,selection,option_type,replacements,updated_at
  )
  values(
    p_client_id,
    p_hunt_key,
    v_vocation,
    p_selection,
    v_option_type,
    case when jsonb_typeof(coalesce(p_replacements,'[]'::jsonb))='array'
      then coalesce(p_replacements,'[]'::jsonb)
      else '[]'::jsonb end,
    now()
  )
  on conflict (client_id,hunt_key,vocation)
  do update set
    selection=excluded.selection,
    option_type=excluded.option_type,
    replacements=excluded.replacements,
    updated_at=now();

  return jsonb_build_object(
    'saved',true,
    'hunt_key',p_hunt_key,
    'vocation',v_vocation,
    'option_type',v_option_type,
    'selection',p_selection,
    'main_set_mutated',false
  );
end;
$function$;

create or replace function public.huntnexus_player_hunt_build_choice_delete(
  p_client_id uuid,
  p_hunt_key text,
  p_vocation text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_count integer;
begin
  delete from public.player_hunt_build_choices
  where client_id=p_client_id
    and hunt_key=p_hunt_key
    and vocation=huntnexus_normalize_vocation(p_vocation);

  get diagnostics v_count = row_count;

  return jsonb_build_object(
    'deleted',v_count=1,
    'main_set_mutated',false
  );
end;
$function$;

revoke all on table public.player_hunt_build_choices from public,anon,authenticated;
revoke all on function public.huntnexus_player_hunt_build_choice_get(uuid,text,text) from public,anon,authenticated;
revoke all on function public.huntnexus_player_hunt_build_choice_save(uuid,text,text,integer,jsonb,text,jsonb) from public,anon,authenticated;
revoke all on function public.huntnexus_player_hunt_build_choice_delete(uuid,text,text) from public,anon,authenticated;

grant execute on function public.huntnexus_player_hunt_build_choice_get(uuid,text,text) to service_role;
grant execute on function public.huntnexus_player_hunt_build_choice_save(uuid,text,text,integer,jsonb,text,jsonb) to service_role;
grant execute on function public.huntnexus_player_hunt_build_choice_delete(uuid,text,text) to service_role;
