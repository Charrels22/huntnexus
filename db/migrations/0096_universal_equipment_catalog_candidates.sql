-- HuntNexus — universal equipment catalog and factual eligibility.
-- Category-first infrastructure for armor/equipment slots. No combat score or ranking.

create or replace view public.vw_equipment_catalog_universal
with (security_invoker=true)
as
 WITH base AS (
         SELECT i.id,
            i.external_id,
            i.slug,
            i.name,
            i.category,
            i.primary_type,
            i.secondary_type,
            i.weapon_type,
            i.vocation,
            i.level_required,
            i.attack,
            i.defense,
            i.armor,
            i.damage_type,
            i.structured_data,
            i.source_id,
            i.snapshot_id,
            i.source_last_updated,
            i.observed_at,
            i.actual_name,
            i.object_class,
            i.hands,
            i.defense_mod,
            i.range_value,
            i.imbue_slots,
            i.damage_range,
            i.energy_attack,
            i.fire_attack,
            i.earth_attack,
            i.ice_attack,
            i.death_attack,
            i.holy_attack,
            i.npc_price,
            i.npc_value,
            i.item_value,
            i.weight,
            i.attrib,
            i.upgrade_class,
            i.wiki_url,
                CASE
                    WHEN i.category = 'Helmets'::text THEN 'head'::text
                    WHEN i.category = 'Armors'::text THEN 'body'::text
                    WHEN i.category = 'Legs'::text THEN 'legs'::text
                    WHEN i.category = 'Boots'::text THEN 'feet'::text
                    WHEN i.category = 'Shields'::text THEN 'offhand'::text
                    WHEN i.category = 'Amulets and Necklaces'::text THEN 'neck'::text
                    WHEN i.category = 'Rings'::text THEN 'ring'::text
                    WHEN i.category = 'Quivers'::text THEN 'offhand'::text
                    ELSE NULL::text
                END AS slot_key,
                CASE
                    WHEN i.category = 'Helmets'::text THEN 'helmet'::text
                    WHEN i.category = 'Armors'::text THEN 'armor'::text
                    WHEN i.category = 'Legs'::text THEN 'legs'::text
                    WHEN i.category = 'Boots'::text THEN 'boots'::text
                    WHEN i.category = 'Shields'::text AND i.primary_type = 'Spellbooks'::text THEN 'spellbook'::text
                    WHEN i.category = 'Shields'::text THEN 'shield'::text
                    WHEN i.category = 'Amulets and Necklaces'::text THEN 'amulet_necklace'::text
                    WHEN i.category = 'Rings'::text THEN 'ring'::text
                    WHEN i.category = 'Quivers'::text THEN 'quiver'::text
                    ELSE NULL::text
                END AS equipment_family
           FROM tibia_items i
          WHERE (i.category = ANY (ARRAY['Helmets'::text, 'Armors'::text, 'Legs'::text, 'Boots'::text, 'Shields'::text, 'Amulets and Necklaces'::text, 'Rings'::text, 'Quivers'::text])) AND (i.slug <> ALL (ARRAY['helmets'::text, 'armors'::text, 'legs'::text, 'boots'::text, 'shields'::text, 'rings'::text, 'spellbooks'::text, 'quivers'::text]))
        ), norm AS (
         SELECT b.id,
            b.external_id,
            b.slug,
            b.name,
            b.category,
            b.primary_type,
            b.secondary_type,
            b.weapon_type,
            b.vocation,
            b.level_required,
            b.attack,
            b.defense,
            b.armor,
            b.damage_type,
            b.structured_data,
            b.source_id,
            b.snapshot_id,
            b.source_last_updated,
            b.observed_at,
            b.actual_name,
            b.object_class,
            b.hands,
            b.defense_mod,
            b.range_value,
            b.imbue_slots,
            b.damage_range,
            b.energy_attack,
            b.fire_attack,
            b.earth_attack,
            b.ice_attack,
            b.death_attack,
            b.holy_attack,
            b.npc_price,
            b.npc_value,
            b.item_value,
            b.weight,
            b.attrib,
            b.upgrade_class,
            b.wiki_url,
            b.slot_key,
            b.equipment_family,
                CASE
                    WHEN b.vocation IS NULL THEN 'unrestricted'::text
                    WHEN lower(TRIM(BOTH FROM b.vocation)) = ANY (ARRAY['none'::text, 'without'::text, ''::text]) THEN 'unrestricted'::text
                    ELSE 'explicit'::text
                END AS vocation_scope,
                CASE
                    WHEN b.vocation IS NULL OR (lower(TRIM(BOTH FROM b.vocation)) = ANY (ARRAY['none'::text, 'without'::text, ''::text])) THEN ARRAY[]::text[]
                    ELSE array_remove(ARRAY[
                    CASE
                        WHEN lower(b.vocation) ~~ '%knight%'::text THEN 'knight'::text
                        ELSE NULL::text
                    END,
                    CASE
                        WHEN lower(b.vocation) ~~ '%paladin%'::text THEN 'paladin'::text
                        ELSE NULL::text
                    END,
                    CASE
                        WHEN lower(b.vocation) ~~ '%druid%'::text THEN 'druid'::text
                        ELSE NULL::text
                    END,
                    CASE
                        WHEN lower(b.vocation) ~~ '%sorcerer%'::text THEN 'sorcerer'::text
                        ELSE NULL::text
                    END,
                    CASE
                        WHEN lower(b.vocation) ~~ '%monk%'::text THEN 'monk'::text
                        ELSE NULL::text
                    END], NULL::text)
                END AS vocation_keys
           FROM base b
        )
 SELECT n.id AS item_id,
    n.slug AS item_key,
    n.name,
    n.category AS source_category,
    n.primary_type AS source_primary_type,
    n.secondary_type AS source_secondary_type,
    n.slot_key,
    n.equipment_family,
    n.vocation AS vocation_raw,
    n.vocation_scope,
    n.vocation_keys,
    COALESCE(huntnexus_first_int(n.level_required), 0) AS level_required,
    huntnexus_first_int(n.armor) AS armor,
    huntnexus_first_int(n.defense) AS defense,
    huntnexus_first_int(n.defense_mod) AS defense_mod,
    huntnexus_first_int(n.imbue_slots) AS imbue_slots,
    COALESCE(e.effects, '[]'::jsonb) AS effects,
        CASE
            WHEN huntnexus_first_int(n.armor) IS NOT NULL OR huntnexus_first_int(n.defense) IS NOT NULL OR huntnexus_first_int(n.defense_mod) IS NOT NULL OR huntnexus_first_int(n.imbue_slots) IS NOT NULL OR jsonb_array_length(COALESCE(e.effects, '[]'::jsonb)) > 0 OR n.vocation IS NOT NULL OR huntnexus_first_int(n.level_required) IS NOT NULL THEN 'combat_relevant'::text
            ELSE 'catalog_only'::text
        END AS combat_relevance,
    n.wiki_url,
    n.source_id,
    n.snapshot_id,
    n.source_last_updated,
    n.observed_at
   FROM norm n
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('effect_type', ie.effect_type, 'effect_key', ie.effect_key, 'value', ie.numeric_value, 'unit', ie.unit, 'raw_value', ie.raw_value) ORDER BY ie.effect_type, ie.effect_key) AS effects
           FROM item_effects ie
          WHERE ie.item_id = n.id) e ON true
  WHERE n.slot_key IS NOT NULL AND n.equipment_family IS NOT NULL;

