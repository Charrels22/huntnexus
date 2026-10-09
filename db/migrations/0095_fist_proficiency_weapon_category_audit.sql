-- HuntNexus — Fist proficiency + weapon category readiness audit.
-- Finalizes the category-first weapon core contract without claiming exhaustive proficiency or final DPS.

create or replace view public.vw_weapon_catalog_universal
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
                    WHEN b.vocation IS NULL THEN 'unrestricted'::text
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
    COALESCE(huntnexus_first_int(n.level_required), 0) AS level_required,
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
  WHERE n.weapon_family IS NOT NULL AND n.slug <> 'fist-fighting-weapons'::text;

revoke all on public.vw_weapon_catalog_universal from public,anon,authenticated;
grant select on public.vw_weapon_catalog_universal to service_role;

update public.weapon_proficiency_family_rules
set system_status='supported',
    progression_group='item_evidence',
    source_tier='B',
    source_url='https://www.tibiawiki.com.br/wiki/Assassin_Star',
    observed_at='2026-10-09 00:00:00+00',
    notes='Current Tier-B Assassin Star page exposes Weapon Proficiency perks. Family-level system table omission is therefore not treated as lack of support.'
where weapon_family='throwing';

insert into public.weapon_proficiency_trees(
  item_key,source_id,source_url,source_tier,levels_declared,topology_status,perk_count,observed_at,notes
) values
  ('amber-kusarigama','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B',7,'flattened_source_order',12,'2026-10-09 00:00:00+00','Rendered source exposes seven proficiency levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('assassin-star','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Assassin_Star','B',7,'flattened_source_order',5,'2026-10-09 00:00:00+00','Current item page exposes Weapon Proficiency perks; source order is preserved and level assignment is not inferred.'),
  ('eldritch-crescent-moon-spade','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Eldritch_Crescent_Moon_Spade','B',7,'flattened_source_order',6,'2026-10-09 00:00:00+00','Rendered source exposes seven proficiency levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('grand-sanguine-claws','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B',7,'flattened_source_order',15,'2026-10-09 00:00:00+00','Rendered source exposes seven proficiency levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('moonsilver-katar','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B',7,'flattened_source_order',17,'2026-10-09 00:00:00+00','Rendered source exposes seven proficiency levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('nunchaku-of-destruction','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Nunchaku_of_Destruction','B',7,'flattened_source_order',6,'2026-10-09 00:00:00+00','Rendered source exposes seven proficiency levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('pair-of-monk-fists','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Pair_of_Monk_Fists','B',7,'flattened_source_order',4,'2026-10-09 00:00:00+00','Rendered source exposes seven proficiency levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('soulkamas','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Soulkamas','B',7,'flattened_source_order',15,'2026-10-09 00:00:00+00','Rendered source exposes seven proficiency levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.')
on conflict (item_key) do update set
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  source_tier=excluded.source_tier,
  levels_declared=excluded.levels_declared,
  topology_status=excluded.topology_status,
  perk_count=excluded.perk_count,
  observed_at=excluded.observed_at,
  notes=excluded.notes;

delete from public.weapon_proficiency_perks
where item_key in ('pair-of-monk-fists','nunchaku-of-destruction','eldritch-crescent-moon-spade','amber-kusarigama','soulkamas','grand-sanguine-claws','moonsilver-katar','assassin-star');

insert into public.weapon_proficiency_perks(
  id,item_key,perk_order,level_number,effect_key,numeric_value,unit,scope,
  spell_key,source_stat_key,description_raw,source_url,source_tier,metadata,created_at
) values
  (gen_random_uuid(),'amber-kusarigama',1,null,'magic_level_auto_attack_extra_damage_percent',25,'percent','auto_attack',null,'magic_level','+25.00% do seu Magic Level como extra damage para auto-attacks','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',2,null,'devastating_knockout_critical_extra_damage',7,'percent','spell','devastating-knockout',null,'+7% critical extra damage para Devastating Knockout','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',3,null,'devastating_knockout_life_leech',35,'percent','spell','devastating-knockout',null,'+35% life leech para Devastating Knockout','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',4,null,'devastating_knockout_base_damage',5,'percent','spell','devastating-knockout',null,'+5% base damage para Devastating Knockout','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',5,null,'devastating_knockout_critical_extra_damage',7,'percent','spell','devastating-knockout',null,'+7% critical extra damage para Devastating Knockout','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',6,null,'devastating_knockout_life_leech',35,'percent','spell','devastating-knockout',null,'+35% life leech para Devastating Knockout','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',7,null,'devastating_knockout_critical_chance',2.5,'percent','spell','devastating-knockout',null,'+2.5% critical hit chance para Devastating Knockout','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',8,null,'magic_level_bonus',2,'flat','global',null,'magic_level','+2 Magic Level','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',9,null,'bestiary_demon_damage',3,'percent','bestiary_demon',null,null,'+3.00% damage contra Demon','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',10,null,'attack',1,'flat','global',null,null,'+1 attack','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',11,null,'devastating_knockout_mana_leech',35,'percent','spell','devastating-knockout',null,'+35% mana leech para Devastating Knockout','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-kusarigama',12,null,'magic_level_spell_extra_damage_percent',25,'percent','spells',null,'magic_level','+25.00% do seu Magic Level como extra damage para suas spells','https://www.tibiawiki.com.br/wiki/Amber_Kusarigama','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'assassin-star',1,null,'life_on_kill',5,'flat','trigger',null,null,'+5 hit points on kill','https://www.tibiawiki.com.br/wiki/Assassin_Star','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'assassin-star',2,null,'life_on_kill',5,'flat','trigger',null,null,'+5 hit points on kill','https://www.tibiawiki.com.br/wiki/Assassin_Star','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'assassin-star',3,null,'life_on_kill',5,'flat','trigger',null,null,'+5 hit points on kill','https://www.tibiawiki.com.br/wiki/Assassin_Star','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'assassin-star',4,null,'life_on_kill',5,'flat','trigger',null,null,'+5 hit points on kill','https://www.tibiawiki.com.br/wiki/Assassin_Star','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'assassin-star',5,null,'life_on_kill',10,'flat','trigger',null,null,'+10 hit points on kill','https://www.tibiawiki.com.br/wiki/Assassin_Star','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-crescent-moon-spade',1,null,'auto_attack_critical_extra_damage',20,'percent','auto_attack',null,null,'+20.00% critical extra damage para auto-attacks','https://www.tibiawiki.com.br/wiki/Eldritch_Crescent_Moon_Spade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-crescent-moon-spade',2,null,'magic_level_auto_attack_extra_damage_percent',10,'percent','auto_attack',null,'magic_level','+10.00% do seu Magic Level como extra damage para auto-attacks','https://www.tibiawiki.com.br/wiki/Eldritch_Crescent_Moon_Spade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-crescent-moon-spade',3,null,'magic_level_spell_extra_damage_percent',12.5,'percent','spells',null,'magic_level','+12.50% do seu Magic Level como extra damage para suas spells','https://www.tibiawiki.com.br/wiki/Eldritch_Crescent_Moon_Spade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-crescent-moon-spade',4,null,'bestiary_magical_damage',3,'percent','bestiary_magical',null,null,'+3.00% damage contra Magical','https://www.tibiawiki.com.br/wiki/Eldritch_Crescent_Moon_Spade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-crescent-moon-spade',5,null,'mana_leech',2,'percent','global',null,null,'+2.00% mana leech','https://www.tibiawiki.com.br/wiki/Eldritch_Crescent_Moon_Spade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-crescent-moon-spade',6,null,'skill_bonus',1,'flat','global',null,'fist_fighting','+1 Fist Fighting','https://www.tibiawiki.com.br/wiki/Eldritch_Crescent_Moon_Spade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',1,null,'skill_bonus',1,'flat','global',null,'fist_fighting','+1 Fist Fighting','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',2,null,'skill_auto_attack_extra_damage_percent',5,'percent','auto_attack',null,'fist_fighting','+5.00% do seu Fist Fighting como extra damage para auto-attacks','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',3,null,'sweeping_takedown_life_leech',5,'percent','spell','sweeping-takedown',null,'+5% life leech para Sweeping Takedown','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',4,null,'critical_extra_damage',4,'percent','global',null,null,'+4.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',5,null,'powerful_foe_damage',3,'percent','powerful_foe',null,null,'+3.00% damage contra bosses e Sinister Embraced','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',6,null,'sweeping_takedown_mana_leech',4,'percent','spell','sweeping-takedown',null,'+4% mana leech para Sweeping Takedown','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',7,null,'critical_extra_damage',8,'percent','global',null,null,'+8.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',8,null,'sweeping_takedown_critical_extra_damage',40,'percent','spell','sweeping-takedown',null,'+40% critical extra damage para Sweeping Takedown','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',9,null,'sweeping_takedown_base_damage',8,'percent','spell','sweeping-takedown',null,'+8% base damage para Sweeping Takedown','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',10,null,'skill_spell_extra_damage_percent',10,'percent','spells',null,'fist_fighting','+10.00% do seu Fist Fighting como extra damage para suas spells','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',11,null,'sweeping_takedown_critical_chance',3,'percent','spell','sweeping-takedown',null,'+3% critical hit chance para Sweeping Takedown','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',12,null,'attack',1,'flat','global',null,null,'+1 attack','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',13,null,'critical_extra_damage',10,'percent','global',null,null,'+10.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',14,null,'magic_level_spell_extra_healing_percent',100,'percent','healing_spells',null,'magic_level','+100.00% do seu Magic Level como extra healing para suas spells','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-claws',15,null,'critical_chance',3,'percent','global',null,null,'+3.00% critical hit chance','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Claws','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',1,null,'critical_extra_damage',8,'percent','global',null,null,'+8.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',2,null,'bestiary_human_damage',3,'percent','bestiary_human',null,null,'+3.00% damage contra Human','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',3,null,'skill_bonus',1,'flat','global',null,'fist_fighting','+1 Fist Fighting','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',4,null,'critical_extra_damage',6,'percent','global',null,null,'+6.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',5,null,'thousand_fist_blows_life_leech',10,'percent','spell','thousand-fist-blows',null,'+10% life leech para Thousand Fist Blows','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',6,null,'energy_homing_missile_proc',1,'percent_chance','offensive_spells',null,'level','Offensive spells have a 1% chance to fire a homing missile that deals Energy damage equal to 200% do seu level','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","element":"energy","topology_status":"flattened_source_order","level_damage_percent":200,"level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',7,null,'thousand_fist_blows_base_damage',9,'percent','spell','thousand-fist-blows',null,'+9% base damage para Thousand Fist Blows','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',8,null,'life_leech',3,'percent','global',null,null,'+3.00% life leech','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',9,null,'attack',1,'flat','global',null,null,'+1 attack','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',10,null,'critical_chance',1,'percent','global',null,null,'+1.00% critical hit chance','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',11,null,'thousand_fist_blows_mana_leech',7.5,'percent','spell','thousand-fist-blows',null,'+7.5% mana leech para Thousand Fist Blows','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',12,null,'attack',1,'flat','global',null,null,'+1 attack','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',13,null,'thousand_fist_blows_critical_chance',5,'percent','spell','thousand-fist-blows',null,'+5% critical hit chance para Thousand Fist Blows','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',14,null,'mana_leech',2,'percent','global',null,null,'+2.00% mana leech','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',15,null,'critical_extra_damage',12,'percent','global',null,null,'+12.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',16,null,'element_pierce_energy',4,'percent','global',null,null,'+4% Energy pierce','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","element":"energy","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'moonsilver-katar',17,null,'omega_damage',6,'percent','target_below_30_percent_hp',null,null,'+6.00% damage contra targets below 30% hit points','https://www.tibiawiki.com.br/wiki/Moonsilver_Katar','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","threshold_hp_percent":30,"level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'nunchaku-of-destruction',1,null,'auto_attack_critical_extra_damage',10,'percent','auto_attack',null,null,'+10.00% critical extra damage para auto-attacks','https://www.tibiawiki.com.br/wiki/Nunchaku_of_Destruction','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'nunchaku-of-destruction',2,null,'skill_auto_attack_extra_damage_percent',15,'percent','auto_attack',null,'fist_fighting','+15.00% do seu Fist Fighting como extra damage para auto-attacks','https://www.tibiawiki.com.br/wiki/Nunchaku_of_Destruction','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'nunchaku-of-destruction',3,null,'powerful_foe_damage',3,'percent','powerful_foe',null,null,'+3.00% damage contra bosses e Sinister Embraced','https://www.tibiawiki.com.br/wiki/Nunchaku_of_Destruction','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'nunchaku-of-destruction',4,null,'auto_attack_critical_chance',3.5,'percent','auto_attack',null,null,'+3.50% critical hit chance para auto-attacks','https://www.tibiawiki.com.br/wiki/Nunchaku_of_Destruction','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'nunchaku-of-destruction',5,null,'skill_bonus',1,'flat','global',null,'fist_fighting','+1 Fist Fighting','https://www.tibiawiki.com.br/wiki/Nunchaku_of_Destruction','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'nunchaku-of-destruction',6,null,'skill_spell_extra_damage_percent',10,'percent','spells',null,'fist_fighting','+10.00% do seu Fist Fighting como extra damage para suas spells','https://www.tibiawiki.com.br/wiki/Nunchaku_of_Destruction','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'pair-of-monk-fists',1,null,'defense',1,'flat','global',null,null,'+1 defence','https://www.tibiawiki.com.br/wiki/Pair_of_Monk_Fists','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'pair-of-monk-fists',2,null,'skill_auto_attack_extra_damage_percent',4,'percent','auto_attack',null,'fist_fighting','+4.00% do seu Fist Fighting como extra damage para auto-attacks','https://www.tibiawiki.com.br/wiki/Pair_of_Monk_Fists','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'pair-of-monk-fists',3,null,'auto_attack_critical_chance',1,'percent','auto_attack',null,null,'+1.00% critical hit chance para auto-attacks','https://www.tibiawiki.com.br/wiki/Pair_of_Monk_Fists','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'pair-of-monk-fists',4,null,'life_on_kill',5,'flat','trigger',null,null,'+5 hit points on kill','https://www.tibiawiki.com.br/wiki/Pair_of_Monk_Fists','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',1,null,'skill_bonus',1,'flat','global',null,'fist_fighting','+1 Fist Fighting','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',2,null,'skill_auto_attack_extra_damage_percent',5,'percent','auto_attack',null,'fist_fighting','+5.00% do seu Fist Fighting como extra damage para auto-attacks','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',3,null,'chained_penance_life_leech',5,'percent','spell','chained-penance',null,'+5% life leech para Chained Penance','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',4,null,'critical_extra_damage',4,'percent','global',null,null,'+4.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',5,null,'bestiary_inkborn_damage',3,'percent','bestiary_inkborn',null,null,'+3.00% damage contra Inkborn','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',6,null,'chained_penance_mana_leech',2,'percent','spell','chained-penance',null,'+2% mana leech para Chained Penance','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',7,null,'critical_extra_damage',6,'percent','global',null,null,'+6.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',8,null,'chained_penance_critical_extra_damage',20,'percent','spell','chained-penance',null,'+20% critical extra damage para Chained Penance','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',9,null,'chained_penance_base_damage',3.5,'percent','spell','chained-penance',null,'+3.5% base damage para Chained Penance','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',10,null,'skill_spell_extra_damage_percent',7.5,'percent','spells',null,'fist_fighting','+7.50% do seu Fist Fighting como extra damage para suas spells','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',11,null,'chained_penance_critical_chance',1.5,'percent','spell','chained-penance',null,'+1.5% critical hit chance para Chained Penance','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',12,null,'attack',1,'flat','global',null,null,'+1 attack','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',13,null,'critical_extra_damage',10,'percent','global',null,null,'+10.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',14,null,'mana_on_kill',20,'flat','trigger',null,null,'+20 mana on kill','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulkamas',15,null,'critical_chance',1,'percent','global',null,null,'+1.00% critical hit chance','https://www.tibiawiki.com.br/wiki/Soulkamas','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now());

CREATE OR REPLACE FUNCTION public.huntnexus_weapon_proficiency_impact_preview(p_item_key text, p_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_effective_weapon_skill integer DEFAULT NULL::integer, p_effective_magic_level integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with base as (
  select
    case when p_effective_weapon_skill is null then null else greatest(p_effective_weapon_skill,0) end as effective_weapon_skill,
    case when p_effective_magic_level is null then null else greatest(p_effective_magic_level,0) end as effective_magic_level
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
      when a.effect_key in (
        'magic_level_auto_attack_extra_damage_percent',
        'magic_level_spell_extra_damage_percent',
        'magic_level_spell_extra_healing_percent'
      ) then
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
      when a.effect_key in (
        'magic_level_auto_attack_extra_damage_percent',
        'magic_level_spell_extra_damage_percent',
        'magic_level_spell_extra_healing_percent'
      ) then b.effective_magic_level is not null
      else true
    end as resolved_with_inputs,
    case
      when a.effect_key in (
        'skill_auto_attack_extra_damage_percent',
        'skill_spell_extra_damage_percent'
      ) and b.effective_weapon_skill is null
        then 'effective_weapon_skill'
      when a.effect_key in (
        'magic_level_auto_attack_extra_damage_percent',
        'magic_level_spell_extra_damage_percent',
        'magic_level_spell_extra_healing_percent'
      ) and b.effective_magic_level is null
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
      where effect_key='magic_level_auto_attack_extra_damage_percent'
    ),0) as auto_attack_magic_level_derived_term,
    coalesce(sum(derived_stat_contribution) filter(
      where effect_key='magic_level_spell_extra_damage_percent'
    ),0) as spell_magic_level_derived_term,
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
    'flat_magic_level_bonus',coalesce((
      select sum(numeric_value) from resolved where effect_key='magic_level_bonus'
    ),0),
    'elemental_magic_level_bonuses',jsonb_build_object(
      'fire',coalesce((select sum(numeric_value) from resolved where effect_key='fire_magic_level_bonus'),0),
      'energy',coalesce((select sum(numeric_value) from resolved where effect_key='energy_magic_level_bonus'),0),
      'ice',coalesce((select sum(numeric_value) from resolved where effect_key='ice_magic_level_bonus'),0),
      'earth',coalesce((select sum(numeric_value) from resolved where effect_key='earth_magic_level_bonus'),0),
      'death',coalesce((select sum(numeric_value) from resolved where effect_key='death_magic_level_bonus'),0),
      'holy',coalesce((select sum(numeric_value) from resolved where effect_key='holy_magic_level_bonus'),0)
    ),
    'healing_magic_level_bonus',coalesce((
      select sum(numeric_value) from resolved where effect_key='healing_magic_level_bonus'
    ),0),
    'flat_attack_bonus',(select attack_bonus from aggregates),
    'flat_defense_bonus',coalesce((
      select sum(numeric_value) from resolved where effect_key='defense' and scope='global'
    ),0),
    'global_critical_chance_percent',(select global_critical_chance from aggregates),
    'global_critical_extra_damage_percent',(select global_critical_extra_damage from aggregates),
    'global_life_leech_percent',(select global_life_leech from aggregates),
    'global_mana_leech_percent',(select global_mana_leech from aggregates),
    'auto_attack_skill_derived_damage_term',(select auto_attack_skill_derived_term from aggregates),
    'spell_skill_derived_damage_term',(select spell_skill_derived_term from aggregates),
    'auto_attack_magic_level_derived_damage_term',
      case
        when (select effective_magic_level from base) is not null
        then (select auto_attack_magic_level_derived_term from aggregates)
        else null
      end,
    'spell_magic_level_derived_damage_term',
      case
        when (select effective_magic_level from base) is not null
        then (select spell_magic_level_derived_term from aggregates)
        else null
      end,
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
    'stage','weapon_proficiency_impact_preview_v2',
    'optimizer_effect_applied',false,
    'ranking_changed',false,
    'dps_calculated',false,
    'damage_formula_applied',false,
    'source_stat_terms_calculated',true,
    'magic_level_damage_terms_calculated',true,
    'flat_magic_level_terms_exposed',true,
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

CREATE OR REPLACE FUNCTION public.huntnexus_weapon_category_audit()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with family as (
  select
    w.weapon_family,
    min(w.weapon_class) as weapon_class,
    count(*)::int as catalog_weapons,
    count(*) filter(where w.hands is null)::int as missing_hands,
    count(*) filter(where w.level_required is null)::int as missing_level,
    count(*) filter(where w.vocation_scope='unknown')::int as unknown_vocation,
    count(*) filter(where w.vocation_scope='explicit' and cardinality(w.vocation_keys)=0)::int as unparsed_explicit_vocation,
    count(*) filter(where w.proficiency_tree_available)::int as normalized_proficiency_trees,
    max(r.system_status) as proficiency_system_status
  from vw_weapon_catalog_universal w
  left join weapon_proficiency_family_rules r on r.weapon_family=w.weapon_family
  group by w.weapon_family
),
family_json as (
  select jsonb_agg(
    jsonb_build_object(
      'weapon_family',weapon_family,
      'weapon_class',weapon_class,
      'catalog_weapons',catalog_weapons,
      'structural_completeness',jsonb_build_object(
        'missing_hands',missing_hands,
        'missing_level',missing_level,
        'unknown_vocation',unknown_vocation,
        'unparsed_explicit_vocation',unparsed_explicit_vocation,
        'ready',(missing_hands=0 and missing_level=0 and unknown_vocation=0 and unparsed_explicit_vocation=0)
      ),
      'proficiency',jsonb_build_object(
        'system_status',proficiency_system_status,
        'normalized_trees',normalized_proficiency_trees,
        'weapons_without_normalized_tree',catalog_weapons-normalized_proficiency_trees,
        'exhaustive',normalized_proficiency_trees=catalog_weapons
      )
    )
    order by weapon_class,weapon_family
  ) as rows
  from family
),
dependency as (
  select jsonb_build_object(
    'quivers',jsonb_build_object(
      'catalog_items',(select count(*) from vw_quiver_catalog_universal),
      'ready',(select count(*) from vw_quiver_catalog_universal)>0
    ),
    'ammunition',jsonb_build_object(
      'arrows',(select count(*) from ammunition_catalog where ammunition_family='arrow'),
      'bolts',(select count(*) from ammunition_catalog where ammunition_family='bolt'),
      'ready',(
        (select count(*) from ammunition_catalog where ammunition_family='arrow')>0
        and (select count(*) from ammunition_catalog where ammunition_family='bolt')>0
      )
    )
  ) as j
)
select jsonb_build_object(
  'summary',jsonb_build_object(
    'catalog_weapons',(select count(*) from vw_weapon_catalog_universal),
    'weapon_classes',(select count(distinct weapon_class) from vw_weapon_catalog_universal),
    'weapon_families',(select count(distinct weapon_family) from vw_weapon_catalog_universal),
    'normalized_proficiency_trees',(select count(*) from weapon_proficiency_trees),
    'structural_gaps',jsonb_build_object(
      'missing_hands',(select sum(missing_hands) from family),
      'missing_level',(select sum(missing_level) from family),
      'unknown_vocation',(select sum(unknown_vocation) from family),
      'unparsed_explicit_vocation',(select sum(unparsed_explicit_vocation) from family)
    ),
    'core_contract_ready',(
      (select sum(missing_hands+missing_level+unknown_vocation+unparsed_explicit_vocation) from family)=0
    ),
    'proficiency_exhaustive',(
      (select count(*) from weapon_proficiency_trees)=(select count(*) from vw_weapon_catalog_universal)
    ),
    'proficiency_backfill_pending',(
      (select count(*) from weapon_proficiency_trees)<(select count(*) from vw_weapon_catalog_universal)
    ),
    'final_combat_formula_ready',false
  ),
  'dependencies',(select j from dependency),
  'families',(select rows from family_json),
  'methodology',jsonb_build_object(
    'stage','weapon_category_audit_v1',
    'category_first',true,
    'core_ready_does_not_mean_exhaustive_proficiency',true,
    'final_combat_formula_applied',false,
    'ranking_applied',false,
    'note','Core readiness means the universal factual/eligibility/compatibility contract has no structural gaps. Weapon Proficiency remains a separately tracked backfill and final combat formulas remain outside this category layer.'
  )
);
$function$
;

revoke all on function public.huntnexus_weapon_category_audit()
  from public,anon,authenticated;
grant execute on function public.huntnexus_weapon_category_audit()
  to service_role;
