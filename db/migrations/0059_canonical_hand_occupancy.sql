-- HuntNexus Analytics — canonical hand occupancy.
-- Uses item hands metadata to resolve one-hand/two-hand conflicts before set optimization.

CREATE OR REPLACE FUNCTION public.huntnexus_canonical_equipment_slot(p_raw_slot text, p_category text, p_hands text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select case
  when p_category in (
    'Sword Weapons','Axe Weapons','Club Weapons','Fist Fighting Weapons',
    'Bows','Crossbows','Throwing Weapons','Rods','Wands','Enchanted Items'
  ) and lower(trim(coalesce(p_hands,'')))='two' then 'Both Hands'
  when p_category in (
    'Sword Weapons','Axe Weapons','Club Weapons','Fist Fighting Weapons',
    'Bows','Crossbows','Throwing Weapons','Rods','Wands','Enchanted Items'
  ) and lower(trim(coalesce(p_hands,'')))='one' then 'Weapon Hand'
  when p_category in ('Shields','Spellbooks','Quivers') then 'Shield Hand'
  else huntnexus_canonical_equipment_slot(p_raw_slot,p_category)
end
$function$
;

revoke all on function huntnexus_canonical_equipment_slot(text,text,text)
  from public,anon,authenticated;
grant execute on function huntnexus_canonical_equipment_slot(text,text,text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_loadout_candidate_matrix(p_hunt_key text, p_vocation text, p_level integer, p_per_dimension integer DEFAULT 3)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with params as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation,
    greatest(coalesce(p_level,1),1) as player_level,
    greatest(1,least(coalesce(p_per_dimension,3),10)) as per_dimension
),
wanted as (
  select unnest(
    case (select vocation from params)
      when 'EK' then array['sword_fighting','axe_fighting','club_fighting','fist_fighting','shielding']
      when 'RP' then array['distance_fighting','magic_level','holy_magic_level']
      when 'ED' then array['magic_level','ice_magic_level','earth_magic_level','healing_magic_level']
      when 'MS' then array['magic_level','fire_magic_level','energy_magic_level','death_magic_level']
      when 'EM' then array['magic_level','fist_fighting']
      else array['magic_level']
    end
  ) as effect_key
),
damage as (
  select element,sum(observed_damage)::numeric as observed_damage
  from vw_hunt_observed_incoming_damage
  where hunt_key=p_hunt_key
    and vocation=(select vocation from params)
  group by element
),
damage_weights as (
  select
    element,
    observed_damage,
    observed_damage / nullif(sum(observed_damage) over (),0) as weight
  from damage
),
eligible as (
  select
    i.id as item_id,
    i.slug as item_key,
    i.name,
    i.category,
    huntnexus_canonical_equipment_slot(s.slot,i.category,i.hands) as slot_key,
    huntnexus_first_int(i.level_required) as level_required,
    i.armor,
    i.defense,
    i.attack,
    i.hands,
    i.weapon_type,
    huntnexus_first_int(i.imbue_slots) as imbue_slots
  from tibia_items i
  left join vw_equipment_slots s on s.item_id=i.id
  where huntnexus_item_vocation_compatible(i.vocation,(select vocation from params))
    and (
      huntnexus_first_int(i.level_required) is null
      or huntnexus_first_int(i.level_required)<=(select player_level from params)
    )
    and huntnexus_canonical_equipment_slot(s.slot,i.category,i.hands) is not null
    and (
      coalesce(huntnexus_first_int(i.imbue_slots),0)>0
      or nullif(i.attack,'') is not null
      or nullif(i.defense,'') is not null
      or nullif(i.armor,'') is not null
      or nullif(i.weapon_type,'') is not null
      or nullif(i.hands,'') is not null
      or exists (
        select 1
        from item_effects ie
        where ie.item_id=i.id
          and (
            ie.effect_type in ('protection','skill','magic_skill','offense','defense','special','leech')
            or ie.effect_key in (
              'critical_hit_chance','critical_extra_damage',
              'attack_modifier','hit_modifier','cleave','perfect_shot'
            )
          )
      )
    )
    and not (
      lower(trim(coalesce(i.name,''))) = lower(trim(coalesce(i.category,'')))
      and s.slot is null
      and coalesce(huntnexus_first_int(i.imbue_slots),0)=0
      and not exists (select 1 from item_effects ie where ie.item_id=i.id)
      and nullif(i.attack,'') is null
      and nullif(i.defense,'') is null
      and nullif(i.armor,'') is null
      and nullif(i.weapon_type,'') is null
    )
),
defense as (
  select
    e.item_id,
    sum(dw.weight * ie.numeric_value) as defensive_score,
    jsonb_agg(
      jsonb_build_object(
        'element',ie.effect_key,
        'protection_percent',ie.numeric_value,
        'observed_damage_weight',round(dw.weight,4)
      )
      order by dw.weight desc,ie.effect_key
    ) as protections
  from eligible e
  join item_effects ie
    on ie.item_id=e.item_id
   and ie.effect_type='protection'
   and ie.unit='percent'
  join damage_weights dw on dw.element=ie.effect_key
  group by e.item_id
),
offense as (
  select
    e.item_id,
    sum(ie.numeric_value) filter (
      where ie.effect_key in (select effect_key from wanted)
    ) as offensive_skill_total,
    jsonb_agg(
      jsonb_build_object(
        'effect_type',ie.effect_type,
        'effect_key',ie.effect_key,
        'value',ie.numeric_value,
        'unit',ie.unit
      )
      order by ie.effect_type,ie.effect_key
    ) filter (
      where ie.effect_key in (select effect_key from wanted)
         or ie.effect_key in (
           'critical_hit_chance','critical_extra_damage',
           'attack_modifier','hit_modifier','cleave','perfect_shot'
         )
    ) as offensive_effects
  from eligible e
  left join item_effects ie
    on ie.item_id=e.item_id
   and ie.effect_type in ('skill','magic_skill','offense')
  group by e.item_id
),
matrix as (
  select
    e.*,
    coalesce(d.defensive_score,0) as defensive_score,
    coalesce(d.protections,'[]'::jsonb) as protections,
    coalesce(o.offensive_skill_total,0) as offensive_skill_total,
    coalesce(o.offensive_effects,'[]'::jsonb) as offensive_effects
  from eligible e
  left join defense d on d.item_id=e.item_id
  left join offense o on o.item_id=e.item_id
),
ranked as (
  select
    m.*,
    row_number() over (
      partition by slot_key
      order by defensive_score desc,
               offensive_skill_total desc,
               coalesce(imbue_slots,0) desc,
               name
    ) as defense_rank,
    row_number() over (
      partition by slot_key
      order by offensive_skill_total desc,
               defensive_score desc,
               coalesce(imbue_slots,0) desc,
               name
    ) as offense_rank,
    row_number() over (
      partition by slot_key
      order by coalesce(imbue_slots,0) desc,
               defensive_score desc,
               offensive_skill_total desc,
               name
    ) as imbue_rank
  from matrix m
),
selected as (
  select *
  from ranked
  where defense_rank<=(select per_dimension from params)
     or offense_rank<=(select per_dimension from params)
     or imbue_rank<=(select per_dimension from params)
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'hunt_key',p_hunt_key,
    'vocation',(select vocation from params),
    'level',(select player_level from params)
  ),
  'incoming_damage',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'element',element,
        'weight',round(weight,4),
        'observed_damage',observed_damage
      )
      order by weight desc
    )
    from damage_weights
  ),'[]'::jsonb),
  'slots',coalesce((
    select jsonb_object_agg(slot_key,items)
    from (
      select
        slot_key,
        jsonb_agg(
          jsonb_build_object(
            'item_key',item_key,
            'name',name,
            'category',category,
            'level_required',level_required,
            'armor',armor,
            'defense',defense,
            'attack',attack,
            'hands',hands,
            'weapon_type',weapon_type,
            'imbue_slots',imbue_slots,
            'defensive_score',round(defensive_score::numeric,3),
            'offensive_skill_total',offensive_skill_total,
            'protections',protections,
            'offensive_effects',offensive_effects,
            'dimension_ranks',jsonb_build_object(
              'defense',defense_rank,
              'offense',offense_rank,
              'imbue_slots',imbue_rank
            )
          )
          order by
            least(defense_rank,offense_rank,imbue_rank),
            defensive_score desc,
            offensive_skill_total desc,
            name
        ) as items
      from selected
      group by slot_key
      order by slot_key
    ) x
  ),'{}'::jsonb),
  'methodology',jsonb_build_object(
    'stage','loadout_candidate_matrix_v4',
    'final_set',false,
    'combined_score',false,
    'canonical_slots',true,
    'hand_occupancy_normalized',true,
    'equipment_evidence_required',true,
    'dimensions',jsonb_build_array(
      'observed_damage_weighted_protection',
      'vocation_relevant_offensive_stats',
      'imbuement_slots'
    ),
    'note','Candidates use canonical slots; one/two-hand occupancy follows item hands metadata for hand equipment. Offense, defense and imbue capacity remain independent.'
  )
);
$function$
;

revoke all on function huntnexus_loadout_candidate_matrix(text,text,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_loadout_candidate_matrix(text,text,int,int)
  to service_role;
