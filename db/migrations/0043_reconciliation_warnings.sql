-- HuntNexus Brain — Phase 16.5 RubinOT reconciliation warnings.

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
        'spell_key',v.spell_key,
        'spell_name',v.name,
        'patch_version',v.patch_version,
        'released_on',v.released_on,
        'change_kind',v.change_kind,
        'summary',v.summary,
        'reconciliation_status',v.reconciliation_status,
        'notes',v.notes
      )
      order by v.released_on desc,v.spell_key
    ),
    '[]'::jsonb
  )
  from vw_spell_rubinot_reconciliation v
  join spell_definitions s on s.spell_key=v.spell_key
  where s.vocation=huntnexus_normalize_vocation(p_vocation)
    and s.min_level<=p_level;
$$;

create or replace view vw_boss_global_rubinot_warnings as
select
  patch_version,
  released_on,
  change_kind,
  summary,
  reconciliation_status,
  notes
from rubinot_change_candidates
where entity_type='boss_system'
  and reconciliation_status<>'resolved';

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
  from vw_boss_global_rubinot_warnings;
$$;

revoke all on function huntnexus_rubinot_spell_warnings(text,int)
  from public,anon,authenticated;
revoke all on function huntnexus_global_boss_warnings()
  from public,anon,authenticated;

grant execute on function huntnexus_rubinot_spell_warnings(text,int)
  to service_role;
grant execute on function huntnexus_global_boss_warnings()
  to service_role;
