-- HuntNexus FE-18 — validate exact proficiency selections when topology is known.

create or replace function public.huntnexus_validate_proficiency_selections(
  p_selections jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_item_key text;
  v_orders jsonb;
  v_invalid jsonb := '[]'::jsonb;
  v_duplicate_levels jsonb := '[]'::jsonb;
  v_known_topology boolean;
begin
  if jsonb_typeof(coalesce(p_selections,'{}'::jsonb)) <> 'object' then
    return jsonb_build_object(
      'valid',false,
      'error','proficiency_selections_must_be_object'
    );
  end if;

  for v_item_key, v_orders in
    select key,value
    from jsonb_each(coalesce(p_selections,'{}'::jsonb))
  loop
    if jsonb_typeof(v_orders) <> 'array' then
      v_invalid := v_invalid || jsonb_build_array(
        jsonb_build_object('item_key',v_item_key,'reason','selection_must_be_array')
      );
      continue;
    end if;

    v_known_topology := exists(
      select 1
      from public.weapon_proficiency_trees t
      where t.item_key=v_item_key
        and t.topology_status='source_backed_level_position'
    );

    if exists (
      select 1
      from jsonb_array_elements_text(v_orders) x(value)
      where x.value !~ '^\d+$'
         or not exists (
           select 1
           from public.weapon_proficiency_perks p
           where p.item_key=v_item_key
             and p.perk_order=x.value::int
         )
    ) then
      v_invalid := v_invalid || jsonb_build_array(
        jsonb_build_object('item_key',v_item_key,'reason','unknown_perk_order')
      );
    end if;

    if v_known_topology then
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'item_key',v_item_key,
            'level_number',q.level_number,
            'selected_perk_orders',q.perk_orders
          )
          order by q.level_number
        ),
        '[]'::jsonb
      )
      into v_duplicate_levels
      from (
        select
          p.level_number,
          jsonb_agg(p.perk_order order by p.perk_order) as perk_orders
        from jsonb_array_elements_text(v_orders) x(value)
        join public.weapon_proficiency_perks p
          on p.item_key=v_item_key
         and p.perk_order=x.value::int
        where p.level_number is not null
        group by p.level_number
        having count(*) > 1
      ) q;

      if jsonb_array_length(v_duplicate_levels) > 0 then
        v_invalid := v_invalid || v_duplicate_levels;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'valid',jsonb_array_length(v_invalid)=0,
    'issues',v_invalid,
    'methodology',jsonb_build_object(
      'stage','proficiency_selection_validation_v1',
      'one_per_known_level',true,
      'unknown_topology_not_inferred',true
    )
  );
end;
$function$;

create or replace function public.huntnexus_player_profile_save(
  p_client_id uuid,
  p_profile jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_selections jsonb := case
    when jsonb_typeof(p_profile->'proficiency_selections')='object'
      then p_profile->'proficiency_selections'
    else '{}'::jsonb
  end;
  v_validation jsonb;
begin
  if p_client_id is null then
    return jsonb_build_object('error','client_id_required');
  end if;

  v_validation := public.huntnexus_validate_proficiency_selections(v_selections);

  if coalesce((v_validation->>'valid')::boolean,false) is not true then
    return jsonb_build_object(
      'saved',false,
      'error','invalid_proficiency_selections',
      'validation',v_validation
    );
  end if;

  insert into public.player_character_profiles(
    client_id,
    character_name,
    world_name,
    vocation,
    level,
    online,
    former_names,
    official_lookup_at,
    official_lookup_status,
    manual_stats,
    proficiency_selections,
    defaults,
    updated_at
  )
  values(
    p_client_id,
    nullif(trim(p_profile->>'character_name'),''),
    nullif(trim(p_profile->>'world_name'),''),
    nullif(trim(p_profile->>'vocation'),''),
    case when coalesce(p_profile->>'level','') ~ '^\d+$' then (p_profile->>'level')::int else null end,
    case when p_profile ? 'online' then (p_profile->>'online')::boolean else null end,
    case when jsonb_typeof(p_profile->'former_names')='array'
      then array(select jsonb_array_elements_text(p_profile->'former_names'))
      else '{}'::text[] end,
    case
      when nullif(p_profile->>'official_lookup_at','') is not null
        then (p_profile->>'official_lookup_at')::timestamptz
      else null
    end,
    nullif(trim(p_profile->>'official_lookup_status'),''),
    case when jsonb_typeof(p_profile->'manual_stats')='object'
      then p_profile->'manual_stats' else '{}'::jsonb end,
    v_selections,
    case when jsonb_typeof(p_profile->'defaults')='object'
      then p_profile->'defaults' else '{}'::jsonb end,
    now()
  )
  on conflict (client_id) do update set
    character_name=excluded.character_name,
    world_name=excluded.world_name,
    vocation=excluded.vocation,
    level=excluded.level,
    online=excluded.online,
    former_names=excluded.former_names,
    official_lookup_at=excluded.official_lookup_at,
    official_lookup_status=excluded.official_lookup_status,
    manual_stats=excluded.manual_stats,
    proficiency_selections=excluded.proficiency_selections,
    defaults=excluded.defaults,
    updated_at=now();

  return jsonb_build_object(
    'saved',true,
    'client_id',p_client_id,
    'proficiency_validation',v_validation
  );
end;
$function$;

revoke all on function public.huntnexus_validate_proficiency_selections(jsonb)
from public,anon,authenticated;
revoke all on function public.huntnexus_player_profile_save(uuid,jsonb)
from public,anon,authenticated;

grant execute on function public.huntnexus_validate_proficiency_selections(jsonb)
to service_role;
grant execute on function public.huntnexus_player_profile_save(uuid,jsonb)
to service_role;
