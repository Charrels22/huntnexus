-- HuntNexus — universal factual weapon eligibility.
-- No combat score, optimizer weighting or vocation-specific ranking is applied.

CREATE OR REPLACE FUNCTION public.huntnexus_weapon_candidates_universal(p_vocation text, p_level integer, p_weapon_class text DEFAULT NULL::text, p_weapon_family text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with params as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    lower(nullif(trim(p_weapon_class),'')) as weapon_class_filter,
    lower(nullif(trim(p_weapon_family),'')) as weapon_family_filter,
    least(greatest(coalesce(p_limit,100),1),250) as limit_value
),
mapped as (
  select *,
    case vocation_code
      when 'EK' then 'knight'
      when 'RP' then 'paladin'
      when 'ED' then 'druid'
      when 'MS' then 'sorcerer'
      when 'EM' then 'monk'
      else null
    end as vocation_key
  from params
),
evaluated as (
  select
    w.*,
    p.vocation_code,
    p.vocation_key,
    p.level_value,
    (w.level_required is not null and w.level_required > p.level_value) as blocked_by_level,
    (
      w.vocation_scope='explicit'
      and p.vocation_key is not null
      and not (p.vocation_key = any(w.vocation_keys))
    ) as blocked_by_vocation,
    (w.level_required is null) as missing_level_requirement,
    (w.vocation_scope='unknown') as missing_vocation_restriction,
    (w.hands is null) as missing_hands,
    (p.vocation_key is null) as unsupported_vocation_input
  from vw_weapon_catalog_universal w
  cross join mapped p
  where (p.weapon_class_filter is null or w.weapon_class=p.weapon_class_filter)
    and (p.weapon_family_filter is null or w.weapon_family=p.weapon_family_filter)
),
classified as (
  select *,
    case
      when unsupported_vocation_input then 'invalid_input'
      when blocked_by_level or blocked_by_vocation then 'blocked'
      when missing_level_requirement or missing_vocation_restriction then 'incomplete'
      else 'eligible'
    end as eligibility_status,
    array_remove(array[
      case when blocked_by_level then 'level_requirement' end,
      case when blocked_by_vocation then 'vocation_restriction' end
    ],null) as blocking_reasons,
    array_remove(array[
      case when missing_level_requirement then 'level_requirement_missing' end,
      case when missing_vocation_restriction then 'vocation_restriction_unknown' end,
      case when missing_hands then 'hands_unknown' end
    ],null) as completeness_flags
  from evaluated
),
limited as (
  select *
  from classified
  order by
    case eligibility_status
      when 'eligible' then 0
      when 'incomplete' then 1
      when 'blocked' then 2
      else 3
    end,
    level_required desc nulls last,
    name,
    item_key
  limit (select limit_value from mapped)
)
select case
  when (select vocation_key from mapped) is null then
    jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'supported_vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
      'methodology',jsonb_build_object(
        'stage','weapon_candidates_universal_v1',
        'combat_score_applied',false
      )
    )
  else jsonb_build_object(
    'query',jsonb_strip_nulls(jsonb_build_object(
      'vocation',(select vocation_code from mapped),
      'vocation_key',(select vocation_key from mapped),
      'level',(select level_value from mapped),
      'weapon_class',(select weapon_class_filter from mapped),
      'weapon_family',(select weapon_family_filter from mapped),
      'limit',(select limit_value from mapped)
    )),
    'summary',jsonb_build_object(
      'matching_catalog_items',(select count(*) from classified),
      'eligible',(select count(*) from classified where eligibility_status='eligible'),
      'incomplete',(select count(*) from classified where eligibility_status='incomplete'),
      'blocked',(select count(*) from classified where eligibility_status='blocked'),
      'returned',(select count(*) from limited)
    ),
    'items',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'item_key',item_key,
          'name',name,
          'weapon_class',weapon_class,
          'weapon_family',weapon_family,
          'primary_skill_key',primary_skill_key,
          'hands',hands,
          'hands_basis',hands_basis,
          'level_required',level_required,
          'vocation_scope',vocation_scope,
          'vocation_keys',to_jsonb(vocation_keys),
          'eligibility_status',eligibility_status,
          'blocking_reasons',to_jsonb(blocking_reasons),
          'completeness_flags',to_jsonb(completeness_flags),
          'base_attack',base_attack,
          'defense',defense,
          'defense_mod',defense_mod,
          'range_value',range_value,
          'imbue_slots',imbue_slots,
          'damage_type',damage_type,
          'attack_components',attack_components,
          'effects',effects,
          'proficiency_tree_available',proficiency_tree_available,
          'proficiency_perk_count',proficiency_perk_count,
          'wiki_url',wiki_url
        )
        order by
          case eligibility_status
            when 'eligible' then 0
            when 'incomplete' then 1
            when 'blocked' then 2
            else 3
          end,
          level_required desc nulls last,
          name,
          item_key
      )
      from limited
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','weapon_candidates_universal_v1',
      'category_first',true,
      'vocation_specific_optimizer_applied',false,
      'combat_score_applied',false,
      'eligibility_only',true,
      'unknown_restrictions_are_not_assumed_eligible',true,
      'blocked_precedes_incomplete',true
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_weapon_candidates_universal(text,integer,text,text,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_weapon_candidates_universal(text,integer,text,text,integer)
  to service_role;
