-- HuntNexus Brain — Phase 16 boss-room foundation.
-- Separates canonical boss facts, room mechanics and versioned RubinOT overrides.

create table if not exists boss_profiles (
  boss_key text primary key,
  name text not null,
  canonical_monster_key text,
  hunting_place_key text,
  encounter_type text not null default 'boss_room',
  party_size_min int,
  party_size_max int,
  recommended_level_text text,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now(),
  notes text
);

create table if not exists boss_room_adds (
  boss_key text not null references boss_profiles(boss_key) on delete cascade,
  add_key text not null,
  canonical_monster_key text,
  raw_name text not null,
  phase_key text,
  role text,
  required boolean not null default true,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now(),
  primary key (boss_key,add_key)
);

create table if not exists boss_room_mechanics (
  id uuid primary key default gen_random_uuid(),
  boss_key text not null references boss_profiles(boss_key) on delete cascade,
  mechanic_key text not null,
  phase_key text,
  mechanic_type text not null,
  title text not null,
  description text not null,
  element text,
  severity text,
  exact_values jsonb not null default '{}'::jsonb,
  required_action text,
  avoid_action text,
  source_id uuid not null references sources(id),
  source_url text not null,
  source_tier text not null,
  patch_version text,
  valid_from timestamptz,
  valid_to timestamptz,
  observed_at timestamptz not null default now(),
  confidence numeric not null default 1.0 check (confidence>=0 and confidence<=1),
  unique (boss_key,mechanic_key,patch_version,source_url)
);

create table if not exists boss_room_spell_guidance (
  boss_key text not null references boss_profiles(boss_key) on delete cascade,
  vocation text not null,
  spell_key text not null,
  guidance_type text not null check (guidance_type in ('recommended','situational','avoid','restricted')),
  phase_key text not null default '',
  rationale text not null,
  source_id uuid not null references sources(id),
  source_url text not null,
  patch_version text,
  observed_at timestamptz not null default now(),
  confidence numeric not null default 1.0 check (confidence>=0 and confidence<=1),
  primary key (boss_key,vocation,spell_key,guidance_type,phase_key,source_url)
);

create table if not exists boss_room_item_guidance (
  boss_key text not null references boss_profiles(boss_key) on delete cascade,
  vocation text not null,
  guidance_type text not null check (guidance_type in ('protection','weapon_element','utility','avoid')),
  effect_key text not null,
  priority int,
  rationale text not null,
  source_id uuid not null references sources(id),
  source_url text not null,
  patch_version text,
  observed_at timestamptz not null default now(),
  confidence numeric not null default 1.0 check (confidence>=0 and confidence<=1),
  primary key (boss_key,vocation,guidance_type,effect_key,source_url)
);

create index if not exists idx_boss_mechanics_lookup
  on boss_room_mechanics(boss_key,phase_key,mechanic_type,valid_to);

create index if not exists idx_boss_spell_guidance_lookup
  on boss_room_spell_guidance(boss_key,vocation,guidance_type);

create or replace view vw_boss_current_mechanics as
select *
from boss_room_mechanics
where (valid_from is null or valid_from<=now())
  and (valid_to is null or valid_to>now());

create or replace view vw_boss_element_profile as
with boss_entities as (
  select bp.boss_key,bp.name,bp.canonical_monster_key as monster_key,'boss'::text as role
  from boss_profiles bp
  where bp.canonical_monster_key is not null
  union all
  select ba.boss_key,ba.raw_name,ba.canonical_monster_key,'add'
  from boss_room_adds ba
  where ba.canonical_monster_key is not null
)
select
  be.boss_key,
  v.element,
  count(distinct be.monster_key)::int as entity_count,
  round(avg(v.modifier_percent),2) as avg_modifier_percent,
  min(v.modifier_percent) as min_modifier_percent,
  max(v.modifier_percent) as max_modifier_percent,
  count(distinct be.monster_key) filter (where v.modifier_percent>100)::int as weak_entities,
  count(distinct be.monster_key) filter (where v.modifier_percent=100)::int as neutral_entities,
  count(distinct be.monster_key) filter (where v.modifier_percent>0 and v.modifier_percent<100)::int as resistant_entities,
  count(distinct be.monster_key) filter (where v.modifier_percent=0)::int as immune_entities
