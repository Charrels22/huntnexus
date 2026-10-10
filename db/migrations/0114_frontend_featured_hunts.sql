-- HuntNexus FE-01 — player-facing featured hunts from observed data.
-- This is not a universal recommendation ranking.

create or replace function public.huntnexus_frontend_featured_hunts(
  p_limit integer default 8
)
returns jsonb
language sql
stable
set search_path to 'public','extensions'
as $function$
with p as (
  select least(greatest(coalesce(p_limit,8),1),20) as row_limit
),
ranked as (
  select
    perf.hunt_key,
    perf.hunt_name,
    perf.session_count,
    perf.solo_sessions,
    perf.duo_sessions,
    perf.party_sessions,
    perf.median_xp_per_hour,
    perf.median_balance_per_hour,
    perf.avg_duration_minutes,
    perf.avg_structural_quality,
    hp.city,
    hp.structured_data->>'image' as hero_image_name,
    hp.location,
    row_number() over (
      order by
        perf.session_count desc,
        coalesce(perf.avg_structural_quality,0) desc,
        perf.hunt_key
    ) as display_order
  from vw_hunt_observed_performance perf
  left join tibia_hunting_places hp on hp.slug=perf.hunt_key
  where perf.session_count > 0
),
limited as (
  select *
  from ranked
  order by display_order
  limit (select row_limit from p)
)
select jsonb_build_object(
  'hunts',coalesce(jsonb_agg(to_jsonb(limited) order by display_order),'[]'::jsonb),
  'summary',jsonb_build_object(
    'returned',(select count(*) from limited),
    'ordering','session_count_then_structural_quality'
  ),
  'methodology',jsonb_build_object(
    'stage','frontend_featured_hunts_v1',
    'recommendation',false,
    'label','most_observed',
    'universal_best_inferred',false
  )
)
from limited;
$function$;

revoke all on function public.huntnexus_frontend_featured_hunts(integer)
from public,anon,authenticated;
grant execute on function public.huntnexus_frontend_featured_hunts(integer)
to service_role;
