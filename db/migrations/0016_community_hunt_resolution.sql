-- HuntNexus Brain — Phase 8.1 community hunt-name reconciliation.

create table if not exists community_hunt_aliases (
  source_id uuid not null references sources(id),
  raw_name_normalized text not null,
  canonical_hunt_key text not null,
  confidence numeric not null check (confidence >= 0 and confidence <= 1),
  resolution_method text not null,
  notes text,
  observed_at timestamptz not null default now(),
  primary key (source_id,raw_name_normalized)
);

create or replace function huntnexus_normalize_label(p_value text)
returns text
language sql
immutable
as $$
  select trim(both '-' from lower(
    regexp_replace(
      translate(
        coalesce(p_value,''),
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'
      ),
      '[^a-zA-Z0-9]+','-','g'
    )
  ));
$$;

create or replace function huntnexus_resolve_community_hunts_exact(p_source_name text)
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_auto int := 0;
  v_alias int := 0;
begin
  select id into strict v_source from sources where name=p_source_name;

  -- Apply explicit source-specific aliases first.
  update community_sessions cs
  set hunt_key=a.canonical_hunt_key,
      hunt_resolution_status='resolved_alias'
  from community_hunt_aliases a
  where cs.source_id=v_source
    and a.source_id=v_source
    and huntnexus_normalize_label(cs.hunt_name_raw)=a.raw_name_normalized
    and cs.hunt_resolution_status <> 'resolved_alias';

  get diagnostics v_alias=row_count;

  -- Automatic resolution is deliberately strict:
  -- normalized community label must equal normalized canonical hunt name.
  update community_sessions cs
  set hunt_key=h.slug,
      hunt_resolution_status='resolved_exact'
  from tibia_hunting_places h
  where cs.source_id=v_source
    and cs.hunt_key is null
    and nullif(cs.hunt_name_raw,'') is not null
    and huntnexus_normalize_label(cs.hunt_name_raw)=huntnexus_normalize_label(h.name);

  get diagnostics v_auto=row_count;

  return jsonb_build_object(
    'source',p_source_name,
    'resolved_explicit_alias',v_alias,
    'resolved_exact',v_auto,
    'remaining_unresolved',(
      select count(*) from community_sessions
      where source_id=v_source and hunt_key is null
    )
  );
end;
$$;

revoke all on function huntnexus_resolve_community_hunts_exact(text)
  from public,anon,authenticated;
grant execute on function huntnexus_resolve_community_hunts_exact(text)
  to service_role;
