-- HuntNexus FE-22 — reconcile hunt creature bindings through canonical aliases.

with alias_rows as (
  select
    hpc.hunting_place_id,
    hpc.monster_slug as alias_key,
    a.canonical_key,
    hpc.metadata
  from public.hunting_place_creatures hpc
  join public.entity_aliases a
    on a.entity_type='creature'
   and a.alias_key=hpc.monster_slug
  where a.canonical_key<>hpc.monster_slug
),
merged as (
  insert into public.hunting_place_creatures(hunting_place_id,monster_slug,metadata)
  select
    r.hunting_place_id,
    r.canonical_key,
    coalesce(r.metadata,'{}'::jsonb) || jsonb_build_object(
      'canonicalized_from_alias',r.alias_key,
      'canonicalized_at',now()
    )
  from alias_rows r
  where not exists (
    select 1
    from public.hunting_place_creatures e
    where e.hunting_place_id=r.hunting_place_id
      and e.monster_slug=r.canonical_key
  )
  returning hunting_place_id,monster_slug
)
delete from public.hunting_place_creatures hpc
using alias_rows r
where hpc.hunting_place_id=r.hunting_place_id
  and hpc.monster_slug=r.alias_key;
