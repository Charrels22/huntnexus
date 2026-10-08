-- HuntNexus — expose Tier C community imbuement usage as context only.
-- Community usage must never alter factual imbuement priority.

CREATE OR REPLACE FUNCTION public.huntnexus_imbuement_candidates(p_hunt_key text, p_vocation text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions', 'net'
AS $function$
with damage as (
  select
    element,
    sum(observed_damage) as observed_damage
  from vw_hunt_observed_incoming_damage
  where hunt_key=p_hunt_key
    and vocation=huntnexus_normalize_vocation(p_vocation)
  group by element
),
weights as (
  select
    element,
    observed_damage,
    observed_damage::numeric/nullif(sum(observed_damage) over (),0) as weight
  from damage
),
defense as (
  select
    d.imbuement_key,d.name,d.effect_key,d.powerful_value,d.unit,
    w.observed_damage,w.weight,
    w.weight*d.powerful_value as weighted_protection_priority,
    d.applicable_categories
  from imbuement_definitions d
  join weights w on w.element=d.effect_key
  where d.category='protection'
),
wanted_skills as (
  select unnest(
    case huntnexus_normalize_vocation(p_vocation)
      when 'EK' then array['sword_fighting','axe_fighting','club_fighting','shielding']
      when 'RP' then array['distance_fighting']
      when 'ED' then array['magic_level']
      when 'MS' then array['magic_level']
      when 'EM' then array['magic_level']
      else array[]::text[]
    end
  ) as effect_key
),
skills as (
  select d.*
  from imbuement_definitions d
  where d.category='skill'
    and d.effect_key in (select effect_key from wanted_skills)
),
core as (
  select d.*
  from imbuement_definitions d
  where d.imbuement_key in ('strike','vampirism','void')
),
observed_usage as (
  select
    imbuement_key,
    imbuement_name,
    eligible_profiles,
    observed_profiles,
    observed_instances,
    observed_profile_share,
    avg_instances_when_observed
  from vw_hunt_observed_imbuement_usage
  where hunt_key=p_hunt_key
    and vocation=huntnexus_normalize_vocation(p_vocation)
)
select jsonb_build_object(
  'hunt_key',p_hunt_key,
  'vocation',huntnexus_normalize_vocation(p_vocation),
  'defensive_priority',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'imbuement_key',imbuement_key,
        'name',name,
        'element',effect_key,
        'powerful_value',powerful_value,
        'unit',unit,
        'observed_damage_weight',round(weight,4),
        'weighted_protection_priority',round(weighted_protection_priority,3),
        'applicable_categories',applicable_categories
      )
      order by weighted_protection_priority desc
    )
    from defense
  ),'[]'::jsonb),
  'vocation_skill_candidates',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'imbuement_key',imbuement_key,
        'name',name,
        'effect_key',effect_key,
        'powerful_value',powerful_value,
        'unit',unit,
        'applicable_categories',applicable_categories
      )
      order by name
    )
    from skills
  ),'[]'::jsonb),
  'core_offense_sustain',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'imbuement_key',imbuement_key,
        'name',name,
        'category',category,
        'effect_key',effect_key,
        'powerful_value',powerful_value,
        'unit',unit,
        'proc_chance_percent',proc_chance_percent,
        'applicable_categories',applicable_categories
      )
      order by category,name
    )
    from core
  ),'[]'::jsonb),
  'community_observed_usage',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'imbuement_key',imbuement_key,
        'name',imbuement_name,
        'eligible_profiles',eligible_profiles,
        'observed_profiles',observed_profiles,
        'observed_instances',observed_instances,
        'observed_profile_share',observed_profile_share,
        'avg_instances_when_observed',avg_instances_when_observed,
        'evidence_tier','C',
        'affects_priority',false
      )
      order by observed_profile_share desc,observed_instances desc,imbuement_name
    )
    from observed_usage
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','imbuement_candidates_v2',
    'final_assignment_to_items',false,
    'defensive_priority_is_data_driven',true,
    'offense_sustain_priority_is_not_inferred',true,
    'community_observed_usage_is_tier_c',true,
    'community_observed_usage_affects_priority',false,
    'note','Elemental protection is ordered by observed incoming damage. Strike, leech and skill boosts remain separate factual candidates. Community usage is exposed as Tier C context and does not alter priority.'
  )
);
$function$
;

revoke all on function public.huntnexus_imbuement_candidates(text,text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_imbuement_candidates(text,text)
  to service_role;
