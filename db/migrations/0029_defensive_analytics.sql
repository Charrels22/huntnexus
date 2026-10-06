-- HuntNexus Analytics — Phase 11.1 observed defensive profile.

create or replace view vw_hunt_observed_incoming_damage as
with subject_totals as (
  select
    d.session_id,
    d.player_name_hash,
    max(d.total_input_damage) as total_input_damage
  from session_incoming_damage d
  group by d.session_id,d.player_name_hash
),
base as (
  select
    cs.hunt_key,
    h.name as hunt_name,
    sp.vocation,
    d.session_id,
    d.player_name_hash,
    d.element,
    d.damage,
    d.share_percent,
    st.total_input_damage,
    d.max_dps
  from session_incoming_damage d
  join subject_totals st
    on st.session_id=d.session_id
   and st.player_name_hash=d.player_name_hash
  join community_sessions cs on cs.id=d.session_id
  join tibia_hunting_places h on h.slug=cs.hunt_key
  left join session_players sp
    on sp.id=d.player_id
  where cs.hunt_key is not null
)
select
  hunt_key,
  hunt_name,
  vocation,
  element,
  count(distinct session_id::text||':'||player_name_hash)::int as subject_samples,
  sum(damage) as observed_damage,
  round(
    sum(damage)::numeric /
    nullif((
      select sum(x.total_input_damage)
      from (
        select distinct b2.session_id,b2.player_name_hash,b2.total_input_damage
        from base b2
        where b2.hunt_key=base.hunt_key
          and b2.vocation is not distinct from base.vocation
      ) x
    ),0),
    4
  ) as damage_share,
  percentile_cont(0.5) within group (order by max_dps) as median_max_dps
from base
group by hunt_key,hunt_name,vocation,element;

comment on view vw_hunt_observed_incoming_damage is
'Observed Tier C input-damage mix for linked HuntAnalyser members only; not party-wide damage unless every member has linked detail data.';

create or replace function huntnexus_hunt_defensive_profile(
  p_hunt_key text,
  p_vocation text default null
)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'hunt_key',p_hunt_key,
    'vocation',case when p_vocation is null then null else huntnexus_normalize_vocation(p_vocation) end,
    'elements',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'element',element,
          'subject_samples',subject_samples,
          'observed_damage',observed_damage,
          'damage_share',damage_share,
          'median_max_dps',median_max_dps
        )
        order by damage_share desc,observed_damage desc
      )
      from vw_hunt_observed_incoming_damage
      where hunt_key=p_hunt_key
        and (
          p_vocation is null
          or vocation=huntnexus_normalize_vocation(p_vocation)
        )
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'layer','community_observations',
      'scope','linked_member_input_damage',
      'party_wide',false,
      'final_set_recommendation',false,
      'note','Use as defensive evidence. Equipment recommendation must also consider level, vocation, slots and other item effects.'
    )
  );
$$;

revoke all on function huntnexus_hunt_defensive_profile(text,text)
  from public,anon,authenticated;
grant execute on function huntnexus_hunt_defensive_profile(text,text)
  to service_role;
