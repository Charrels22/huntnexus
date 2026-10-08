-- HuntNexus — correct profiled EK skill semantics.
-- Client-displayed effective skill is observed context and candidate item skill
-- bonuses are compared separately instead of being added again.

CREATE OR REPLACE FUNCTION public.huntnexus_character_combat_profile_contract(p_vocation text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with v as (
  select huntnexus_normalize_vocation(p_vocation) as vocation
)
select jsonb_build_object(
  'stage','character_combat_profile_contract_v2',
  'vocation',(select vocation from v),
  'input_principle','Prefer effective values displayed by the RubinOT client. Do not separately add Loyalty, Guild Ascension, VIP or Weapon Proficiency bonuses when they are already reflected in the supplied effective stat.',
  'common',jsonb_build_object(
    'critical_chance_percent',jsonb_build_object(
      'required',false,
      'type','number',
      'meaning','Effective total critical chance used by the character.'
    ),
    'life_leech_percent',jsonb_build_object(
      'required',false,
      'type','number',
      'meaning','Effective total life leech percentage.'
    ),
    'mana_leech_percent',jsonb_build_object(
      'required',false,
      'type','number',
      'meaning','Effective total mana leech percentage.'
    ),
    'elemental_damage_bonus_percent',jsonb_build_object(
      'required',false,
      'type','object_by_element',
      'elements',jsonb_build_array('physical','fire','ice','earth','energy','death','holy'),
      'meaning','Effective additional damage percentage by element.'
    ),
    'elemental_defense_bonus_percent',jsonb_build_object(
      'required',false,
      'type','object_by_element',
      'elements',jsonb_build_array('physical','fire','ice','earth','energy','death','holy'),
      'meaning','Effective additional defense percentage by element.'
    ),
    'race_damage_bonus_percent',jsonb_build_object(
      'required',false,
      'type','object_by_race',
      'meaning','Effective Guild Ascension or other race-specific damage bonuses.'
    ),
    'vip_active',jsonb_build_object(
      'required',false,
      'type','boolean',
      'meaning','Used for consumption/economy behavior such as protected imbuements in protection zones, not for silently adding combat stats.'
    )
  ),
  'vocation_specific',
  case (select vocation from v)
    when 'EK' then jsonb_build_object(
      'weapon_family',jsonb_build_object(
        'required_for_precise_hand_comparison',true,
        'type','enum',
        'values',jsonb_build_array('sword','axe','club'),
        'meaning','Knight weapon family actually trained/used by the character.'
      ),
      'effective_weapon_skill',jsonb_build_object(
        'required_for_precise_damage_comparison',true,
        'type','integer',
        'meaning','Effective displayed skill for the selected weapon family. It is treated as observed context and is not incremented again by candidate item or proficiency skill bonuses.'
      ),
      'effective_magic_level',jsonb_build_object(
        'required',false,
        'type','integer',
        'meaning','Effective displayed Magic Level, used only for explicitly ML-derived preview terms.'
      ),
      'effective_shielding',jsonb_build_object(
        'required',false,
        'type','integer',
        'meaning','Effective displayed shielding skill.'
      )
    )
    when 'RP' then jsonb_build_object(
      'effective_distance_skill',jsonb_build_object(
        'required_for_precise_damage_comparison',true,
        'type','integer'
      ),
      'effective_magic_level',jsonb_build_object(
        'required',false,
        'type','integer'
      ),
      'effective_shielding',jsonb_build_object(
        'required',false,
        'type','integer'
      )
    )
    when 'ED' then jsonb_build_object(
      'effective_magic_level',jsonb_build_object(
        'required_for_precise_spell_comparison',true,
        'type','integer'
      )
    )
    when 'MS' then jsonb_build_object(
      'effective_magic_level',jsonb_build_object(
        'required_for_precise_spell_comparison',true,
        'type','integer'
      )
    )
    else '{}'::jsonb
  end,
  'known_rubinot_dynamic_sources',jsonb_build_array(
    'vip',
    'loyalty',
    'guild_ascension',
    'weapon_proficiency'
  ),
  'current_limitations',jsonb_build_array(
    'weapon_proficiency exact combat formula not yet reconciled',
    'seasonal Guild Ascension numeric perk values are not inferred',
    'current player equipment/inventory is not yet imported automatically'
  )
);
$function$
;

revoke all on function public.huntnexus_character_combat_profile_contract(text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_character_combat_profile_contract(text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_ek_hand_options_profiled(p_hunt_key text, p_level integer, p_character_profile jsonb, p_limit integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with params as (
  select
    greatest(coalesce(p_level,1),1) as player_level,
    greatest(1,least(coalesce(p_limit,5),10)) as result_limit,
    lower(nullif(trim(p_character_profile->>'weapon_family'),'')) as weapon_family,
    huntnexus_first_int(p_character_profile->>'effective_weapon_skill') as base_weapon_skill,
    huntnexus_first_int(p_character_profile->>'effective_shielding') as base_shielding
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
    huntnexus_ek_weapon_candidates_profiled(
      p_hunt_key,
      (select player_level from params),
      p_character_profile,
      25
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
    coalesce((
      select sum(dw.weight * ie.numeric_value)
      from item_effects ie
      join damage_weights dw on dw.element=ie.effect_key
      where ie.item_id=i.id
        and ie.effect_type='protection'
        and ie.unit='percent'
    ),0) as weighted_protection,
    case (select weapon_family from params)
      when 'sword' then 'sword_fighting'
      when 'axe' then 'axe_fighting'
      when 'club' then 'club_fighting'
      else null
    end as skill_key
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
    (select base_weapon_skill from params) as displayed_effective_weapon_skill,
    case
      when (select base_shielding from params) is not null then
        (select base_shielding from params) + o.shielding_bonus
      else null
    end as effective_shielding_with_offhand,
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
  select
    w.*,
    (select base_weapon_skill from params) as displayed_effective_weapon_skill,
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
  from weapons w
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
  'character_profile',jsonb_strip_nulls(jsonb_build_object(
    'weapon_family',(select weapon_family from params),
    'effective_weapon_skill',(select base_weapon_skill from params),
    'effective_shielding',(select base_shielding from params)
  )),
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
          'profile_effective_weapon_skill',(select base_weapon_skill from params),
          'displayed_effective_weapon_skill',displayed_effective_weapon_skill,
          'profile_effective_shielding',(select base_shielding from params),
          'effective_shielding_with_offhand',effective_shielding_with_offhand,
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
          'profile_effective_weapon_skill',(select base_weapon_skill from params),
          'displayed_effective_weapon_skill',displayed_effective_weapon_skill,
          'profile_effective_shielding',(select base_shielding from params),
          'effective_shielding_with_offhand',effective_shielding_with_offhand,
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
          'profile_effective_weapon_skill',(select base_weapon_skill from params),
          'displayed_effective_weapon_skill',displayed_effective_weapon_skill,
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
          'profile_effective_weapon_skill',(select base_weapon_skill from params),
          'displayed_effective_weapon_skill',displayed_effective_weapon_skill,
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
    'resolution_rule','Pareto dominance within the selected character weapon family only. Effective skill is contextual and is not converted to final DPS.',
    'best_offense_delta_two_minus_one',(
      select jsonb_build_object(
        'effective_attack_proxy',round(bt.effective_attack_proxy-bo.effective_attack_proxy,2),
        'matching_weapon_skill_bonus',bt.weapon_skill_bonus-bo.matching_weapon_skill_bonus,
        'candidate_item_skill_bonus',bt.weapon_skill_bonus-bo.matching_weapon_skill_bonus,
        'displayed_effective_weapon_skill',
          case
            when (select base_weapon_skill from params) is not null then 0
            else null
          end,
        'weighted_protection',round(bt.weighted_protection-bo.pair_weighted_protection,3),
        'imbue_capacity',bt.imbue_slots-bo.pair_imbue_capacity
      )
      from best_one bo cross join best_two bt
    )
  ),
  'methodology',jsonb_build_object(
    'stage','ek_hand_options_profiled_v2',
    'base_stage','ek_hand_options_v2',
    'character_profile_applied',true,
    'weapon_family_filter_applied',true,
    'effective_skill_context_applied',(select base_weapon_skill is not null from params),
    'effective_shielding_context_applied',(select base_shielding is not null from params),
    'final_damage_formula_applied',false,
    'displayed_skill_recalculated_with_candidate_items',false,
    'candidate_item_skill_bonus_compared_separately',true,
    'sustained_hunt_viability_guard',true
  )
);
$function$
;

revoke all on function public.huntnexus_ek_hand_options_profiled(text,int,jsonb,int)
  from public,anon,authenticated;
grant execute on function public.huntnexus_ek_hand_options_profiled(text,int,jsonb,int)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_loadout_set_preview_profiled(p_hunt_key text, p_vocation text, p_level integer, p_objective text, p_per_dimension integer, p_character_profile jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_base jsonb;
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
  v_family text := lower(nullif(trim(p_character_profile->>'weapon_family'),''));
  v_hands jsonb;
  v_main jsonb;
  v_off jsonb;
  v_two jsonb;
  v_hand_options jsonb;
  v_hand_choice text;
  v_profile jsonb;
begin
  v_base := huntnexus_loadout_set_preview(
    p_hunt_key,p_vocation,p_level,p_objective,p_per_dimension
  );

  v_profile := jsonb_strip_nulls(jsonb_build_object(
    'weapon_family',v_family,
    'effective_weapon_skill',huntnexus_first_int(p_character_profile->>'effective_weapon_skill'),
    'effective_magic_level',huntnexus_first_int(p_character_profile->>'effective_magic_level'),
    'effective_shielding',huntnexus_first_int(p_character_profile->>'effective_shielding'),
    'critical_chance_percent',p_character_profile->'critical_chance_percent',
    'life_leech_percent',p_character_profile->'life_leech_percent',
    'mana_leech_percent',p_character_profile->'mana_leech_percent',
    'elemental_damage_bonus_percent',p_character_profile->'elemental_damage_bonus_percent',
    'elemental_defense_bonus_percent',p_character_profile->'elemental_defense_bonus_percent',
    'race_damage_bonus_percent',p_character_profile->'race_damage_bonus_percent',
    'vip_active',p_character_profile->'vip_active'
  ));

  if v_vocation <> 'EK' or v_family not in ('sword','axe','club') then
    return v_base || jsonb_build_object(
      'character_profile',v_profile,
      'character_profile_analysis',jsonb_build_object(
        'stage','character_profile_application_v1',
        'applied',false,
        'reason',
          case when v_vocation <> 'EK'
            then 'vocation_specific_profiled_hand_model_not_implemented'
            else 'valid_weapon_family_required'
          end
      ),
      'methodology',
        coalesce(v_base->'methodology','{}'::jsonb)
        || jsonb_build_object(
          'profiled_stage','loadout_set_preview_profiled_v2',
          'character_profile_applied',false
        )
    );
  end if;

  v_hands := huntnexus_ek_hand_options_profiled(
    p_hunt_key,p_level,v_profile,p_per_dimension
  );
  v_hand_choice := v_hands #>> '{comparison,resolved_configuration}';
  v_main := v_hands #> '{one_handed,offense_options,0,weapon}';
  v_off := v_hands #> '{one_handed,offense_options,0,off_hand}';
  v_two := v_hands #> '{two_handed,offense_options,0}';

  v_hand_options := jsonb_build_object(
    'one_handed',jsonb_build_object(
      'available',v_main is not null,
      'main_hand',v_main,
      'off_hand',v_off,
      'off_hand_available',v_off is not null
    ),
    'two_handed',jsonb_build_object(
      'available',v_two is not null,
      'item',v_two
    )
  );

  return v_base || jsonb_build_object(
    'query',
      coalesce(v_base->'query','{}'::jsonb)
      || jsonb_build_object('character_profile',v_profile),
    'hand_options',v_hand_options,
    'hand_analysis',v_hands,
    'recommended_hand_configuration',v_hand_choice,
    'imbuement_preview',
      huntnexus_loadout_imbuement_preview(
        p_hunt_key,v_vocation,
        coalesce(v_base->'selected_slots','{}'::jsonb),
        v_hand_options
      ),
    'character_profile',v_profile,
    'character_profile_analysis',jsonb_build_object(
      'stage','character_profile_application_v1',
      'applied',true,
      'weapon_family',v_family,
      'effective_weapon_skill_supplied',
        huntnexus_first_int(p_character_profile->>'effective_weapon_skill') is not null,
      'effective_shielding_supplied',
        huntnexus_first_int(p_character_profile->>'effective_shielding') is not null,
      'final_damage_formula_applied',false,
      'note','The selected weapon family constrains EK weapon candidates. Client-displayed effective skill is context only and candidate item skill bonuses are compared separately to avoid double counting. Skill/shielding are not converted into final damage/mitigation.'
    ),
    'methodology',
      coalesce(v_base->'methodology','{}'::jsonb)
      || jsonb_build_object(
        'stage','loadout_set_preview_profiled_v2',
        'base_stage',v_base #>> '{methodology,stage}',
        'character_profile_applied',true,
        'weapon_family_filter_applied',true,
        'final_damage_formula_applied',false,
        'displayed_skill_recalculated_with_candidate_items',false
      )
  );
end;
$function$
;

revoke all on function public.huntnexus_loadout_set_preview_profiled(text,text,int,text,int,jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_loadout_set_preview_profiled(text,text,int,text,int,jsonb)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_recommendation_preview_profiled(p_vocation text, p_level integer, p_objective text DEFAULT 'balanced'::text, p_party_size integer DEFAULT 1, p_limit integer DEFAULT 5, p_defensive_items_per_slot integer DEFAULT 3, p_character_profile jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions', 'net'
AS $function$
declare
  v_base jsonb;
  v_result jsonb := '[]'::jsonb;
  v_row jsonb;
  v_hunt_key text;
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
  v_family text := lower(nullif(trim(p_character_profile->>'weapon_family'),''));
  v_applied boolean := v_vocation='EK' and v_family in ('sword','axe','club');
begin
  v_base := huntnexus_recommendation_preview(
    p_vocation,p_level,p_objective,p_party_size,p_limit,p_defensive_items_per_slot
  );

  for v_row in
    select value
    from jsonb_array_elements(coalesce(v_base->'results','[]'::jsonb))
  loop
    v_hunt_key := v_row #>> '{ranking,hunt_key}';

    if v_applied then
      v_row := v_row || jsonb_build_object(
        'ek_weapon_candidates',
          huntnexus_ek_weapon_candidates_profiled(
            v_hunt_key,p_level,p_character_profile,5
          ),
        'loadout_set_preview',
          huntnexus_loadout_set_preview_profiled(
            v_hunt_key,p_vocation,p_level,p_objective,
            greatest(5,p_defensive_items_per_slot),
            p_character_profile
          )
      );
    else
      v_row := v_row || jsonb_build_object(
        'loadout_set_preview',
          huntnexus_loadout_set_preview_profiled(
            v_hunt_key,p_vocation,p_level,p_objective,
            greatest(5,p_defensive_items_per_slot),
            p_character_profile
          )
      );
    end if;

    v_result := v_result || jsonb_build_array(v_row);
  end loop;

  return jsonb_build_object(
    'query',
      coalesce(v_base->'query','{}'::jsonb)
      || jsonb_build_object('character_profile',coalesce(p_character_profile,'{}'::jsonb)),
    'results',v_result,
    'methodology',
      coalesce(v_base->'methodology','{}'::jsonb)
      || jsonb_build_object(
        'stage','recommendation_preview_profiled_v2',
        'base_stage',v_base #>> '{methodology,stage}',
        'character_profile_applied',v_applied,
        'weapon_family_filter_applied',v_applied,
        'final_damage_formula_applied',false,
        'character_profile_contract_stage','character_combat_profile_contract_v2'
      )
  );
end;
$function$
;

revoke all on function public.huntnexus_recommendation_preview_profiled(text,int,text,int,int,int,jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_recommendation_preview_profiled(text,int,text,int,int,int,jsonb)
  to service_role;
