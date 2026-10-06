-- HuntNexus Brain — Phase 15 core spell catalogue and spell candidates.
-- Tier B factual source: TibiaWiki BR.

create table if not exists spell_definitions (
  spell_key text primary key,
  name text not null,
  words text,
  vocation text not null,
  min_level int not null,
  spell_group text not null,
  mana_cost int,
  cooldown_seconds numeric,
  group_cooldown_seconds numeric,
  base_power numeric,
  scaling text,
  element text,
  area_type text,
  max_targets int,
  lever_boss_restricted boolean not null default false,
  effect_summary text,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now()
);

insert into spell_definitions(
  spell_key,name,words,vocation,min_level,spell_group,mana_cost,
  cooldown_seconds,group_cooldown_seconds,base_power,scaling,element,
  area_type,max_targets,lever_boss_restricted,effect_summary,
  source_id,source_url
)
select
  x.spell_key,x.name,x.words,x.vocation,x.min_level,x.spell_group,x.mana_cost,
  x.cooldown_seconds,x.group_cooldown_seconds,x.base_power,x.scaling,x.element,
  x.area_type,x.max_targets,x.lever_boss_restricted,x.effect_summary,
  s.id,x.source_url
from sources s
cross join (
  values
  -- Knight
  ('berserk','Berserk','exori','EK',35,'attack',125,4,2,44,'weapon + melee skill','weapon','around',8,false,
   'Hits adjacent area; enchanted weapon can convert part of the damage.',
   'https://www.tibiawiki.com.br/Berserk'),
  ('fierce-berserk','Fierce Berserk','exori gran','EK',90,'attack',360,6,2,92,'weapon + melee skill','weapon','around',8,false,
   'Higher-power adjacent-area weapon-based attack.',
   'https://www.tibiawiki.com.br/wiki/Exori_Gran'),
  ('front-sweep','Front Sweep','exori min','EK',70,'attack',200,6,2,80,'weapon + melee skill','weapon','frontal',3,false,
   'Hits three squares in front; enchanted weapon can convert part of the damage.',
   'https://www.tibiawiki.com.br/wiki/Front_Sweep'),
  ('annihilation','Annihilation','exori gran ico','EK',110,'attack',300,30,2,125,'weapon + melee skill','weapon','single',1,false,
   'High-power single-target melee attack; weapon element can affect part of the damage.',
   'https://www.tibiawiki.com.br/wiki/Annihilation'),
  ('wound-cleansing','Wound Cleansing','exura ico','EK',8,'healing',60,2,2,70,'magic level + shielding',null,'self',1,false,
   'Standard Knight self-heal.',
   'https://tibiawiki.com.br/Wound%20Cleansing'),
  ('intense-wound-cleansing','Intense Wound Cleansing','exura gran ico','EK',80,'healing',300,120,2,500,'magic level + shielding',null,'self',1,false,
   'High-power Knight self-heal with long individual cooldown.',
   'https://tibiawiki.com.br/Intense_Wound_Cleansing'),
  ('blood-rage','Blood Rage','utito tempo','EK',20,'support',20,null,null,null,'melee skill',null,'self',1,false,
   'Raises melee skill by 25%, removes blocking ability and increases incoming damage by 15%.',
   'https://www.tibiawiki.com.br/wiki/Magias'),
  ('challenge','Challenge','exeta res','EK',20,'support',40,null,null,null,null,null,'around',null,false,
   'Taunts nearby creatures.',
   'https://www.tibiawiki.com.br/wiki/Magias'),
  ('chivalrous-challenge','Chivalrous Challenge','exeta amp res','EK',150,'support',80,null,null,null,null,null,'multi_target',4,true,
   'Forces ranged creatures into melee behavior; documented as unavailable against some lever bosses.',
   'https://www.tibiawiki.com.br/wiki/Magias'),

  -- Paladin
  ('divine-caldera','Divine Caldera','exevo mas san','RP',50,'attack',160,4,2,150,'magic level','holy','around',null,false,
   'Large holy area around the Paladin.',
   'https://www.tibiawiki.com.br/wiki/Exevo_Mas_San'),
  ('divine-barrage','Divine Barrage','exori dir san','RP',70,'attack',175,4,2,130,'magic level','holy','target_aoe',null,false,
   'Holy damage to target and surrounding area.',
   'https://www.tibiawiki.com.br/wiki/Divine_Barrage'),
  ('strong-ethereal-spear','Strong Ethereal Spear','exori gran con','RP',90,'attack',55,8,2,38,'distance fighting','physical','single',1,false,
   'Single-target physical attack.',
   'https://www.tibiawiki.com.br/Strong_Ethereal_Spear'),
  ('divine-healing','Divine Healing','exura san','RP',35,'healing',160,1,1,250,'magic level',null,'self',1,false,
   'Primary Paladin self-heal.',
   'https://www.tibiawiki.com.br/wiki/Divine_Healing'),
  ('divine-dazzle','Divine Dazzle','exana amp res','RP',250,'support',80,null,null,null,null,null,'multi_target',3,true,
   'Forces ranged creatures into melee behavior; documented as unavailable against lever bosses.',
   'https://www.tibiawiki.com.br/wiki/Magias'),
  ('divine-defiance','Divine Defiance','utori hur','RP',20,'support',250,null,null,null,'distance fighting',null,'self',1,false,
   'Defensive stance converting part of Distance Fighting into Holy/Healing Magic Level and granting ranged evasion.',
   'https://www.tibiawiki.com.br/wiki/Magias'),

  -- Druid
  ('terra-wave','Terra Wave','exevo tera hur','ED',38,'attack',170,4,2,120,'magic level','earth','wave',null,false,
   'Earth wave.',
   'https://www.tibiawiki.com.br/wiki/Terra_Wave'),
  ('strong-ice-wave','Strong Ice Wave','exevo gran frigo hur','ED',40,'attack',170,4,2,140,'magic level','ice','wave',null,false,
   'High-power ice wave.',
   'https://www.tibiawiki.com.br/wiki/Strong_Ice_Wave'),
  ('forked-glacier','Forked Glacier','exevo fur frigo','ED',90,'attack',180,6,2,90,'magic level','ice','chain',7,false,
   'Ice chain attack hitting target and up to six nearby targets.',
   'https://www.tibiawiki.com.br/wiki/Forked_Glacier'),
  ('forked-thorns','Forked Thorns','exevo fur tera','ED',80,'attack',180,6,2,97,'magic level','earth','chain',6,false,
   'Earth chain attack hitting target and up to five nearby targets.',
   'https://www.tibiawiki.com.br/wiki/Forked_Thorns'),
  ('strong-terra-strike','Strong Terra Strike','exori gran tera','ED',70,'attack',60,8,2,115,'magic level','earth','single',1,false,
   'Strong single-target earth spell.',
   'https://www.tibiawiki.com.br/wiki/Strong_Terra_Strike'),
  ('strong-ice-strike','Strong Ice Strike','exori gran frigo','ED',80,'attack',60,8,2,115,'magic level','ice','single',1,false,
   'Strong single-target ice spell.',
   'https://www.tibiawiki.com.br/wiki/Strong_Ice_Strike'),
  ('ultimate-terra-strike','Ultimate Terra Strike','exori max tera','ED',90,'attack',100,30,2,195,'magic level','earth','single',1,false,
   'High-power single-target earth spell.',
   'https://www.tibiawiki.com.br/Ultimate_Terra_Strike'),
  ('ultimate-ice-strike','Ultimate Ice Strike','exori max frigo','ED',100,'attack',100,30,2,195,'magic level','ice','single',1,false,
   'High-power single-target ice spell.',
   'https://www.tibiawiki.com.br/wiki/Ultimate_Ice_Strike'),
  ('eternal-winter','Eternal Winter','exevo gran mas frigo','ED',60,'attack',1050,40,4,200,'magic level','ice','ultimate_aoe',null,false,
   'Large-area ice focus spell.',
   'https://www.tibiawiki.com.br/wiki/Eternal_Winter'),
  ('mass-healing','Mass Healing','exura gran mas res','ED',36,'healing',150,2,1,200,'magic level',null,'party_aoe',null,false,
   'Heals nearby party members and summons.',
   'https://www.tibiawiki.com.br/wiki/Mass_Healing'),
  ('ultimate-healing-ed','Ultimate Healing','exura vita','ED',30,'healing',160,1,1,250,'magic level',null,'self',1,false,
   'Strong self-heal.',
   'https://www.tibiawiki.com.br/Ultimate_Healing'),
  ('elemental-synthesis','Elemental Synthesis','utito dru','ED',20,'support',400,null,null,null,'magic level','ice_earth','self',1,false,
   'Stance granting additional Ice/Earth Magic Level based on Magic Level.',
   'https://www.tibiawiki.com.br/wiki/Magias'),

  -- Sorcerer
  ('energy-wave','Energy Wave','exevo vis hur','MS',38,'attack',170,8,2,150,'magic level','energy','wave',null,false,
   'Energy cone/wave.',
   'https://www.tibiawiki.com.br/wiki/Energy_Wave'),
  ('great-fire-wave','Great Fire Wave','exevo gran flam hur','MS',38,'attack',120,4,2,100,'magic level','fire','wave',null,false,
   'Fire wave.',
   'https://www.tibiawiki.com.br/wiki/Great_Fire_Wave'),
  ('strong-energy-strike','Strong Energy Strike','exori gran vis','MS',80,'attack',60,8,2,125,'magic level','energy','single',1,false,
   'Strong single-target energy spell.',
   'https://www.tibiawiki.com.br/wiki/Strong_Energy_Strike'),
  ('strong-flame-strike','Strong Flame Strike','exori gran flam','MS',70,'attack',60,8,2,125,'magic level','fire','single',1,false,
   'Strong single-target fire spell.',
   'https://www.tibiawiki.com.br/wiki/Strong_Flame_Strike'),
  ('ultimate-energy-strike','Ultimate Energy Strike','exori max vis','MS',100,'attack',100,30,2,210,'magic level','energy','single',1,false,
   'High-power single-target energy spell.',
   'https://www.tibiawiki.com.br/wiki/Ultimate_Energy_Strike'),
  ('ultimate-flame-strike','Ultimate Flame Strike','exori max flam','MS',90,'attack',100,30,2,210,'magic level','fire','single',1,false,
   'High-power single-target fire spell.',
   'https://www.tibiawiki.com.br/wiki/Ultimate_Flame_Strike'),
  ('death-echo','Death Echo','exevo mort ora','MS',120,'attack',150,6,2,75,'magic level','death','delayed_aoe',null,false,
   'Death area hit followed by a second larger impact.',
   'https://www.tibiawiki.com.br/wiki/Death_Echo'),
  ('hells-core','Hell''s Core','exevo gran mas flam','MS',60,'attack',1100,40,4,250,'magic level','fire','ultimate_aoe',null,false,
   'Large-area fire focus spell.',
   'https://www.tibiawiki.com.br/Hell%27s_Core'),
  ('rage-of-the-skies','Rage of the Skies','exevo gran mas vis','MS',55,'attack',600,40,4,200,'magic level','energy','ultimate_aoe',null,false,
   'Large-area energy focus spell.',
   'https://www.tibiawiki.com.br/wiki/Rage_of_the_Skies'),
  ('ultimate-healing-ms','Ultimate Healing','exura vita','MS',30,'healing',160,1,1,250,'magic level',null,'self',1,false,
   'Strong self-heal.',
   'https://www.tibiawiki.com.br/Ultimate_Healing'),
  ('aura-exposed-weakness','Aura of Exposed Weakness','exori moe tempo','MS',175,'support',1500,null,null,null,'magic level',null,'stance',null,false,
   'Elemental offense stance applying increased elemental vulnerability to enemies hit.',
   'https://www.tibiawiki.com.br/wiki/Magias'),
  ('aura-sapped-strength','Aura of Sapped Strength','exori kor tempo','MS',175,'support',1500,null,null,null,'magic level',null,'stance',null,false,
   'Defensive stance reducing damage caused by affected enemies.',
   'https://www.tibiawiki.com.br/wiki/Magias')
) as x(
  spell_key,name,words,vocation,min_level,spell_group,mana_cost,
  cooldown_seconds,group_cooldown_seconds,base_power,scaling,element,
  area_type,max_targets,lever_boss_restricted,effect_summary,source_url
)
where s.name='TibiaWiki BR'
on conflict(spell_key) do update set
  name=excluded.name,
  words=excluded.words,
  vocation=excluded.vocation,
  min_level=excluded.min_level,
  spell_group=excluded.spell_group,
  mana_cost=excluded.mana_cost,
  cooldown_seconds=excluded.cooldown_seconds,
  group_cooldown_seconds=excluded.group_cooldown_seconds,
  base_power=excluded.base_power,
  scaling=excluded.scaling,
  element=excluded.element,
  area_type=excluded.area_type,
  max_targets=excluded.max_targets,
  lever_boss_restricted=excluded.lever_boss_restricted,
  effect_summary=excluded.effect_summary,
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=now();

