-- HuntNexus Analytics — Phase 9 community observation views.
-- Uses only public/community Tier C observations already stored in community_sessions.
-- No claim of causal or final recommendation quality is made.

create or replace view vw_community_session_quality as
select
  cs.id as session_id,
  cs.source_id,
  cs.external_id,
  cs.hunt_key,
  cs.hunt_name_raw,
  cs.hunt_resolution_status,
  cs.duration_seconds,
  cs.party_size,
  cs.xp_gain,
  cs.xp_per_hour,
  cs.raw_xp_per_hour,
  cs.balance_value,
  cs.total_damage,
  cs.total_healing,
  count(distinct sp.id)::int as player_rows,
  count(distinct sc.id)::int as creature_rows,
  coalesce(sum(sc.kills),0)::bigint as total_kills,
  count(distinct sc.id) filter (where sc.resolution_status='resolved_exact')::int as resolved_creature_rows,
  count(distinct sc.id) filter (where sc.resolution_status='unresolved')::int as unresolved_creature_rows,
  (
    case when cs.duration_seconds is not null and cs.duration_seconds > 0 then 1 else 0 end +
    case when cs.party_size is not null and cs.party_size > 0 then 1 else 0 end +
    case when cs.xp_per_hour is not null then 1 else 0 end +
    case when cs.raw_xp_per_hour is not null then 1 else 0 end +
    case when cs.balance_value is not null then 1 else 0 end +
    case when count(distinct sp.id) > 0 then 1 else 0 end +
    case when count(distinct sc.id) > 0 then 1 else 0 end
  )::numeric / 7.0 as structural_quality_score
from community_sessions cs
left join session_players sp on sp.session_id=cs.id
left join session_creatures sc on sc.session_id=cs.id
group by cs.id;

create or replace view vw_hunt_observed_performance as
select
  cs.hunt_key,
  h.name as hunt_name,
  count(*)::int as session_count,
  count(*) filter (where cs.party_size=1)::int as solo_sessions,
  count(*) filter (where cs.party_size=2)::int as duo_sessions,
  count(*) filter (where cs.party_size>=3)::int as party_sessions,
  round(avg(cs.duration_seconds)/60.0,1) as avg_duration_minutes,
  round(avg(cs.xp_per_hour),0) as avg_xp_per_hour,
  percentile_cont(0.5) within group (order by cs.xp_per_hour) as median_xp_per_hour,
  round(avg(cs.raw_xp_per_hour),0) as avg_raw_xp_per_hour,
  percentile_cont(0.5) within group (order by cs.raw_xp_per_hour) as median_raw_xp_per_hour,
  round(avg(cs.balance_value),0) as avg_balance,
  percentile_cont(0.5) within group (order by cs.balance_value) as median_balance,
  round(avg(cs.total_damage),0) as avg_total_damage,
  round(avg(cs.total_healing),0) as avg_total_healing,
  min(cs.xp_per_hour) as min_xp_per_hour,
  max(cs.xp_per_hour) as max_xp_per_hour
from community_sessions cs
join tibia_hunting_places h on h.slug=cs.hunt_key
where cs.hunt_key is not null
group by cs.hunt_key,h.name;

create or replace view vw_hunt_observed_kill_mix as
select
  cs.hunt_key,
  h.name as hunt_name,
  sc.monster_key,
  e.name as monster_name,
  count(distinct cs.id)::int as sessions_seen,
  sum(sc.kills)::bigint as kills,
  sum(sc.kills)::numeric /
    nullif(sum(sum(sc.kills)) over (partition by cs.hunt_key),0) as kill_share
from community_sessions cs
join tibia_hunting_places h on h.slug=cs.hunt_key
join session_creatures sc on sc.session_id=cs.id
join tibia_entities e
  on e.entity_type='creature'
 and e.entity_key=sc.monster_key
where cs.hunt_key is not null
  and sc.monster_key is not null
group by cs.hunt_key,h.name,sc.monster_key,e.name;

create or replace view vw_hunt_observed_element_profile as
select
  k.hunt_key,
  k.hunt_name,
  v.element,
  round(sum(k.kill_share * v.modifier_percent),2) as kill_weighted_modifier_percent,
  round(sum(k.kill_share) filter (where v.modifier_percent > 100),4) as weak_kill_share,
  round(sum(k.kill_share) filter (where v.modifier_percent = 100),4) as neutral_kill_share,
  round(sum(k.kill_share) filter (where v.modifier_percent > 0 and v.modifier_percent < 100),4) as resistant_kill_share,
  round(sum(k.kill_share) filter (where v.modifier_percent = 0),4) as immune_kill_share
from vw_hunt_observed_kill_mix k
join monster_vulnerability v on v.monster_key=k.monster_key
group by k.hunt_key,k.hunt_name,v.element;

comment on view vw_hunt_observed_element_profile is
'Kill-weighted Tier C observation profile. It improves on species-only weighting but remains observational/community evidence, not a guaranteed recommendation.';

create or replace function huntnexus_hunt_observed_profile(p_hunt_key text)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'hunt_key',p_hunt_key,
    'performance',(
      select to_jsonb(p)
      from vw_hunt_observed_performance p
      where p.hunt_key=p_hunt_key
    ),
    'kill_mix',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'monster_key',monster_key,
          'monster_name',monster_name,
          'sessions_seen',sessions_seen,
          'kills',kills,
          'kill_share',round(kill_share,4)
        )
        order by kills desc
      )
      from vw_hunt_observed_kill_mix
      where hunt_key=p_hunt_key
    ),'[]'::jsonb),
    'elements',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'element',element,
          'kill_weighted_modifier_percent',kill_weighted_modifier_percent,
          'weak_kill_share',weak_kill_share,
          'neutral_kill_share',neutral_kill_share,
          'resistant_kill_share',resistant_kill_share,
          'immune_kill_share',immune_kill_share
        )
        order by element
      )
      from vw_hunt_observed_element_profile
      where hunt_key=p_hunt_key
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'layer','community_observations',
      'kill_weighted',true,
      'final_recommendation',false,
      'note','Public community observations. Sample size, party composition, boosts, events and other modifiers can affect results.'
    )
  );
$$;

revoke all on function huntnexus_hunt_observed_profile(text)
  from public,anon,authenticated;
grant execute on function huntnexus_hunt_observed_profile(text)
  to service_role;
