-- HuntNexus Analytics — Phase 9.3 normalized community performance.
-- Normalizes Balance to an hourly metric and defines an analysis-eligible subset.

create or replace view vw_community_analysis_eligible as
select q.*,
       case
         when q.duration_seconds > 0 and q.balance_value is not null
           then q.balance_value * 3600.0 / q.duration_seconds
         else null
       end as balance_per_hour
from vw_community_session_quality q
where q.hunt_key is not null
  and q.duration_seconds >= 900
  and q.party_size is not null
  and q.xp_per_hour is not null
  and q.raw_xp_per_hour is not null
  and q.structural_quality_score >= 0.85;

create or replace view vw_hunt_observed_performance as
select
  q.hunt_key,
  h.name as hunt_name,
  count(*)::int as session_count,
  count(*) filter (where q.party_size=1)::int as solo_sessions,
  count(*) filter (where q.party_size=2)::int as duo_sessions,
  count(*) filter (where q.party_size>=3)::int as party_sessions,
  round(avg(q.duration_seconds)/60.0,1) as avg_duration_minutes,
  round(avg(q.xp_per_hour),0) as avg_xp_per_hour,
  percentile_cont(0.5) within group (order by q.xp_per_hour) as median_xp_per_hour,
  round(avg(q.raw_xp_per_hour),0) as avg_raw_xp_per_hour,
  percentile_cont(0.5) within group (order by q.raw_xp_per_hour) as median_raw_xp_per_hour,
  round(avg(q.balance_value),0) as avg_balance,
  percentile_cont(0.5) within group (order by q.balance_value) as median_balance,
  round(avg(q.balance_per_hour),0) as avg_balance_per_hour,
  percentile_cont(0.5) within group (order by q.balance_per_hour) as median_balance_per_hour,
  round(avg(q.total_damage),0) as avg_total_damage,
  round(avg(q.total_healing),0) as avg_total_healing,
  min(q.xp_per_hour) as min_xp_per_hour,
  max(q.xp_per_hour) as max_xp_per_hour,
  round(avg(q.structural_quality_score),3) as avg_structural_quality
from vw_community_analysis_eligible q
join tibia_hunting_places h on h.slug=q.hunt_key
group by q.hunt_key,h.name;

create or replace view vw_hunt_observed_performance_segmented as
select
  q.hunt_key,
  h.name as hunt_name,
  q.party_size,
  count(*)::int as session_count,
  round(avg(q.duration_seconds)/60.0,1) as avg_duration_minutes,
  percentile_cont(0.5) within group (order by q.xp_per_hour) as median_xp_per_hour,
  percentile_cont(0.5) within group (order by q.raw_xp_per_hour) as median_raw_xp_per_hour,
  percentile_cont(0.5) within group (order by q.balance_per_hour) as median_balance_per_hour,
  round(avg(q.structural_quality_score),3) as avg_structural_quality
from vw_community_analysis_eligible q
join tibia_hunting_places h on h.slug=q.hunt_key
group by q.hunt_key,h.name,q.party_size;

comment on view vw_community_analysis_eligible is
'Community observations eligible for comparative analytics: canonical hunt resolved, >=15 min, core metrics present and structural quality >=0.85.';

comment on view vw_hunt_observed_performance_segmented is
'Observed Tier C performance segmented by exact party size. Balance is normalized per hour.';
