-- HuntNexus — normalized Weapon Proficiency perks for optimizer-relevant Grand Sanguine EK weapons.
-- Source: TibiaWiki BR (Tier B).
-- Exact level/branch topology is intentionally left NULL because the rendered source flattens the tree.

create table if not exists public.weapon_proficiency_trees (
  item_key text primary key references public.tibia_items(slug) on delete cascade,
  source_id uuid not null references public.sources(id),
  source_url text not null,
  source_tier text not null,
  levels_declared integer,
  topology_status text not null,
  perk_count integer not null,
  observed_at timestamptz not null default now(),
  notes text
);

create table if not exists public.weapon_proficiency_perks (
  id uuid primary key default gen_random_uuid(),
  item_key text not null references public.tibia_items(slug) on delete cascade,
  perk_order integer not null,
  level_number integer,
  effect_key text not null,
  numeric_value numeric,
  unit text,
  scope text not null default 'global',
  spell_key text,
  source_stat_key text,
  description_raw text not null,
  source_url text not null,
  source_tier text not null default 'B',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(item_key,perk_order)
);

create index if not exists idx_weapon_proficiency_perks_item
  on public.weapon_proficiency_perks(item_key);
create index if not exists idx_weapon_proficiency_perks_effect
  on public.weapon_proficiency_perks(effect_key);

alter table public.weapon_proficiency_trees enable row level security;
alter table public.weapon_proficiency_perks enable row level security;
revoke all on public.weapon_proficiency_trees from public,anon,authenticated;
revoke all on public.weapon_proficiency_perks from public,anon,authenticated;
grant select,insert,update,delete on public.weapon_proficiency_trees to service_role;
grant select,insert,update,delete on public.weapon_proficiency_perks to service_role;

delete from public.weapon_proficiency_perks
where item_key in (
  'grand-sanguine-blade','grand-sanguine-razor',
  'grand-sanguine-hatchet','grand-sanguine-battleaxe',
  'grand-sanguine-cudgel','grand-sanguine-bludgeon'
);

delete from public.weapon_proficiency_trees
where item_key in (
  'grand-sanguine-blade','grand-sanguine-razor',
  'grand-sanguine-hatchet','grand-sanguine-battleaxe',
  'grand-sanguine-cudgel','grand-sanguine-bludgeon'
);

insert into public.weapon_proficiency_trees(
  item_key,source_id,source_url,source_tier,levels_declared,topology_status,perk_count,notes
) values
(
  'grand-sanguine-battleaxe','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B',
  7,'flattened_source_order',15,'Perk order preserved from TibiaWiki. Exact branch/level topology not assigned because rendered text flattens the proficiency table.'
),
(
  'grand-sanguine-blade','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B',
  7,'flattened_source_order',15,'Perk order preserved from TibiaWiki. Exact branch/level topology not assigned because rendered text flattens the proficiency table.'
),
(
  'grand-sanguine-bludgeon','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B',
  7,'flattened_source_order',15,'Perk order preserved from TibiaWiki. Exact branch/level topology not assigned because rendered text flattens the proficiency table.'
),
(
  'grand-sanguine-cudgel','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B',
  7,'flattened_source_order',15,'Perk order preserved from TibiaWiki. Exact branch/level topology not assigned because rendered text flattens the proficiency table.'
),
(
  'grand-sanguine-hatchet','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B',
  7,'flattened_source_order',15,'Perk order preserved from TibiaWiki. Exact branch/level topology not assigned because rendered text flattens the proficiency table.'
),
(
  'grand-sanguine-razor','53148ef0-b2d6-44fd-b205-59e6fd33b9ea','https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B',
  7,'flattened_source_order',15,'Perk order preserved from TibiaWiki. Exact branch/level topology not assigned because rendered text flattens the proficiency table.'
);

