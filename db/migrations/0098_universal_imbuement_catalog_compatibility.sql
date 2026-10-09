-- HuntNexus — universal Powerful Imbuement catalog and factual item compatibility.
-- Current Tier-B catalog has 24 imbuement types.
-- Factual compatibility is separated from hunt-context priority and final assignment.

insert into public.imbuement_definitions(
  imbuement_key,name,category,effect_key,powerful_value,unit,proc_chance_percent,
  applicable_categories,source_id,source_url,observed_at,notes
) values
  ('bash','Bash','skill','club_fighting',4,'levels',null,'["Club Weapons","Helmets"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful Club Fighting boost.'),
  ('blockade','Blockade','skill','shielding',4,'levels',null,'["Helmets","Shields","Spellbooks"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful Shielding boost.'),
  ('chop','Chop','skill','axe_fighting',4,'levels',null,'["Axe Weapons","Helmets"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful Axe Fighting boost.'),
  ('cloud-fabric','Cloud Fabric','protection','energy',15,'percent',null,'["Armors","Shields","Spellbooks"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful elemental protection.'),
  ('demon-presence','Demon Presence','protection','holy',15,'percent',null,'["Armors","Shields","Spellbooks"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful elemental protection.'),
  ('dragon-hide','Dragon Hide','protection','fire',15,'percent',null,'["Armors","Shields","Spellbooks"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful elemental protection.'),
  ('electrify','Electrify','damage_conversion','energy',50,'percent',null,'["Axe Weapons","Club Weapons","Sword Weapons","Bows","Crossbows"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Powerful physical-to-energy damage conversion.'),
  ('epiphany','Epiphany','skill','magic_level',4,'levels',null,'["Helmets","Rods","Wands"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful Magic Level boost.'),
  ('featherweight','Featherweight','support','capacity',15,'percent',null,'["Backpacks"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Powerful capacity increase; backpacks are outside the current equipment-slot catalog.'),
  ('frost','Frost','damage_conversion','ice',50,'percent',null,'["Axe Weapons","Club Weapons","Sword Weapons","Bows","Crossbows"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Powerful physical-to-ice damage conversion.'),
  ('lich-shroud','Lich Shroud','protection','death',10,'percent',null,'["Armors","Shields","Spellbooks"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful death protection.'),
  ('precision','Precision','skill','distance_fighting',4,'levels',null,'["Bows","Crossbows","Helmets"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful Distance Fighting boost.'),
  ('punch','Punch','skill','fist_fighting',4,'levels',null,'["Fist Fighting Weapons","Helmets"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Punch_(Skillboost_de_Punhos)','2026-10-09 00:00:00+00'::timestamptz,'Powerful Fist Fighting boost. Dedicated current item page says Fist weapons and Helmets.'),
  ('quara-scale','Quara Scale','protection','ice',15,'percent',null,'["Armors","Shields","Spellbooks"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful elemental protection.'),
  ('reap','Reap','damage_conversion','death',50,'percent',null,'["Axe Weapons","Club Weapons","Sword Weapons","Bows","Crossbows"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Powerful physical-to-death damage conversion.'),
  ('scorch','Scorch','damage_conversion','fire',50,'percent',null,'["Axe Weapons","Club Weapons","Sword Weapons","Bows","Crossbows"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Powerful physical-to-fire damage conversion.'),
  ('slash','Slash','skill','sword_fighting',4,'levels',null,'["Sword Weapons","Helmets"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful Sword Fighting boost.'),
  ('snake-skin','Snake Skin','protection','earth',15,'percent',null,'["Armors","Shields","Spellbooks"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful elemental protection.'),
  ('strike','Strike','offense','critical_extra_damage',50,'percent',10,'["Axe Weapons","Club Weapons","Sword Weapons","Bows","Crossbows","Rods","Wands"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Powerful critical damage; proc chance is 10%. Rod/Wand item restrictions can depend on item level.'),
  ('swiftness','Swiftness','support','speed',30,'speed_points',null,'["Boots"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Powerful speed boost.'),
  ('vampirism','Vampirism','sustain','life_leech',25,'percent',100,'["Armors","Bows","Crossbows","Club Weapons","Sword Weapons","Axe Weapons","Rods","Wands"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful life leech.'),
  ('venom','Venom','damage_conversion','earth',50,'percent',null,'["Axe Weapons","Club Weapons","Sword Weapons","Bows","Crossbows"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Powerful physical-to-earth damage conversion.'),
  ('vibrancy','Vibrancy','support','paralysis_avoid_chance',50,'percent',null,'["Boots"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Powerful chance to avoid/remove paralysis.'),
  ('void','Void','sustain','mana_leech',8,'percent',100,'["Bows","Crossbows","Helmets","Club Weapons","Sword Weapons","Axe Weapons","Rods","Wands"]'::jsonb,'53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-07 17:33:36.60898+00'::timestamptz,'Powerful mana leech.')
