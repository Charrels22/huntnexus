-- HuntNexus FE-04 — browser-scoped player character profile.

create table if not exists public.player_character_profiles (
  client_id uuid primary key,
  character_name text,
  world_name text,
  vocation text,
  level integer,
  online boolean,
  former_names text[] not null default '{}',
  official_lookup_at timestamptz,
  official_lookup_status text,
  manual_stats jsonb not null default '{}'::jsonb,
  proficiency_selections jsonb not null default '{}'::jsonb,
  defaults jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.player_character_profiles enable row level security;

create or replace function public.huntnexus_player_profile_get(
  p_client_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
select case
  when p.client_id is null then jsonb_build_object(
    'profile',null,
    'exists',false
  )
  else jsonb_build_object(
    'exists',true,
    'profile',jsonb_build_object(
      'character_name',p.character_name,
      'world_name',p.world_name,
      'vocation',p.vocation,
      'level',p.level,
      'online',p.online,
      'former_names',to_jsonb(p.former_names),
      'official_lookup_at',p.official_lookup_at,
      'official_lookup_status',p.official_lookup_status,
      'manual_stats',p.manual_stats,
      'proficiency_selections',p.proficiency_selections,
      'defaults',p.defaults,
      'updated_at',p.updated_at
    )
  )
end
from (
  select *
  from public.player_character_profiles
  where client_id=p_client_id
  limit 1
) p
right join (select 1 as anchor) a on true;
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
begin
  if p_client_id is null then
    return jsonb_build_object('error','client_id_required');
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
    case when jsonb_typeof(p_profile->'proficiency_selections')='object'
      then p_profile->'proficiency_selections' else '{}'::jsonb end,
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
    'client_id',p_client_id
  );
end;
$function$;

revoke all on table public.player_character_profiles from public,anon,authenticated;
revoke all on function public.huntnexus_player_profile_get(uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_player_profile_save(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.huntnexus_player_profile_get(uuid) to service_role;
grant execute on function public.huntnexus_player_profile_save(uuid,jsonb) to service_role;