create or replace function huntnexus_spell_candidates(
  p_hunt_key text,
  p_vocation text,
  p_level int,
  p_context text default 'hunt'
)
returns jsonb
language sql
stable
as $$
with params as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation,
    greatest(coalesce(p_level,1),1) as player_level,
    case lower(coalesce(p_context,'hunt'))
      when 'boss' then 'boss'
      else 'hunt'
    end as context
),
mods as (
  select element,kill_weighted_modifier_percent
  from vw_hunt_observed_element_profile
  where hunt_key=p_hunt_key
),
eligible as (
  select
    s.*,
    case
      when s.element='weapon' then null
      when s.element is null then null
      when s.element='ice_earth' then null
      else coalesce(m.kill_weighted_modifier_percent,100)
    end as element_modifier_percent,
    case
      when s.base_power is not null
       and s.element not in ('weapon','ice_earth')
       and s.element is not null
      then s.base_power * coalesce(m.kill_weighted_modifier_percent,100)/100.0
      else null
    end as element_adjusted_base_power_proxy
  from spell_definitions s
  left join mods m on m.element=s.element
  where s.vocation=(select vocation from params)
    and s.min_level<=(select player_level from params)
    and not (
      (select context from params)='boss'
      and s.lever_boss_restricted
    )
),
attack as (
  select *
  from eligible
  where spell_group='attack'
),
support as (
  select *
  from eligible
  where spell_group='support'
),
healing as (
  select *
  from eligible
  where spell_group='healing'
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'hunt_key',p_hunt_key,
    'vocation',(select vocation from params),
    'level',(select player_level from params),
    'context',(select context from params)
  ),
  'single_target_attacks',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',spell_key,'name',name,'words',words,'level',min_level,
        'mana',mana_cost,'cooldown_seconds',cooldown_seconds,
        'group_cooldown_seconds',group_cooldown_seconds,'base_power',base_power,
        'scaling',scaling,'element',element,'area_type',area_type,
        'element_modifier_percent',element_modifier_percent,
        'element_adjusted_base_power_proxy',
          case when element_adjusted_base_power_proxy is null then null
               else round(element_adjusted_base_power_proxy::numeric,2) end,
        'effect_summary',effect_summary
      )
      order by element_modifier_percent desc nulls last,
               element_adjusted_base_power_proxy desc nulls last,
               base_power desc nulls last,
               cooldown_seconds asc nulls last
    )
    from attack
    where area_type='single'
  ),'[]'::jsonb),
  'multi_target_attacks',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',spell_key,'name',name,'words',words,'level',min_level,
        'mana',mana_cost,'cooldown_seconds',cooldown_seconds,
        'group_cooldown_seconds',group_cooldown_seconds,'base_power',base_power,
        'scaling',scaling,'element',element,'area_type',area_type,'max_targets',max_targets,
        'element_modifier_percent',element_modifier_percent,
        'element_adjusted_base_power_proxy',
          case when element_adjusted_base_power_proxy is null then null
               else round(element_adjusted_base_power_proxy::numeric,2) end,
        'effect_summary',effect_summary
      )
      order by element_modifier_percent desc nulls last,
               element_adjusted_base_power_proxy desc nulls last,
               base_power desc nulls last,
               cooldown_seconds asc nulls last
    )
    from attack
    where area_type<>'single'
  ),'[]'::jsonb),
  'healing',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',spell_key,'name',name,'words',words,'level',min_level,
        'mana',mana_cost,'cooldown_seconds',cooldown_seconds,
        'base_power',base_power,'scaling',scaling,'area_type',area_type,
        'effect_summary',effect_summary
      )
      order by base_power desc nulls last,cooldown_seconds asc nulls last
    )
    from healing
  ),'[]'::jsonb),
  'support',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',spell_key,'name',name,'words',words,'level',min_level,
        'mana',mana_cost,'area_type',area_type,
        'lever_boss_restricted',lever_boss_restricted,
        'effect_summary',effect_summary
      )
      order by name
    )
    from support
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','spell_candidates',
    'final_rotation',false,
    'element_fit_uses_kill_weighted_profile',true,
    'weapon_based_knight_spells_need_weapon_layer',true,
    'note','Element-adjusted base power is a comparison proxy within comparable spell contexts, not final DPS. Area, positioning, shared cooldowns, Wheel/proficiency and boss mechanics remain separate.'
  )
);
$$;

revoke all on function huntnexus_spell_candidates(text,text,int,text)
  from public,anon,authenticated;
grant execute on function huntnexus_spell_candidates(text,text,int,text)
  to service_role;
