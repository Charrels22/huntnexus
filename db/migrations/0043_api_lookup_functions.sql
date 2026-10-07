-- HuntNexus API — Phase 17 lookup/readiness functions.
-- Service-role-only lookup helpers for the Edge Function.

create or replace function huntnexus_search_hunts(
  p_query text default '',
  p_limit int default 20
)
returns jsonb
language sql
stable
as $$
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
      from vw_hunt_observed_incoming_damage d
      where d.hunt_key=h.slug
    ) as has_observed_incoming_damage
  from tibia_hunting_places h
  left join vw_hunt_observed_performance p on p.hunt_key=h.slug
  where
    (select term from q)=''
    or lower(h.name) like '%'||(select term from q)||'%'
    or lower(coalesce(h.city,'')) like '%'||(select term from q)||'%'
    or lower(h.slug) like '%'||(select term from q)||'%'
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
      'has_observed_incoming_damage',has_observed_incoming_damage
    )
  ),
  '[]'::jsonb
)
from rows;
$$;

create or replace function huntnexus_search_bosses(
  p_query text default '',
  p_limit int default 20
)
returns jsonb
language sql
stable
as $$
with q as (
  select lower(trim(coalesce(p_query,''))) as term,
         greatest(1,least(coalesce(p_limit,20),50)) as lim
),
rows as (
  select
    bp.boss_key,
    bp.name,
    bp.encounter_type,
    r.final_build_blocked,
    r.readiness_status,
    r.guards
  from boss_profiles bp
  left join vw_boss_recommendation_readiness r on r.boss_key=bp.boss_key
  where
    (select term from q)=''
    or lower(bp.name) like '%'||(select term from q)||'%'
    or lower(bp.boss_key) like '%'||(select term from q)||'%'
  order by
    case when lower(bp.name)= (select term from q) then 0
         when lower(bp.name) like (select term from q)||'%' then 1
         else 2 end,
    bp.name
  limit (select lim from q)
)
select coalesce(
  jsonb_agg(
    jsonb_build_object(
      'boss_key',boss_key,
      'name',name,
      'encounter_type',encounter_type,
      'final_build_blocked',coalesce(final_build_blocked,false),
      'readiness_status',coalesce(readiness_status,'base_profile_available'),
      'guards',coalesce(guards,'[]'::jsonb)
    )
  ),
  '[]'::jsonb
)
from rows;
$$;

create or replace function huntnexus_api_health()
returns jsonb
language sql
stable
as $$
select jsonb_build_object(
  'status','ok',
  'product','HuntNexus',
  'counts',jsonb_build_object(
    'creatures',(select count(*) from tibia_entities where entity_type='creature'),
    'hunts',(select count(*) from tibia_hunting_places),
    'items',(select count(*) from tibia_items),
    'bosses',(select count(*) from boss_profiles),
    'spells',(select count(*) from spell_definitions),
    'community_sessions',(select count(*) from community_sessions)
  ),
  'versions',jsonb_build_object(
    'latest_rubinot_server',(
      select version_label from game_versions
      where scope='rubinot_server'
      order by released_on desc,version_label desc
      limit 1
    ),
    'latest_rubinot_client',(
      select version_label from game_versions
      where scope='rubinot_client'
      order by released_on desc,version_label desc
      limit 1
    )
  ),
  'recommendation_stage','preview_v3',
  'final_recommendation_ready',false
);
$$;

revoke all on function huntnexus_search_hunts(text,int)
  from public,anon,authenticated;
revoke all on function huntnexus_search_bosses(text,int)
  from public,anon,authenticated;
revoke all on function huntnexus_api_health()
  from public,anon,authenticated;

grant execute on function huntnexus_search_hunts(text,int) to service_role;
grant execute on function huntnexus_search_bosses(text,int) to service_role;
grant execute on function huntnexus_api_health() to service_role;
