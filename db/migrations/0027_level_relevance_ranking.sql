-- HuntNexus Analytics — Phase 10.1 evidence-adjusted observed-hunt ranking.
-- Adds soft observed-level relevance while keeping canonical minimum level as the hard eligibility gate.

create or replace function huntnexus_rank_observed_hunts(
  p_vocation text,
  p_level int,
  p_objective text default 'balanced',
  p_party_size int default 1,
  p_limit int default 10
)
returns jsonb
language sql
stable
as $$
with params as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as player_level,
    case lower(coalesce(p_objective,'balanced'))
      when 'xp' then 'xp'
      when 'experience' then 'xp'
      when 'profit' then 'profit'
      when 'loot' then 'profit'
      else 'balanced'
    end as objective,
    greatest(coalesce(p_party_size,1),1) as party_size,
    greatest(1,least(coalesce(p_limit,10),25)) as result_limit
),
eligible_sessions as (
  select
    q.*,
    h.name as hunt_name,
    huntnexus_hunt_min_level(
      h.level_knights,h.level_paladins,h.level_mages,(select vocation_code from params)
    ) as canonical_min_level,
    (
      select percentile_cont(0.5) within group (order by sp.level)
      from session_players sp
      where sp.session_id=q.session_id
        and sp.vocation=(select vocation_code from params)
    ) as matching_vocation_median_level
  from vw_community_analysis_eligible q
  join tibia_hunting_places h on h.slug=q.hunt_key
  where q.party_size=(select party_size from params)
    and exists (
      select 1
      from session_players sp
      where sp.session_id=q.session_id
        and sp.vocation=(select vocation_code from params)
    )
),
level_filtered as (
  select *
  from eligible_sessions
  where canonical_min_level is null
     or (select player_level from params) >= canonical_min_level
),
agg as (
  select
    hunt_key,
    hunt_name,
    max(canonical_min_level) as canonical_min_level,
    count(*)::int as session_count,
    percentile_cont(0.5) within group (order by matching_vocation_median_level)
      filter (where matching_vocation_median_level is not null) as observed_median_player_level,
    percentile_cont(0.5) within group (order by raw_xp_per_hour) as median_raw_xp_per_hour,
    percentile_cont(0.5) within group (order by xp_per_hour) as median_xp_per_hour,
    percentile_cont(0.5) within group (order by balance_per_hour) as median_balance_per_hour,
    round(avg(structural_quality_score),3) as avg_structural_quality
  from level_filtered
  group by hunt_key,hunt_name
),
ranked as (
  select
    a.*,
    percent_rank() over (order by median_raw_xp_per_hour) as xp_rank,
    percent_rank() over (order by median_balance_per_hour) as profit_rank,
    least(1.0,ln(1.0+session_count::numeric)/ln(11.0)) as sample_confidence,
    (
      0.60*least(1.0,ln(1.0+session_count::numeric)/ln(11.0)) +
      0.40*avg_structural_quality
    ) as confidence_score,
    case
      when observed_median_player_level is null then 0.70
      when (select player_level from params) >= observed_median_player_level then 1.00
      else greatest(
        0.35,
        (select player_level from params)::numeric /
          nullif(observed_median_player_level::numeric,0)
      )
    end as level_fit_score
  from agg a
),
scored as (
  select
    r.*,
    case (select objective from params)
      when 'xp' then xp_rank
      when 'profit' then profit_rank
      else (xp_rank+profit_rank)/2.0
    end as performance_score,
    (
      (0.55+0.45*level_fit_score) *
      (0.70+0.30*confidence_score)
    ) as evidence_fit_score,
    case
      when observed_median_player_level is null then 'no_observed_level'
      when (select player_level from params) >= observed_median_player_level then 'at_or_above_observed_median'
      when (select player_level from params)::numeric /
             nullif(observed_median_player_level::numeric,0) >= 0.85
        then 'near_observed_median'
      else 'below_observed_median'
    end as level_evidence_label,
    (
      select ep.element
      from vw_hunt_observed_element_profile ep
      where ep.hunt_key=r.hunt_key
        and ep.element in ('physical','fire','ice','earth','energy','holy','death')
      order by ep.kill_weighted_modifier_percent desc,ep.element
      limit 1
    ) as strongest_observed_element,
    (
      select ep.kill_weighted_modifier_percent
      from vw_hunt_observed_element_profile ep
      where ep.hunt_key=r.hunt_key
        and ep.element in ('physical','fire','ice','earth','energy','holy','death')
      order by ep.kill_weighted_modifier_percent desc,ep.element
      limit 1
    ) as strongest_observed_element_modifier
  from ranked r
),
final as (
  select *,
         performance_score*evidence_fit_score as ranking_score
  from scored
  order by
    performance_score*evidence_fit_score desc,
    confidence_score desc,
    session_count desc,
    hunt_name
  limit (select result_limit from params)
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'vocation',(select vocation_code from params),
    'level',(select player_level from params),
    'objective',(select objective from params),
    'party_size',(select party_size from params)
  ),
  'results',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'hunt_key',hunt_key,
        'hunt_name',hunt_name,
        'canonical_min_level',canonical_min_level,
        'observed_median_player_level',observed_median_player_level,
        'level_fit_score',round(level_fit_score::numeric,3),
        'level_evidence_label',level_evidence_label,
        'session_count',session_count,
        'median_xp_per_hour',median_xp_per_hour,
        'median_raw_xp_per_hour',median_raw_xp_per_hour,
        'median_balance_per_hour',round(median_balance_per_hour::numeric,0),
        'strongest_observed_element',strongest_observed_element,
        'strongest_observed_element_modifier',strongest_observed_element_modifier,
        'performance_score',round(performance_score::numeric,3),
        'confidence_score',round(confidence_score::numeric,3),
        'evidence_fit_score',round(evidence_fit_score::numeric,3),
        'ranking_score',round(ranking_score::numeric,3)
      )
      order by ranking_score desc,confidence_score desc,session_count desc,hunt_name
    )
    from final
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','experimental_observed_ranking_v2',
    'final_recommendation',false,
    'source_layer','community_observations',
    'canonical_min_level_is_hard_gate',true,
    'observed_level_is_soft_evidence',true,
    'confidence_separate_from_performance',true,
    'note','Observed player level adjusts evidence relevance without redefining the canonical hunt requirement.'
  )
);
$$;

revoke all on function huntnexus_rank_observed_hunts(text,int,text,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_rank_observed_hunts(text,int,text,int,int)
  to service_role;
