-- HuntNexus — explanatory Weapon Proficiency impact vectors.
-- No ranking, winner selection or DPS formula is applied.

CREATE OR REPLACE FUNCTION public.huntnexus_weapon_proficiency_impact_preview(p_item_key text, p_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_effective_weapon_skill integer DEFAULT NULL::integer, p_effective_magic_level integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with base as (
  select
    greatest(p_effective_weapon_skill,0) as effective_weapon_skill,
    greatest(p_effective_magic_level,0) as effective_magic_level
),
orders as (
  select distinct value::int as perk_order
  from jsonb_array_elements_text(
    case
      when jsonb_typeof(coalesce(p_active_perk_orders,'[]'::jsonb))='array'
        then coalesce(p_active_perk_orders,'[]'::jsonb)
      else '[]'::jsonb
    end
  )
  where value ~ '^[0-9]+$'
),
active as (
  select
    p.*,
    huntnexus_proficiency_effect_family(p.effect_key) as effect_family
  from weapon_proficiency_perks p
  join orders o on o.perk_order=p.perk_order
  where p.item_key=p_item_key
),
resolved as (
  select
    a.*,
    case
      when a.effect_key in (
        'skill_auto_attack_extra_damage_percent',
        'skill_spell_extra_damage_percent'
      ) then
        case when b.effective_weapon_skill is not null
          then round(b.effective_weapon_skill * a.numeric_value / 100.0,3)
        end
      when a.effect_key='magic_level_spell_extra_healing_percent' then
        case when b.effective_magic_level is not null
          then round(b.effective_magic_level * a.numeric_value / 100.0,3)
        end
      else null
    end as derived_stat_contribution,
    case
      when a.effect_key in (
        'skill_auto_attack_extra_damage_percent',
        'skill_spell_extra_damage_percent'
      ) then b.effective_weapon_skill is not null
      when a.effect_key='magic_level_spell_extra_healing_percent'
        then b.effective_magic_level is not null
      else true
    end as resolved_with_inputs,
    case
      when a.effect_key in (
        'skill_auto_attack_extra_damage_percent',
        'skill_spell_extra_damage_percent'
      ) and b.effective_weapon_skill is null
        then 'effective_weapon_skill'
      when a.effect_key='magic_level_spell_extra_healing_percent'
        and b.effective_magic_level is null
        then 'effective_magic_level'
      else null
    end as missing_input
  from active a
  cross join base b
),
aggregates as (
  select
    coalesce(sum(numeric_value) filter(
      where effect_family='skill_bonus' and scope='global'
    ),0) as skill_bonus,
    coalesce(sum(numeric_value) filter(
      where effect_family='attack' and scope='global'
    ),0) as attack_bonus,
    coalesce(sum(numeric_value) filter(
      where effect_family='critical_chance' and scope='global'
    ),0) as global_critical_chance,
    coalesce(sum(numeric_value) filter(
      where effect_family='critical_extra_damage' and scope='global'
    ),0) as global_critical_extra_damage,
    coalesce(sum(numeric_value) filter(
      where effect_family='life_leech' and scope='global'
    ),0) as global_life_leech,
    coalesce(sum(numeric_value) filter(
      where effect_family='mana_leech' and scope='global'
    ),0) as global_mana_leech,
    coalesce(sum(derived_stat_contribution) filter(
      where effect_key='skill_auto_attack_extra_damage_percent'
    ),0) as auto_attack_skill_derived_term,
    coalesce(sum(derived_stat_contribution) filter(
      where effect_key='skill_spell_extra_damage_percent'
    ),0) as spell_skill_derived_term,
    coalesce(sum(derived_stat_contribution) filter(
      where effect_key='magic_level_spell_extra_healing_percent'
    ),0) as healing_magic_level_derived_term
  from resolved
)
select jsonb_build_object(
  'item_key',p_item_key,
  'inputs',jsonb_strip_nulls(jsonb_build_object(
    'effective_weapon_skill',(select effective_weapon_skill from base),
    'effective_magic_level',(select effective_magic_level from base)
  )),
  'active_perk_orders',
    coalesce((select jsonb_agg(perk_order order by perk_order) from orders),'[]'::jsonb),
  'active_perk_count',(select count(*) from active),
  'resolved_effects',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'perk_order',perk_order,
        'effect_key',effect_key,
        'effect_family',effect_family,
        'scope',scope,
        'spell_key',spell_key,
        'source_stat_key',source_stat_key,
        'value',numeric_value,
        'unit',unit,
        'derived_stat_contribution',derived_stat_contribution,
        'resolved_with_inputs',resolved_with_inputs,
        'missing_input',missing_input,
        'description',description_raw
      )
      order by perk_order
    )
    from resolved
  ),'[]'::jsonb),
  'impact_vector',jsonb_build_object(
    'displayed_effective_weapon_skill',(select effective_weapon_skill from base),
    'flat_skill_bonus',(select skill_bonus from aggregates),
    'flat_skill_bonus_applied_to_displayed_skill',false,
    'flat_attack_bonus',(select attack_bonus from aggregates),
    'global_critical_chance_percent',(select global_critical_chance from aggregates),
    'global_critical_extra_damage_percent',(select global_critical_extra_damage from aggregates),
    'global_life_leech_percent',(select global_life_leech from aggregates),
    'global_mana_leech_percent',(select global_mana_leech from aggregates),
    'auto_attack_skill_derived_damage_term',(select auto_attack_skill_derived_term from aggregates),
    'spell_skill_derived_damage_term',(select spell_skill_derived_term from aggregates),
    'healing_magic_level_derived_term',
      case
        when (select effective_magic_level from base) is not null
        then (select healing_magic_level_derived_term from aggregates)
        else null
      end
  ),
  'unresolved_inputs',coalesce((
    select jsonb_agg(distinct missing_input)
    from resolved
    where missing_input is not null
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','weapon_proficiency_impact_preview_v1',
    'optimizer_effect_applied',false,
    'ranking_changed',false,
    'dps_calculated',false,
    'damage_formula_applied',false,
    'source_stat_terms_calculated',true,
    'displayed_effective_skill_may_already_include_proficiency',true,
    'note','The supplied effective skill is treated as the client-displayed total and is not incremented again by proficiency skill perks. It is used only as the source stat for explicit percentage terms. Derived terms are not final hit damage or DPS.'
  )
);
$function$
;

