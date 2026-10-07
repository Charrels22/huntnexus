-- HuntNexus Analytics — Phase 16.3 boss spell evidence.
-- Uses canonical boss vulnerability and explicit boss restrictions.
-- Does not claim a final room rotation.

create or replace view vw_boss_primary_element_profile as
select
  bp.boss_key,
  bp.name as boss_name,
  v.element,
  v.modifier_percent
from boss_profiles bp
join monster_vulnerability v
  on v.monster_key=bp.canonical_monster_key
where bp.canonical_monster_key is not null;

create or replace function huntnexus_boss_spell_candidates(
  p_boss_key text,
  p_vocation text,
  p_level int
)
returns jsonb
language sql
stable
as $$
with params as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation,
    greatest(coalesce(p_level,1),1) as player_level
),
primary_mods as (
  select element,modifier_percent
  from vw_boss_primary_element_profile
  where boss_key=p_boss_key
),
room_mods as (
  select element,avg_modifier_percent
  from vw_boss_element_profile
  where boss_key=p_boss_key
),
eligible as (
  select
    s.*,
    pm.modifier_percent as boss_modifier_percent,
    rm.avg_modifier_percent as room_avg_modifier_percent,
    case
      when s.base_power is not null
       and s.element is not null
       and s.element not in ('weapon','ice_earth')
      then s.base_power * coalesce(pm.modifier_percent,100)/100.0
      else null
    end as boss_adjusted_base_power_proxy,
    g.guidance_type,
    g.rationale as explicit_guidance_rationale,
    g.confidence as explicit_guidance_confidence
  from spell_definitions s
  left join primary_mods pm on pm.element=s.element
  left join room_mods rm on rm.element=s.element
  left join boss_room_spell_guidance g
    on g.boss_key=p_boss_key
   and g.vocation=(select vocation from params)
   and g.spell_key=s.spell_key
   and g.phase_key=''
  where s.vocation=(select vocation from params)
    and s.min_level<=(select player_level from params)
    and not s.lever_boss_restricted
),
blocked as (
  select s.*
  from spell_definitions s
  where s.vocation=(select vocation from params)
    and s.min_level<=(select player_level from params)
    and s.lever_boss_restricted
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'boss_key',p_boss_key,
    'vocation',(select vocation from params),
    'level',(select player_level from params)
  ),
  'single_target_attacks',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',spell_key,
        'name',name,
        'words',words,
        'element',element,
        'base_power',base_power,
        'boss_modifier_percent',boss_modifier_percent,
        'boss_adjusted_base_power_proxy',
          case when boss_adjusted_base_power_proxy is null then null
               else round(boss_adjusted_base_power_proxy::numeric,2) end,
        'cooldown_seconds',cooldown_seconds,
        'explicit_guidance',guidance_type,
        'explicit_guidance_rationale',explicit_guidance_rationale,
        'explicit_guidance_confidence',explicit_guidance_confidence
      )
      order by
        case guidance_type when 'recommended' then 0 when 'situational' then 1 else 2 end,
        boss_adjusted_base_power_proxy desc nulls last,
        base_power desc nulls last
    )
    from eligible
    where spell_group='attack'
      and area_type='single'
      and coalesce(guidance_type,'')<>'avoid'
  ),'[]'::jsonb),
  'multi_target_attacks',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',spell_key,
        'name',name,
        'words',words,
        'element',element,
        'base_power',base_power,
        'boss_modifier_percent',boss_modifier_percent,
        'room_avg_modifier_percent',room_avg_modifier_percent,
        'cooldown_seconds',cooldown_seconds,
        'area_type',area_type,
        'max_targets',max_targets,
        'explicit_guidance',guidance_type,
        'explicit_guidance_rationale',explicit_guidance_rationale
      )
      order by
        case guidance_type when 'recommended' then 0 when 'situational' then 1 else 2 end,
        room_avg_modifier_percent desc nulls last,
        base_power desc nulls last
    )
    from eligible
    where spell_group='attack'
      and area_type<>'single'
      and coalesce(guidance_type,'')<>'avoid'
  ),'[]'::jsonb),
  'healing',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',spell_key,'name',name,'words',words,
        'base_power',base_power,'cooldown_seconds',cooldown_seconds,
        'effect_summary',effect_summary
      )
      order by base_power desc nulls last,cooldown_seconds asc nulls last
    )
    from eligible
    where spell_group='healing'
  ),'[]'::jsonb),
  'support',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',spell_key,'name',name,'words',words,
        'explicit_guidance',guidance_type,
        'explicit_guidance_rationale',explicit_guidance_rationale,
        'effect_summary',effect_summary
      )
      order by
        case guidance_type when 'recommended' then 0 when 'situational' then 1 else 2 end,
        name
    )
    from eligible
    where spell_group='support'
      and coalesce(guidance_type,'')<>'avoid'
  ),'[]'::jsonb),
  'boss_restricted_spells',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',spell_key,'name',name,'words',words,
        'reason','Spell definition is marked as lever-boss restricted.'
      )
      order by name
    )
    from blocked
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','boss_spell_evidence',
    'final_rotation',false,
    'primary_target_element_fit',true,
    'room_add_weighting',false,
    'lever_boss_restrictions_applied',true,
    'note','Element fit and factual restrictions only. Current RubinOT room mechanics and phase timing can supersede these generic candidates.'
  )
);
$$;

revoke all on function huntnexus_boss_spell_candidates(text,text,int)
  from public,anon,authenticated;
grant execute on function huntnexus_boss_spell_candidates(text,text,int)
  to service_role;
