-- FE-26: prevent alternative owned loadouts from being mislabeled as "Main".
-- The existing ownership, vocation, level and weapon dependency checks remain.
-- No old choices are rewritten. A valid Main option is the exact Main inventory.
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
  v_main_selection jsonb;
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

  -- A Main option must be the actual equipped Main baseline, not an
  -- alternative owned in BP disguised with option_type='main'. No partial
  -- Main subset is accepted; the persisted snapshot must be truthful.
  if v_option_type='main' then
    select coalesce(jsonb_object_agg(i.selection_key,i.item_key),'{}'::jsonb)
      into v_main_selection
    from public.player_character_inventory i
    where i.client_id=p_client_id and i.storage_kind='main';

    if p_selection <> v_main_selection then
      return jsonb_build_object(
        'error','main_choice_must_match_main_set',
        'main_set_mutated',false
      );
    end if;
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

revoke all on function public.huntnexus_player_hunt_build_choice_save(uuid,text,text,integer,jsonb,text,jsonb) from public,anon,authenticated;
grant execute on function public.huntnexus_player_hunt_build_choice_save(uuid,text,text,integer,jsonb,text,jsonb) to service_role;
