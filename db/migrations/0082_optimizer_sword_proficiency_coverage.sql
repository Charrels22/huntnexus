-- HuntNexus — base Weapon Proficiency reference trees for optimizer-selected Sword weapons.
-- Source: TibiaWiki BR (Tier B). Per-item level/branch topology is intentionally not inferred.

delete from public.weapon_proficiency_perks where item_key in ('gnome-sword','naga-sword','soulshredder','eldritch-claymore');
delete from public.weapon_proficiency_trees where item_key in ('gnome-sword','naga-sword','soulshredder','eldritch-claymore');

insert into public.weapon_proficiency_trees(
  item_key,source_id,source_url,source_tier,levels_declared,topology_status,perk_count,notes
) values
(
  'eldritch-claymore','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://tibiawiki.com.br/wiki/Eldritch_Claymore','B',
  7,'flattened_source_order',8,'Base-tree Tier B reference. Source rendering flattens level/branch topology; Perk Shaping state on RubinOT is not assumed.'
),
(
  'gnome-sword','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/index.php?stable=1&title=Gnome_Sword','B',
  7,'flattened_source_order',2,'Base-tree Tier B reference. Source rendering flattens level/branch topology; Perk Shaping state on RubinOT is not assumed.'
),
(
  'naga-sword','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/index.php?title=Naga_Sword','B',
  7,'flattened_source_order',7,'Base-tree Tier B reference. Source rendering flattens level/branch topology; Perk Shaping state on RubinOT is not assumed.'
),
(
  'soulshredder','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/soulshredder','B',
  7,'flattened_source_order',16,'Base-tree Tier B reference. Source rendering flattens level/branch topology; Perk Shaping state on RubinOT is not assumed.'
);

