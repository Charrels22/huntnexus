-- HuntNexus — normalize first Wand/Rod Weapon Proficiency trees and expose caster ML impact terms.
-- Source topology is flattened by TibiaWiki BR; perk_order is source order only.
-- No unlock level, branch, final damage or DPS is inferred.

insert into public.weapon_proficiency_trees(
  item_key,source_id,source_url,source_tier,levels_declared,topology_status,perk_count,observed_at,notes
) values
  ('amber-rod','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Amber_Rod','B',7,'flattened_source_order',11,'2026-10-09 00:00:00+00','Rendered source exposes seven levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('amber-wand','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Amber_Wand','B',7,'flattened_source_order',11,'2026-10-09 00:00:00+00','Rendered source exposes seven levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('eldritch-rod','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B',7,'flattened_source_order',9,'2026-10-09 00:00:00+00','Rendered source exposes seven levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('eldritch-wand','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B',7,'flattened_source_order',9,'2026-10-09 00:00:00+00','Rendered source exposes seven levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('grand-sanguine-coil','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B',7,'flattened_source_order',15,'2026-10-09 00:00:00+00','Rendered source exposes seven levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('grand-sanguine-rod','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B',7,'flattened_source_order',16,'2026-10-09 00:00:00+00','Rendered source exposes seven levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('soulhexer','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Soulhexer','B',7,'flattened_source_order',15,'2026-10-09 00:00:00+00','Rendered source exposes seven levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.'),
  ('soultainter','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Soultainter','B',7,'flattened_source_order',14,'2026-10-09 00:00:00+00','Rendered source exposes seven levels but flattens perk topology; perk_order preserves source order and level_number remains unknown.')
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
where item_key in ('soulhexer','soultainter','grand-sanguine-rod','grand-sanguine-coil','amber-rod','amber-wand','eldritch-rod','eldritch-wand');

insert into public.weapon_proficiency_perks(
  id,item_key,perk_order,level_number,effect_key,numeric_value,unit,scope,
  spell_key,source_stat_key,description_raw,source_url,source_tier,metadata,created_at
) values
  (gen_random_uuid(),'amber-rod',1,null,'magic_level_bonus',1,'flat','global',null,'magic_level','+1 Magic Level','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',2,null,'magic_level_spell_extra_healing_percent',8,'percent','healing_spells',null,'magic_level','+8.00% do seu Magic Level como extra healing para suas spells','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',3,null,'offensive_rune_critical_extra_damage',5,'percent','offensive_runes',null,null,'+5.00% critical extra damage para offensive runes','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',4,null,'ice_spells_runes_critical_chance',1,'percent','ice_spells_runes',null,null,'+1.00% critical hit chance para Ice spells e runes','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',5,null,'life_on_kill',25,'flat','trigger',null,null,'+25 hit points on kill','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',6,null,'offensive_rune_critical_chance',1,'percent','offensive_runes',null,null,'+1.00% critical hit chance para offensive runes','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',7,null,'bestiary_demon_damage',3,'percent','bestiary_demon',null,null,'+3.00% damage contra Demon','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',8,null,'ice_magic_level_bonus',1,'flat','ice_magic',null,'magic_level','+1 Ice Magic Level','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',9,null,'strong_ice_wave_critical_extra_damage',6,'percent','spell','strong-ice-wave',null,'+6% critical extra damage para Strong Ice Wave','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',10,null,'ice_spells_runes_critical_extra_damage',7,'percent','ice_spells_runes',null,null,'+7.00% critical extra damage para Ice spells e runes','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-rod',11,null,'strong_ice_wave_life_leech',10,'percent','spell','strong-ice-wave',null,'+10% life leech para Strong Ice Wave','https://www.tibiawiki.com.br/wiki/Amber_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',1,null,'magic_level_bonus',1,'flat','global',null,'magic_level','+1 Magic Level','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',2,null,'magic_level_spell_extra_damage_percent',4,'percent','spells',null,'magic_level','+4.00% do seu Magic Level como extra damage para suas spells','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',3,null,'offensive_rune_critical_extra_damage',5,'percent','offensive_runes',null,null,'+5.00% critical extra damage para offensive runes','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',4,null,'energy_spells_runes_critical_chance',1,'percent','energy_spells_runes',null,null,'+1.00% critical hit chance para Energy spells e runes','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',5,null,'mana_on_kill',30,'flat','trigger',null,null,'+30 mana on kill','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',6,null,'offensive_rune_critical_chance',1,'percent','offensive_runes',null,null,'+1.00% critical hit chance para offensive runes','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',7,null,'bestiary_demon_damage',3,'percent','bestiary_demon',null,null,'+3.00% damage contra Demon','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',8,null,'energy_magic_level_bonus',1,'flat','energy_magic',null,'magic_level','+1 Energy Magic Level','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',9,null,'rage_of_the_skies_critical_extra_damage',10,'percent','spell','rage-of-the-skies',null,'+10% critical extra damage para Rage of the Skies','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',10,null,'energy_spells_runes_critical_extra_damage',7,'percent','energy_spells_runes',null,null,'+7.00% critical extra damage para Energy spells e runes','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'amber-wand',11,null,'rage_of_the_skies_mana_leech',50,'percent','spell','rage-of-the-skies',null,'+50% mana leech para Rage of the Skies','https://www.tibiawiki.com.br/wiki/Amber_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-rod',1,null,'mana_on_kill',25,'flat','trigger',null,null,'+25 mana on kill','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-rod',2,null,'ice_magic_level_bonus',1,'flat','ice_magic',null,'magic_level','+1 Ice Magic Level','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-rod',3,null,'healing_magic_level_bonus',2,'flat','healing_magic',null,'magic_level','+2 Healing Magic Level','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-rod',4,null,'critical_extra_damage',3.5,'percent','global',null,null,'+3.50% critical extra damage','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-rod',5,null,'heal_friend_healing',4,'percent','spell','heal-friend',null,'+4% healing para Heal Friend','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-rod',6,null,'bestiary_magical_damage',3,'percent','bestiary_magical',null,null,'+3.00% damage contra Magical','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-rod',7,null,'offensive_rune_critical_extra_damage',7,'percent','offensive_runes',null,null,'+7.00% critical extra damage para offensive runes','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-rod',8,null,'magic_level_spell_extra_healing_percent',10,'percent','healing_spells',null,'magic_level','+10.00% do seu Magic Level como extra healing para suas spells','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-rod',9,null,'offensive_rune_critical_chance',1.5,'percent','offensive_runes',null,null,'+1.50% critical hit chance para offensive runes','https://www.tibiawiki.com.br/wiki/Eldritch_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-wand',1,null,'mana_on_kill',25,'flat','trigger',null,null,'+25 mana on kill','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-wand',2,null,'death_magic_level_bonus',1,'flat','death_magic',null,'magic_level','+1 Death Magic Level','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-wand',3,null,'fire_magic_level_bonus',1,'flat','fire_magic',null,'magic_level','+1 Fire Magic Level','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-wand',4,null,'critical_extra_damage',3.5,'percent','global',null,null,'+3.50% critical extra damage','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-wand',5,null,'great_fire_wave_critical_extra_damage',5,'percent','spell','great-fire-wave',null,'+5% critical extra damage para Great Fire Wave','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-wand',6,null,'bestiary_magical_damage',3,'percent','bestiary_magical',null,null,'+3.00% damage contra Magical','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-wand',7,null,'offensive_rune_critical_extra_damage',7,'percent','offensive_runes',null,null,'+7.00% critical extra damage para offensive runes','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-wand',8,null,'magic_level_spell_extra_damage_percent',5,'percent','spells',null,'magic_level','+5.00% do seu Magic Level como extra damage para suas spells','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'eldritch-wand',9,null,'offensive_rune_critical_chance',1.5,'percent','offensive_runes',null,null,'+1.50% critical hit chance para offensive runes','https://www.tibiawiki.com.br/wiki/Eldritch_Wand','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',1,null,'magic_level_bonus',1,'flat','global',null,'magic_level','+1 Magic Level','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',2,null,'energy_spells_runes_critical_extra_damage',10,'percent','energy_spells_runes',null,null,'+10.00% critical extra damage para Energy spells e runes','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',3,null,'fire_spells_runes_critical_extra_damage',10,'percent','fire_spells_runes',null,null,'+10.00% critical extra damage para Fire spells e runes','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',4,null,'critical_extra_damage',7,'percent','global',null,null,'+7.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',5,null,'energy_wave_base_damage',8,'percent','spell','energy-wave',null,'+8% base damage para Energy Wave','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',6,null,'hells_core_critical_extra_damage',25,'percent','spell','hells-core',null,'+25% critical extra damage para Hell''s Core','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',7,null,'powerful_foe_damage',3,'percent','powerful_foe',null,null,'+3.00% damage contra bosses e Sinister Embraced','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',8,null,'magic_level_spell_extra_damage_percent',8,'percent','spells',null,'magic_level','+8.00% do seu Magic Level como extra damage para suas spells','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',9,null,'hells_core_base_damage',6,'percent','spell','hells-core',null,'+6% base damage para Hell''s Core','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',10,null,'energy_magic_level_bonus',2,'flat','energy_magic',null,'magic_level','+2 Energy Magic Level','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',11,null,'fire_magic_level_bonus',2,'flat','fire_magic',null,'magic_level','+2 Fire Magic Level','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',12,null,'energy_spells_runes_critical_chance',2,'percent','energy_spells_runes',null,null,'+2.00% critical hit chance para Energy spells e runes','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',13,null,'fire_spells_runes_critical_chance',2,'percent','fire_spells_runes',null,null,'+2.00% critical hit chance para Fire spells e runes','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',14,null,'critical_extra_damage',10,'percent','global',null,null,'+10.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-coil',15,null,'critical_chance',3,'percent','global',null,null,'+3.00% critical hit chance','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Coil','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',1,null,'magic_level_bonus',1,'flat','global',null,'magic_level','+1 Magic Level','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',2,null,'earth_spells_runes_critical_extra_damage',10,'percent','earth_spells_runes',null,null,'+10.00% critical extra damage para Earth spells e runes','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',3,null,'ice_spells_runes_critical_extra_damage',10,'percent','ice_spells_runes',null,null,'+10.00% critical extra damage para Ice spells e runes','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',4,null,'mana_leech',2,'percent','global',null,null,'+2.00% mana leech','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',5,null,'terra_wave_base_damage',8,'percent','spell','terra-wave',null,'+8% base damage para Terra Wave','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',6,null,'eternal_winter_critical_extra_damage',25,'percent','spell','eternal-winter',null,'+25% critical extra damage para Eternal Winter','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',7,null,'powerful_foe_damage',3,'percent','powerful_foe',null,null,'+3.00% damage contra bosses e Sinister Embraced','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',8,null,'magic_level_spell_extra_damage_percent',8,'percent','spells',null,'magic_level','+8.00% do seu Magic Level como extra damage para suas spells','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',9,null,'eternal_winter_base_damage',6,'percent','spell','eternal-winter',null,'+6% base damage para Eternal Winter','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',10,null,'earth_magic_level_bonus',2,'flat','earth_magic',null,'magic_level','+2 Earth Magic Level','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',11,null,'ice_magic_level_bonus',2,'flat','ice_magic',null,'magic_level','+2 Ice Magic Level','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',12,null,'healing_magic_level_bonus',3,'flat','healing_magic',null,'magic_level','+3 Healing Magic Level','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',13,null,'heal_friend_healing',6,'percent','spell','heal-friend',null,'+6% healing para Heal Friend','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',14,null,'mana_leech',2,'percent','global',null,null,'+2.00% mana leech','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',15,null,'critical_extra_damage',10,'percent','global',null,null,'+10.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'grand-sanguine-rod',16,null,'critical_chance',3,'percent','global',null,null,'+3.00% critical hit chance','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Rod','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',1,null,'life_leech',3,'percent','global',null,null,'+3.00% life leech','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',2,null,'ice_spells_runes_critical_extra_damage',7.5,'percent','ice_spells_runes',null,null,'+7.50% critical extra damage para Ice spells e runes','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',3,null,'magic_level_bonus',1,'flat','global',null,'magic_level','+1 Magic Level','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',4,null,'ice_burst_life_leech',10,'percent','spell','ice-burst',null,'+10% life leech para Ice Burst','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',5,null,'mana_leech',2,'percent','global',null,null,'+2.00% mana leech','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',6,null,'bestiary_inkborn_damage',3,'percent','bestiary_inkborn',null,null,'+3.00% damage contra Inkborn','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',7,null,'ice_spells_runes_critical_chance',1,'percent','ice_spells_runes',null,null,'+1.00% critical hit chance para Ice spells e runes','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',8,null,'ice_burst_mana_leech',5,'percent','spell','ice-burst',null,'+5% mana leech para Ice Burst','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',9,null,'offensive_rune_critical_chance',1,'percent','offensive_runes',null,null,'+1.00% critical hit chance para offensive runes','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',10,null,'ice_magic_level_bonus',2,'flat','ice_magic',null,'magic_level','+2 Ice Magic Level','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',11,null,'magic_level_bonus',1,'flat','global',null,'magic_level','+1 Magic Level','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',12,null,'life_leech',5,'percent','global',null,null,'+5.00% life leech','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',13,null,'mana_leech',2,'percent','global',null,null,'+2.00% mana leech','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',14,null,'offensive_rune_critical_extra_damage',12,'percent','offensive_runes',null,null,'+12.00% critical extra damage para offensive runes','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soulhexer',15,null,'critical_chance',1,'percent','global',null,null,'+1.00% critical hit chance','https://www.tibiawiki.com.br/wiki/Soulhexer','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',1,null,'critical_extra_damage',5,'percent','global',null,null,'+5.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',2,null,'death_spells_runes_critical_extra_damage',7.5,'percent','death_spells_runes',null,null,'+7.50% critical extra damage para Death spells e runes','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',3,null,'magic_level_bonus',1,'flat','global',null,'magic_level','+1 Magic Level','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',4,null,'great_death_beam_critical_chance',2,'percent','spell','great-death-beam',null,'+2% critical hit chance para Great Death Beam','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',5,null,'critical_extra_damage',5,'percent','global',null,null,'+5.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',6,null,'bestiary_inkborn_damage',3,'percent','bestiary_inkborn',null,null,'+3.00% damage contra Inkborn','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',7,null,'death_spells_runes_critical_chance',1.5,'percent','death_spells_runes',null,null,'+1.50% critical hit chance para Death spells e runes','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',8,null,'great_death_beam_critical_extra_damage',10,'percent','spell','great-death-beam',null,'+10% critical extra damage para Great Death Beam','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',9,null,'offensive_rune_critical_chance',1,'percent','offensive_runes',null,null,'+1.00% critical hit chance para offensive runes','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',10,null,'death_magic_level_bonus',2,'flat','death_magic',null,'magic_level','+2 Death Magic Level','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',11,null,'magic_level_bonus',1,'flat','global',null,'magic_level','+1 Magic Level','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',12,null,'critical_extra_damage',10,'percent','global',null,null,'+10.00% critical extra damage','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',13,null,'offensive_rune_critical_extra_damage',12,'percent','offensive_runes',null,null,'+12.00% critical extra damage para offensive runes','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now()),
  (gen_random_uuid(),'soultainter',14,null,'critical_chance',1,'percent','global',null,null,'+1.00% critical hit chance','https://www.tibiawiki.com.br/wiki/Soultainter','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb,now());

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
