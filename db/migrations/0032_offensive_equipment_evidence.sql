-- HuntNexus Analytics — Phase 13 offensive equipment evidence.
-- Keeps incomparable offensive dimensions separate instead of forcing a single DPS score.

create or replace view vw_item_attack_components as
select i.id as item_id,i.slug as item_key,i.name,i.category,i.weapon_type,i.vocation,
       huntnexus_first_int(i.level_required) as level_required,
       'physical'::text as element,
       nullif(regexp_replace(coalesce(i.attack,''),'[^0-9.+-]','','g'),'')::numeric as component_attack
from tibia_items i
where nullif(regexp_replace(coalesce(i.attack,''),'[^0-9.+-]','','g'),'') is not null
union all
select i.id,i.slug,i.name,i.category,i.weapon_type,i.vocation,
       huntnexus_first_int(i.level_required),'fire',
       nullif(regexp_replace(coalesce(i.fire_attack,''),'[^0-9.+-]','','g'),'')::numeric
from tibia_items i
where nullif(regexp_replace(coalesce(i.fire_attack,''),'[^0-9.+-]','','g'),'') is not null
union all
select i.id,i.slug,i.name,i.category,i.weapon_type,i.vocation,
       huntnexus_first_int(i.level_required),'ice',
       nullif(regexp_replace(coalesce(i.ice_attack,''),'[^0-9.+-]','','g'),'')::numeric
from tibia_items i
where nullif(regexp_replace(coalesce(i.ice_attack,''),'[^0-9.+-]','','g'),'') is not null
union all
select i.id,i.slug,i.name,i.category,i.weapon_type,i.vocation,
       huntnexus_first_int(i.level_required),'earth',
       nullif(regexp_replace(coalesce(i.earth_attack,''),'[^0-9.+-]','','g'),'')::numeric
from tibia_items i
where nullif(regexp_replace(coalesce(i.earth_attack,''),'[^0-9.+-]','','g'),'') is not null
union all
select i.id,i.slug,i.name,i.category,i.weapon_type,i.vocation,
       huntnexus_first_int(i.level_required),'energy',
       nullif(regexp_replace(coalesce(i.energy_attack,''),'[^0-9.+-]','','g'),'')::numeric
from tibia_items i
where nullif(regexp_replace(coalesce(i.energy_attack,''),'[^0-9.+-]','','g'),'') is not null
union all
select i.id,i.slug,i.name,i.category,i.weapon_type,i.vocation,
       huntnexus_first_int(i.level_required),'death',
       nullif(regexp_replace(coalesce(i.death_attack,''),'[^0-9.+-]','','g'),'')::numeric
from tibia_items i
where nullif(regexp_replace(coalesce(i.death_attack,''),'[^0-9.+-]','','g'),'') is not null
union all
select i.id,i.slug,i.name,i.category,i.weapon_type,i.vocation,
       huntnexus_first_int(i.level_required),'holy',
       nullif(regexp_replace(coalesce(i.holy_attack,''),'[^0-9.+-]','','g'),'')::numeric
from tibia_items i
where nullif(regexp_replace(coalesce(i.holy_attack,''),'[^0-9.+-]','','g'),'') is not null;

create or replace function huntnexus_ek_weapon_candidates(
  p_hunt_key text,
  p_level int,
  p_limit int default 12
)
returns jsonb
language sql
stable
as $$
with modifiers as (
  select element,kill_weighted_modifier_percent
  from vw_hunt_observed_element_profile
  where hunt_key=p_hunt_key
    and element in ('physical','fire','ice','earth','energy','death','holy')
),
weapons as (
  select
    c.item_id,c.item_key,c.name,c.category,c.weapon_type,c.level_required,
    sum(c.component_attack * coalesce(m.kill_weighted_modifier_percent,100)/100.0) as effective_attack_proxy,
    jsonb_agg(
      jsonb_build_object(
        'element',c.element,
        'attack_component',c.component_attack,
        'hunt_modifier_percent',coalesce(m.kill_weighted_modifier_percent,100),
        'adjusted_component',round((c.component_attack * coalesce(m.kill_weighted_modifier_percent,100)/100.0)::numeric,2)
      )
      order by c.element
    ) as components
  from vw_item_attack_components c
  left join modifiers m on m.element=c.element
  where c.category in ('Sword Weapons','Axe Weapons','Club Weapons','Fist Fighting Weapons','Enchanted Items')
    and huntnexus_item_vocation_compatible(c.vocation,'EK')
    and (c.level_required is null or c.level_required<=p_level)
  group by c.item_id,c.item_key,c.name,c.category,c.weapon_type,c.level_required
),
with_skill as (
  select
    w.*,
    coalesce((
      select max(e.numeric_value)
      from item_effects e
      where e.item_id=w.item_id
        and e.effect_type='skill'
        and e.effect_key in ('sword_fighting','axe_fighting','club_fighting','fist_fighting')
    ),0) as weapon_skill_bonus
  from weapons w
),
ranked as (
  select *,
         row_number() over (
           partition by coalesce(weapon_type,category)
           order by effective_attack_proxy desc,weapon_skill_bonus desc,name
         ) as type_rank
  from with_skill
)
select jsonb_build_object(
  'hunt_key',p_hunt_key,
  'vocation','EK',
  'level',p_level,
  'candidates',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'item_key',item_key,
        'name',name,
        'category',category,
        'weapon_type',weapon_type,
        'level_required',level_required,
        'effective_attack_proxy',round(effective_attack_proxy::numeric,2),
        'weapon_skill_bonus',weapon_skill_bonus,
        'components',components
      )
      order by effective_attack_proxy desc,weapon_skill_bonus desc,name
    )
    from (
      select *
      from ranked
      where type_rank<=greatest(1,least(coalesce(p_limit,12),25))
    ) x
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','ek_elemental_weapon_proxy',
    'final_dps',false,
    'uses_skill_formula',false,
    'uses_attack_speed',false,
    'uses_spell_rotation',false,
    'note','Proxy = sum(raw physical/elemental attack component × observed kill-weighted monster modifier). Skill bonus is reported separately.'
  )
);
$$;

