-- HuntNexus — universal weapon catalog across melee, distance and caster weapons.
-- This is vocation-agnostic infrastructure. EK remains a regression consumer only.

create or replace view public.vw_weapon_catalog_universal
with (security_invoker = true)
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
                    WHEN lower(COALESCE(i.weapon_type, ''::text)) = 'sword'::text THEN 'sword'::text
                    WHEN lower(COALESCE(i.weapon_type, ''::text)) = 'axe'::text THEN 'axe'::text
                    WHEN lower(COALESCE(i.weapon_type, ''::text)) = 'club'::text THEN 'club'::text
                    WHEN lower(COALESCE(i.weapon_type, ''::text)) = ANY (ARRAY['fist'::text, 'fist fighting'::text]) THEN 'fist'::text
                    WHEN i.category = 'Fist Fighting Weapons'::text THEN 'fist'::text
                    WHEN i.category = 'Bows'::text THEN 'bow'::text
                    WHEN i.category = 'Crossbows'::text THEN 'crossbow'::text
                    WHEN i.category = 'Throwing Weapons'::text THEN 'throwing'::text
                    WHEN i.category = 'Wands'::text THEN 'wand'::text
                    WHEN i.category = 'Rods'::text THEN 'rod'::text
                    WHEN lower(COALESCE(i.weapon_type, ''::text)) = 'distance'::text THEN 'distance_other'::text
                    ELSE NULL::text
                END AS weapon_family
           FROM tibia_items i
          WHERE i.weapon_type IS NOT NULL OR (i.category = ANY (ARRAY['Sword Weapons'::text, 'Axe Weapons'::text, 'Club Weapons'::text, 'Fist Fighting Weapons'::text, 'Bows'::text, 'Crossbows'::text, 'Throwing Weapons'::text, 'Wands'::text, 'Rods'::text]))
        ), normalized AS (
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
            b.weapon_family,
                CASE
                    WHEN b.weapon_family = ANY (ARRAY['sword'::text, 'axe'::text, 'club'::text, 'fist'::text]) THEN 'melee'::text
                    WHEN b.weapon_family = ANY (ARRAY['bow'::text, 'crossbow'::text, 'throwing'::text, 'distance_other'::text]) THEN 'distance'::text
                    WHEN b.weapon_family = ANY (ARRAY['wand'::text, 'rod'::text]) THEN 'caster'::text
                    ELSE 'unknown'::text
                END AS weapon_class,
                CASE b.weapon_family
                    WHEN 'sword'::text THEN 'sword_fighting'::text
                    WHEN 'axe'::text THEN 'axe_fighting'::text
                    WHEN 'club'::text THEN 'club_fighting'::text
                    WHEN 'fist'::text THEN 'fist_fighting'::text
                    WHEN 'bow'::text THEN 'distance_fighting'::text
                    WHEN 'crossbow'::text THEN 'distance_fighting'::text
                    WHEN 'throwing'::text THEN 'distance_fighting'::text
                    WHEN 'distance_other'::text THEN 'distance_fighting'::text
                    WHEN 'wand'::text THEN 'magic_level'::text
                    WHEN 'rod'::text THEN 'magic_level'::text
                    ELSE NULL::text
                END AS primary_skill_key,
                CASE
                    WHEN b.hands = ANY (ARRAY['One'::text, 'Two'::text]) THEN b.hands
                    WHEN b.weapon_family = ANY (ARRAY['wand'::text, 'rod'::text, 'throwing'::text]) THEN 'One'::text
                    ELSE NULL::text
                END AS hands_normalized,
                CASE
                    WHEN b.hands = ANY (ARRAY['One'::text, 'Two'::text]) THEN 'source'::text
                    WHEN b.weapon_family = ANY (ARRAY['wand'::text, 'rod'::text, 'throwing'::text]) THEN 'category_default'::text
                    ELSE 'unknown'::text
                END AS hands_basis,
                CASE
                    WHEN b.vocation IS NULL THEN 'unknown'::text
                    WHEN lower(TRIM(BOTH FROM b.vocation)) = ANY (ARRAY['none'::text, 'without'::text, ''::text]) THEN 'unrestricted'::text
                    ELSE 'explicit'::text
                END AS vocation_scope,
                CASE
                    WHEN b.vocation IS NULL THEN ARRAY[]::text[]
                    WHEN lower(TRIM(BOTH FROM b.vocation)) = ANY (ARRAY['none'::text, 'without'::text, ''::text]) THEN ARRAY[]::text[]
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
    n.weapon_type AS source_weapon_type,
    n.weapon_class,
    n.weapon_family,
    n.primary_skill_key,
    n.hands_normalized AS hands,
    n.hands_basis,
    n.vocation AS vocation_raw,
    n.vocation_scope,
    n.vocation_keys,
    huntnexus_first_int(n.level_required) AS level_required,
    huntnexus_first_int(n.attack) AS base_attack,
    huntnexus_first_int(n.defense) AS defense,
    huntnexus_first_int(n.defense_mod) AS defense_mod,
    huntnexus_first_int(n.range_value) AS range_value,
    huntnexus_first_int(n.imbue_slots) AS imbue_slots,
    lower(NULLIF(TRIM(BOTH FROM n.damage_type), ''::text)) AS damage_type,
    jsonb_strip_nulls(jsonb_build_object('physical', huntnexus_first_int(n.attack), 'energy', huntnexus_first_int(n.energy_attack), 'fire', huntnexus_first_int(n.fire_attack), 'earth', huntnexus_first_int(n.earth_attack), 'ice', huntnexus_first_int(n.ice_attack), 'death', huntnexus_first_int(n.death_attack), 'holy', huntnexus_first_int(n.holy_attack))) AS attack_components,
    COALESCE(e.effects, '[]'::jsonb) AS effects,
    (EXISTS ( SELECT 1
           FROM weapon_proficiency_trees t
          WHERE t.item_key = n.slug)) AS proficiency_tree_available,
    COALESCE(( SELECT t.perk_count
           FROM weapon_proficiency_trees t
          WHERE t.item_key = n.slug), 0) AS proficiency_perk_count,
    n.wiki_url,
    n.source_id,
    n.snapshot_id,
    n.source_last_updated,
    n.observed_at
   FROM normalized n
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('effect_type', ie.effect_type, 'effect_key', ie.effect_key, 'value', ie.numeric_value, 'unit', ie.unit, 'raw_value', ie.raw_value) ORDER BY ie.effect_type, ie.effect_key) AS effects
           FROM item_effects ie
          WHERE ie.item_id = n.id) e ON true
  WHERE n.weapon_family IS NOT NULL;

revoke all on public.vw_weapon_catalog_universal from public, anon, authenticated;
grant select on public.vw_weapon_catalog_universal to service_role;
