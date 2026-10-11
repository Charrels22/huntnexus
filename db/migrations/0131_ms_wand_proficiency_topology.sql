-- HuntNexus FE-16 — source-backed Weapon Proficiency topology for MS Wands.
-- Canonical complementary source:
-- zimbadev/crystalserver @ 96d13eff5a1afef17b11b9abc7d574020381cc53
-- data/json/proficiencies.json
--
-- Level/position assignments are applied only after exact sequential effect validation
-- against the existing HuntNexus perk rows. This source is canonical Tibia-compatible
-- topology evidence, not a claim of RubinOT-specific customization.

alter table public.weapon_proficiency_perks
  add column if not exists position_in_level integer;

create table if not exists public.weapon_proficiency_topology_sources (
  item_key text primary key,
  source_kind text not null,
  source_repository text,
  source_revision text,
  source_path text,
  source_profile_name text not null,
  source_proficiency_id integer,
  source_profile_version integer,
  confidence text not null,
  validation_status text not null,
  levels_json jsonb not null,
  observed_at timestamptz not null default now(),
  notes text
);

alter table public.weapon_proficiency_topology_sources enable row level security;

insert into public.weapon_proficiency_topology_sources(
  item_key,source_kind,source_repository,source_revision,source_path,
  source_profile_name,source_proficiency_id,source_profile_version,
  confidence,validation_status,levels_json,notes
)
values
(
  'soultainter',
  'canonical_tibia_compatible',
  'zimbadev/crystalserver',
  '96d13eff5a1afef17b11b9abc7d574020381cc53',
  'data/json/proficiencies.json',
  'Soul 1H Wand',36,10,
  'high','exact_effect_sequence_match',
  '[1,2,3,3,2,2,1]'::jsonb,
  '14/14 existing HuntNexus perk rows match the canonical flattened level order.'
),
(
  'amber-wand',
  'canonical_tibia_compatible',
  'zimbadev/crystalserver',
  '96d13eff5a1afef17b11b9abc7d574020381cc53',
  'data/json/proficiencies.json',
  'Amber 1H Wand',46,5,
  'high','exact_effect_sequence_match',
  '[1,2,2,2,2,1,1]'::jsonb,
  '11/11 existing HuntNexus perk rows match the canonical flattened level order.'
),
(
  'eldritch-wand',
  'canonical_tibia_compatible',
  'zimbadev/crystalserver',
  '96d13eff5a1afef17b11b9abc7d574020381cc53',
  'data/json/proficiencies.json',
  'Eldritch 1H Wand',93,9,
  'high','exact_effect_sequence_match',
  '[1,2,3,2,1]'::jsonb,
  '9/9 existing HuntNexus perk rows match the canonical flattened level order. Corrects levels_declared from 7 to 5.'
),
(
  'grand-sanguine-coil',
  'canonical_tibia_compatible',
  'zimbadev/crystalserver',
  '96d13eff5a1afef17b11b9abc7d574020381cc53',
  'data/json/proficiencies.json',
  'Grand Sanguine 1H Wand',26,9,
  'high','exact_effect_sequence_match',
  '[1,3,3,2,2,3,1]'::jsonb,
  '15/15 existing HuntNexus perk rows match the canonical flattened level order.'
)
on conflict (item_key) do update set
  source_kind=excluded.source_kind,
  source_repository=excluded.source_repository,
  source_revision=excluded.source_revision,
  source_path=excluded.source_path,
  source_profile_name=excluded.source_profile_name,
  source_proficiency_id=excluded.source_proficiency_id,
  source_profile_version=excluded.source_profile_version,
  confidence=excluded.confidence,
  validation_status=excluded.validation_status,
  levels_json=excluded.levels_json,
  observed_at=now(),
  notes=excluded.notes;

-- Soultainter: [1,2,3,3,2,2,1]
update public.weapon_proficiency_perks
set
  level_number = case
    when perk_order=1 then 1
    when perk_order between 2 and 3 then 2
    when perk_order between 4 and 6 then 3
    when perk_order between 7 and 9 then 4
    when perk_order between 10 and 11 then 5
    when perk_order between 12 and 13 then 6
    when perk_order=14 then 7
  end,
  position_in_level = case
    when perk_order=1 then 1
    when perk_order between 2 and 3 then perk_order-1
    when perk_order between 4 and 6 then perk_order-3
    when perk_order between 7 and 9 then perk_order-6
    when perk_order between 10 and 11 then perk_order-9
    when perk_order between 12 and 13 then perk_order-11
    when perk_order=14 then 1
  end,
  metadata = metadata || jsonb_build_object(
    'topology_status','source_backed_level_position',
    'level_assignment_known',true,
    'topology_source','zimbadev/crystalserver',
    'topology_source_revision','96d13eff5a1afef17b11b9abc7d574020381cc53',
    'topology_source_profile','Soul 1H Wand'
  )
