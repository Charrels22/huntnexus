-- HuntNexus character-aware recommendation contract.
-- Prefer effective client-displayed combat values to avoid double-counting RubinOT modifiers.

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
  'stage','character_combat_profile_contract_v1',
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
        'values',jsonb_build_array('sword','axe','club','fist'),
        'meaning','Weapon family actually trained/used by the character.'
      ),
      'effective_weapon_skill',jsonb_build_object(
        'required_for_precise_damage_comparison',true,
        'type','integer',
        'meaning','Effective displayed skill for the selected weapon family.'
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

revoke all on function huntnexus_character_combat_profile_contract(text)
  from public,anon,authenticated;
grant execute on function huntnexus_character_combat_profile_contract(text)
  to service_role;
