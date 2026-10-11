-- HuntNexus FE-21 — recover explicit CreatureList rows from raw wiki text.
-- Conservative parser: only pipe rows inside {{CreatureList ... }} blocks are accepted.
-- Free prose is never interpreted as a creature list.

create or replace function public.huntnexus_extract_creature_list_names(
  p_raw_wiki_text text
)
returns text[]
language plpgsql
immutable
set search_path to 'public','extensions'
as $function$
declare
  v_line text;
  v_inside boolean := false;
  v_name text;
  v_names text[] := '{}'::text[];
begin
  if nullif(p_raw_wiki_text,'') is null then
    return v_names;
  end if;

  foreach v_line in array regexp_split_to_array(p_raw_wiki_text,E'\n')
  loop
    if not v_inside and v_line ~* '\{\{CreatureList' then
      v_inside := true;
      continue;
    end if;

    if v_inside and trim(v_line) = '}}' then
      v_inside := false;
      continue;
    end if;

    if v_inside and v_line ~ '^\s*\|\s*[^|{}]+\s*$'
       and v_line !~* '^\s*\|\s*(type|caption)\s*=' then
      v_name := trim(regexp_replace(v_line,'^\s*\|\s*',''));
      if nullif(v_name,'') is not null
         and not (v_name = any(v_names)) then
        v_names := array_append(v_names,v_name);
      end if;
    end if;
  end loop;

  return v_names;
end;
$function$;

create table if not exists public.hunting_place_creature_recovery_audit (
  hunting_place_id uuid not null,
  hunt_key text not null,
  creature_name_raw text not null,
  monster_slug text,
  resolution_status text not null,
  source_kind text not null default 'raw_wiki_creature_list',
  source_snapshot_id uuid,
  recovered_at timestamptz not null default now(),
  primary key (hunting_place_id,creature_name_raw)
);

alter table public.hunting_place_creature_recovery_audit enable row level security;

with candidates as (
  select
    h.id as hunting_place_id,
    h.slug as hunt_key,
    h.snapshot_id,
    n.name_raw,
    public.huntnexus_resolve_creature_exact(n.name_raw) as monster_slug
  from public.tibia_hunting_places h
  cross join lateral unnest(
    public.huntnexus_extract_creature_list_names(h.structured_data->>'rawWikiText')
  ) n(name_raw)
  where not exists (
    select 1
    from public.hunting_place_creatures existing
    where existing.hunting_place_id=h.id
  )
)
insert into public.hunting_place_creature_recovery_audit(
  hunting_place_id,hunt_key,creature_name_raw,monster_slug,resolution_status,
  source_snapshot_id
)
select
  hunting_place_id,
  hunt_key,
  name_raw,
  monster_slug,
  case when monster_slug is null then 'unresolved' else 'resolved_exact' end,
  snapshot_id
from candidates
on conflict (hunting_place_id,creature_name_raw) do update set
  monster_slug=excluded.monster_slug,
  resolution_status=excluded.resolution_status,
  source_snapshot_id=excluded.source_snapshot_id,
  recovered_at=now();

insert into public.hunting_place_creatures(hunting_place_id,monster_slug,metadata)
select
  a.hunting_place_id,
  a.monster_slug,
  jsonb_build_object(
    'source_kind','raw_wiki_creature_list_recovery',
    'creature_name_raw',a.creature_name_raw,
    'resolution_status',a.resolution_status,
    'recovered_at',a.recovered_at
  )
from public.hunting_place_creature_recovery_audit a
where a.resolution_status='resolved_exact'
  and a.monster_slug is not null
  and not exists (
    select 1
    from public.hunting_place_creatures hpc
    where hpc.hunting_place_id=a.hunting_place_id
      and hpc.monster_slug=a.monster_slug
  );

revoke all on table public.hunting_place_creature_recovery_audit
from public,anon,authenticated;
revoke all on function public.huntnexus_extract_creature_list_names(text)
from public,anon,authenticated;
grant execute on function public.huntnexus_extract_creature_list_names(text)
to service_role;
