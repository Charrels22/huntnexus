-- FE-20 / Tier C: make sample size visible for the chosen vocation.
-- Participating in a party does not make total party XP attributable to a
-- single vocation. Preserve that distinction in all returned metadata.
-- No invented session data, extrapolated DPS or fake personal benchmarks.
create or replace function public.huntnexus_hunt_vocation_observation_sample(
  p_hunt_key text,
  p_vocation text
)
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $function$
with sourced as (
  select distinct
    cs.id, cs.source_url,cs.duration_seconds,
    cs.xp_per_hour,cs.balance_value,cs.party_size
  from public.community_sessions cs
  join public.session_players sp on sp.session_id=cs.id
  where cs.hunt_key=p_hunt_key
    and sp.vocation=p_vocation
    and cs.source_url is not null
    and cs.duration_seconds > 0
),
aggregate as (
  select
    count(*)::integer as session_count,
    count(distinct source_url)::integer as sourced_session_count,
    count(*) filter (where xp_per_hour is not null)::integer as xp_sample_count,
    count(*) filter (where balance_value is not null)::integer as balance_sample_count,
    count(*) filter (where party_size = 1)::integer as solo_sessions,
    count(*) filter (where party_size > 1)::integer as party_sessions,
    percentile_cont(0.5) within group (order by xp_per_hour::double precision)
      filter (where xp_per_hour is not null) as median_xp_per_hour,
    percentile_cont(0.5) within group (order by (balance_value * 3600 / duration_seconds)::double precision)
      filter (where balance_value is not null and duration_seconds > 0) as median_balance_per_hour
  from sourced
)
select jsonb_build_object(
  'hunt_key',p_hunt_key,
  'vocation',p_vocation,
  'sample',jsonb_build_object(
    'session_count',session_count,
    'sourced_session_count',sourced_session_count,
    'xp_sample_count',xp_sample_count,
    'balance_sample_count',balance_sample_count,
    'solo_sessions',solo_sessions,
    'party_sessions',party_sessions,
    'median_xp_per_hour',case when xp_sample_count >= 3 then median_xp_per_hour else null end,
    'median_balance_per_hour',case when balance_sample_count >= 3 then median_balance_per_hour else null end
  ),
  'methodology',jsonb_build_object(
    'stage','hunt_vocation_observation_sample_v1',
    'layer','community_observations',
    'observation_unit','sourced_session_including_vocation',
    'party_level_metrics_not_attributable_to_individual_vocation',true,
    'minimum_sample_for_median',3,
    'insufficient_xp_sample',xp_sample_count < 3,
    'insufficient_balance_sample',balance_sample_count < 3,
    'not_a_player_personal_benchmark',true,
    'unavailable_not_zero',true
  )
)
from aggregate;
$function$;

revoke all on function public.huntnexus_hunt_vocation_observation_sample(text,text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_hunt_vocation_observation_sample(text,text)
  to service_role;
