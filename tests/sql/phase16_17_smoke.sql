-- HuntNexus smoke checks — Phase 16/17.
-- Run after applying migrations 0043 and 0044.

-- 1. Core catalogue readiness.
select
  (select count(*) from tibia_entities where entity_type='creature') as creatures,
  (select count(*) from tibia_hunting_places) as hunts,
  (select count(*) from tibia_items) as items,
  (select count(*) from boss_profiles) as bosses,
  (select count(*) from spell_definitions) as spells,
  (select count(*) from community_sessions) as community_sessions;

-- 2. RubinOT current versions.
select scope,version_label,released_on
from game_versions
where scope in ('rubinot_server','rubinot_client')
order by released_on desc,scope
limit 4;

-- 3. Boss guards.
select boss_key,name,final_build_blocked,readiness_status,guards
from vw_boss_recommendation_readiness
where boss_key='magma-bubble'
   or boss_key in (
     select boss_key
     from boss_group_members
     where group_key='soul-war'
   )
order by boss_key;

-- Expected:
-- Magma Bubble blocked.
-- All 8 Soul War canonical profiles blocked.

-- 4. Lever-boss restricted spell behavior.
select huntnexus_boss_spell_candidates('magma-bubble','EK',700)
  #> '{boss_restricted_spells}' as ek_restricted;

select huntnexus_boss_spell_candidates('scarlett-etzel','RP',700)
  #> '{boss_restricted_spells}' as rp_restricted;

-- Expected:
-- EK includes Chivalrous Challenge.
-- RP includes Divine Dazzle.

-- 5. Hunt recommendation v3.
with p as (
  select huntnexus_recommendation_preview('EK',700,'xp',1,3,2) as j
)
select
  j #>> '{methodology,stage}' as stage,
  jsonb_array_length(j->'results') as result_count,
  j #>> '{results,0,ranking,hunt_name}' as first_hunt,
  jsonb_array_length(
    coalesce(j #> '{results,0,spell_candidates,multi_target_attacks}','[]'::jsonb)
  ) as first_hunt_multi_spells
from p;

-- Expected stage: recommendation_preview_v3.

-- 6. API helpers.
select huntnexus_api_health();

select huntnexus_search_hunts('cobra',10);

select huntnexus_search_bosses('magma',10);

-- 7. RubinOT warning payloads.
select huntnexus_rubinot_spell_warnings('ED',1000);
select huntnexus_global_boss_warnings();

-- Expected ED warning includes Forked Thorns / Forked Glacier v13.9
-- while their exact RubinOT proximity/range behavior remains unresolved.
