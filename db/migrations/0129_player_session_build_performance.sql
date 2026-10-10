-- HuntNexus FE-14 — observed private performance by immutable loadout snapshot.
-- Descriptive only: no causal attribution from loadout to performance.

create or replace function public.huntnexus_player_session_build_performance(
  p_client_id uuid,
  p_hunt_key text,
  p_vocation text default null
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with base as (
  select
    s.id,
    s.created_at,
    s.vocation,
    s.loadout_snapshot,
    coalesce(s.loadout_snapshot->'selection','{}'::jsonb) as selection,
    md5(coalesce(s.loadout_snapshot->'selection','{}'::jsonb)::text) as build_signature,
    nullif(s.parsed_data #>> '{hunt_analyse,xp_per_hour}','')::numeric as xp_per_hour,
    case
      when nullif(s.parsed_data #>> '{hunt_analyse,duration_seconds}','')::numeric > 0
       and nullif(s.parsed_data #>> '{hunt_analyse,balance_value}','') is not null
      then
        nullif(s.parsed_data #>> '{hunt_analyse,balance_value}','')::numeric
        * 3600
        / nullif(s.parsed_data #>> '{hunt_analyse,duration_seconds}','')::numeric
      else null
    end as profit_per_hour,
    case
      when nullif(s.parsed_data #>> '{hunt_analyse,duration_seconds}','')::numeric > 0
       and nullif(s.parsed_data #>> '{hunt_analyse,total_damage}','') is not null
      then
        nullif(s.parsed_data #>> '{hunt_analyse,total_damage}','')::numeric
        * 3600
        / nullif(s.parsed_data #>> '{hunt_analyse,duration_seconds}','')::numeric
      else null
    end as damage_per_hour,
    case
      when nullif(s.parsed_data #>> '{hunt_analyse,duration_seconds}','')::numeric > 0
       and nullif(s.parsed_data #>> '{hunt_analyse,total_healing}','') is not null
      then
        nullif(s.parsed_data #>> '{hunt_analyse,total_healing}','')::numeric
        * 3600
        / nullif(s.parsed_data #>> '{hunt_analyse,duration_seconds}','')::numeric
      else null
    end as healing_per_hour
  from public.player_hunt_sessions s
  where s.client_id=p_client_id
    and s.hunt_key=p_hunt_key
    and (p_vocation is null or s.vocation=huntnexus_normalize_vocation(p_vocation))
    and coalesce(s.loadout_snapshot->>'source','not_available') <> 'not_available'
    and exists (
      select 1
      from jsonb_object_keys(coalesce(s.loadout_snapshot->'selection','{}'::jsonb))
    )
),
agg as (
  select
    build_signature,
    selection,
    count(*)::int as session_count,
    min(created_at) as first_session_at,
    max(created_at) as latest_session_at,
    percentile_cont(0.5) within group (order by xp_per_hour)
      filter (where xp_per_hour is not null) as median_xp_per_hour,
    percentile_cont(0.5) within group (order by profit_per_hour)
      filter (where profit_per_hour is not null) as median_profit_per_hour,
    percentile_cont(0.5) within group (order by damage_per_hour)
      filter (where damage_per_hour is not null) as median_damage_per_hour,
    percentile_cont(0.5) within group (order by healing_per_hour)
      filter (where healing_per_hour is not null) as median_healing_per_hour
  from base
  group by build_signature,selection
),
latest_snapshot as (
  select distinct on (build_signature)
    build_signature,
    loadout_snapshot
  from base
  order by build_signature,created_at desc,id desc
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'hunt_key',p_hunt_key,
    'vocation',case when p_vocation is null then null else huntnexus_normalize_vocation(p_vocation) end
  ),
  'builds',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'build_signature',a.build_signature,
        'selection',a.selection,
        'source',l.loadout_snapshot->>'source',
        'option_type',l.loadout_snapshot->>'option_type',
        'items',coalesce(l.loadout_snapshot->'items','[]'::jsonb),
        'session_count',a.session_count,
        'sample_status',case
          when a.session_count=1 then 'single_session'
          when a.session_count=2 then 'very_low_sample'
          when a.session_count between 3 and 4 then 'low_sample'
          else 'observed_sample'
        end,
        'first_session_at',a.first_session_at,
        'latest_session_at',a.latest_session_at,
        'median_xp_per_hour',a.median_xp_per_hour,
        'median_profit_per_hour',a.median_profit_per_hour,
        'median_damage_per_hour',a.median_damage_per_hour,
        'median_healing_per_hour',a.median_healing_per_hour
      )
      order by a.session_count desc,a.latest_session_at desc,a.build_signature
    )
    from agg a
    join latest_snapshot l using (build_signature)
  ),'[]'::jsonb),
  'summary',jsonb_build_object(
    'sessions',(select count(*) from base),
    'distinct_builds',(select count(*) from agg)
  ),
  'methodology',jsonb_build_object(
    'stage','player_session_build_performance_v1',
    'private_sessions_only',true,
    'loadout_snapshot_required',true,
    'median_used',true,
    'causal_effect_inferred',false,
    'small_sample_warning_required',true,
    'community_evidence_written',false
  )
);
$function$;

revoke all on function public.huntnexus_player_session_build_performance(uuid,text,text)
from public,anon,authenticated;
grant execute on function public.huntnexus_player_session_build_performance(uuid,text,text)
to service_role;
