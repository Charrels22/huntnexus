-- HuntNexus FE-01 — normalized Session Analyzer read contract.
-- Exposes session summaries and detail through server-only RPCs.
-- Raw payload stays hidden; unavailable charm damage is explicit instead of fabricated.

CREATE OR REPLACE FUNCTION public.huntnexus_session_analyzer_list(p_limit integer DEFAULT 20, p_hunt_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select least(greatest(coalesce(p_limit,20),1),100) as row_limit
),
rows as (
  select
    cs.id as session_id,
    cs.external_id,
    cs.hunt_key,
    cs.hunt_name_raw,
    cs.server_name,
    cs.session_started_at,
    cs.observed_at,
    cs.duration_seconds,
    cs.party_size,
    cs.xp_gain,
    cs.xp_per_hour,
    cs.raw_xp_per_hour,
    cs.loot_value,
    cs.supplies_value,
    cs.balance_value,
    cs.total_damage,
    cs.total_healing,
    cs.quality_score,
    coalesce(q.total_kills,0) as total_kills,
    coalesce(q.player_rows,0) as player_rows,
    coalesce(q.creature_rows,0) as creature_rows,
    coalesce(q.structural_quality_score,cs.quality_score) as structural_quality_score
  from community_sessions cs
  left join vw_community_session_quality q on q.session_id=cs.id
  where (p_hunt_key is null or cs.hunt_key=p_hunt_key)
  order by coalesce(cs.session_started_at,cs.observed_at) desc nulls last,cs.id
  limit (select row_limit from p)
)
select jsonb_build_object(
  'sessions',coalesce(jsonb_agg(to_jsonb(rows)),'[]'::jsonb),
  'summary',jsonb_build_object(
    'returned',(select count(*) from rows),
    'filter_hunt_key',p_hunt_key
  ),
  'methodology',jsonb_build_object(
    'stage','session_analyzer_list_v1',
    'source','community_sessions',
    'raw_payload_exposed',false
  )
)
from rows;
$function$
;

