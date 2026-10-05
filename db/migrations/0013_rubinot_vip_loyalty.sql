-- HuntNexus Brain — Phase 6.2 RubinOT VIP/Loyalty modifiers.

insert into sources(name,tier,layer,url,status,collection_method,last_access_status,last_checked_at)
values (
  'RubinOT Website',
  'A',
  'rubinot_overlay',
  'https://rubinot.com.br',
  'active',
  'browser/web fetch',
  'official website; use browser/web-compatible collection where direct HTTP is blocked',
  now()
)
on conflict (name) do update set
  tier=excluded.tier,
  layer=excluded.layer,
  url=excluded.url,
  status=excluded.status,
  collection_method=excluded.collection_method,
  last_access_status=excluded.last_access_status,
  last_checked_at=excluded.last_checked_at;

create table if not exists rubinot_loyalty_tiers (
  title_name text primary key,
  required_points int not null,
  skill_bonus int not null,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now()
);

insert into rubinot_modifier_definitions(
  modifier_key,system_key,category,target_dimension,unit,value_mode,
  allowed_targets,source_id,source_url,observed_at,notes
)
select
  'vip.weapon_proficiency_xp',
  'vip',
  'proficiency',
  'weapon_proficiency_xp',
  'percent',
  'dynamic',
  '[]'::jsonb,
  s.id,
  'https://rubinot.com.br/vip',
  now(),
  'Official VIP page states an additional 10% Weapon Proficiency experience while the VIP bonus applies.'
from sources s
where s.name='RubinOT Website'
on conflict (modifier_key) do update set
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=excluded.observed_at,
  notes=excluded.notes;

insert into rubinot_system_facts(
  system_key,fact_key,value,source_id,source_url,notes
)
select
  'vip','weapon_proficiency_bonus',
  '{"value":10,"unit":"percent","target":"weapon_proficiency_xp"}'::jsonb,
  s.id,
  'https://rubinot.com.br/vip',
  'Static value published on the official VIP page.'
from sources s
where s.name='RubinOT Website';

insert into rubinot_loyalty_tiers(
  title_name,required_points,skill_bonus,source_id,source_url
)
select x.title_name,x.required_points,x.skill_bonus,s.id,'https://rubinot.com.br/vip'
from sources s
cross join (
  values
    ('Scout of RubinOT',0,0),
    ('Sentinel of RubinOT',1,1),
    ('Steward of RubinOT',3,2),
    ('Warden of RubinOT',6,3),
    ('Squire of RubinOT',9,4),
    ('Warrior of RubinOT',15,5),
    ('Keeper of RubinOT',21,6),
    ('Guardian of RubinOT',30,7),
    ('Sage of RubinOT',42,8),
    ('Savant of RubinOT',56,9),
    ('Enlightened of RubinOT',70,10)
) as x(title_name,required_points,skill_bonus)
where s.name='RubinOT Website'
on conflict (title_name) do update set
  required_points=excluded.required_points,
  skill_bonus=excluded.skill_bonus,
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=now();

insert into rubinot_system_facts(
  system_key,fact_key,value,source_id,source_url,notes
)
select
  'loyalty','vocation_skill_mapping',
  '{
    "knight":["axe","sword","club","shielding"],
    "paladin":["distance","shielding"],
    "druid":["magic_level"],
    "sorcerer":["magic_level"],
    "monk":["magic_level","fist_fighting"]
  }'::jsonb,
  s.id,
  'https://rubinot.com.br/vip',
  'Official Loyalty skill mapping by vocation.'
from sources s
where s.name='RubinOT Website';
