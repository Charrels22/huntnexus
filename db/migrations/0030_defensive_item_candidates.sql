-- HuntNexus Analytics — Phase 12 defensive equipment candidates.
-- Scores item protections against observed incoming-damage shares.
-- This produces candidates per equipment slot, not a final set.

create or replace function huntnexus_item_vocation_compatible(
  p_item_vocation text,
  p_vocation text
)
returns boolean
language sql
immutable
as $$
  select
    p_item_vocation is null
    or trim(p_item_vocation)=''
    or lower(p_item_vocation) in ('all','all vocations','all vocations.')
    or case huntnexus_normalize_vocation(p_vocation)
      when 'EK' then lower(p_item_vocation) like '%knight%'
      when 'RP' then lower(p_item_vocation) like '%paladin%'
      when 'ED' then lower(p_item_vocation) like '%druid%'
      when 'MS' then lower(p_item_vocation) like '%sorcerer%'
      when 'EM' then lower(p_item_vocation) like '%monk%'
      else false
    end;
$$;

create or replace view vw_equipment_slots as
select
  i.id as item_id,
  max(a.attribute_value) filter (where a.attribute_key='slot') as slot
from tibia_items i
left join item_attribute_entries a on a.item_id=i.id
group by i.id;

create or replace function huntnexus_defensive_item_candidates(
  p_hunt_key text,
  p_vocation text,
  p_level int,
  p_per_slot int default 5
)
returns jsonb
language sql
stable
as $$
with damage_profile as (
  select
    element,
    sum(observed_damage) as observed_damage
  from vw_hunt_observed_incoming_damage
  where hunt_key=p_hunt_key
    and vocation=huntnexus_normalize_vocation(p_vocation)
  group by element
),
damage_weights as (
  select
    element,
    observed_damage,
    observed_damage::numeric/nullif(sum(observed_damage) over (),0) as weight
  from damage_profile
),
eligible_items as (
  select
    i.id as item_id,
    i.slug as item_key,
    i.name,
    i.category,
    i.vocation,
    huntnexus_first_int(i.level_required) as level_required,
    i.armor,
    i.defense,
    i.imbue_slots,
    s.slot
  from tibia_items i
  left join vw_equipment_slots s on s.item_id=i.id
  where huntnexus_item_vocation_compatible(i.vocation,p_vocation)
    and (
      huntnexus_first_int(i.level_required) is null
      or huntnexus_first_int(i.level_required)<=p_level
    )
),
scored as (
  select
    ei.item_id,
    ei.item_key,
    ei.name,
    ei.category,
    ei.slot,
    ei.level_required,
    ei.armor,
    ei.defense,
    ei.imbue_slots,
    sum(dw.weight * ie.numeric_value) as weighted_protection_score,
    jsonb_agg(
      jsonb_build_object(
        'element',ie.effect_key,
        'protection_percent',ie.numeric_value,
        'observed_damage_weight',round(dw.weight,4)
      )
      order by dw.weight desc,ie.effect_key
    ) as matched_protections
  from eligible_items ei
  join item_effects ie
    on ie.item_id=ei.item_id
   and ie.effect_type='protection'
   and ie.unit='percent'
  join damage_weights dw on dw.element=ie.effect_key
  group by
    ei.item_id,ei.item_key,ei.name,ei.category,ei.slot,
    ei.level_required,ei.armor,ei.defense,ei.imbue_slots
),
ranked as (
  select *,
         row_number() over (
           partition by coalesce(slot,category,'unknown')
           order by weighted_protection_score desc,
                    coalesce(level_required,0) desc,
                    name
         ) as slot_rank
  from scored
),
final as (
  select *
  from ranked
  where slot_rank<=greatest(1,least(coalesce(p_per_slot,5),10))
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'hunt_key',p_hunt_key,
    'vocation',huntnexus_normalize_vocation(p_vocation),
    'level',p_level
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
  'candidates',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'item_key',item_key,
        'name',name,
        'category',category,
        'slot',slot,
        'level_required',level_required,
        'armor',armor,
        'defense',defense,
        'imbue_slots',imbue_slots,
        'weighted_protection_score',round(weighted_protection_score,3),
        'matched_protections',matched_protections
      )
      order by coalesce(slot,category,'unknown'),slot_rank
    )
    from final
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','defensive_item_candidates',
    'final_set',false,
    'source_layers',jsonb_build_array('community_observations','tibia_factual'),
    'note','Protection score weights item elemental protections by observed incoming damage. Offensive stats, imbuements, price, availability and complete set interactions are not optimized yet.'
  )
);
$$;

revoke all on function huntnexus_defensive_item_candidates(text,text,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_defensive_item_candidates(text,text,int,int)
  to service_role;
