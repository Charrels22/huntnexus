-- HuntNexus FE-23 — hunt catalog semantics + source-backed prose creature recovery.

create table if not exists public.hunting_place_catalog_semantics (
  hunt_key text primary key,
  catalog_role text not null,
  fixed_spawn boolean not null,
  planner_eligible boolean not null,
  source_kind text not null,
  evidence_note text not null,
  observed_at timestamptz not null default now()
);

alter table public.hunting_place_catalog_semantics enable row level security;

insert into public.hunting_place_catalog_semantics(
  hunt_key,catalog_role,fixed_spawn,planner_eligible,source_kind,evidence_note
)
values
  ('hunting-places','directory',false,false,'source_page_semantics',
   'Source page is explicitly a list/directory of documented hunting places, not a hunting spawn.'),
  ('forsaken-mine','dynamic_spawn_container',false,false,'source_page_semantics',
   'Source states the mine can change daily and links distinct creature variants.'),
  ('poacher-caves','dynamic_spawn_container',false,false,'source_page_semantics',
   'Source states this is a Varying Monster Spawn with three daily cave variations.'),
  ('magician-quarter','aggregate_region',false,false,'source_page_semantics',
   'Source states the quarter is divided into six distinct hunting regions.')
on conflict (hunt_key) do update set
  catalog_role=excluded.catalog_role,
  fixed_spawn=excluded.fixed_spawn,
  planner_eligible=excluded.planner_eligible,
  source_kind=excluded.source_kind,
  evidence_note=excluded.evidence_note,
  observed_at=now();

create table if not exists public.hunting_place_prose_creature_recovery_audit (
  hunting_place_id uuid not null,
  hunt_key text not null,
  creature_name_raw text not null,
  monster_slug text not null,
  source_kind text not null default 'raw_wiki_prose_explicit',
  evidence_note text not null,
  source_snapshot_id uuid,
  recovered_at timestamptz not null default now(),
  primary key (hunting_place_id,monster_slug)
);

alter table public.hunting_place_prose_creature_recovery_audit enable row level security;

with raw(hunt_key,creature_name_raw,evidence_note) as (
  values
    ('roshamuul-mines','Terrorsleep',
     'Raw wiki prose: Roshamuul Mines are a small mine infested with Terrorsleeps and Feversleeps.'),
    ('roshamuul-mines','Feversleep',
     'Raw wiki prose: Roshamuul Mines are a small mine infested with Terrorsleeps and Feversleeps.'),
    ('silencer-plateau','Silencer',
     'Raw wiki prose explicitly describes waves of Silencers spawning on the plateau.'),
    ('silencer-plateau','Sight of Surrender',
     'Raw wiki prose explicitly states the fifth wave spawns Sights of Surrender.'),
    ('pits-of-inferno-spa','Diabolic Imp',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.'),
    ('pits-of-inferno-spa','Nightmare',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.'),
    ('pits-of-inferno-spa','Defiler',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.'),
    ('pits-of-inferno-spa','Destroyer',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.'),
    ('pits-of-inferno-spa','Hellfire Fighter',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.'),
    ('pits-of-inferno-spa','Phantasm',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.'),
    ('pits-of-inferno-spa','Dark Torturer',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.'),
    ('pits-of-inferno-spa','Plaguesmith',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.'),
    ('pits-of-inferno-spa','Blightwalker',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.'),
    ('pits-of-inferno-spa','Fire Devil',
     'Raw wiki prose explicitly lists creatures contained in PoI Spa.')
),
resolved as (
  select
    h.id as hunting_place_id,
    h.slug as hunt_key,
    r.creature_name_raw,
    public.huntnexus_resolve_creature_exact(r.creature_name_raw) as monster_slug,
    r.evidence_note,
    h.snapshot_id
  from raw r
  join public.tibia_hunting_places h on h.slug=r.hunt_key
)
insert into public.hunting_place_prose_creature_recovery_audit(
  hunting_place_id,hunt_key,creature_name_raw,monster_slug,evidence_note,source_snapshot_id
)
select hunting_place_id,hunt_key,creature_name_raw,monster_slug,evidence_note,snapshot_id
from resolved
where monster_slug is not null
on conflict (hunting_place_id,monster_slug) do update set
  creature_name_raw=excluded.creature_name_raw,
  evidence_note=excluded.evidence_note,
  source_snapshot_id=excluded.source_snapshot_id,
  recovered_at=now();

insert into public.hunting_place_creatures(hunting_place_id,monster_slug,metadata)
select
  a.hunting_place_id,
  a.monster_slug,
  jsonb_build_object(
    'source_kind',a.source_kind,
    'creature_name_raw',a.creature_name_raw,
    'evidence_note',a.evidence_note,
    'recovered_at',a.recovered_at
  )
from public.hunting_place_prose_creature_recovery_audit a
where not exists (
  select 1
  from public.hunting_place_creatures hpc
  where hpc.hunting_place_id=a.hunting_place_id
    and hpc.monster_slug=a.monster_slug
);

revoke all on table public.hunting_place_catalog_semantics
from public,anon,authenticated;
revoke all on table public.hunting_place_prose_creature_recovery_audit
from public,anon,authenticated;
