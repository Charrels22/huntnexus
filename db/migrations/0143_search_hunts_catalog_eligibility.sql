-- HuntNexus FE-26 — canonical hunt search respects catalog eligibility.

create or replace function public.huntnexus_search_hunts(
  p_query text default '',
  p_limit integer default 20
)
returns jsonb
language sql
stable
set search_path to 'public','extensions','net'
as $function$
with q as (
  select lower(trim(coalesce(p_query,''))) as term,
         greatest(1,least(coalesce(p_limit,20),50)) as lim
),
rows as (
  select
    h.slug as hunt_key,
    h.name,
    h.city,
    h.vocation,
    h.level_knights,
    h.level_paladins,
    h.level_mages,
    coalesce(p.session_count,0) as observed_sessions,
    exists(
      select 1
      from public.vw_hunt_observed_incoming_damage d
      where d.hunt_key=h.slug
    ) as has_observed_incoming_damage,
    coalesce(s.catalog_role,'fixed_hunt') as catalog_role,
    coalesce(s.fixed_spawn,true) as fixed_spawn,
    coalesce(s.planner_eligible,true) as planner_eligible
  from public.tibia_hunting_places h
  left join public.vw_hunt_observed_performance p on p.hunt_key=h.slug
  left join public.hunting_place_catalog_semantics s on s.hunt_key=h.slug
  where
    coalesce(s.planner_eligible,true)=true
    and (
      (select term from q)=''
      or lower(h.name) like '%'||(select term from q)||'%'
      or lower(coalesce(h.city,'')) like '%'||(select term from q)||'%'
      or lower(h.slug) like '%'||(select term from q)||'%'
    )
  order by
    case when lower(h.name)= (select term from q) then 0
         when lower(h.name) like (select term from q)||'%' then 1
         else 2 end,
    observed_sessions desc,
    h.name
  limit (select lim from q)
)
select coalesce(
  jsonb_agg(
    jsonb_build_object(
      'hunt_key',hunt_key,
      'name',name,
      'city',city,
      'vocation',vocation,
      'level_knights',level_knights,
      'level_paladins',level_paladins,
      'level_mages',level_mages,
      'observed_sessions',observed_sessions,
      'has_observed_incoming_damage',has_observed_incoming_damage,
      'catalog_role',catalog_role,
      'fixed_spawn',fixed_spawn,
      'planner_eligible',planner_eligible
    )
  ),
  '[]'::jsonb
)
from rows;
$function$;