revoke all on public.vw_equipment_catalog_universal from public,anon,authenticated;
grant select on public.vw_equipment_catalog_universal to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_equipment_candidates_universal(p_vocation text, p_level integer, p_slot_key text DEFAULT NULL::text, p_equipment_family text DEFAULT NULL::text, p_combat_only boolean DEFAULT true, p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with params as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    lower(nullif(trim(p_slot_key),'')) as slot_filter,
    lower(nullif(trim(p_equipment_family),'')) as family_filter,
    coalesce(p_combat_only,true) as combat_only,
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
    e.*,
    p.vocation_code,
    p.vocation_key,
    p.level_value,
    (e.level_required > p.level_value) as blocked_by_level,
    (
      e.vocation_scope='explicit'
      and p.vocation_key is not null
      and not (p.vocation_key = any(e.vocation_keys))
    ) as blocked_by_vocation,
    (p.vocation_key is null) as unsupported_vocation_input
  from vw_equipment_catalog_universal e
  cross join mapped p
  where (p.slot_filter is null or e.slot_key=p.slot_filter)
    and (p.family_filter is null or e.equipment_family=p.family_filter)
    and (not p.combat_only or e.combat_relevance='combat_relevant')
),
classified as (
  select *,
    case
      when unsupported_vocation_input then 'invalid_input'
      when blocked_by_level or blocked_by_vocation then 'blocked'
      else 'eligible'
    end as eligibility_status,
    array_remove(array[
      case when blocked_by_level then 'level_requirement' end,
      case when blocked_by_vocation then 'vocation_restriction' end
    ],null) as blocking_reasons
  from evaluated
),
limited as (
  select *
  from classified
  order by
    case eligibility_status when 'eligible' then 0 when 'blocked' then 1 else 2 end,
    level_required desc,
    coalesce(armor,defense,0) desc,
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
        'stage','equipment_candidates_universal_v1',
        'combat_score_applied',false
      )
    )
  else jsonb_build_object(
    'query',jsonb_strip_nulls(jsonb_build_object(
      'vocation',(select vocation_code from mapped),
      'vocation_key',(select vocation_key from mapped),
      'level',(select level_value from mapped),
      'slot_key',(select slot_filter from mapped),
      'equipment_family',(select family_filter from mapped),
      'combat_only',(select combat_only from mapped),
      'limit',(select limit_value from mapped)
    )),
    'summary',jsonb_build_object(
      'matching_catalog_items',(select count(*) from classified),
      'eligible',(select count(*) from classified where eligibility_status='eligible'),
      'blocked',(select count(*) from classified where eligibility_status='blocked'),
      'returned',(select count(*) from limited)
    ),
    'items',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'item_key',item_key,
          'name',name,
          'slot_key',slot_key,
          'equipment_family',equipment_family,
          'level_required',level_required,
          'vocation_scope',vocation_scope,
          'vocation_keys',to_jsonb(vocation_keys),
          'eligibility_status',eligibility_status,
          'blocking_reasons',to_jsonb(blocking_reasons),
          'combat_relevance',combat_relevance,
          'armor',armor,
          'defense',defense,
          'defense_mod',defense_mod,
          'imbue_slots',imbue_slots,
          'effects',effects,
          'wiki_url',wiki_url
        )
        order by
          case eligibility_status when 'eligible' then 0 when 'blocked' then 1 else 2 end,
          level_required desc,
          coalesce(armor,defense,0) desc,
          name,
          item_key
      )
      from limited
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','equipment_candidates_universal_v1',
      'category_first',true,
      'combat_score_applied',false,
      'ranking_applied',false,
      'eligibility_only',true,
      'catalog_only_items_excluded_by_default',true
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_equipment_candidates_universal(text,integer,text,text,boolean,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_equipment_candidates_universal(text,integer,text,text,boolean,integer)
  to service_role;
