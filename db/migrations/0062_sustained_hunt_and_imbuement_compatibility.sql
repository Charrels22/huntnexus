-- HuntNexus Analytics — sustained-hunt viability, EK hand tradeoff and
-- per-item imbuement compatibility.

CREATE OR REPLACE FUNCTION public.huntnexus_item_hunt_viability(p_item_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with item as (
  select
    i.slug,
    i.name,
    coalesce((
      select e->>'value'
      from jsonb_array_elements(coalesce(i.structured_data #> '{additionalAttributes,entries}','[]'::jsonb)) e
      where e->>'key'='notes'
      limit 1
    ),'') as notes
  from tibia_items i
  where i.id=p_item_id
)
select coalesce((
  select jsonb_build_object(
    'item_key',slug,
    'name',name,
    'eligible',
      not (
        lower(notes) like '%break with the first hit%'
        or lower(notes) like '%breaks after 2 hits%'
        or lower(notes) like '%break after the first shot%'
        or (lower(notes) like '%temporary weapon%' and lower(notes) like '%disappear after%')
        or lower(notes) like '%only meant as decoration%'
        or lower(notes) like '%used as decoration rather than in actual fights%'
      ),
    'exclusion_reason',
      case
        when lower(notes) like '%break with the first hit%'
          or lower(notes) like '%breaks after 2 hits%'
          or lower(notes) like '%break after the first shot%'
        then 'fragile_few_hit_weapon'
        when lower(notes) like '%temporary weapon%' and lower(notes) like '%disappear after%'
        then 'temporary_duration_or_shot_limited'
        when lower(notes) like '%only meant as decoration%'
          or lower(notes) like '%used as decoration rather than in actual fights%'
        then 'decoration_or_replica'
        else null
      end
  )
  from item
),jsonb_build_object('eligible',false,'exclusion_reason','item_not_found'));
$function$
;

revoke all on function huntnexus_item_hunt_viability(uuid)
  from public,anon,authenticated;
grant execute on function huntnexus_item_hunt_viability(uuid)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_ek_hand_options(p_hunt_key text, p_level integer, p_limit integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with params as (
  select greatest(coalesce(p_level,1),1) as player_level,
         greatest(1,least(coalesce(p_limit,5),10)) as result_limit
),
damage as (
  select element,sum(observed_damage)::numeric as observed_damage
  from vw_hunt_observed_incoming_damage
  where hunt_key=p_hunt_key and vocation='EK'
  group by element
),
damage_weights as (
  select element,
         observed_damage/nullif(sum(observed_damage) over (),0) as weight
  from damage
),
weapon_json as (
  select value as j
  from jsonb_array_elements(
    huntnexus_ek_weapon_candidates(
      p_hunt_key,(select player_level from params),25
    )->'candidates'
  )
),
weapons as (
  select
    i.id as item_id,
    i.slug as item_key,
    i.name,
    i.category,
    i.weapon_type,
    i.hands,
    i.attack,
    i.defense,
    coalesce(huntnexus_first_int(i.imbue_slots),0) as imbue_slots,
    (w.j->>'effective_attack_proxy')::numeric as effective_attack_proxy,
    coalesce((w.j->>'weapon_skill_bonus')::numeric,0) as weapon_skill_bonus,
    w.j->'components' as components,
    case lower(coalesce(i.weapon_type,''))
      when 'sword' then 'sword_fighting'
      when 'axe' then 'axe_fighting'
      when 'club' then 'club_fighting'
      when 'fist' then 'fist_fighting'
      when 'fist fighting' then 'fist_fighting'
      else null
    end as skill_key,
    coalesce((
      select sum(dw.weight * ie.numeric_value)
      from item_effects ie
      join damage_weights dw on dw.element=ie.effect_key
      where ie.item_id=i.id
        and ie.effect_type='protection'
        and ie.unit='percent'
    ),0) as weighted_protection
  from weapon_json w
  join tibia_items i on i.slug=w.j->>'item_key'
  where lower(coalesce(i.hands,'')) in ('one','two')
    and coalesce((huntnexus_item_hunt_viability(i.id)->>'eligible')::boolean,false)
),
excluded as (
  select
    i.slug as item_key,
    i.name,
    huntnexus_item_hunt_viability(i.id)->>'exclusion_reason' as reason
  from weapon_json w
  join tibia_items i on i.slug=w.j->>'item_key'
  where lower(coalesce(i.hands,'')) in ('one','two')
    and not coalesce((huntnexus_item_hunt_viability(i.id)->>'eligible')::boolean,false)
),
offhands as (
  select
    i.id as item_id,
    i.slug as item_key,
    i.name,
    i.category,
    i.defense,
    coalesce(huntnexus_first_int(i.imbue_slots),0) as imbue_slots,
    coalesce((
      select sum(dw.weight * ie.numeric_value)
      from item_effects ie
      join damage_weights dw on dw.element=ie.effect_key
      where ie.item_id=i.id
        and ie.effect_type='protection'
        and ie.unit='percent'
    ),0) as weighted_protection,
    coalesce((
      select max(ie.numeric_value)
      from item_effects ie
      where ie.item_id=i.id
        and ie.effect_type='skill'
        and ie.effect_key='shielding'
    ),0) as shielding_bonus
  from tibia_items i
  left join vw_equipment_slots s on s.item_id=i.id
  where i.category='Shields'
    and huntnexus_item_vocation_compatible(i.vocation,'EK')
    and (
      huntnexus_first_int(i.level_required) is null
      or huntnexus_first_int(i.level_required)<=(select player_level from params)
    )
    and huntnexus_canonical_equipment_slot(s.slot,i.category,i.hands)='Shield Hand'
),
pairs as (
  select
    w.*,
    o.item_key as offhand_item_key,
    o.name as offhand_name,
    o.category as offhand_category,
    o.defense as offhand_defense,
    o.imbue_slots as offhand_imbue_slots,
    o.shielding_bonus,
    coalesce((
      select max(ie.numeric_value)
      from item_effects ie
      where ie.item_id=o.item_id
        and ie.effect_type='skill'
        and ie.effect_key=w.skill_key
    ),0) as offhand_matching_skill_bonus,
    w.weapon_skill_bonus + coalesce((
      select max(ie.numeric_value)
      from item_effects ie
      where ie.item_id=o.item_id
        and ie.effect_type='skill'
        and ie.effect_key=w.skill_key
    ),0) as matching_weapon_skill_bonus,
    w.weighted_protection + o.weighted_protection as pair_weighted_protection,
    w.imbue_slots + o.imbue_slots as pair_imbue_capacity
  from weapons w
  cross join offhands o
  where lower(w.hands)='one'
),
one_ranked as (
  select *,
    row_number() over (
      order by effective_attack_proxy desc,
               matching_weapon_skill_bonus desc,
               pair_imbue_capacity desc,
               pair_weighted_protection desc,
               name,offhand_name
    ) as offense_rank,
    row_number() over (
      order by pair_weighted_protection desc,
               shielding_bonus desc,
               effective_attack_proxy desc,
               matching_weapon_skill_bonus desc,
               pair_imbue_capacity desc,
               name,offhand_name
    ) as defense_rank
  from pairs
),
two_ranked as (
  select *,
    row_number() over (
      order by effective_attack_proxy desc,
               weapon_skill_bonus desc,
               imbue_slots desc,
               weighted_protection desc,
               name
    ) as offense_rank,
    row_number() over (
      order by weighted_protection desc,
               effective_attack_proxy desc,
               weapon_skill_bonus desc,
               imbue_slots desc,
               name
    ) as defense_rank
  from weapons
  where lower(hands)='two'
),
best_one as (select * from one_ranked where offense_rank=1),
best_two as (select * from two_ranked where offense_rank=1),
resolved as (
  select case
    when bo.item_key is null and bt.item_key is null then null
    when bo.item_key is not null and bt.item_key is null then 'one_handed'
    when bo.item_key is null and bt.item_key is not null then 'two_handed'
    when bo.effective_attack_proxy >= bt.effective_attack_proxy
      and bo.matching_weapon_skill_bonus >= bt.weapon_skill_bonus
      and bo.pair_weighted_protection >= bt.weighted_protection
      and bo.pair_imbue_capacity >= bt.imbue_slots
      and (
        bo.effective_attack_proxy > bt.effective_attack_proxy
        or bo.matching_weapon_skill_bonus > bt.weapon_skill_bonus
        or bo.pair_weighted_protection > bt.weighted_protection
        or bo.pair_imbue_capacity > bt.imbue_slots
      )
    then 'one_handed'
    when bt.effective_attack_proxy >= bo.effective_attack_proxy
      and bt.weapon_skill_bonus >= bo.matching_weapon_skill_bonus
      and bt.weighted_protection >= bo.pair_weighted_protection
      and bt.imbue_slots >= bo.pair_imbue_capacity
      and (
        bt.effective_attack_proxy > bo.effective_attack_proxy
        or bt.weapon_skill_bonus > bo.matching_weapon_skill_bonus
        or bt.weighted_protection > bo.pair_weighted_protection
        or bt.imbue_slots > bo.pair_imbue_capacity
      )
    then 'two_handed'
    else null
  end as configuration
  from best_one bo
  full join best_two bt on true
)
select jsonb_build_object(
  'hunt_key',p_hunt_key,
  'vocation','EK',
  'level',(select player_level from params),
  'one_handed',jsonb_build_object(
    'offense_options',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'weapon',jsonb_build_object(
            'item_key',item_key,'name',name,'category',category,
            'weapon_type',weapon_type,'attack',attack,'defense',defense,
            'effective_attack_proxy',round(effective_attack_proxy,2),
            'base_weapon_skill_bonus',weapon_skill_bonus,
            'components',components,'imbue_slots',imbue_slots
          ),
          'off_hand',jsonb_build_object(
            'item_key',offhand_item_key,'name',offhand_name,
            'category',offhand_category,'defense',offhand_defense,
            'matching_weapon_skill_bonus',offhand_matching_skill_bonus,
            'shielding_bonus',shielding_bonus,'imbue_slots',offhand_imbue_slots
          ),
          'matching_weapon_skill_bonus',matching_weapon_skill_bonus,
          'weighted_protection',round(pair_weighted_protection,3),
          'imbue_capacity',pair_imbue_capacity
        ) order by offense_rank
      )
      from one_ranked
      where offense_rank<=(select result_limit from params)
    ),'[]'::jsonb),
    'defense_options',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'weapon',jsonb_build_object(
            'item_key',item_key,'name',name,'category',category,
            'weapon_type',weapon_type,
            'effective_attack_proxy',round(effective_attack_proxy,2),
            'base_weapon_skill_bonus',weapon_skill_bonus,'imbue_slots',imbue_slots
          ),
          'off_hand',jsonb_build_object(
            'item_key',offhand_item_key,'name',offhand_name,
            'category',offhand_category,'defense',offhand_defense,
            'matching_weapon_skill_bonus',offhand_matching_skill_bonus,
            'shielding_bonus',shielding_bonus,'imbue_slots',offhand_imbue_slots
          ),
          'matching_weapon_skill_bonus',matching_weapon_skill_bonus,
          'weighted_protection',round(pair_weighted_protection,3),
          'imbue_capacity',pair_imbue_capacity
        ) order by defense_rank
      )
      from one_ranked
      where defense_rank<=(select result_limit from params)
    ),'[]'::jsonb)
  ),
  'two_handed',jsonb_build_object(
    'offense_options',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'item_key',item_key,'name',name,'category',category,
          'weapon_type',weapon_type,'attack',attack,'defense',defense,
          'effective_attack_proxy',round(effective_attack_proxy,2),
          'weapon_skill_bonus',weapon_skill_bonus,
          'weighted_protection',round(weighted_protection,3),
          'imbue_capacity',imbue_slots,'components',components
        ) order by offense_rank
      )
      from two_ranked
      where offense_rank<=(select result_limit from params)
    ),'[]'::jsonb),
    'defense_options',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'item_key',item_key,'name',name,'category',category,
          'weapon_type',weapon_type,
          'effective_attack_proxy',round(effective_attack_proxy,2),
          'weapon_skill_bonus',weapon_skill_bonus,
          'weighted_protection',round(weighted_protection,3),
          'imbue_capacity',imbue_slots
        ) order by defense_rank
      )
      from two_ranked
      where defense_rank<=(select result_limit from params)
    ),'[]'::jsonb)
  ),
  'excluded_from_sustained_hunt',coalesce((
    select jsonb_agg(
      jsonb_build_object('item_key',item_key,'name',name,'reason',reason)
      order by name
    ) from excluded
  ),'[]'::jsonb),
  'comparison',jsonb_build_object(
    'resolved_configuration',(select configuration from resolved),
    'resolution_rule','Pareto dominance only across attack proxy, matching weapon skill bonus, observed-damage-weighted protection and imbue capacity.',
    'best_offense_delta_two_minus_one',(
      select jsonb_build_object(
        'effective_attack_proxy',round(bt.effective_attack_proxy-bo.effective_attack_proxy,2),
        'matching_weapon_skill_bonus',bt.weapon_skill_bonus-bo.matching_weapon_skill_bonus,
        'weighted_protection',round(bt.weighted_protection-bo.pair_weighted_protection,3),
        'imbue_capacity',bt.imbue_slots-bo.pair_imbue_capacity
      )
      from best_one bo cross join best_two bt
    )
  ),
  'methodology',jsonb_build_object(
    'stage','ek_hand_options_v2',
    'final_choice',false,
    'combined_numeric_score',false,
    'uses_elemental_attack_proxy',true,
    'offhand_skill_matches_weapon_type',true,
    'shielding_separate_from_offense',true,
    'sustained_hunt_viability_guard',true
  )
);
$function$
;