where item_key='soultainter';

-- Amber Wand: [1,2,2,2,2,1,1]
update public.weapon_proficiency_perks
set
  level_number = case
    when perk_order=1 then 1
    when perk_order between 2 and 3 then 2
    when perk_order between 4 and 5 then 3
    when perk_order between 6 and 7 then 4
    when perk_order between 8 and 9 then 5
    when perk_order=10 then 6
    when perk_order=11 then 7
  end,
  position_in_level = case
    when perk_order=1 then 1
    when perk_order between 2 and 3 then perk_order-1
    when perk_order between 4 and 5 then perk_order-3
    when perk_order between 6 and 7 then perk_order-5
    when perk_order between 8 and 9 then perk_order-7
    when perk_order in (10,11) then 1
  end,
  metadata = metadata || jsonb_build_object(
    'topology_status','source_backed_level_position',
    'level_assignment_known',true,
    'topology_source','zimbadev/crystalserver',
    'topology_source_revision','96d13eff5a1afef17b11b9abc7d574020381cc53',
    'topology_source_profile','Amber 1H Wand'
  )
where item_key='amber-wand';

-- Eldritch Wand: [1,2,3,2,1]
update public.weapon_proficiency_perks
set
  level_number = case
    when perk_order=1 then 1
    when perk_order between 2 and 3 then 2
    when perk_order between 4 and 6 then 3
    when perk_order between 7 and 8 then 4
    when perk_order=9 then 5
  end,
  position_in_level = case
    when perk_order=1 then 1
    when perk_order between 2 and 3 then perk_order-1
    when perk_order between 4 and 6 then perk_order-3
    when perk_order between 7 and 8 then perk_order-6
    when perk_order=9 then 1
  end,
  metadata = metadata || jsonb_build_object(
    'topology_status','source_backed_level_position',
    'level_assignment_known',true,
    'topology_source','zimbadev/crystalserver',
    'topology_source_revision','96d13eff5a1afef17b11b9abc7d574020381cc53',
    'topology_source_profile','Eldritch 1H Wand'
  )
where item_key='eldritch-wand';

-- Grand Sanguine Coil: [1,3,3,2,2,3,1]
update public.weapon_proficiency_perks
set
  level_number = case
    when perk_order=1 then 1
    when perk_order between 2 and 4 then 2
    when perk_order between 5 and 7 then 3
    when perk_order between 8 and 9 then 4
    when perk_order between 10 and 11 then 5
    when perk_order between 12 and 14 then 6
    when perk_order=15 then 7
  end,
  position_in_level = case
    when perk_order=1 then 1
    when perk_order between 2 and 4 then perk_order-1
    when perk_order between 5 and 7 then perk_order-4
    when perk_order between 8 and 9 then perk_order-7
    when perk_order between 10 and 11 then perk_order-9
    when perk_order between 12 and 14 then perk_order-11
    when perk_order=15 then 1
  end,
  metadata = metadata || jsonb_build_object(
    'topology_status','source_backed_level_position',
    'level_assignment_known',true,
    'topology_source','zimbadev/crystalserver',
    'topology_source_revision','96d13eff5a1afef17b11b9abc7d574020381cc53',
    'topology_source_profile','Grand Sanguine 1H Wand'
  )
where item_key='grand-sanguine-coil';

update public.weapon_proficiency_trees
set
  levels_declared = case item_key
    when 'eldritch-wand' then 5
    else 7
  end,
  topology_status='source_backed_level_position',
  notes=concat_ws(
    ' ',
    notes,
    'Topology verified against zimbadev/crystalserver data/json/proficiencies.json @ 96d13eff5a1afef17b11b9abc7d574020381cc53.'
  )
where item_key in ('soultainter','amber-wand','eldritch-wand','grand-sanguine-coil');

revoke all on table public.weapon_proficiency_topology_sources from public,anon,authenticated;
