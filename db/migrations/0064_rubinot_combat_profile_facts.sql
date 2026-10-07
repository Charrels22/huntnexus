-- HuntNexus RubinOT Tier A facts required by future character-aware combat optimization.

insert into public.rubinot_system_facts(
  system_key,fact_key,value,source_id,source_url,observed_at,notes
)
values
(
  'vip',
  'protected_imbuement',
  '{"consumed_in_protection_zone":false,"applies_to":["all_imbuements","capacity_imbuement"]}'::jsonb,
  '9cf56e75-311a-4867-b7cb-f3a2588b562a',
  'https://rubinot.com.br/vip',
  now(),
  'Official VIP page: imbuements are not consumed inside protection zones, including capacity.'
),
(
  'vip',
  'additional_critical',
  '{"chance_bonus_percent":3,"scope":"all_characters_on_account"}'::jsonb,
  '9cf56e75-311a-4867-b7cb-f3a2588b562a',
  'https://rubinot.com.br/vip',
  now(),
  'Official VIP page: all characters on the account receive 3% additional critical chance.'
),
(
  'loyalty',
  'skill_bonus_tiers',
  '{
    "tiers":[
      {"title":"Scout of RubinOT","points":0,"skill_bonus":0},
      {"title":"Sentinel of RubinOT","points":1,"skill_bonus":1},
      {"title":"Steward of RubinOT","points":3,"skill_bonus":2},
      {"title":"Warden of RubinOT","points":6,"skill_bonus":3},
      {"title":"Squire of RubinOT","points":9,"skill_bonus":4},
      {"title":"Warrior of RubinOT","points":15,"skill_bonus":5},
      {"title":"Keeper of RubinOT","points":21,"skill_bonus":6},
      {"title":"Guardian of RubinOT","points":30,"skill_bonus":7},
      {"title":"Sage of RubinOT","points":42,"skill_bonus":8},
      {"title":"Savant of RubinOT","points":56,"skill_bonus":9},
      {"title":"Enlightened of RubinOT","points":70,"skill_bonus":10}
    ],
    "persistent_account_bonus":true
  }'::jsonb,
  '9cf56e75-311a-4867-b7cb-f3a2588b562a',
  'https://rubinot.com.br/vip',
  now(),
  'Official Loyalty table. The vocation-specific skill mapping is stored separately.'
),
(
  'guild_ascension',
  'combat_bonus_categories',
  '{
    "seasonal":true,
    "general":["life_leech","mana_leech","critical","skill"],
    "race_damage":true,
    "elemental_damage":["ice","fire","earth","energy","death","holy","physical"],
    "elemental_defense":["ice","fire","earth","energy","death","holy","physical"],
    "numeric_values_known":false
  }'::jsonb,
  '3235bcef-e29e-47a8-a65d-35b02c122fac',
  'https://wiki.rubinot.com/pt-BR/guild-ascension',
  now(),
  'Official Guild Ascension categories. Perk percentages are intentionally not inferred from illustrative examples.'
),
(
  'weapon_proficiency',
  'offense_stats_visibility',
  '{"client_version":"v4.061","bonus_visible_in_offense_stats":true}'::jsonb,
  '543ebb3e-e072-4749-9fb9-92b530e26f98',
  'https://rubinot.com.br/changelog',
  now(),
  'Client v4.061 changelog states Weapon Proficiency bonuses are displayed correctly in Offense Stats.'
);