revoke all on function public.huntnexus_weapon_proficiency_impact_preview(text,jsonb,integer,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_weapon_proficiency_impact_preview(text,jsonb,integer,integer)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_ek_proficiency_impact_comparison(p_weapon_family text, p_one_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_two_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_effective_weapon_skill integer DEFAULT NULL::integer, p_effective_magic_level integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with pair as (
  select
    lower(trim(coalesce(p_weapon_family,''))) as weapon_family,
    case lower(trim(coalesce(p_weapon_family,'')))
      when 'sword' then 'grand-sanguine-blade'
      when 'axe' then 'grand-sanguine-hatchet'
      when 'club' then 'grand-sanguine-cudgel'
      else null
    end as one_hand_item_key,
    case lower(trim(coalesce(p_weapon_family,'')))
      when 'sword' then 'grand-sanguine-razor'
      when 'axe' then 'grand-sanguine-battleaxe'
      when 'club' then 'grand-sanguine-bludgeon'
      else null
    end as two_hand_item_key
)
select case
  when one_hand_item_key is null then
    jsonb_build_object(
      'weapon_family',weapon_family,
      'error','unsupported_ek_weapon_family',
      'methodology',jsonb_build_object(
        'stage','ek_weapon_proficiency_impact_comparison_v1',
        'optimizer_effect_applied',false
      )
    )
  else
    jsonb_build_object(
      'weapon_family',weapon_family,
      'one_handed',huntnexus_weapon_proficiency_impact_preview(
        one_hand_item_key,
        p_one_hand_active_perk_orders,
        p_effective_weapon_skill,
        p_effective_magic_level
      ),
      'two_handed',huntnexus_weapon_proficiency_impact_preview(
        two_hand_item_key,
        p_two_hand_active_perk_orders,
        p_effective_weapon_skill,
        p_effective_magic_level
      ),
      'methodology',jsonb_build_object(
        'stage','ek_weapon_proficiency_impact_comparison_v1',
        'optimizer_effect_applied',false,
        'ranking_changed',false,
        'hand_choice_changed',false,
        'dps_calculated',false,
        'note','Impact vectors are explanatory only. They do not select a winner.'
      )
    )
end
from pair;
$function$
;

revoke all on function public.huntnexus_ek_proficiency_impact_comparison(text,jsonb,jsonb,integer,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_ek_proficiency_impact_comparison(text,jsonb,jsonb,integer,integer)
  to service_role;
