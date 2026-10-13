-- FE-39: efficient, read-only provenance / factual coverage per canonical hunt.
-- Computes ONLY the requested hunt's joined creature rows: never scans the
-- complete catalog nor confuses content coverage with player-performance samples.
-- No existing hunt facts are modified by this migration.
create or replace function public.huntnexus_hunt_evidence_context(p_hunt_key text)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with selected as (
  select
    h.id, h.slug, h.city, h.location,
    h.level_knights, h.level_paladins, h.level_mages,
    h.snapshot_id,h.source_last_updated,
    coalesce(sem.catalog_role,'fixed_hunt') as catalog_role,
    coalesce(sem.fixed_spawn,true) as fixed_spawn,
    coalesce(sem.planner_eligible,true) as planner_eligible,
    coalesce(sem.source_kind,'canonical_hunt_page') as source_kind,
    sem.evidence_note,
    sem.observed_at as catalog_observed_at,
    src.name as source_name,
    src.tier::text as source_tier,
    src.layer::text as source_layer,
    src.url as source_url,
    src.status as source_status,
    src.terms_review_status
  from public.tibia_hunting_places h
  left join public.hunting_place_catalog_semantics sem
    on sem.hunt_key=h.slug
  left join public.sources src on src.id=h.source_id
  where h.slug=p_hunt_key
  limit 1
),
scoped as (
  select s.*,
    coalesce(c.creature_count,0) as creature_count,
    coalesce(c.creatures_with_elements,0) as creatures_with_elements,
    coalesce(c.creatures_with_detail,0) as creatures_with_detail,
    coalesce(c.creatures_with_abilities,0) as creatures_with_abilities,
    coalesce(c.creatures_with_loot,0) as creatures_with_loot
  from selected s
  left join lateral (
    select
      count(distinct hpc.monster_slug)::integer as creature_count,
      count(distinct hpc.monster_slug) filter(where exists(
        select 1 from public.monster_vulnerability v
        where v.monster_key=hpc.monster_slug
      ))::integer as creatures_with_elements,
      count(distinct hpc.monster_slug) filter(where exists(
        select 1 from public.creature_detail_state d
        where d.monster_key=hpc.monster_slug and d.status='completed'
      ))::integer as creatures_with_detail,
      count(distinct hpc.monster_slug) filter(where exists(
        select 1 from public.creature_abilities a
        where a.monster_key=hpc.monster_slug
      ))::integer as creatures_with_abilities,
      count(distinct hpc.monster_slug) filter(where exists(
        select 1 from public.creature_loot l
        where l.monster_key=hpc.monster_slug
      ) or exists(
        select 1 from public.tibia_entities e
        where e.entity_type='creature'
          and e.entity_key=hpc.monster_slug
          and e.attributes ? 'lootStatistics'
          and jsonb_typeof(e.attributes->'lootStatistics')='array'
      ))::integer as creatures_with_loot
    from public.hunting_place_creatures hpc
    where hpc.hunting_place_id=s.id
  ) c on true
),
coverage as (
  select *,
    (creature_count>0 and creatures_with_elements=creature_count) as elements_complete,
    (creature_count>0 and creatures_with_detail=creature_count) as creature_detail_complete,
    (creature_count>0 and creatures_with_abilities=creature_count) as abilities_complete,
    (creature_count>0 and creatures_with_loot=creature_count) as loot_complete
  from scoped
)
select coalesce((
  select jsonb_build_object(
    'hunt_key',slug,
    'catalog',jsonb_build_object(
      'catalog_role',catalog_role,
      'fixed_spawn',fixed_spawn,
      'planner_eligible',planner_eligible,
      'semantic_source_kind',source_kind,
      'semantic_evidence_note',evidence_note
    ),
    'source',jsonb_build_object(
      'name',source_name,
      'tier',source_tier,
      'layer',source_layer,
      'url',source_url,
      'status',source_status,
      'terms_review_status',terms_review_status,
      'source_last_updated',source_last_updated,
      'catalog_observed_at',catalog_observed_at,
      'snapshot_recorded',snapshot_id is not null
    ),
    'coverage',jsonb_build_object(
      'creature_count',creature_count,
      'creatures_with_elements',creatures_with_elements,
      'creatures_with_detail',creatures_with_detail,
      'creatures_with_abilities',creatures_with_abilities,
      'creatures_with_loot',creatures_with_loot,
      'elements_complete',elements_complete,
      'creature_detail_complete',creature_detail_complete,
      'abilities_complete',abilities_complete,
      'loot_complete',loot_complete,
      'location_available',nullif(trim(coalesce(location,'')),'') is not null,
      'city_available',nullif(trim(coalesce(city,'')),'') is not null,
      'level_guidance_available',(
        nullif(trim(coalesce(level_knights,'')),'') is not null or
        nullif(trim(coalesce(level_paladins,'')),'') is not null or
        nullif(trim(coalesce(level_mages,'')),'') is not null
      )
    ),
    'source_core_complete',
      creature_count>0 and elements_complete and creature_detail_complete
      and abilities_complete and loot_complete,
    'methodology',jsonb_build_object(
      'stage','hunt_evidence_context_fe39_v1',
      'scoped_to_one_hunt',true,
      'observed_sessions_do_not_determine_source_completeness',true,
      'provenance_not_specific_hunt_deep_link',true,
      'collection_timestamp_not_live_verified',true,
      'snapshot_id_not_exposed',true,
      'missing_facts_not_inferred',true
    )
  ) from coverage
),jsonb_build_object('error','hunt_not_found'));
$function$;

revoke all on function public.huntnexus_hunt_evidence_context(text)
from public,anon,authenticated;
grant execute on function public.huntnexus_hunt_evidence_context(text)
to service_role;
