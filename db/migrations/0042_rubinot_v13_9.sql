-- HuntNexus Brain — RubinOT 2026-10-06 release checkpoint.
-- Official RubinOT changelog: client v4.064 / server v13.9.

insert into game_versions(source_id,scope,version_label,released_on,change_count,source_url)
select id,'rubinot_client','v4.064','2026-10-06',12,'https://rubinot.com.br/changelog'
from sources where name='RubinOT Changelog'
on conflict(scope,version_label) do update set
  released_on=excluded.released_on,
  change_count=excluded.change_count,
  source_url=excluded.source_url;

insert into game_versions(source_id,scope,version_label,released_on,change_count,source_url)
select id,'rubinot_server','v13.9','2026-10-06',36,'https://rubinot.com.br/changelog'
from sources where name='RubinOT Changelog'
on conflict(scope,version_label) do update set
  released_on=excluded.released_on,
  change_count=excluded.change_count,
  source_url=excluded.source_url;

insert into rubinot_change_candidates(
  patch_version,released_on,entity_type,entity_key,change_kind,summary,
  source_id,source_url,reconciliation_status,notes
)
select x.patch_version,x.released_on::date,x.entity_type,x.entity_key,x.change_kind,x.summary,
       s.id,'https://rubinot.com.br/changelog',x.status,x.notes
from sources s
cross join (
  values
    ('v13.9','2026-10-06','spell','forked-thorns','targeting_range',
      'RubinOT corrected the range/targeting behavior of exevo fur tera according to monster proximity.',
      'needs_exact_value',
      'Do not alter canonical max-target count from this summary alone; exact RubinOT proximity/range behavior still needs reconciliation.'),
    ('v13.9','2026-10-06','spell','forked-glacier','targeting_range',
      'RubinOT corrected the range/targeting behavior of exevo fur frigo according to monster proximity.',
      'needs_exact_value',
      'Do not alter canonical max-target count from this summary alone; exact RubinOT proximity/range behavior still needs reconciliation.'),
    ('v13.9','2026-10-06','boss_system',null,'familiar_creation',
      'RubinOT corrected familiar creation in some boss fight rooms.',
      'pending',
      'Affected boss rooms are not identified by the visible changelog summary; do not apply a global boss mechanic override.'),
    ('v13.9','2026-10-06','boss_group','paw-and-fur','boss_points',
      'RubinOT reworked Paw and Fur boss points so they count correctly.',
      'pending',
      'Progression/system change; not a combat-stat override.'),
    ('v13.9','2026-10-06','boss_group','lycanthrope-bosses','instance_system',
      'RubinOT implemented boss instances for Bloodback, Darkfang, Sharpclaw, Black Vixen and Shadowpelt.',
      'pending',
      'Encounter-access/runtime change; does not imply combat-stat changes.')
) as x(patch_version,released_on,entity_type,entity_key,change_kind,summary,status,notes)
where s.name='RubinOT Changelog'
on conflict do nothing;

insert into rubinot_system_facts(
  system_key,fact_key,value,source_id,source_url,notes
)
select
  'equipment_preset','v4.064_update',
  '{"version":"v4.064","released_on":"2026-10-06","change":"shield_of_the_white_knight_reading_added"}'::jsonb,
  s.id,
  'https://rubinot.com.br/changelog',
  'Client v4.064 added Equipment Preset reading support for Shield of the White Knight.'
from sources s
where s.name='RubinOT Changelog';

create or replace view vw_spell_rubinot_reconciliation as
select
  s.spell_key,
  s.name,
  c.patch_version,
  c.released_on,
  c.change_kind,
  c.summary,
  c.reconciliation_status,
  c.notes
from spell_definitions s
join rubinot_change_candidates c
  on c.entity_type='spell'
 and c.entity_key=s.spell_key
where c.reconciliation_status<>'resolved';

comment on view vw_spell_rubinot_reconciliation is
'RubinOT-specific spell changes that are not yet fully reconciled with the base factual spell definition.';