on conflict (imbuement_key) do update set
  name=excluded.name,
  category=excluded.category,
  effect_key=excluded.effect_key,
  powerful_value=excluded.powerful_value,
  unit=excluded.unit,
  proc_chance_percent=excluded.proc_chance_percent,
  applicable_categories=excluded.applicable_categories,
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=excluded.observed_at,
  notes=excluded.notes;

create table if not exists public.imbuement_applicability_rules (
  imbuement_key text not null references public.imbuement_definitions(imbuement_key) on delete cascade,
  target_domain text not null check (target_domain in ('weapon','equipment','container')),
  target_family text not null,
  min_item_level integer not null default 0 check (min_item_level >= 0),
  source_tier text not null default 'B',
  source_id uuid references public.sources(id),
  source_url text not null,
  observed_at timestamptz not null,
  notes text,
  primary key (imbuement_key,target_domain,target_family)
);

alter table public.imbuement_applicability_rules enable row level security;
revoke all on public.imbuement_applicability_rules from public,anon,authenticated;
grant select on public.imbuement_applicability_rules to service_role;

delete from public.imbuement_applicability_rules;

insert into public.imbuement_applicability_rules(
  imbuement_key,target_domain,target_family,min_item_level,source_tier,
  source_id,source_url,observed_at,notes
) values
  ('bash','equipment','helmet',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('bash','weapon','club',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('blockade','equipment','helmet',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('blockade','equipment','shield',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('blockade','equipment','spellbook',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('chop','equipment','helmet',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('chop','weapon','axe',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('cloud-fabric','equipment','armor',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('cloud-fabric','equipment','shield',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('cloud-fabric','equipment','spellbook',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('demon-presence','equipment','armor',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('demon-presence','equipment','shield',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('demon-presence','equipment','spellbook',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('dragon-hide','equipment','armor',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('dragon-hide','equipment','shield',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('dragon-hide','equipment','spellbook',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('electrify','weapon','axe',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('electrify','weapon','bow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('electrify','weapon','club',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('electrify','weapon','crossbow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('electrify','weapon','sword',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('epiphany','equipment','helmet',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('epiphany','weapon','rod',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('epiphany','weapon','wand',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('featherweight','container','backpack',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Backpacks are outside current weapon/equipment catalog scope.'),
  ('frost','weapon','axe',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('frost','weapon','bow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('frost','weapon','club',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('frost','weapon','crossbow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('frost','weapon','sword',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('lich-shroud','equipment','armor',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('lich-shroud','equipment','shield',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('lich-shroud','equipment','spellbook',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('precision','equipment','helmet',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('precision','weapon','bow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('precision','weapon','crossbow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('punch','equipment','helmet',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Punch_(Skillboost_de_Punhos)','2026-10-09 00:00:00+00'::timestamptz,'Dedicated current Punch page used because aggregate page contains stale applicability text.'),
  ('punch','weapon','fist',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Punch_(Skillboost_de_Punhos)','2026-10-09 00:00:00+00'::timestamptz,'Dedicated current Punch page used because aggregate page contains stale applicability text.'),
  ('quara-scale','equipment','armor',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('quara-scale','equipment','shield',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('quara-scale','equipment','spellbook',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('reap','weapon','axe',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('reap','weapon','bow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('reap','weapon','club',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('reap','weapon','crossbow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('reap','weapon','sword',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('scorch','weapon','axe',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('scorch','weapon','bow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('scorch','weapon','club',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('scorch','weapon','crossbow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('scorch','weapon','sword',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('slash','equipment','helmet',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('slash','weapon','sword',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('snake-skin','equipment','armor',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('snake-skin','equipment','shield',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('snake-skin','equipment','spellbook',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('strike','weapon','axe',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('strike','weapon','bow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('strike','weapon','club',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('strike','weapon','crossbow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('strike','weapon','rod',200,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Strike on Rods requires item level 200+.'),
  ('strike','weapon','sword',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('strike','weapon','wand',200,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,'Strike on Wands requires item level 200+.'),
  ('swiftness','equipment','boots',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('vampirism','equipment','armor',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('vampirism','weapon','axe',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('vampirism','weapon','bow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('vampirism','weapon','club',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('vampirism','weapon','crossbow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('vampirism','weapon','rod',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('vampirism','weapon','sword',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('vampirism','weapon','wand',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('venom','weapon','axe',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('venom','weapon','bow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('venom','weapon','club',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('venom','weapon','crossbow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('venom','weapon','sword',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('vibrancy','equipment','boots',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('void','equipment','helmet',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('void','weapon','axe',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('void','weapon','bow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('void','weapon','club',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('void','weapon','crossbow',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('void','weapon','rod',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('void','weapon','sword',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null),
  ('void','weapon','wand',0,'B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/Imbuements','2026-10-09 00:00:00+00'::timestamptz,null);

create or replace view public.vw_imbuement_catalog_universal
with (security_invoker=true)
as
 SELECT d.imbuement_key,
    d.name,
    d.category,
    d.effect_key,
    d.powerful_value,
    d.unit,
    d.proc_chance_percent,
    count(r.imbuement_key)::integer AS applicability_rule_count,
    COALESCE(jsonb_agg(jsonb_build_object('target_domain', r.target_domain, 'target_family', r.target_family, 'min_item_level', r.min_item_level, 'source_tier', r.source_tier, 'source_url', r.source_url, 'observed_at', r.observed_at, 'notes', r.notes) ORDER BY r.target_domain, r.target_family) FILTER (WHERE r.imbuement_key IS NOT NULL), '[]'::jsonb) AS applicability_rules,
    d.source_id,
    d.source_url,
    d.observed_at,
    d.notes
   FROM imbuement_definitions d
     LEFT JOIN imbuement_applicability_rules r ON r.imbuement_key = d.imbuement_key
  GROUP BY d.imbuement_key, d.name, d.category, d.effect_key, d.powerful_value, d.unit, d.proc_chance_percent, d.source_id, d.source_url, d.observed_at, d.notes;

revoke all on public.vw_imbuement_catalog_universal from public,anon,authenticated;
grant select on public.vw_imbuement_catalog_universal to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_item_imbuement_compatibility_universal(p_item_key text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with item as (
  select
    'weapon'::text as item_domain,
    w.item_key,w.name,w.weapon_family as item_family,w.level_required,
    coalesce(w.imbue_slots,0) as imbue_slots,w.source_category
  from vw_weapon_catalog_universal w
  where w.item_key=p_item_key
  union all
  select
    'equipment'::text as item_domain,
    e.item_key,e.name,e.equipment_family as item_family,e.level_required,
    coalesce(e.imbue_slots,0) as imbue_slots,e.source_category
  from vw_equipment_catalog_universal e
  where e.item_key=p_item_key
  limit 1
),
matches as (
  select
    d.imbuement_key,d.name,d.category,d.effect_key,d.powerful_value,d.unit,
    d.proc_chance_percent,r.min_item_level,r.source_tier,r.source_url,
    r.notes as applicability_notes,
    case
      when i.imbue_slots<=0 then 'blocked'
      when i.level_required<r.min_item_level then 'blocked'
      else 'eligible'
    end as eligibility_status,
    array_remove(array[
      case when i.imbue_slots<=0 then 'no_imbuement_slots' end,
      case when i.level_required<r.min_item_level then 'minimum_item_level' end
    ],null) as blocking_reasons
  from item i
  join imbuement_applicability_rules r
    on r.target_domain=i.item_domain
   and r.target_family=i.item_family
  join imbuement_definitions d on d.imbuement_key=r.imbuement_key
)
select coalesce((
  select jsonb_build_object(
    'item',jsonb_build_object(
      'item_key',i.item_key,
      'name',i.name,
      'item_domain',i.item_domain,
      'item_family',i.item_family,
      'source_category',i.source_category,
      'level_required',i.level_required,
      'imbue_slots',i.imbue_slots
    ),
    'summary',jsonb_build_object(
      'known_compatible_imbuements',(select count(*) from matches),
      'eligible',(select count(*) from matches where eligibility_status='eligible'),
      'blocked',(select count(*) from matches where eligibility_status='blocked')
    ),
    'coverage',jsonb_build_object(
      'source_driven',true,
      'source_scope_note',
        case
          when i.item_domain='weapon' and i.item_family='fist'
            then 'Current source explicitly confirms Punch for Fist weapons. Other imbuements are not inferred for Fist without explicit applicability evidence.'
          else null
        end,
      'unconfirmed_imbuements_are_not_inferred',true
    ),
    'candidates',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'imbuement_key',m.imbuement_key,
          'name',m.name,
          'category',m.category,
          'effect_key',m.effect_key,
          'powerful_value',m.powerful_value,
          'unit',m.unit,
          'proc_chance_percent',m.proc_chance_percent,
          'min_item_level',m.min_item_level,
          'eligibility_status',m.eligibility_status,
          'blocking_reasons',to_jsonb(m.blocking_reasons),
          'source_tier',m.source_tier,
          'source_url',m.source_url,
          'applicability_notes',m.applicability_notes
        )
        order by
          case m.eligibility_status when 'eligible' then 0 else 1 end,
          m.category,m.name
      )
      from matches m
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','item_imbuement_compatibility_universal_v1',
      'category_first',true,
      'powerful_tier_only',true,
      'hunt_priority_applied',false,
      'final_assignment',false,
      'slot_capacity_used_as_eligibility_gate',true,
      'multiple_candidates_do_not_imply_simultaneous_assignment',true,
      'source_driven_applicability',true
    )
  )
  from item i
),jsonb_build_object(
  'error','item_not_found',
  'item_key',p_item_key,
  'methodology',jsonb_build_object(
    'stage','item_imbuement_compatibility_universal_v1'
  )
));
$function$
;

revoke all on function public.huntnexus_item_imbuement_compatibility_universal(text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_item_imbuement_compatibility_universal(text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_imbuement_category_audit()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select jsonb_build_object(
  'summary',jsonb_build_object(
    'powerful_definitions',(select count(*) from imbuement_definitions),
    'applicability_rules',(select count(*) from imbuement_applicability_rules),
    'definitions_without_rules',(
      select count(*)
      from imbuement_definitions d
      where not exists (
        select 1 from imbuement_applicability_rules r
        where r.imbuement_key=d.imbuement_key
      )
    ),
    'categories',(select count(distinct category) from imbuement_definitions),
    'source_catalog_complete_for_current_24',(
      (select count(*) from imbuement_definitions)=24
      and (
        select count(*)
        from imbuement_definitions d
        where not exists (
          select 1 from imbuement_applicability_rules r
          where r.imbuement_key=d.imbuement_key
        )
      )=0
    ),
    'factual_compatibility_ready',true,
    'hunt_context_priority_ready',false,
    'final_assignment_ready',false
  ),
  'scope',jsonb_build_object(
    'weapon_families',coalesce((
      select jsonb_agg(distinct target_family order by target_family)
      from imbuement_applicability_rules where target_domain='weapon'
    ),'[]'::jsonb),
    'equipment_families',coalesce((
      select jsonb_agg(distinct target_family order by target_family)
      from imbuement_applicability_rules where target_domain='equipment'
    ),'[]'::jsonb),
    'container_families',coalesce((
      select jsonb_agg(distinct target_family order by target_family)
      from imbuement_applicability_rules where target_domain='container'
    ),'[]'::jsonb),
    'current_catalog_outside_scope',jsonb_build_array('backpack')
  ),
  'known_caveats',jsonb_build_array(
    jsonb_build_object(
      'key','fist_applicability',
      'status','source_strict',
      'note','Punch is explicitly confirmed for Fist weapons. Other imbuements are not inferred without explicit current applicability evidence.'
    ),
    jsonb_build_object(
      'key','powerful_only',
      'status','intentional',
      'note','Current normalized definition layer stores Powerful values; Basic/Intricate tier modeling remains separate future work.'
    )
  ),
  'methodology',jsonb_build_object(
    'stage','imbuement_category_audit_v1',
    'category_first',true,
    'legacy_functions_preserved',true,
    'source_driven_applicability',true,
    'hunt_priority_applied',false,
    'final_assignment_applied',false
  )
);
$function$
;

revoke all on function public.huntnexus_imbuement_category_audit()
  from public,anon,authenticated;
grant execute on function public.huntnexus_imbuement_category_audit()
  to service_role;