from boss_entities be
join monster_vulnerability v on v.monster_key=be.monster_key
group by be.boss_key,v.element;

comment on view vw_boss_element_profile is
'Unweighted canonical boss + add elemental evidence. Mechanics/phases may override practical priorities.';

create or replace function huntnexus_boss_room_profile(
  p_boss_key text,
  p_vocation text,
  p_level int
)
returns jsonb
language sql
stable
as $$
select jsonb_build_object(
  'boss',(
    select jsonb_build_object(
      'boss_key',bp.boss_key,
      'name',bp.name,
      'canonical_monster_key',bp.canonical_monster_key,
      'hunting_place_key',bp.hunting_place_key,
      'encounter_type',bp.encounter_type,
      'party_size_min',bp.party_size_min,
      'party_size_max',bp.party_size_max,
      'recommended_level_text',bp.recommended_level_text
    )
    from boss_profiles bp
    where bp.boss_key=p_boss_key
  ),
  'element_profile',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'element',element,
        'entity_count',entity_count,
        'avg_modifier_percent',avg_modifier_percent,
        'min_modifier_percent',min_modifier_percent,
        'max_modifier_percent',max_modifier_percent,
        'weak_entities',weak_entities,
        'neutral_entities',neutral_entities,
        'resistant_entities',resistant_entities,
        'immune_entities',immune_entities
      )
      order by avg_modifier_percent desc,element
    )
    from vw_boss_element_profile
    where boss_key=p_boss_key
  ),'[]'::jsonb),
  'adds',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'add_key',add_key,
        'name',raw_name,
        'canonical_monster_key',canonical_monster_key,
        'phase_key',phase_key,
        'role',role,
        'required',required
      )
      order by coalesce(phase_key,''),raw_name
    )
    from boss_room_adds
    where boss_key=p_boss_key
  ),'[]'::jsonb),
  'mechanics',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'mechanic_key',mechanic_key,
        'phase_key',phase_key,
        'type',mechanic_type,
        'title',title,
        'description',description,
        'element',element,
        'severity',severity,
        'exact_values',exact_values,
        'required_action',required_action,
        'avoid_action',avoid_action,
        'source_tier',source_tier,
        'patch_version',patch_version,
        'confidence',confidence
      )
      order by coalesce(phase_key,''),mechanic_key
    )
    from vw_boss_current_mechanics
    where boss_key=p_boss_key
  ),'[]'::jsonb),
  'spell_guidance',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',g.spell_key,
        'spell_name',s.name,
        'words',s.words,
        'guidance_type',g.guidance_type,
        'phase_key',g.phase_key,
        'rationale',g.rationale,
        'confidence',g.confidence
      )
      order by g.guidance_type,s.name
    )
    from boss_room_spell_guidance g
    left join spell_definitions s on s.spell_key=g.spell_key
    where g.boss_key=p_boss_key
      and g.vocation=huntnexus_normalize_vocation(p_vocation)
      and (s.min_level is null or s.min_level<=p_level)
  ),'[]'::jsonb),
  'item_guidance',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'guidance_type',guidance_type,
        'effect_key',effect_key,
        'priority',priority,
        'rationale',rationale,
        'patch_version',patch_version,
        'confidence',confidence
      )
      order by coalesce(priority,999),guidance_type,effect_key
    )
    from boss_room_item_guidance
    where boss_key=p_boss_key
      and vocation=huntnexus_normalize_vocation(p_vocation)
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','boss_room_profile',
    'final_build',false,
    'version_sensitive',true,
    'rubinot_overrides_can_supersede_tibia_base',true,
    'note','Boss-room output keeps mechanics, elemental evidence and build/spell guidance versioned and separately sourced.'
  )
);
$$;

revoke all on function huntnexus_boss_room_profile(text,text,int)
  from public,anon,authenticated;
grant execute on function huntnexus_boss_room_profile(text,text,int)
  to service_role;
