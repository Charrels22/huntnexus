-- HuntNexus FE-20 — factual hunt content coverage audit.
-- Explicit dimensions only; no opaque aggregate quality score.

create or replace function public.huntnexus_hunt_content_coverage_audit()
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with hunt_base as (
  select
    h.id,
    h.slug as hunt_key,
    h.name,
    h.title,
    h.city,
    h.location,
    h.vocation,
    h.level_knights,
    h.level_paladins,
    h.level_mages,
    h.loot_rating,
    h.experience_rating,
    h.source_id,
    h.snapshot_id,
    h.source_last_updated,
    h.observed_at,
    ds.status as detail_status,
    ds.fetched_at as detail_fetched_at,
    ds.error_text as detail_error
  from public.tibia_hunting_places h
  left join public.hunting_place_detail_state ds
    on ds.hunting_place_id=h.id
),
creature_stats as (
  select
    hb.hunt_key,
    count(distinct hpc.monster_slug)::int as creature_count,
    count(distinct hpc.monster_slug) filter (
      where exists (
        select 1
        from public.monster_vulnerability mv
        where mv.monster_key=hpc.monster_slug
      )
    )::int as creatures_with_elements,
    count(distinct hpc.monster_slug) filter (
      where exists (
        select 1
        from public.creature_detail_state cds
        where cds.monster_key=hpc.monster_slug
          and cds.status='ok'
      )
    )::int as creatures_with_detail,
    count(distinct hpc.monster_slug) filter (
      where exists (
        select 1
        from public.creature_abilities ca
        where ca.monster_key=hpc.monster_slug
      )
    )::int as creatures_with_abilities,
    count(distinct hpc.monster_slug) filter (
      where exists (
        select 1
        from public.creature_loot cl
        where cl.monster_key=hpc.monster_slug
      )
    )::int as creatures_with_loot
  from hunt_base hb
  left join public.tibia_hunting_places hp on hp.slug=hb.hunt_key
  left join public.hunting_place_creatures hpc on hpc.hunting_place_id=hp.id
  group by hb.hunt_key
),
observed as (
  select
    hb.hunt_key,
    coalesce(p.session_count,0)::int as observed_sessions,
    (p.hunt_key is not null) as performance_available,
    exists(
      select 1 from public.vw_hunt_observed_kill_mix k
      where k.hunt_key=hb.hunt_key
    ) as observed_kill_mix_available,
    exists(
      select 1 from public.vw_hunt_observed_element_profile e
      where e.hunt_key=hb.hunt_key
    ) as observed_element_profile_available,
    exists(
      select 1 from public.vw_hunt_observed_incoming_damage d
      where d.hunt_key=hb.hunt_key
    ) as observed_incoming_damage_available
  from hunt_base hb
  left join public.vw_hunt_observed_performance p
    on p.hunt_key=hb.hunt_key
),
rows as (
  select
    hb.hunt_key,
    hb.name,
    hb.title,
    hb.city,
    hb.location,
    hb.vocation,
    hb.level_knights,
    hb.level_paladins,
    hb.level_mages,
    hb.loot_rating,
    hb.experience_rating,
    hb.detail_status,
    hb.detail_fetched_at,
    hb.detail_error,
    coalesce(cs.creature_count,0) as creature_count,
    coalesce(cs.creatures_with_elements,0) as creatures_with_elements,
    coalesce(cs.creatures_with_detail,0) as creatures_with_detail,
    coalesce(cs.creatures_with_abilities,0) as creatures_with_abilities,
    coalesce(cs.creatures_with_loot,0) as creatures_with_loot,
    o.observed_sessions,
    o.performance_available,
    o.observed_kill_mix_available,
    o.observed_element_profile_available,
    o.observed_incoming_damage_available,
    (nullif(trim(coalesce(hb.city,'')),'') is not null) as city_available,
    (nullif(trim(coalesce(hb.location,'')),'') is not null) as location_available,
    (
      nullif(trim(coalesce(hb.level_knights,'')),'') is not null
      or nullif(trim(coalesce(hb.level_paladins,'')),'') is not null
      or nullif(trim(coalesce(hb.level_mages,'')),'') is not null
    ) as level_guidance_available,
    (coalesce(cs.creature_count,0)>0) as creatures_available,
    (
      coalesce(cs.creature_count,0)>0
      and coalesce(cs.creatures_with_elements,0)=coalesce(cs.creature_count,0)
    ) as element_coverage_complete,
    (
      coalesce(cs.creature_count,0)>0
      and coalesce(cs.creatures_with_detail,0)=coalesce(cs.creature_count,0)
    ) as creature_detail_complete,
    (
      coalesce(cs.creature_count,0)>0
      and coalesce(cs.creatures_with_abilities,0)=coalesce(cs.creature_count,0)
    ) as ability_coverage_complete,
    (
      coalesce(cs.creature_count,0)>0
      and coalesce(cs.creatures_with_loot,0)=coalesce(cs.creature_count,0)
    ) as loot_coverage_complete
  from hunt_base hb
  left join creature_stats cs using(hunt_key)
  left join observed o using(hunt_key)
),
classified as (
  select
    r.*,
    case
      when city_available
       and location_available
       and level_guidance_available
       and creatures_available
       and element_coverage_complete
       and creature_detail_complete
       and ability_coverage_complete
       and loot_coverage_complete
      then 'content_complete'
      when creatures_available
       and element_coverage_complete
       and creature_detail_complete
      then 'core_complete_enrichment_pending'
      when creatures_available
      then 'partial_creature_coverage'
      else 'identity_only'
    end as content_status
  from rows r
)
select jsonb_build_object(
  'summary',jsonb_build_object(
    'hunts',(select count(*) from classified),
    'content_complete',(select count(*) from classified where content_status='content_complete'),
    'core_complete_enrichment_pending',(select count(*) from classified where content_status='core_complete_enrichment_pending'),
    'partial_creature_coverage',(select count(*) from classified where content_status='partial_creature_coverage'),
    'identity_only',(select count(*) from classified where content_status='identity_only'),
    'with_observed_sessions',(select count(*) from classified where observed_sessions>0),
    'with_incoming_damage',(select count(*) from classified where observed_incoming_damage_available),
    'with_complete_elements',(select count(*) from classified where element_coverage_complete),
    'with_complete_creature_detail',(select count(*) from classified where creature_detail_complete)
  ),
  'hunts',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'hunt_key',hunt_key,
        'name',name,
        'title',title,
        'city',city,
        'location',location,
        'vocation',vocation,
        'level_guidance',jsonb_build_object(
          'knight',level_knights,
          'paladin',level_paladins,
          'mages',level_mages
        ),
        'ratings',jsonb_build_object(
          'loot',loot_rating,
          'experience',experience_rating
        ),
        'detail_status',detail_status,
        'content_status',content_status,
        'coverage',jsonb_build_object(
          'city',city_available,
          'location',location_available,
          'level_guidance',level_guidance_available,
          'creatures',creatures_available,
          'creature_count',creature_count,
          'creatures_with_elements',creatures_with_elements,
          'creatures_with_detail',creatures_with_detail,
          'creatures_with_abilities',creatures_with_abilities,
          'creatures_with_loot',creatures_with_loot,
          'elements_complete',element_coverage_complete,
          'creature_detail_complete',creature_detail_complete,
          'abilities_complete',ability_coverage_complete,
          'loot_complete',loot_coverage_complete
        ),
        'observed',jsonb_build_object(
          'sessions',observed_sessions,
          'performance',performance_available,
          'kill_mix',observed_kill_mix_available,
          'element_profile',observed_element_profile_available,
          'incoming_damage',observed_incoming_damage_available
        )
      )
      order by
        case content_status
          when 'identity_only' then 0
          when 'partial_creature_coverage' then 1
          when 'core_complete_enrichment_pending' then 2
          else 3
        end,
        observed_sessions desc,
        name
    )
    from classified
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','hunt_content_coverage_audit_v1',
    'opaque_score_used',false,
    'observed_sessions_required_for_content_complete',false,
    'incoming_damage_required_for_content_complete',false,
    'coverage_dimensions_explicit',true
  )
);
$function$;

revoke all on function public.huntnexus_hunt_content_coverage_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_hunt_content_coverage_audit()
to service_role;