insert into public.weapon_proficiency_perks(
  item_key,perk_order,level_number,effect_key,numeric_value,unit,scope,
  spell_key,source_stat_key,description_raw,source_url,source_tier,metadata
) values
(
  'eldritch-claymore',1,null,'critical_extra_damage',
  20,'percent','auto_attack',
  null,null,'+20% critical extra damage for auto-attacks',
  'https://tibiawiki.com.br/wiki/Eldritch_Claymore','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'eldritch-claymore',2,null,'magic_level_auto_attack_extra_damage_percent',
  75,'percent','auto_attack',
  null,'magic_level','+75% of Magic Level as an auto-attack extra-damage term',
  'https://tibiawiki.com.br/wiki/Eldritch_Claymore','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'eldritch-claymore',3,null,'magic_level_spell_extra_damage_percent',
  50,'percent','spells',
  null,'magic_level','+50% of Magic Level as a spell extra-damage term',
  'https://tibiawiki.com.br/wiki/Eldritch_Claymore','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'eldritch-claymore',4,null,'critical_chance',
  5,'percent','auto_attack',
  null,null,'+5% critical hit chance for auto-attacks',
  'https://tibiawiki.com.br/wiki/Eldritch_Claymore','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'eldritch-claymore',5,null,'bestiary_damage_magical',
  3,'percent','bestiary',
  'magical',null,'+3% damage against Magical creatures',
  'https://tibiawiki.com.br/wiki/Eldritch_Claymore','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'eldritch-claymore',6,null,'critical_extra_damage',
  8,'percent','spell',
  'groundshaker',null,'+8% critical extra damage for Groundshaker',
  'https://tibiawiki.com.br/wiki/Eldritch_Claymore','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'eldritch-claymore',7,null,'mana_leech',
  2,'percent','global',
  null,null,'+2% mana leech',
  'https://tibiawiki.com.br/wiki/Eldritch_Claymore','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'eldritch-claymore',8,null,'critical_chance',
  1.5,'percent','spell',
  'groundshaker',null,'+1.5% critical hit chance for Groundshaker',
  'https://tibiawiki.com.br/wiki/Eldritch_Claymore','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'gnome-sword',1,null,'mana_on_kill',
  5,'flat','kill',
  null,null,'+5 mana on kill',
  'https://www.tibiawiki.com.br/index.php?stable=1&title=Gnome_Sword','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'gnome-sword',2,null,'skill_bonus',
  1,'flat','global',
  null,'sword_fighting','+1 Sword Fighting',
  'https://www.tibiawiki.com.br/index.php?stable=1&title=Gnome_Sword','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'naga-sword',1,null,'defense_modifier',
  1,'flat','global',
  null,null,'+1 defence modifier',
  'https://www.tibiawiki.com.br/index.php?title=Naga_Sword','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'naga-sword',2,null,'mana_on_kill',
  15,'flat','kill',
  null,null,'+15 mana on kill',
  'https://www.tibiawiki.com.br/index.php?title=Naga_Sword','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'naga-sword',3,null,'life_on_kill',
  30,'flat','kill',
  null,null,'+30 hit points on kill',
  'https://www.tibiawiki.com.br/index.php?title=Naga_Sword','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'naga-sword',4,null,'magic_level_auto_attack_extra_damage_percent',
  75,'percent','auto_attack',
  null,'magic_level','+75% of Magic Level as an auto-attack extra-damage term',
  'https://www.tibiawiki.com.br/index.php?title=Naga_Sword','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'naga-sword',5,null,'skill_bonus',
  1,'flat','global',
  null,'sword_fighting','+1 Sword Fighting',
  'https://www.tibiawiki.com.br/index.php?title=Naga_Sword','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'naga-sword',6,null,'bestiary_damage_reptile',
  3,'percent','bestiary',
  'reptile',null,'+3% damage against Reptile creatures',
  'https://www.tibiawiki.com.br/index.php?title=Naga_Sword','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'naga-sword',7,null,'magic_level_spell_extra_damage_percent',
  50,'percent','spells',
  null,'magic_level','+50% of Magic Level as a spell extra-damage term',
  'https://www.tibiawiki.com.br/index.php?title=Naga_Sword','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',1,null,'skill_bonus',
  1,'flat','global',
  null,'sword_fighting','+1 Sword Fighting',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',2,null,'skill_auto_attack_extra_damage_percent',
  5,'percent','auto_attack',
  null,'sword_fighting','+5% of Sword Fighting as an auto-attack extra-damage term',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',3,null,'life_leech',
  5,'percent','spell',
  'executioners-throw',null,'+5% life leech for Executioner''s Throw',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',4,null,'critical_extra_damage',
  4,'percent','global',
  null,null,'+4% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',5,null,'bestiary_damage_inkborn',
  3,'percent','bestiary',
  'inkborn',null,'+3% damage against Inkborn creatures',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',6,null,'mana_leech',
  2,'percent','spell',
  'executioners-throw',null,'+2% mana leech for Executioner''s Throw',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',7,null,'critical_extra_damage',
  6,'percent','global',
  null,null,'+6% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',8,null,'critical_extra_damage',
  20,'percent','spell',
  'executioners-throw',null,'+20% critical extra damage for Executioner''s Throw',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',9,null,'critical_chance',
  3,'percent','auto_attack',
  null,null,'+3% critical hit chance for auto-attacks',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',10,null,'base_damage',
  4,'percent','spell',
  'executioners-throw',null,'+4% base damage for Executioner''s Throw',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',11,null,'skill_spell_extra_damage_percent',
  7.5,'percent','spells',
  null,'sword_fighting','+7.5% of Sword Fighting as a spell extra-damage term',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',12,null,'critical_chance',
  1.5,'percent','spell',
  'executioners-throw',null,'+1.5% critical hit chance for Executioner''s Throw',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',13,null,'attack',
  1,'flat','global',
  null,null,'+1 attack',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',14,null,'critical_extra_damage',
  10,'percent','global',
  null,null,'+10% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',15,null,'mana_on_kill',
  20,'flat','kill',
  null,null,'+20 mana on kill',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
),
(
  'soulshredder',16,null,'critical_chance',
  1,'percent','global',
  null,null,'+1% critical hit chance',
  'https://www.tibiawiki.com.br/wiki/soulshredder','B','{"topology_status":"flattened_source_order","base_tree_reference":true,"level_assignment_known":false}'::jsonb
);
