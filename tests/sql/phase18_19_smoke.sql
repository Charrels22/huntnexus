-- HuntNexus smoke checks — Phase 18/19.
-- Run after 0049 and 0050 are applied.

-- 1. Loadout matrix: real observed hunt.
with m as (
  select huntnexus_loadout_candidate_matrix('cobra-bastion','EK',700,2) as j
)
select
  j #>> '{methodology,stage}' as stage,
  (select count(*) from jsonb_each(j->'slots')) as slot_count,
  jsonb_array_length(j->'incoming_damage') as incoming_damage_elements
from m;

-- 2. No irrelevant empty category explosion.
with m as (
  select huntnexus_loadout_candidate_matrix('cobra-bastion','EK',700,2) as j
)
select key as slot_key, jsonb_array_length(value) as candidates
from m, lateral jsonb_each(m.j->'slots')
order by key;

-- 3. Recommendation preview v4 embeds matrix.
with p as (
  select huntnexus_recommendation_preview('EK',700,'xp',1,1,2) as j
)
select
  j #>> '{methodology,stage}' as preview_stage,
  j #>> '{results,0,ranking,hunt_name}' as hunt_name,
  (j #> '{results,0,loadout_candidate_matrix}') is not null as has_loadout_matrix
from p;

-- Expected preview_stage = recommendation_preview_v4.

-- 4. Boss factual combat.
select
  boss_key,
  name,
  attack_type,
  max_damage,
  uses_spells,
  abilities_raw is not null as has_abilities
from vw_boss_factual_combat_profile
where boss_key in ('magma-bubble','scarlett-etzel','goshnars-hatred')
order by boss_key;

-- 5. Boss profile v2 keeps guard behavior while exposing factual combat.
select jsonb_build_object(
  'magma_profile',huntnexus_boss_room_profile('magma-bubble','EK',700),
  'magma_readiness',huntnexus_boss_recommendation_readiness('magma-bubble'),
  'goshnar_readiness',huntnexus_boss_recommendation_readiness('goshnars-hatred')
);