insert into public.weapon_proficiency_perks(
  item_key,perk_order,level_number,effect_key,numeric_value,unit,scope,
  spell_key,source_stat_key,description_raw,source_url,source_tier,metadata
) values
(
  'grand-sanguine-battleaxe',1,null,'skill_bonus',
  1,'flat','global',
  null,'axe_fighting','+1 Axe Fighting',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',2,null,'skill_auto_attack_extra_damage_percent',
  5,'percent','auto_attack',
  null,'axe_fighting','+5.00% do seu Axe Fighting como extra damage para auto-attacks',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',3,null,'fierce_berserk_life_leech',
  5,'percent','spell',
  'fierce-berserk',null,'+5% life leech para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',4,null,'critical_extra_damage_4',
  4,'percent','global',
  null,null,'+4.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',5,null,'powerful_foe_damage',
  3,'percent','powerful_foe',
  null,null,'+3.00% damage contra bosses e Sinister Embraced',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',6,null,'fierce_berserk_mana_leech',
  4,'percent','spell',
  'fierce-berserk',null,'+4% mana leech para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',7,null,'critical_extra_damage_8',
  8,'percent','global',
  null,null,'+8.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',8,null,'fierce_berserk_critical_extra_damage_40',
  40,'percent','spell',
  'fierce-berserk',null,'+40% critical extra damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',9,null,'fierce_berserk_base_damage',
  8,'percent','spell',
  'fierce-berserk',null,'+8% base damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',10,null,'skill_spell_extra_damage_percent',
  10,'percent','spells',
  null,'axe_fighting','+10.00% do seu Axe Fighting como extra damage para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',11,null,'fierce_berserk_critical_chance',
  3,'percent','spell',
  'fierce-berserk',null,'+3% critical hit chance para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',12,null,'attack',
  1,'flat','global',
  null,null,'+1 attack',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',13,null,'critical_extra_damage_10',
  10,'percent','global',
  null,null,'+10.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',14,null,'magic_level_spell_extra_healing_percent',
  1000,'percent','healing_spells',
  null,'magic_level','+1000.00% do seu Magic Level como extra healing para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-battleaxe',15,null,'critical_chance',
  3,'percent','global',
  null,null,'+3.00% critical hit chance',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Battleaxe','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',1,null,'skill_bonus',
  1,'flat','global',
  null,'sword_fighting','+1 Sword Fighting',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',2,null,'auto_attack_critical_extra_damage',
  10,'percent','auto_attack',
  null,null,'+10.00% critical extra damage para auto-attacks',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',3,null,'skill_auto_attack_extra_damage_percent',
  5,'percent','auto_attack',
  null,'sword_fighting','+5.00% do seu Sword Fighting como extra damage para auto-attacks',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',4,null,'life_leech',
  3,'percent','global',
  null,null,'+3.00% life leech',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',5,null,'powerful_foe_damage',
  3,'percent','powerful_foe',
  null,null,'+3.00% damage contra bosses e Sinister Embraced',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',6,null,'fierce_berserk_critical_extra_damage_20',
  20,'percent','spell',
  'fierce-berserk',null,'+20% critical extra damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',7,null,'mana_leech',
  2,'percent','global',
  null,null,'+2.00% mana leech',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',8,null,'fierce_berserk_critical_extra_damage_40',
  40,'percent','spell',
  'fierce-berserk',null,'+40% critical extra damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',9,null,'fierce_berserk_base_damage',
  8,'percent','spell',
  'fierce-berserk',null,'+8% base damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',10,null,'skill_spell_extra_damage_percent',
  10,'percent','spells',
  null,'sword_fighting','+10.00% do seu Sword Fighting como extra damage para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',11,null,'fierce_berserk_critical_chance',
  3,'percent','spell',
  'fierce-berserk',null,'+3% critical hit chance para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',12,null,'attack',
  1,'flat','global',
  null,null,'+1 attack',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',13,null,'critical_extra_damage',
  10,'percent','global',
  null,null,'+10.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',14,null,'magic_level_spell_extra_healing_percent',
  1000,'percent','healing_spells',
  null,'magic_level','+1000.00% do seu Magic Level como extra healing para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-blade',15,null,'critical_chance',
  3,'percent','global',
  null,null,'+3.00% critical hit chance',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Blade','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',1,null,'skill_bonus',
  1,'flat','global',
  null,'club_fighting','+1 Club Fighting',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',2,null,'skill_auto_attack_extra_damage_percent',
  5,'percent','auto_attack',
  null,'club_fighting','+5.00% do seu Club Fighting como extra damage para auto-attacks',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',3,null,'fierce_berserk_life_leech',
  5,'percent','spell',
  'fierce-berserk',null,'+5% life leech para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',4,null,'critical_extra_damage_4',
  4,'percent','global',
  null,null,'+4.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',5,null,'powerful_foe_damage',
  3,'percent','powerful_foe',
  null,null,'+3.00% damage contra bosses e Sinister Embraced',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',6,null,'fierce_berserk_mana_leech',
  4,'percent','spell',
  'fierce-berserk',null,'+4% mana leech para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',7,null,'critical_extra_damage_8',
  8,'percent','global',
  null,null,'+8.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',8,null,'fierce_berserk_critical_extra_damage_40',
  40,'percent','spell',
  'fierce-berserk',null,'+40% critical extra damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',9,null,'fierce_berserk_base_damage',
  8,'percent','spell',
  'fierce-berserk',null,'+8% base damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',10,null,'skill_spell_extra_damage_percent',
  10,'percent','spells',
  null,'club_fighting','+10.00% do seu Club Fighting como extra damage para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',11,null,'fierce_berserk_critical_chance',
  3,'percent','spell',
  'fierce-berserk',null,'+3% critical hit chance para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',12,null,'attack',
  1,'flat','global',
  null,null,'+1 attack',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',13,null,'critical_extra_damage_10',
  10,'percent','global',
  null,null,'+10.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',14,null,'magic_level_spell_extra_healing_percent',
  1000,'percent','healing_spells',
  null,'magic_level','+1000.00% do seu Magic Level como extra healing para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-bludgeon',15,null,'critical_chance',
  3,'percent','global',
  null,null,'+3.00% critical hit chance',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Bludgeon','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',1,null,'skill_bonus',
  1,'flat','global',
  null,'club_fighting','+1 Club Fighting',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',2,null,'auto_attack_critical_extra_damage',
  10,'percent','auto_attack',
  null,null,'+10.00% critical extra damage para auto-attacks',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',3,null,'skill_auto_attack_extra_damage_percent',
  5,'percent','auto_attack',
  null,'club_fighting','+5.00% do seu Club Fighting como extra damage para auto-attacks',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',4,null,'life_leech',
  3,'percent','global',
  null,null,'+3.00% life leech',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',5,null,'powerful_foe_damage',
  3,'percent','powerful_foe',
  null,null,'+3.00% damage contra bosses e Sinister Embraced',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',6,null,'fierce_berserk_critical_extra_damage_20',
  20,'percent','spell',
  'fierce-berserk',null,'+20% critical extra damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',7,null,'mana_leech',
  2,'percent','global',
  null,null,'+2.00% mana leech',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',8,null,'fierce_berserk_critical_extra_damage_40',
  40,'percent','spell',
  'fierce-berserk',null,'+40% critical extra damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',9,null,'fierce_berserk_base_damage',
  8,'percent','spell',
  'fierce-berserk',null,'+8% base damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',10,null,'skill_spell_extra_damage_percent',
  10,'percent','spells',
  null,'club_fighting','+10.00% do seu Club Fighting como extra damage para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',11,null,'fierce_berserk_critical_chance',
  3,'percent','spell',
  'fierce-berserk',null,'+3% critical hit chance para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',12,null,'attack',
  1,'flat','global',
  null,null,'+1 attack',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',13,null,'critical_extra_damage',
  10,'percent','global',
  null,null,'+10.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',14,null,'magic_level_spell_extra_healing_percent',
  500,'percent','healing_spells',
  null,'magic_level','+500.00% do seu Magic Level como extra healing para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-cudgel',15,null,'critical_chance',
  3,'percent','global',
  null,null,'+3.00% critical hit chance',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Cudgel','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',1,null,'skill_bonus',
  1,'flat','global',
  null,'axe_fighting','+1 Axe Fighting',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',2,null,'auto_attack_critical_extra_damage',
  10,'percent','auto_attack',
  null,null,'+10.00% critical extra damage para auto-attacks',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',3,null,'skill_auto_attack_extra_damage_percent',
  5,'percent','auto_attack',
  null,'axe_fighting','+5.00% do seu Axe Fighting como extra damage para auto-attacks',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',4,null,'life_leech',
  3,'percent','global',
  null,null,'+3.00% life leech',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',5,null,'powerful_foe_damage',
  3,'percent','powerful_foe',
  null,null,'+3.00% damage contra bosses e Sinister Embraced',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',6,null,'fierce_berserk_critical_extra_damage_20',
  20,'percent','spell',
  'fierce-berserk',null,'+20% critical extra damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',7,null,'mana_leech',
  2,'percent','global',
  null,null,'+2.00% mana leech',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',8,null,'fierce_berserk_critical_extra_damage_40',
  40,'percent','spell',
  'fierce-berserk',null,'+40% critical extra damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',9,null,'fierce_berserk_base_damage',
  8,'percent','spell',
  'fierce-berserk',null,'+8% base damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',10,null,'skill_spell_extra_damage_percent',
  10,'percent','spells',
  null,'axe_fighting','+10.00% do seu Axe Fighting como extra damage para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',11,null,'fierce_berserk_critical_chance',
  3,'percent','spell',
  'fierce-berserk',null,'+3% critical hit chance para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',12,null,'attack',
  1,'flat','global',
  null,null,'+1 attack',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',13,null,'critical_extra_damage',
  10,'percent','global',
  null,null,'+10.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',14,null,'magic_level_spell_extra_healing_percent',
  1000,'percent','healing_spells',
  null,'magic_level','+1000.00% do seu Magic Level como extra healing para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-hatchet',15,null,'critical_chance',
  3,'percent','global',
  null,null,'+3.00% critical hit chance',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Hatchet','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',1,null,'skill_bonus',
  1,'flat','global',
  null,'sword_fighting','+1 Sword Fighting',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',2,null,'skill_auto_attack_extra_damage_percent',
  5,'percent','auto_attack',
  null,'sword_fighting','+5.00% do seu Sword Fighting como extra damage para auto-attacks',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',3,null,'fierce_berserk_life_leech',
  5,'percent','spell',
  'fierce-berserk',null,'+5% life leech para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',4,null,'critical_extra_damage_4',
  4,'percent','global',
  null,null,'+4.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',5,null,'powerful_foe_damage',
  3,'percent','powerful_foe',
  null,null,'+3.00% damage contra bosses e Sinister Embraced',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',6,null,'fierce_berserk_mana_leech',
  4,'percent','spell',
  'fierce-berserk',null,'+4% mana leech para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',7,null,'critical_extra_damage_8',
  8,'percent','global',
  null,null,'+8.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',8,null,'fierce_berserk_critical_extra_damage_40',
  40,'percent','spell',
  'fierce-berserk',null,'+40% critical extra damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',9,null,'fierce_berserk_base_damage',
  8,'percent','spell',
  'fierce-berserk',null,'+8% base damage para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',10,null,'skill_spell_extra_damage_percent',
  10,'percent','spells',
  null,'sword_fighting','+10.00% do seu Sword Fighting como extra damage para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',11,null,'fierce_berserk_critical_chance',
  3,'percent','spell',
  'fierce-berserk',null,'+3% critical hit chance para Fierce Berserk',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',12,null,'attack',
  1,'flat','global',
  null,null,'+1 attack',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',13,null,'critical_extra_damage_10',
  10,'percent','global',
  null,null,'+10.00% critical extra damage',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',14,null,'magic_level_spell_extra_healing_percent',
  1000,'percent','healing_spells',
  null,'magic_level','+1000.00% do seu Magic Level como extra healing para suas spells',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
),
(
  'grand-sanguine-razor',15,null,'critical_chance',
  3,'percent','global',
  null,null,'+3.00% critical hit chance',
  'https://www.tibiawiki.com.br/wiki/Grand_Sanguine_Razor','B','{"source":"TibiaWiki BR","topology_status":"flattened_source_order","level_assignment_known":false}'::jsonb
);