revoke all on function huntnexus_ek_hand_options(text,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_ek_hand_options(text,int,int)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_item_imbuement_compatibility(p_item_key text, p_hunt_key text, p_vocation text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with item as (
  select i.id,i.slug as item_key,i.name,i.category,i.weapon_type,
         coalesce(huntnexus_first_int(i.imbue_slots),0) as imbue_slots
  from tibia_items i
  where i.slug=p_item_key
),
damage as (
  select element,sum(observed_damage)::numeric as observed_damage
  from vw_hunt_observed_incoming_damage
  where hunt_key=p_hunt_key
    and vocation=huntnexus_normalize_vocation(p_vocation)
  group by element
),
weights as (
  select element,
         observed_damage/nullif(sum(observed_damage) over (),0) as weight
  from damage
),
skill_keys as (
  select unnest(
    case huntnexus_normalize_vocation(p_vocation)
      when 'EK' then array['sword_fighting','axe_fighting','club_fighting','fist_fighting','shielding']
      when 'RP' then array['distance_fighting','magic_level','holy_magic_level']
      when 'ED' then array['magic_level','ice_magic_level','earth_magic_level','healing_magic_level']
      when 'MS' then array['magic_level','fire_magic_level','energy_magic_level','death_magic_level']
      when 'EM' then array['magic_level','fist_fighting']
      else array[]::text[]
    end
  ) as effect_key
),
compatible as (
  select d.*,
         coalesce(w.weight,0) as observed_damage_weight,
         coalesce(w.weight,0) * d.powerful_value as weighted_protection_priority
  from imbuement_definitions d
  cross join item i
  left join weights w on w.element=d.effect_key
  where d.applicable_categories ? i.category
)
select coalesce((
  select jsonb_build_object(
    'item_key',i.item_key,
    'name',i.name,
    'category',i.category,
    'weapon_type',i.weapon_type,
    'imbue_slots',i.imbue_slots,
    'protection_candidates',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'imbuement_key',c.imbuement_key,'name',c.name,
          'element',c.effect_key,'powerful_value',c.powerful_value,'unit',c.unit,
          'observed_damage_weight',round(c.observed_damage_weight,4),
          'weighted_protection_priority',round(c.weighted_protection_priority,3)
        )
        order by c.weighted_protection_priority desc,c.name
      )
      from compatible c
      where c.category='protection' and c.observed_damage_weight>0
    ),'[]'::jsonb),
    'skill_candidates',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'imbuement_key',c.imbuement_key,'name',c.name,
          'effect_key',c.effect_key,'powerful_value',c.powerful_value,'unit',c.unit
        ) order by c.name
      )
      from compatible c
      where c.category='skill'
        and c.effect_key in (select effect_key from skill_keys)
    ),'[]'::jsonb),
    'core_offense_sustain_candidates',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'imbuement_key',c.imbuement_key,'name',c.name,'category',c.category,
          'effect_key',c.effect_key,'powerful_value',c.powerful_value,'unit',c.unit,
          'proc_chance_percent',c.proc_chance_percent
        ) order by c.category,c.name
      )
      from compatible c
      where c.imbuement_key in ('strike','vampirism','void')
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','item_imbuement_compatibility_v1',
      'final_assignment',false,
      'capacity_enforced_at_item_level',true,
      'cross_type_priority_inferred',false
    )
  )
  from item i
),jsonb_build_object('item_key',p_item_key,'imbue_slots',0,'error','item_not_found'));
$function$
;

