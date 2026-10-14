-- HuntNexus Brain source audit — point-in-time, read-only evidence.
-- Project: urbncbjapasnjqjqicjv
-- Captured: 2026-10-14 (America/Sao_Paulo)
-- These statements contain SELECTs only. Counts prove presence, not correctness.

-- 1. Registry, collection metadata and terms state.
select
  name,
  tier,
  layer,
  url,
  status,
  collection_method,
  last_access_status,
  last_checked_at,
  terms_review_status
from public.sources
order by tier, name;

-- 2. Raw provenance by registered source.
select
  s.name,
  count(rs.id) as raw_snapshot_count,
  min(rs.fetched_at) as first_snapshot_at,
  max(rs.fetched_at) as last_snapshot_at
from public.sources s
left join public.raw_snapshots rs on rs.source_id = s.id
group by s.id, s.name
order by s.name;

-- 3. Domain rows by source. A row count of zero is intentionally retained.
with evidence as (
  select source_id, 'game_versions'::text as domain, count(*)::bigint as row_count from public.game_versions group by source_id
  union all select source_id, 'tibia_entities', count(*) from public.tibia_entities group by source_id
  union all select source_id, 'tibia_items', count(*) from public.tibia_items group by source_id
  union all select source_id, 'tibia_hunting_places', count(*) from public.tibia_hunting_places group by source_id
  union all select source_id, 'monster_vulnerability', count(*) from public.monster_vulnerability group by source_id
  union all select source_id, 'creature_abilities', count(*) from public.creature_abilities group by source_id
  union all select source_id, 'creature_loot', count(*) from public.creature_loot group by source_id
  union all select source_id, 'item_effects', count(*) from public.item_effects group by source_id
  union all select source_id, 'boss_profiles', count(*) from public.boss_profiles group by source_id
  union all select source_id, 'spell_definitions', count(*) from public.spell_definitions group by source_id
  union all select source_id, 'imbuement_definitions', count(*) from public.imbuement_definitions group by source_id
  union all select source_id, 'weapon_proficiency_trees', count(*) from public.weapon_proficiency_trees group by source_id
  union all select source_id, 'rubinot_system_facts', count(*) from public.rubinot_system_facts group by source_id
  union all select source_id, 'rubinot_modifier_definitions', count(*) from public.rubinot_modifier_definitions group by source_id
  union all select source_id, 'rubinot_change_candidates', count(*) from public.rubinot_change_candidates group by source_id
  union all select source_id, 'rubinot_overrides', count(*) from public.rubinot_overrides group by source_id
  union all select source_id, 'community_sessions', count(*) from public.community_sessions group by source_id
  union all select source_id, 'editorial_notes', count(*) from public.editorial_notes group by source_id
  union all select source_id, 'recommendation_evidence', count(*) from public.recommendation_evidence group by source_id
), domains(domain) as (
  values
    ('game_versions'), ('tibia_entities'), ('tibia_items'), ('tibia_hunting_places'),
    ('monster_vulnerability'), ('creature_abilities'), ('creature_loot'), ('item_effects'),
    ('boss_profiles'), ('spell_definitions'), ('imbuement_definitions'), ('weapon_proficiency_trees'),
    ('rubinot_system_facts'), ('rubinot_modifier_definitions'), ('rubinot_change_candidates'),
    ('rubinot_overrides'), ('community_sessions'), ('editorial_notes'), ('recommendation_evidence')
)
select s.name, d.domain, coalesce(e.row_count, 0) as row_count
from public.sources s
cross join domains d
left join evidence e on e.source_id = s.id and e.domain = d.domain
order by s.name, d.domain;

-- 4. Aggregate Brain presence snapshot.
select jsonb_build_object(
  'sources', (select count(*) from public.sources),
  'raw_snapshots', (select count(*) from public.raw_snapshots),
  'creatures', (select count(*) from public.tibia_entities where entity_type = 'creature'),
  'items', (select count(*) from public.tibia_items),
  'hunts', (select count(*) from public.tibia_hunting_places),
  'bosses', (select count(*) from public.boss_profiles),
  'spells', (select count(*) from public.spell_definitions),
  'community_sessions', (select count(*) from public.community_sessions),
  'recommendation_evidence', (select count(*) from public.recommendation_evidence),
  'editorial_notes', (select count(*) from public.editorial_notes),
  'rubinot_system_facts', (select count(*) from public.rubinot_system_facts),
  'rubinot_modifier_definitions', (select count(*) from public.rubinot_modifier_definitions),
  'rubinot_wiki_pages', (select count(*) from public.rubinot_wiki_pages),
  'changelog_entries', (select count(*) from public.changelog_entries),
  'rubinot_change_candidates', (select count(*) from public.rubinot_change_candidates),
  'active_rubinot_overrides', (select count(*) from public.rubinot_overrides where valid_to is null)
) as brain_presence;

-- 5. Automation: installed extensions and callable ingestion functions.
-- Absence of pg_cron plus absence of a collector workflow proves no DB/GitHub schedule
-- only when checked together with .github/workflows/ at the same commit.
select extname, extversion from pg_extension where extname in ('http', 'pg_net', 'pg_cron') order by extname;

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name ~ '^huntnexus_(ingest|retry|sync)'
order by routine_name;

-- 6. Contract-only readiness. Read methodology before interpreting the score.
select public.huntnexus_product_readiness_audit() -> 'summary' as summary,
       public.huntnexus_product_readiness_audit() -> 'methodology' as methodology;