create or replace function huntnexus_offensive_stat_candidates(
  p_hunt_key text,
  p_vocation text,
  p_level int,
  p_limit int default 20
)
returns jsonb
language sql
stable
as $$
with wanted as (
  select unnest(
    case huntnexus_normalize_vocation(p_vocation)
      when 'EK' then array['sword_fighting','axe_fighting','club_fighting','fist_fighting']
      when 'RP' then array['distance_fighting','magic_level','holy_magic_level']
      when 'ED' then array['magic_level','ice_magic_level','earth_magic_level','healing_magic_level']
      when 'MS' then array['magic_level','fire_magic_level','energy_magic_level','death_magic_level']
      when 'EM' then array['magic_level','fist_fighting']
      else array['magic_level']
    end
  ) as effect_key
),
eligible as (
  select
    i.id as item_id,i.slug as item_key,i.name,i.category,
    s.slot,
    huntnexus_first_int(i.level_required) as level_required,
    e.effect_type,e.effect_key,e.numeric_value,e.unit,
    case
      when e.effect_key='magic_level' then 2
      when e.effect_key in (select effect_key from wanted) then 1
      else 0
    end as relevance_group
  from tibia_items i
  join item_effects e on e.item_id=i.id
  left join vw_equipment_slots s on s.item_id=i.id
  where e.effect_type in ('skill','magic_skill','offense')
    and huntnexus_item_vocation_compatible(i.vocation,p_vocation)
    and (
      huntnexus_first_int(i.level_required) is null
      or huntnexus_first_int(i.level_required)<=p_level
    )
    and (
      e.effect_key in (select effect_key from wanted)
      or e.effect_key in ('critical_hit_chance','critical_extra_damage','attack_modifier','hit_modifier','cleave','perfect_shot')
    )
),
grouped as (
  select
    item_id,item_key,name,category,slot,level_required,
    max(relevance_group) as relevance_group,
    sum(numeric_value) filter (
      where effect_key in (select effect_key from wanted)
    ) as relevant_skill_total,
    jsonb_agg(
      jsonb_build_object(
        'effect_type',effect_type,
        'effect_key',effect_key,
        'value',numeric_value,
        'unit',unit
      )
      order by effect_type,effect_key
    ) as effects
  from eligible
  group by item_id,item_key,name,category,slot,level_required
)
select jsonb_build_object(
  'hunt_key',p_hunt_key,
  'vocation',huntnexus_normalize_vocation(p_vocation),
  'level',p_level,
  'candidates',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'item_key',item_key,
        'name',name,
        'category',category,
        'slot',slot,
        'level_required',level_required,
        'relevant_skill_total',coalesce(relevant_skill_total,0),
        'effects',effects
      )
      order by relevance_group desc,coalesce(relevant_skill_total,0) desc,name
    )
    from (
      select *
      from grouped
      order by relevance_group desc,coalesce(relevant_skill_total,0) desc,name
      limit greatest(1,least(coalesce(p_limit,20),50))
    ) x
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','offensive_stat_candidates',
    'final_dps',false,
    'hunt_element_used_for_spell_choice',false,
    'note','Ranks factual offensive bonuses relevant to the vocation. Elemental spell/munition selection remains a separate layer.'
  )
);
$$;

revoke all on function huntnexus_ek_weapon_candidates(text,int,int)
  from public,anon,authenticated;
revoke all on function huntnexus_offensive_stat_candidates(text,text,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_ek_weapon_candidates(text,int,int)
  to service_role;
grant execute on function huntnexus_offensive_stat_candidates(text,text,int,int)
  to service_role;