revoke all on function huntnexus_item_imbuement_compatibility(text,text,text)
  from public,anon,authenticated;
grant execute on function huntnexus_item_imbuement_compatibility(text,text,text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_loadout_imbuement_preview(p_hunt_key text, p_vocation text, p_selected_slots jsonb, p_hand_options jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_fixed jsonb := '{}'::jsonb;
  v_slot text;
  v_item jsonb;
  v_one_main_key text := p_hand_options #>> '{one_handed,main_hand,item_key}';
  v_one_off_key text := p_hand_options #>> '{one_handed,off_hand,item_key}';
  v_two_key text := p_hand_options #>> '{two_handed,item,item_key}';
begin
  for v_slot,v_item in
    select key,value from jsonb_each(coalesce(p_selected_slots,'{}'::jsonb))
    order by key
  loop
    if v_item->>'item_key' is not null then
      v_fixed := v_fixed || jsonb_build_object(
        v_slot,
        huntnexus_item_imbuement_compatibility(v_item->>'item_key',p_hunt_key,p_vocation)
      );
    end if;
  end loop;

  return jsonb_build_object(
    'fixed_slots',v_fixed,
    'hand_options',jsonb_build_object(
      'one_handed',jsonb_build_object(
        'main_hand',
          case when v_one_main_key is not null
            then huntnexus_item_imbuement_compatibility(v_one_main_key,p_hunt_key,p_vocation)
            else null end,
        'off_hand',
          case when v_one_off_key is not null
            then huntnexus_item_imbuement_compatibility(v_one_off_key,p_hunt_key,p_vocation)
            else null end
      ),
      'two_handed',
        case when v_two_key is not null
          then huntnexus_item_imbuement_compatibility(v_two_key,p_hunt_key,p_vocation)
          else null end
    ),
    'methodology',jsonb_build_object(
      'stage','loadout_imbuement_compatibility_v1',
      'final_assignment',false,
      'item_slot_capacity_exposed',true,
      'defensive_priority_uses_observed_incoming_damage',true,
      'cross_type_priority_inferred',false
    )
  );
end;
$function$
;

revoke all on function huntnexus_loadout_imbuement_preview(text,text,jsonb,jsonb)
  from public,anon,authenticated;
grant execute on function huntnexus_loadout_imbuement_preview(text,text,jsonb,jsonb)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_loadout_set_preview(p_hunt_key text, p_vocation text, p_level integer, p_objective text DEFAULT 'balanced'::text, p_per_dimension integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_objective text := lower(coalesce(p_objective,'balanced'));
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
  v_matrix jsonb;
  v_slots jsonb;
  v_selected jsonb := '{}'::jsonb;
  v_key text;
  v_items jsonb;
  v_pick jsonb;
  v_two jsonb;
  v_main jsonb;
  v_off jsonb;
  v_one_available boolean;
  v_two_available boolean;
  v_hand_choice text;
  v_ek_hands jsonb;
  v_hand_options jsonb;
begin
  if v_objective not in ('xp','profit','balanced') then
    v_objective := 'balanced';
  end if;

  v_matrix := huntnexus_loadout_candidate_matrix(
    p_hunt_key,p_vocation,p_level,greatest(3,least(coalesce(p_per_dimension,5),10))
  );
  v_slots := coalesce(v_matrix->'slots','{}'::jsonb);

  for v_key,v_items in
    select key,value
    from jsonb_each(v_slots)
    where key not in ('Weapon Hand','Both Hands','Shield Hand')
    order by key
  loop
    v_pick := huntnexus_pick_loadout_candidate(v_items,v_objective);
    if v_pick is not null then
      v_selected := v_selected || jsonb_build_object(v_key,v_pick);
    end if;
  end loop;

  if v_vocation='EK' then
    v_ek_hands := huntnexus_ek_hand_options(p_hunt_key,p_level,p_per_dimension);
    v_hand_choice := v_ek_hands #>> '{comparison,resolved_configuration}';
    v_main := v_ek_hands #> '{one_handed,offense_options,0,weapon}';
    v_off := v_ek_hands #> '{one_handed,offense_options,0,off_hand}';
    v_two := v_ek_hands #> '{two_handed,offense_options,0}';
    v_one_available := v_main is not null;
    v_two_available := v_two is not null;
  else
    v_two := huntnexus_pick_loadout_candidate(v_slots->'Both Hands',v_objective);
    v_main := huntnexus_pick_loadout_candidate(v_slots->'Weapon Hand',v_objective);
    v_off := huntnexus_pick_loadout_candidate(v_slots->'Shield Hand',v_objective);
    v_two_available := v_two is not null;
    v_one_available := v_main is not null;
    if v_two_available and not v_one_available then
      v_hand_choice := 'two_handed';
    elsif v_one_available and not v_two_available then
      v_hand_choice := 'one_handed';
    else
      v_hand_choice := null;
    end if;
  end if;

  v_hand_options := jsonb_build_object(
    'one_handed',jsonb_build_object(
      'available',v_one_available,
      'main_hand',v_main,
      'off_hand',v_off,
      'off_hand_available',v_off is not null
    ),
    'two_handed',jsonb_build_object(
      'available',v_two_available,
      'item',v_two
    )
  );

  return jsonb_build_object(
    'query',jsonb_build_object(
      'hunt_key',p_hunt_key,'vocation',v_vocation,
      'level',greatest(coalesce(p_level,1),1),'objective',v_objective
    ),
    'selected_slots',v_selected,
    'hand_options',v_hand_options,
    'hand_analysis',v_ek_hands,
    'recommended_hand_configuration',v_hand_choice,
    'imbuement_preview',
      huntnexus_loadout_imbuement_preview(
        p_hunt_key,v_vocation,v_selected,v_hand_options
      ),
    'incoming_damage',coalesce(v_matrix->'incoming_damage','[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','loadout_set_preview_v3',
      'final_set',false,
      'combined_numeric_score',false,
      'ek_hand_model_applied',v_vocation='EK',
      'sustained_hunt_viability_guard',v_vocation='EK',
      'imbuement_compatibility_preview_applied',true,
      'hand_configuration_resolved',v_hand_choice is not null,
      'known_gaps',jsonb_build_array(
        'item price and market-aware cost',
        'current player inventory/equipment',
        'final cross-type imbuement priority',
        'non-EK vocation-specific hand tradeoff models',
        'RubinOT exact item overrides'
      )
    )
  );
end;
$function$
;

revoke all on function huntnexus_loadout_set_preview(text,text,int,text,int)
  from public,anon,authenticated;
grant execute on function huntnexus_loadout_set_preview(text,text,int,text,int)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_recommendation_preview(p_vocation text, p_level integer, p_objective text DEFAULT 'balanced'::text, p_party_size integer DEFAULT 1, p_limit integer DEFAULT 5, p_defensive_items_per_slot integer DEFAULT 3)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions', 'net'
AS $function$
declare
  v_rank jsonb;
  v_result jsonb := '[]'::jsonb;
  v_row jsonb;
  v_hunt_key text;
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
begin
  v_rank := huntnexus_rank_observed_hunts(
    p_vocation,p_level,p_objective,p_party_size,p_limit
  );

  for v_row in
    select value from jsonb_array_elements(coalesce(v_rank->'results','[]'::jsonb))
  loop
    v_hunt_key := v_row->>'hunt_key';
    v_result := v_result || jsonb_build_array(
      jsonb_build_object(
        'ranking',v_row,
        'factual_profile',huntnexus_hunt_factual_profile(v_hunt_key),
        'observed_profile',huntnexus_hunt_observed_profile(v_hunt_key),
        'defensive_candidates',
          huntnexus_defensive_item_candidates(
            v_hunt_key,p_vocation,p_level,p_defensive_items_per_slot
          ),
        'offensive_stat_candidates',
          huntnexus_offensive_stat_candidates(v_hunt_key,p_vocation,p_level,20),
        'ek_weapon_candidates',
          case when v_vocation='EK'
            then huntnexus_ek_weapon_candidates(v_hunt_key,p_level,5)
            else null end,
        'imbuement_candidates',huntnexus_imbuement_candidates(v_hunt_key,p_vocation),
        'spell_candidates',huntnexus_spell_candidates(v_hunt_key,p_vocation,p_level,'hunt'),
        'loadout_candidate_matrix',
          huntnexus_loadout_candidate_matrix(
            v_hunt_key,p_vocation,p_level,p_defensive_items_per_slot
          ),
        'loadout_set_preview',
          huntnexus_loadout_set_preview(
            v_hunt_key,p_vocation,p_level,p_objective,
            greatest(5,p_defensive_items_per_slot)
          )
      )
    );
  end loop;

  return jsonb_build_object(
    'query',v_rank->'query',
    'results',v_result,
    'methodology',jsonb_build_object(
      'stage','recommendation_preview_v7',
      'final_recommendation',false,
      'spell_layer_applied',true,
      'loadout_matrix_applied',true,
      'loadout_set_preview_applied',true,
      'ek_hand_tradeoff_applied',v_vocation='EK',
      'sustained_hunt_viability_guard_applied',v_vocation='EK',
      'imbuement_compatibility_preview_applied',true,
      'final_set_optimizer_applied',false,
      'boss_mechanics_applied',false
    )
  );
end;
$function$
;

revoke all on function huntnexus_recommendation_preview(text,int,text,int,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_recommendation_preview(text,int,text,int,int,int)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_api_health()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions', 'net'
AS $function$
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
      order by released_on desc,version_label desc limit 1
    ),
    'latest_rubinot_client',(
      select version_label from game_versions
      where scope='rubinot_client'
      order by released_on desc,version_label desc limit 1
    )
  ),
  'recommendation_stage','preview_v7',
  'final_recommendation_ready',false
);
$function$
;

revoke all on function huntnexus_api_health()
  from public,anon,authenticated;
grant execute on function huntnexus_api_health()
  to service_role;
