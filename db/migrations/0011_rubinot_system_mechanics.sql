-- HuntNexus Brain — Phase 6 RubinOT official system mechanics.
-- Tier A semantics sourced from official RubinOT Wiki.
-- Numeric Guild Ascension perk values are intentionally NOT hardcoded because
-- the official page states that real progression values vary by bonus.

create table if not exists rubinot_system_facts (
  id uuid primary key default gen_random_uuid(),
  system_key text not null,
  fact_key text not null,
  value jsonb not null,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now(),
  valid_from timestamptz,
  valid_to timestamptz,
  patch_version text,
  notes text,
  unique (system_key, fact_key, source_url, observed_at)
);

create index if not exists idx_rubinot_system_facts_lookup
  on rubinot_system_facts(system_key,fact_key,observed_at desc);

create table if not exists rubinot_modifier_definitions (
  modifier_key text primary key,
  system_key text not null,
  category text not null,
  target_dimension text,
  unit text,
  value_mode text not null check (value_mode in ('dynamic','boolean','text')),
  allowed_targets jsonb not null default '[]'::jsonb,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now(),
  notes text
);

alter table session_modifiers
  add column if not exists definition_key text
  references rubinot_modifier_definitions(modifier_key);

-- Official Guild Ascension modifier definitions.
insert into rubinot_modifier_definitions(
  modifier_key,system_key,category,target_dimension,unit,value_mode,
  allowed_targets,source_id,source_url,notes
)
select x.modifier_key,'guild_ascension',x.category,x.target_dimension,x.unit,'dynamic',
       x.allowed_targets,s.id,'https://wiki.rubinot.com/pt-BR/guild-ascension',x.notes
from sources s
cross join (
  values
    ('guild_ascension.experience','general','xp_gain','percent','[]'::jsonb,'Season/perk dependent.'),
    ('guild_ascension.stamina_regeneration','general','stamina_regeneration','percent','[]'::jsonb,'Season/perk dependent.'),
    ('guild_ascension.fast_exercise','general','exercise_speed','percent','[]'::jsonb,'Season/perk dependent.'),
    ('guild_ascension.life_leech','general','life_leech','percent','[]'::jsonb,'Season/perk dependent.'),
    ('guild_ascension.mana_leech','general','mana_leech','percent','[]'::jsonb,'Season/perk dependent.'),
    ('guild_ascension.critical','general','critical_chance','percent','[]'::jsonb,'Season/perk dependent.'),
    ('guild_ascension.skill','general','primary_skill','levels','[]'::jsonb,'Primary skill depends on vocation.'),
    ('guild_ascension.weapon_proficiency','general','weapon_proficiency_xp','percent','[]'::jsonb,'Season/perk dependent.'),
    ('guild_ascension.familiar_damage','general','familiar_damage','percent','[]'::jsonb,'Season/perk dependent.'),
    ('guild_ascension.loot','general','loot_rate','percent','[]'::jsonb,'Season/perk dependent.'),
    ('guild_ascension.race_damage','race_damage','bestiary_race','percent',
      '["Amphibic","Aquatic","Bird","Construct","Demon","Dragon","Elemental","Extra Dimensional","Fey","Giant","Human","Humanoid","Inkborn","Lycanthrope","Magical","Mammal","Plant","Reptile","Slime","Undead","Vermin"]'::jsonb,
      'Target race is randomly selected each Season.'),
    ('guild_ascension.elemental_damage','elemental_damage','damage_element','percent',
      '["ice","fire","earth","energy","death","holy","physical"]'::jsonb,
      'Target element is randomly selected each Season.'),
    ('guild_ascension.elemental_defense','elemental_defense','defense_element','percent',
      '["ice","fire","earth","energy","death","holy","physical"]'::jsonb,
      'Target element is randomly selected each Season.')
) as x(modifier_key,category,target_dimension,unit,allowed_targets,notes)
where s.name='RubinOT Wiki'
on conflict (modifier_key) do update set
  category=excluded.category,
  target_dimension=excluded.target_dimension,
  unit=excluded.unit,
  value_mode=excluded.value_mode,
  allowed_targets=excluded.allowed_targets,
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=now(),
  notes=excluded.notes;

-- Current official system facts useful to HuntNexus Analytics/UI.
insert into rubinot_system_facts(
  system_key,fact_key,value,source_id,source_url,notes
)
select 'huntfinder','capabilities',
       '{
          "filters":["vocation","solo","duo","party"],
          "suggestions":["level","class"],
          "recommendations":["items","imbuements","set","charm_runes"],
          "metrics":["experience_per_hour","profit_per_hour"],
          "categories":["xp","loot","both"],
          "features":["track_kills","hunt_rotation","map_guidance","monster_search"]
        }'::jsonb,
       s.id,'https://wiki.rubinot.com/pt-BR/huntfinder',
       'Official Huntfinder capabilities.'
from sources s where s.name='RubinOT Wiki';

insert into rubinot_system_facts(
  system_key,fact_key,value,source_id,source_url,notes
)
select 'equipment_preset','constraints',
       '{
          "supports_action_bar_switching":true,
          "intended_contexts":["pvp","hunt","elemental_resistance"],
          "charged_amulets_and_rings_supported":false,
          "activation_delay":true,
          "items_must_be_equipped_or_in_backpack":true
        }'::jsonb,
       s.id,'https://wiki.rubinot.com/pt-BR/equipment-preset',
       'Official Equipment Preset behavior.'
from sources s where s.name='RubinOT Wiki';

insert into rubinot_system_facts(
  system_key,fact_key,value,source_id,source_url,notes
)
select 'guild_ascension','structure',
       '{
          "seasonal":true,
          "resets_at_season_end":true,
          "bonus_slots":6,
          "general_bonus_slots":[1,2,3],
          "race_damage_slot":4,
          "elemental_damage_slot":5,
          "elemental_defense_slot":6,
          "perk_levels":5,
          "perk_progression":"sequential",
          "perk_benefits_cumulative":true,
          "numeric_example_values_are_not_real_game_values":true
        }'::jsonb,
       s.id,'https://wiki.rubinot.com/pt-BR/guild-ascension',
       'Do not infer real perk percentages from the illustrative table.'
from sources s where s.name='RubinOT Wiki';

insert into rubinot_system_facts(
  system_key,fact_key,value,source_id,source_url,notes
)
select 'linked_tasks','behavior',
       '{
          "repeatable_after_first_completion":true,
          "only_one_active_task_per_character":true,
          "first_completion_rewards_can_differ_from_repeat_rewards":true,
          "commands":["!task check","!task clear","!task bonus"]
        }'::jsonb,
       s.id,'https://wiki.rubinot.com/pt-BR/linked-tasks',
       'Official Linked Tasks behavior.'
from sources s where s.name='RubinOT Wiki';
