-- HuntNexus Brain — Phase 14 factual imbuement definitions and hunt candidates.
-- Tier B reference: TibiaWiki BR Imbuements.
-- Uses Powerful values where the factual source exposes exact values.

create table if not exists imbuement_definitions (
  imbuement_key text primary key,
  name text not null,
  category text not null,
  effect_key text not null,
  powerful_value numeric,
  unit text not null,
  proc_chance_percent numeric,
  applicable_categories jsonb not null default '[]'::jsonb,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now(),
  notes text
);

insert into imbuement_definitions(
  imbuement_key,name,category,effect_key,powerful_value,unit,proc_chance_percent,
  applicable_categories,source_id,source_url,notes
)
select x.imbuement_key,x.name,x.category,x.effect_key,x.powerful_value,x.unit,x.proc_chance_percent,
       x.applicable_categories,s.id,'https://www.tibiawiki.com.br/Imbuements',x.notes
from sources s
cross join (
  values
    ('cloud-fabric','Cloud Fabric','protection','energy',15,'percent',null,
      '["Armors","Shields","Spellbooks"]'::jsonb,'Powerful elemental protection.'),
    ('demon-presence','Demon Presence','protection','holy',15,'percent',null,
      '["Armors","Shields","Spellbooks"]'::jsonb,'Powerful elemental protection.'),
    ('dragon-hide','Dragon Hide','protection','fire',15,'percent',null,
      '["Armors","Shields","Spellbooks"]'::jsonb,'Powerful elemental protection.'),
    ('quara-scale','Quara Scale','protection','ice',15,'percent',null,
      '["Armors","Shields","Spellbooks"]'::jsonb,'Powerful elemental protection.'),
    ('snake-skin','Snake Skin','protection','earth',15,'percent',null,
      '["Armors","Shields","Spellbooks"]'::jsonb,'Powerful elemental protection.'),
    ('lich-shroud','Lich Shroud','protection','death',10,'percent',null,
      '["Armors","Shields","Spellbooks"]'::jsonb,'Powerful death protection.'),
    ('vampirism','Vampirism','sustain','life_leech',25,'percent',100,
      '["Armors","Bows","Crossbows","Club Weapons","Sword Weapons","Axe Weapons","Rods","Wands"]'::jsonb,
      'Powerful life leech.'),
    ('void','Void','sustain','mana_leech',8,'percent',100,
      '["Bows","Crossbows","Helmets","Club Weapons","Sword Weapons","Axe Weapons","Rods","Wands"]'::jsonb,
      'Powerful mana leech.'),
    ('strike','Strike','offense','critical_extra_damage',50,'percent',10,
      '["Axe Weapons","Club Weapons","Sword Weapons","Bows","Rods","Wands"]'::jsonb,
      'Powerful critical damage; proc chance is 10%. Rod/Wand item restrictions can depend on item level.'),
    ('epiphany','Epiphany','skill','magic_level',4,'levels',null,
      '["Helmets","Rods","Wands"]'::jsonb,'Powerful Magic Level boost.'),
    ('precision','Precision','skill','distance_fighting',4,'levels',null,
      '["Bows","Crossbows","Helmets"]'::jsonb,'Powerful Distance Fighting boost.'),
    ('slash','Slash','skill','sword_fighting',4,'levels',null,
      '["Sword Weapons","Helmets"]'::jsonb,'Powerful Sword Fighting boost.'),
    ('chop','Chop','skill','axe_fighting',4,'levels',null,
      '["Axe Weapons","Helmets"]'::jsonb,'Powerful Axe Fighting boost.'),
    ('bash','Bash','skill','club_fighting',4,'levels',null,
      '["Club Weapons","Helmets"]'::jsonb,'Powerful Club Fighting boost.'),
    ('blockade','Blockade','skill','shielding',4,'levels',null,
      '["Helmets","Shields","Spellbooks"]'::jsonb,'Powerful Shielding boost.')
) as x(
  imbuement_key,name,category,effect_key,powerful_value,unit,proc_chance_percent,
  applicable_categories,notes
)
where s.name='TibiaWiki BR'
on conflict(imbuement_key) do update set
  name=excluded.name,
  category=excluded.category,
  effect_key=excluded.effect_key,
  powerful_value=excluded.powerful_value,
  unit=excluded.unit,
  proc_chance_percent=excluded.proc_chance_percent,
  applicable_categories=excluded.applicable_categories,
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=now(),
  notes=excluded.notes;

create or replace function huntnexus_imbuement_candidates(
  p_hunt_key text,
  p_vocation text
)
returns jsonb
language sql
stable
as $$
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
  'methodology',jsonb_build_object(
    'stage','imbuement_candidates',
    'final_assignment_to_items',false,
    'defensive_priority_is_data_driven',true,
    'offense_sustain_priority_is_not_inferred',true,
    'note','Elemental protection is ordered by observed incoming damage. Strike, leech and skill boosts remain separate factual candidates until slot/build optimization.'
  )
);
$$;

revoke all on function huntnexus_imbuement_candidates(text,text)
  from public,anon,authenticated;
grant execute on function huntnexus_imbuement_candidates(text,text)
  to service_role;