CREATE OR REPLACE FUNCTION public.huntnexus_session_analyzer_detail(p_session_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with s as (
  select
    cs.id as session_id,
    cs.external_id,
    cs.source_url,
    cs.server_name,
    cs.hunt_key,
    cs.hunt_name_raw,
    cs.session_started_at,
    cs.observed_at,
    cs.duration_seconds,
    cs.party_size,
    cs.xp_gain,
    cs.xp_per_hour,
    cs.raw_xp_per_hour,
    cs.loot_value,
    cs.supplies_value,
    cs.balance_value,
    cs.total_damage,
    cs.total_healing,
    cs.quality_score,
    cs.hunt_resolution_status
  from community_sessions cs
  where cs.id=p_session_id
),
players as (
  select
    p.id as player_id,
    p.vocation,
    p.level,
    p.damage,
    p.healing,
    p.loot,
    p.supplies,
    p.metadata
  from session_players p
  where p.session_id=p_session_id
  order by coalesce(p.damage,0) desc,p.level desc nulls last,p.id
),
creatures as (
  select
    c.monster_key,
    c.monster_name_raw,
    c.kills,
    c.damage_received,
    c.loot_value,
    c.resolution_status
  from session_creatures c
  where c.session_id=p_session_id
  order by coalesce(c.kills,0) desc,c.monster_name_raw
),
incoming as (
  select
    d.player_id,
    d.element,
    d.damage,
    d.share_percent,
    d.total_input_damage,
    d.max_dps
  from session_incoming_damage d
  where d.session_id=p_session_id
  order by coalesce(d.damage,0) desc,d.element
),
incoming_sources as (
  select
    d.player_id,
    d.monster_key,
    d.monster_name_raw,
    d.damage,
    d.share_percent
  from session_incoming_damage_sources d
  where d.session_id=p_session_id
  order by coalesce(d.damage,0) desc,d.monster_name_raw
),
combat_stats as (
  select
    c.player_id,
    c.stat_key,
    c.stat_name_raw,
    c.numeric_value,
    c.unit,
    c.occurrence_order,
    c.metadata
  from session_player_combat_stats c
  where c.session_id=p_session_id
  order by c.player_id,c.occurrence_order,c.stat_key
),
equipment as (
  select
    e.player_id,
    e.slot_key,
    e.item_key,
    e.item_name_raw,
    e.asset_group,
    e.raw_asset_file,
    e.occurrence_order
  from session_player_equipment e
  where e.session_id=p_session_id
  order by e.player_id,e.occurrence_order,e.slot_key
),
modifiers as (
  select
    m.player_id,
    m.modifier_type,
    m.target,
    m.value,
    m.unit,
    m.definition_key,
    m.metadata
  from session_modifiers m
  where m.session_id=p_session_id
  order by m.player_id,m.modifier_type,m.target
)
select case
  when not exists(select 1 from s) then jsonb_build_object(
    'error','session_not_found',
    'session_id',p_session_id
  )
  else jsonb_build_object(
    'session',(select to_jsonb(s) from s),
    'hunt_analyse',jsonb_build_object(
      'duration_seconds',(select duration_seconds from s),
      'xp_gain',(select xp_gain from s),
      'xp_per_hour',(select xp_per_hour from s),
      'raw_xp_per_hour',(select raw_xp_per_hour from s),
      'loot_value',(select loot_value from s),
      'supplies_value',(select supplies_value from s),
      'balance_value',(select balance_value from s),
      'total_damage',(select total_damage from s),
      'total_healing',(select total_healing from s),
      'party_size',(select party_size from s),
      'total_kills',coalesce((select sum(kills) from creatures),0)
    ),
    'misc',jsonb_build_object(
      'combat_stats',coalesce((select jsonb_agg(to_jsonb(c)) from combat_stats c),'[]'::jsonb),
      'equipment',coalesce((select jsonb_agg(to_jsonb(e)) from equipment e),'[]'::jsonb),
      'modifiers',coalesce((select jsonb_agg(to_jsonb(m)) from modifiers m),'[]'::jsonb),
      'creatures',coalesce((select jsonb_agg(to_jsonb(c)) from creatures c),'[]'::jsonb)
    ),
    'damage',jsonb_build_object(
      'total_damage',(select total_damage from s),
      'incoming_by_element',coalesce((select jsonb_agg(to_jsonb(i)) from incoming i),'[]'::jsonb),
      'incoming_by_source',coalesce((select jsonb_agg(to_jsonb(i)) from incoming_sources i),'[]'::jsonb),
      'charm_damage','[]'::jsonb,
      'charm_damage_available',false
    ),
    'party_hunt',jsonb_build_object(
      'party_size',(select party_size from s),
      'players',coalesce((select jsonb_agg(to_jsonb(p)) from players p),'[]'::jsonb)
    ),
    'availability',jsonb_build_object(
      'hunt_analyse',true,
      'misc',(exists(select 1 from combat_stats) or exists(select 1 from equipment) or exists(select 1 from creatures)),
      'damage',((select total_damage from s) is not null or exists(select 1 from incoming)),
      'party_hunt',(select coalesce(party_size,0) from s)>1 or (select count(*) from players)>1,
      'charm_damage',false
    ),
    'methodology',jsonb_build_object(
      'stage','session_analyzer_detail_v1',
      'normalized_tables_only',true,
      'raw_payload_exposed',false,
      'missing_charm_data_invented',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_session_analyzer_list(integer,text)
from public,anon,authenticated;
grant execute on function public.huntnexus_session_analyzer_list(integer,text)
to service_role;

revoke all on function public.huntnexus_session_analyzer_detail(uuid)
from public,anon,authenticated;
grant execute on function public.huntnexus_session_analyzer_detail(uuid)
to service_role;
