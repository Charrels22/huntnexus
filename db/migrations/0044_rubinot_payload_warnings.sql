-- HuntNexus Brain — Phase 17.1 RubinOT warnings for product payloads.

create or replace view vw_spell_rubinot_reconciliation as
select
  s.spell_key,
  s.name,
  c.patch_version,
  c.released_on,
  c.change_kind,
  c.summary,
  c.reconciliation_status,
  c.notes,
  s.vocation,
  s.min_level
from spell_definitions s
join rubinot_change_candidates c
  on c.entity_type='spell'
 and c.entity_key=s.spell_key
where c.reconciliation_status<>'resolved';

create or replace function huntnexus_rubinot_spell_warnings(
  p_vocation text,
  p_level int
)
returns jsonb
language sql
stable
as $$
select coalesce(
  jsonb_agg(
    jsonb_build_object(
      'spell_key',spell_key,
      'spell_name',name,
      'patch_version',patch_version,
      'released_on',released_on,
      'change_kind',change_kind,
      'summary',summary,
      'reconciliation_status',reconciliation_status,
      'notes',notes
    )
    order by released_on desc,spell_key
  ),
  '[]'::jsonb
)
from vw_spell_rubinot_reconciliation
where vocation=huntnexus_normalize_vocation(p_vocation)
  and min_level<=p_level;
$$;

create or replace function huntnexus_global_boss_warnings()
returns jsonb
language sql
stable
as $$
select coalesce(
  jsonb_agg(
    jsonb_build_object(
      'patch_version',patch_version,
      'released_on',released_on,
      'change_kind',change_kind,
      'summary',summary,
      'reconciliation_status',reconciliation_status,
      'notes',notes
    )
    order by released_on desc,change_kind
  ),
  '[]'::jsonb
)
from rubinot_change_candidates
where entity_type='boss_system'
  and reconciliation_status<>'resolved';
$$;

revoke all on function huntnexus_rubinot_spell_warnings(text,int)
  from public,anon,authenticated;
revoke all on function huntnexus_global_boss_warnings()
  from public,anon,authenticated;
grant execute on function huntnexus_rubinot_spell_warnings(text,int) to service_role;
grant execute on function huntnexus_global_boss_warnings() to service_role;
