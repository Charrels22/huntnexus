-- HuntNexus Brain — Phase 16.2 boss reconciliation guards.
-- Prevents base/global mechanics from being presented as current RubinOT mechanics
-- after an official RubinOT boss rework.

create table if not exists boss_groups (
  group_key text primary key,
  name text not null,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now()
);

create table if not exists boss_group_members (
  group_key text not null references boss_groups(group_key) on delete cascade,
  boss_key text not null references boss_profiles(boss_key) on delete cascade,
  membership_method text not null,
  confidence numeric not null default 1.0 check (confidence>=0 and confidence<=1),
  observed_at timestamptz not null default now(),
  primary key(group_key,boss_key)
);

create table if not exists boss_reconciliation_guards (
  guard_key text primary key,
  target_type text not null check (target_type in ('boss','boss_group')),
  target_key text not null,
  patch_version text not null,
  released_on date,
  reason text not null,
  current_mechanics_status text not null default 'needs_exact_rubinot_reconciliation'
    check (current_mechanics_status in (
      'needs_exact_rubinot_reconciliation',
      'partially_reconciled',
      'reconciled'
    )),
  block_final_build boolean not null default true,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now(),
  resolved_at timestamptz,
  notes text
);

insert into boss_groups(group_key,name,source_id,source_url)
select
  'soul-war',
  'Soul War',
  s.id,
  'https://rubinot.com.br/changelog'
from sources s
where s.name='RubinOT Changelog'
on conflict(group_key) do update set
  name=excluded.name,
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=now();

insert into boss_reconciliation_guards(
  guard_key,target_type,target_key,patch_version,released_on,reason,
  current_mechanics_status,block_final_build,source_id,source_url,notes
)
select
  'rubinot-v13.7-soul-war-rework',
  'boss_group',
  'soul-war',
  'v13.7',
  date '2026-09-22',
  'RubinOT official changelog states that all Soul War boss fight mechanics were completely reworked.',
  'needs_exact_rubinot_reconciliation',
  true,
  s.id,
  'https://rubinot.com.br/changelog',
  'Base Tibia/TibiaWiki mechanics may be retained as reference evidence but must not be presented as current RubinOT mechanics until reconciled.'
from sources s
where s.name='RubinOT Changelog'
on conflict(guard_key) do update set
  reason=excluded.reason,
  current_mechanics_status=excluded.current_mechanics_status,
  block_final_build=excluded.block_final_build,
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=now(),
  notes=excluded.notes;

insert into boss_reconciliation_guards(
  guard_key,target_type,target_key,patch_version,released_on,reason,
  current_mechanics_status,block_final_build,source_id,source_url,notes
)
select
  'rubinot-v13.8-magma-bubble-rework',
  'boss',
  'magma-bubble',
  'v13.8',
  date '2026-09-29',
  'RubinOT official changelog states that the Magma Bubble fight mechanics were completely reworked.',
  'needs_exact_rubinot_reconciliation',
  true,
  s.id,
  'https://rubinot.com.br/changelog',
  'Do not treat pre-rework/global mechanics as current RubinOT behavior.'
from sources s
where s.name='RubinOT Changelog'
on conflict(guard_key) do update set
  reason=excluded.reason,
  current_mechanics_status=excluded.current_mechanics_status,
  block_final_build=excluded.block_final_build,
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=now(),
  notes=excluded.notes;

create or replace function huntnexus_refresh_boss_groups()
returns jsonb
language plpgsql
as $$
declare
  v_inserted int := 0;
begin
  -- Soul War canonical bosses are Goshnar encounters.
  insert into boss_group_members(
    group_key,boss_key,membership_method,confidence,observed_at
  )
  select
    'soul-war',
    bp.boss_key,
    'canonical_name_pattern',
    1.0,
    now()
  from boss_profiles bp
  where lower(bp.name) like 'goshnar''s %'
  on conflict(group_key,boss_key) do update set
    membership_method=excluded.membership_method,
    confidence=excluded.confidence,
    observed_at=excluded.observed_at;

  get diagnostics v_inserted=row_count;

  return jsonb_build_object(
    'soul_war_members_upserted',v_inserted,
    'soul_war_members_total',(
      select count(*) from boss_group_members where group_key='soul-war'
    )
  );
end;
$$;

create or replace view vw_boss_recommendation_readiness as
with direct_guards as (
  select
    bp.boss_key,
    g.guard_key,
    g.patch_version,
    g.current_mechanics_status,
    g.block_final_build,
    g.reason
  from boss_profiles bp
  join boss_reconciliation_guards g
    on g.target_type='boss'
   and g.target_key=bp.boss_key
),
group_guards as (
  select
    m.boss_key,
    g.guard_key,
    g.patch_version,
    g.current_mechanics_status,
    g.block_final_build,
    g.reason
  from boss_group_members m
  join boss_reconciliation_guards g
    on g.target_type='boss_group'
   and g.target_key=m.group_key
),
all_guards as (
  select * from direct_guards
  union all
  select * from group_guards
)
select
  bp.boss_key,
  bp.name,
  coalesce(bool_or(g.block_final_build),false) as final_build_blocked,
  case
    when coalesce(bool_or(g.block_final_build),false)
      then 'needs_rubinot_reconciliation'
    else 'base_profile_available'
  end as readiness_status,
  coalesce(
    jsonb_agg(
      jsonb_build_object(
        'guard_key',g.guard_key,
        'patch_version',g.patch_version,
        'status',g.current_mechanics_status,
        'reason',g.reason
      )
    ) filter (where g.guard_key is not null),
    '[]'::jsonb
  ) as guards
from boss_profiles bp
left join all_guards g on g.boss_key=bp.boss_key
group by bp.boss_key,bp.name;

create or replace function huntnexus_boss_recommendation_readiness(p_boss_key text)
returns jsonb
language sql
stable
as $$
  select coalesce(
    (
      select jsonb_build_object(
        'boss_key',boss_key,
        'name',name,
        'final_build_blocked',final_build_blocked,
        'readiness_status',readiness_status,
        'guards',guards
      )
      from vw_boss_recommendation_readiness
      where boss_key=p_boss_key
    ),
    jsonb_build_object(
      'boss_key',p_boss_key,
      'readiness_status','boss_not_synchronized',
      'final_build_blocked',true,
      'guards','[]'::jsonb
    )
  );
$$;

revoke all on function huntnexus_refresh_boss_groups()
  from public,anon,authenticated;
revoke all on function huntnexus_boss_recommendation_readiness(text)
  from public,anon,authenticated;
grant execute on function huntnexus_refresh_boss_groups()
  to service_role;
grant execute on function huntnexus_boss_recommendation_readiness(text)
  to service_role;
