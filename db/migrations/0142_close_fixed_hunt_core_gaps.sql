-- HuntNexus FE-25 — close remaining fixed hunt core gap conservatively.
-- Mount Sternum Dragon Cave gets an explicit external-source Dragon binding.
-- Pits of Inferno Levers is classified as a quest subarea and excluded from Planner
-- rather than receiving an inferred creature composition from broader PoI quest areas.

insert into public.hunting_place_catalog_semantics(
  hunt_key,catalog_role,fixed_spawn,planner_eligible,source_kind,evidence_note
)
values
  (
    'pits-of-inferno-levers',
    'quest_subarea',
    true,
    false,
    'current_tibiawiki_semantics',
    'Current TibiaWiki groups creatures as "Levers and other quest areas"; no exclusive fixed creature composition for the Levers subarea is established, so it is excluded from recommendations rather than inferred.'
  )
on conflict (hunt_key) do update set
  catalog_role=excluded.catalog_role,
  fixed_spawn=excluded.fixed_spawn,
  planner_eligible=excluded.planner_eligible,
  source_kind=excluded.source_kind,
  evidence_note=excluded.evidence_note,
  observed_at=now();

create table if not exists public.hunting_place_external_creature_recovery_audit (
  hunting_place_id uuid not null,
  hunt_key text not null,
  creature_name_raw text not null,
  monster_slug text not null,
  source_kind text not null,
  source_url text not null,
  evidence_note text not null,
  observed_at timestamptz not null default now(),
  primary key (hunting_place_id,monster_slug)
);

alter table public.hunting_place_external_creature_recovery_audit enable row level security;

with resolved as (
  select
    h.id as hunting_place_id,
    h.slug as hunt_key,
    'Dragon'::text as creature_name_raw,
    public.huntnexus_resolve_creature_exact('Dragon') as monster_slug
  from public.tibia_hunting_places h
  where h.slug='mount-sternum-dragon-cave'
)
insert into public.hunting_place_external_creature_recovery_audit(
  hunting_place_id,hunt_key,creature_name_raw,monster_slug,
  source_kind,source_url,evidence_note
)
select
  hunting_place_id,
  hunt_key,
  creature_name_raw,
  monster_slug,
  'tibiawiki_current',
  'https://www.tibiawiki.com.br/wiki/Dragon_Lair_%28Mount_Sternum%29',
  'Current TibiaWiki creature table lists Dragon for Dragon Lair (Mount Sternum).'
from resolved
where monster_slug is not null
on conflict (hunting_place_id,monster_slug) do update set
  source_kind=excluded.source_kind,
  source_url=excluded.source_url,
  evidence_note=excluded.evidence_note,
  observed_at=now();

insert into public.hunting_place_creatures(hunting_place_id,monster_slug,metadata)
select
  a.hunting_place_id,
  a.monster_slug,
  jsonb_build_object(
    'source_kind',a.source_kind,
    'source_url',a.source_url,
    'creature_name_raw',a.creature_name_raw,
    'evidence_note',a.evidence_note,
    'observed_at',a.observed_at
  )
from public.hunting_place_external_creature_recovery_audit a
where a.hunt_key='mount-sternum-dragon-cave'
  and not exists (
    select 1
    from public.hunting_place_creatures hpc
    where hpc.hunting_place_id=a.hunting_place_id
      and hpc.monster_slug=a.monster_slug
  );

revoke all on table public.hunting_place_external_creature_recovery_audit
from public,anon,authenticated;
