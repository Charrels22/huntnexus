-- HuntNexus Analytics — Phase 10 experimental observed-hunt ranking.
-- This is an evidence ranking, not the final HuntNexus recommendation engine.

create or replace function huntnexus_normalize_vocation(p_vocation text)
returns text
language sql
immutable
as $$
  select case lower(trim(coalesce(p_vocation,'')))
    when 'ek' then 'EK'
    when 'elite knight' then 'EK'
    when 'knight' then 'EK'
    when 'rp' then 'RP'
    when 'royal paladin' then 'RP'
    when 'paladin' then 'RP'
    when 'ed' then 'ED'
    when 'elder druid' then 'ED'
    when 'druid' then 'ED'
    when 'ms' then 'MS'
    when 'master sorcerer' then 'MS'
    when 'sorcerer' then 'MS'
    when 'em' then 'EM'
    when 'exalted monk' then 'EM'
    when 'monk' then 'EM'
    else upper(trim(coalesce(p_vocation,'')))
  end;
$$;

create or replace function huntnexus_first_int(p_value text)
returns int
language sql
immutable
as $$
  select case
    when regexp_match(coalesce(p_value,''),'([0-9]+)') is null then null
    else ((regexp_match(coalesce(p_value,''),'([0-9]+)'))[1])::int
  end;
$$;

create or replace function huntnexus_hunt_min_level(
  p_knights text,
  p_paladins text,
  p_mages text,
  p_vocation text
)
returns int
language sql
immutable
as $$
  select case huntnexus_normalize_vocation(p_vocation)
    when 'EK' then huntnexus_first_int(p_knights)
    when 'RP' then huntnexus_first_int(p_paladins)
    when 'ED' then huntnexus_first_int(p_mages)
    when 'MS' then huntnexus_first_int(p_mages)
    else null
  end;
$$;

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
    h.level_knights,
    h.level_paladins,
    h.level_mages,
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
    and (
      exists (
        select 1
        from session_players sp
        where sp.session_id=q.session_id
          and sp.vocation=(select vocation_code from params)
      )
      or (select vocation_code from params)=''
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
    least(
      1.0,
      ln(1.0 + session_count::numeric) / ln(11.0)
    ) as sample_confidence,
    (
      0.60 * least(1.0,ln(1.0 + session_count::numeric)/ln(11.0)) +
      0.40 * avg_structural_quality
    ) as confidence_score
  from agg a
),
scored as (
  select
    r.*,
    case (select objective from params)
      when 'xp' then xp_rank
      when 'profit' then profit_rank
      else (xp_rank + profit_rank)/2.0
    end as objective_score,
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
  select *
  from scored
  order by
    objective_score desc,
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
        'session_count',session_count,
        'median_xp_per_hour',median_xp_per_hour,
        'median_raw_xp_per_hour',median_raw_xp_per_hour,
        'median_balance_per_hour',round(median_balance_per_hour::numeric,0),
        'strongest_observed_element',strongest_observed_element,
        'strongest_observed_element_modifier',strongest_observed_element_modifier,
        'objective_score',round(objective_score::numeric,3),
        'confidence_score',round(confidence_score::numeric,3)
      )
      order by objective_score desc,confidence_score desc,session_count desc,hunt_name
    )
    from final
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','experimental_observed_ranking',
    'final_recommendation',false,
    'source_layer','community_observations',
    'minimum_session_duration_minutes',15,
    'profit_metric','balance_per_hour',
    'xp_metric','median_raw_xp_per_hour',
    'confidence_separate_from_score',true,
    'note','Ranking uses the current public community sample. It does not yet include full RubinOT overrides, player-owned equipment, boss mechanics, spells or all session modifiers.'
  )
);
$$;

revoke all on function huntnexus_rank_observed_hunts(text,int,text,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_rank_observed_hunts(text,int,text,int,int)
  to service_role;
