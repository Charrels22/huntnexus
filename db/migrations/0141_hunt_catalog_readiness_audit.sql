-- HuntNexus FE-24 — catalog readiness audit.
-- Separates source-core completeness from optional enrichment and non-fixed catalog pages.

create or replace function public.huntnexus_hunt_catalog_readiness_audit()
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with raw as (
  select jsonb_array_elements(huntnexus_hunt_content_coverage_audit()->'hunts') as h
),
rows as (
  select
    h->>'hunt_key' as hunt_key,
    h->>'name' as name,
    coalesce(s.catalog_role,'fixed_hunt') as catalog_role,
    coalesce(s.fixed_spawn,true) as fixed_spawn,
    coalesce(s.planner_eligible,true) as planner_eligible,
    coalesce(s.source_kind,'canonical_hunt_page') as semantic_source_kind,
    s.evidence_note as semantic_evidence_note,
    h->'coverage' as coverage,
    h->'observed' as observed,
    h->'level_guidance' as level_guidance,
    h->>'city' as city,
    h->>'location' as location,
    h->>'content_status' as legacy_content_status,
    (
      coalesce((h #>> '{coverage,creatures}')::boolean,false)
      and coalesce((h #>> '{coverage,elements_complete}')::boolean,false)
      and coalesce((h #>> '{coverage,creature_detail_complete}')::boolean,false)
      and coalesce((h #>> '{coverage,abilities_complete}')::boolean,false)
      and coalesce((h #>> '{coverage,loot_complete}')::boolean,false)
    ) as source_core_complete
  from raw
  left join public.hunting_place_catalog_semantics s
    on s.hunt_key=h->>'hunt_key'
),
classified as (
  select
    r.*,
    case
      when not fixed_spawn then 'non_fixed_catalog_entry'
      when source_core_complete then 'source_core_complete'
      else 'source_core_incomplete'
    end as readiness_status,
    array_remove(array[
      case when nullif(trim(coalesce(city,'')),'') is null then 'city' end,
      case when nullif(trim(coalesce(location,'')),'') is null then 'location' end,
      case when not coalesce((coverage->>'level_guidance')::boolean,false) then 'level_guidance' end
    ],null) as optional_source_fields_missing,
    array_remove(array[
      case when coalesce((observed->>'sessions')::int,0)=0 then 'community_sessions' end,
      case when not coalesce((observed->>'incoming_damage')::boolean,false) then 'incoming_damage' end
    ],null) as observational_enrichment_missing
  from rows r
)
select jsonb_build_object(
  'summary',jsonb_build_object(
    'catalog_entries',(select count(*) from classified),
    'fixed_spawn_entries',(select count(*) from classified where fixed_spawn),
    'non_fixed_catalog_entries',(select count(*) from classified where not fixed_spawn),
    'planner_eligible_entries',(select count(*) from classified where planner_eligible),
    'source_core_complete',(select count(*) from classified where fixed_spawn and source_core_complete),
    'source_core_incomplete',(select count(*) from classified where fixed_spawn and not source_core_complete),
    'with_observed_sessions',(select count(*) from classified where coalesce((observed->>'sessions')::int,0)>0),
    'with_incoming_damage',(select count(*) from classified where coalesce((observed->>'incoming_damage')::boolean,false))
  ),
  'entries',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'hunt_key',hunt_key,
        'name',name,
        'catalog_role',catalog_role,
        'fixed_spawn',fixed_spawn,
        'planner_eligible',planner_eligible,
        'readiness_status',readiness_status,
        'source_core_complete',source_core_complete,
        'coverage',coverage,
        'observed',observed,
        'optional_source_fields_missing',to_jsonb(optional_source_fields_missing),
        'observational_enrichment_missing',to_jsonb(observational_enrichment_missing),
        'semantic_source_kind',semantic_source_kind,
        'semantic_evidence_note',semantic_evidence_note
      )
      order by
        case readiness_status
          when 'source_core_incomplete' then 0
          when 'non_fixed_catalog_entry' then 1
          else 2
        end,
        coalesce((observed->>'sessions')::int,0) desc,
        name
    )
    from classified
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','hunt_catalog_readiness_audit_v1',
    'opaque_score_used',false,
    'optional_source_fields_are_not_core_failures',true,
    'observational_data_is_not_source_core_requirement',true,
    'non_fixed_entries_separated',true,
    'planner_eligibility_explicit',true
  )
);
$function$;

revoke all on function public.huntnexus_hunt_catalog_readiness_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_hunt_catalog_readiness_audit()
to service_role;
