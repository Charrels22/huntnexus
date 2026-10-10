-- HuntNexus — universal vocation composition contract.
-- Keeps canonical vocation identity separate from raw catalog compatibility.
-- No cross-vocation score, ranking or final optimizer is introduced.

create table if not exists public.vocation_composition_rules (
  vocation_code text primary key check (vocation_code in ('EK','RP','ED','MS','EM')),
  vocation_key text not null unique,
  vocation_name text not null,
  promotion_name text not null,
  primary_skill_mode text not null,
  primary_skill_keys jsonb not null default '[]'::jsonb,
  secondary_skill_keys jsonb not null default '[]'::jsonb,
  canonical_weapon_families jsonb not null default '[]'::jsonb,
  resource_key text,
  source_tier text not null default 'B',
  source_url text not null,
  observed_at timestamptz not null,
  notes text
);

alter table public.vocation_composition_rules enable row level security;
revoke all on public.vocation_composition_rules from public,anon,authenticated;
grant select on public.vocation_composition_rules to service_role;

insert into public.vocation_composition_rules(
  vocation_code,vocation_key,vocation_name,promotion_name,
  primary_skill_mode,primary_skill_keys,secondary_skill_keys,
  canonical_weapon_families,resource_key,source_tier,source_url,observed_at,notes
) values
  ('ED','druid','Druid','Elder Druid','magic','["magic_level"]'::jsonb,'[]'::jsonb,'["rod"]'::jsonb,null,'B','https://www.tibiawiki.com.br/wiki/Vocation','2026-10-10 00:00:00+00'::timestamptz,'Canonical Druid identity emphasizes Magic Level, healing, Earth and Ice. Catalog-compatible off-family items are reported separately.'),
  ('EK','knight','Knight','Elite Knight','weapon_family_choice','["sword_fighting","axe_fighting","club_fighting"]'::jsonb,'["magic_level","shielding"]'::jsonb,'["sword","axe","club"]'::jsonb,null,'B','https://www.tibiawiki.com.br/wiki/Vocation','2026-10-10 00:00:00+00'::timestamptz,'Canonical melee identity uses a trained Sword/Axe/Club family; catalog eligibility may include unrestricted legacy items and is reported separately.'),
  ('EM','monk','Monk','Exalted Monk','fist_melee','["fist_fighting"]'::jsonb,'["magic_level"]'::jsonb,'["fist"]'::jsonb,'harmony','B','https://www.tibiawiki.com.br/wiki/Vocation','2026-10-10 00:00:00+00'::timestamptz,'Canonical Monk identity uses Fist Fighting with healing/magic support and Harmony mechanics.'),
  ('MS','sorcerer','Sorcerer','Master Sorcerer','magic','["magic_level"]'::jsonb,'[]'::jsonb,'["wand"]'::jsonb,null,'B','https://www.tibiawiki.com.br/wiki/Vocation','2026-10-10 00:00:00+00'::timestamptz,'Canonical Sorcerer identity emphasizes Magic Level and offensive magic.'),
  ('RP','paladin','Paladin','Royal Paladin','distance','["distance_fighting"]'::jsonb,'["magic_level","shielding"]'::jsonb,'["bow","crossbow"]'::jsonb,null,'B','https://www.tibiawiki.com.br/wiki/Vocation','2026-10-10 00:00:00+00'::timestamptz,'Canonical distance identity; ammunition/quiver dependencies are handled by the loadout compatibility layer.')
on conflict(vocation_code) do update set
  vocation_key=excluded.vocation_key,
  vocation_name=excluded.vocation_name,
  promotion_name=excluded.promotion_name,
  primary_skill_mode=excluded.primary_skill_mode,
  primary_skill_keys=excluded.primary_skill_keys,
  secondary_skill_keys=excluded.secondary_skill_keys,
  canonical_weapon_families=excluded.canonical_weapon_families,
  resource_key=excluded.resource_key,
  source_tier=excluded.source_tier,
  source_url=excluded.source_url,
  observed_at=excluded.observed_at,
  notes=excluded.notes;

CREATE OR REPLACE FUNCTION public.huntnexus_vocation_profile_contract_universal(p_vocation text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with v as (
  select huntnexus_normalize_vocation(p_vocation) as vocation_code
),
r as (
  select *
  from vocation_composition_rules
  where vocation_code=(select vocation_code from v)
)
select coalesce((
  select jsonb_build_object(
    'stage','vocation_profile_contract_universal_v1',
    'vocation',jsonb_build_object(
      'code',r.vocation_code,
      'key',r.vocation_key,
      'name',r.vocation_name,
      'promotion_name',r.promotion_name
    ),
    'identity',jsonb_build_object(
      'primary_skill_mode',r.primary_skill_mode,
      'primary_skill_keys',r.primary_skill_keys,
      'secondary_skill_keys',r.secondary_skill_keys,
      'canonical_weapon_families',r.canonical_weapon_families,
      'resource_key',r.resource_key
    ),
    'common',jsonb_build_object(
      'critical_chance_percent',jsonb_build_object('required',false,'type','number'),
      'life_leech_percent',jsonb_build_object('required',false,'type','number'),
      'mana_leech_percent',jsonb_build_object('required',false,'type','number'),
      'elemental_damage_bonus_percent',jsonb_build_object(
        'required',false,'type','object_by_element',
        'elements',jsonb_build_array('physical','fire','ice','earth','energy','death','holy')
      ),
      'elemental_defense_bonus_percent',jsonb_build_object(
        'required',false,'type','object_by_element',
        'elements',jsonb_build_array('physical','fire','ice','earth','energy','death','holy')
      ),
      'race_damage_bonus_percent',jsonb_build_object('required',false,'type','object_by_race'),
      'vip_active',jsonb_build_object(
        'required',false,'type','boolean',
        'meaning','Economy/consumption context only unless an explicit combat source says otherwise.'
      )
    ),
    'vocation_specific',
      case r.vocation_code
        when 'EK' then jsonb_build_object(
          'weapon_family',jsonb_build_object(
            'required_for_precise_weapon_comparison',true,
            'type','enum',
            'values',r.canonical_weapon_families
          ),
          'effective_weapon_skill',jsonb_build_object(
            'required_for_precise_damage_comparison',true,'type','integer'
          ),
          'effective_magic_level',jsonb_build_object('required',false,'type','integer'),
          'effective_shielding',jsonb_build_object('required',false,'type','integer')
        )
        when 'RP' then jsonb_build_object(
          'effective_distance_skill',jsonb_build_object(
            'required_for_precise_damage_comparison',true,'type','integer'
          ),
          'effective_magic_level',jsonb_build_object('required',false,'type','integer'),
          'effective_shielding',jsonb_build_object('required',false,'type','integer')
        )
        when 'ED' then jsonb_build_object(
          'effective_magic_level',jsonb_build_object(
            'required_for_precise_spell_comparison',true,'type','integer'
          )
        )
        when 'MS' then jsonb_build_object(
          'effective_magic_level',jsonb_build_object(
            'required_for_precise_spell_comparison',true,'type','integer'
          )
        )
        when 'EM' then jsonb_build_object(
          'effective_fist_skill',jsonb_build_object(
            'required_for_precise_damage_comparison',true,'type','integer'
          ),
          'effective_magic_level',jsonb_build_object(
            'required_for_precise_healing_spell_comparison',false,'type','integer'
          ),
          'harmony_state',jsonb_build_object(
            'required_for_static_candidate_comparison',false,
            'type','integer_or_state',
            'meaning','Dynamic combat resource; not assumed when evaluating static equipment candidates.'
          )
        )
      end,
    'input_principle',
      'Prefer effective values displayed by the RubinOT client. Do not add Loyalty, Guild Ascension, VIP, equipment or Weapon Proficiency bonuses again when they are already reflected in an effective supplied stat.',
    'source',jsonb_build_object(
      'tier',r.source_tier,'url',r.source_url,'observed_at',r.observed_at
    ),
    'methodology',jsonb_build_object(
      'category_first',true,
      'canonical_identity_separate_from_catalog_eligibility',true,
      'optimizer_applied',false
    )
  )
  from r
),jsonb_build_object(
  'error','unsupported_vocation',
  'input_vocation',p_vocation,
  'supported_vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
  'stage','vocation_profile_contract_universal_v1'
));
$function$
;

revoke all on function public.huntnexus_vocation_profile_contract_universal(text)
from public,anon,authenticated;
grant execute on function public.huntnexus_vocation_profile_contract_universal(text)
to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_vocation_composition_universal(p_vocation text, p_level integer, p_unlocked_requirement_keys jsonb DEFAULT '[]'::jsonb, p_hunt_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    case when jsonb_typeof(coalesce(p_unlocked_requirement_keys,'[]'::jsonb))='array'
      then coalesce(p_unlocked_requirement_keys,'[]'::jsonb) else '[]'::jsonb end as unlocks
),
r as (
  select vr.*,p.level_value,p.unlocks
  from vocation_composition_rules vr
  cross join p
  where vr.vocation_code=p.vocation_code
),
all_families as (
  select distinct weapon_family from vw_weapon_catalog_universal
),
family_eval as (
  select
    f.weapon_family,
    huntnexus_weapon_candidates_universal(
      (select vocation_code from r),(select level_value from r),null,f.weapon_family,1
    ) as candidate_result
  from all_families f
),
canonical_family_eval as (
  select
    x.family,
    huntnexus_weapon_candidates_universal(
      (select vocation_code from r),(select level_value from r),null,x.family,1
    ) as candidate_result
  from r
  cross join lateral jsonb_array_elements_text(r.canonical_weapon_families) x(family)
),
explicit_families as (
  select
    w.weapon_family,
    count(*) filter(where w.level_required<=(select level_value from r))::int as level_eligible_items
  from vw_weapon_catalog_universal w
  where w.vocation_scope='explicit'
    and (select vocation_key from r)=any(w.vocation_keys)
  group by w.weapon_family
),
unrestricted_families as (
  select
    w.weapon_family,
    count(*) filter(where w.level_required<=(select level_value from r))::int as level_eligible_items
  from vw_weapon_catalog_universal w
  where w.vocation_scope<>'explicit'
  group by w.weapon_family
),
equipment_by_slot as (
  select
    e.slot_key,
    count(*) filter(
      where e.level_required<=(select level_value from r)
        and (
          e.vocation_scope<>'explicit'
          or (select vocation_key from r)=any(e.vocation_keys)
        )
    )::int as eligible,
    count(*)::int as catalog_items
  from vw_equipment_catalog_universal e
  group by e.slot_key
),
spells as (
  select huntnexus_spell_candidates_with_unlocks_universal(
    (select vocation_code from r),(select level_value from r),(select unlocks from r),
    null,null,250
  ) as j
),
spell_groups as (
  select
    x->>'spell_group' as spell_group,
    count(*)::int as returned,
    count(*) filter(where x->>'eligibility_status'='eligible')::int as eligible,
    count(*) filter(where x->>'eligibility_status'='incomplete')::int as incomplete,
    count(*) filter(where x->>'eligibility_status'='blocked')::int as blocked
  from spells
  cross join lateral jsonb_array_elements(spells.j->'spells') x
  group by x->>'spell_group'
),
spell_elements as (
  select
    coalesce(x->>'element','none') as element,
    count(*) filter(where x->>'eligibility_status'='eligible')::int as eligible
  from spells
  cross join lateral jsonb_array_elements(spells.j->'spells') x
  group by coalesce(x->>'element','none')
),
community as (
  select count(*)::int as observed_players
  from session_players
  where vocation=(select vocation_code from r)
),
hunt_ctx as (
  select case
    when p_hunt_key is null then null
    else huntnexus_imbuement_hunt_context_universal(
      p_hunt_key,(select vocation_code from r)
    )
  end as j
)
select case
  when not exists(select 1 from r) then
    jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'supported_vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
      'methodology',jsonb_build_object('stage','vocation_composition_universal_v1')
    )
  else jsonb_build_object(
    'vocation_profile',huntnexus_vocation_profile_contract_universal((select vocation_code from r)),
    'context',jsonb_build_object(
      'level',(select level_value from r),
      'hunt_key',p_hunt_key,
      'unlocked_requirement_keys',(select unlocks from r)
    ),
    'weapons',jsonb_build_object(
      'canonical_families',(select canonical_weapon_families from r),
      'canonical_family_status',coalesce((
        select jsonb_agg(jsonb_build_object(
          'weapon_family',family,
          'matching_catalog_items',(candidate_result #>> '{summary,matching_catalog_items}')::int,
          'eligible',(candidate_result #>> '{summary,eligible}')::int,
          'incomplete',(candidate_result #>> '{summary,incomplete}')::int,
          'blocked',(candidate_result #>> '{summary,blocked}')::int
        ) order by family)
        from canonical_family_eval
      ),'[]'::jsonb),
      'explicit_vocation_families',coalesce((
        select jsonb_agg(jsonb_build_object(
          'weapon_family',weapon_family,
          'level_eligible_items',level_eligible_items
        ) order by weapon_family)
        from explicit_families
      ),'[]'::jsonb),
      'unrestricted_catalog_families',coalesce((
        select jsonb_agg(jsonb_build_object(
          'weapon_family',weapon_family,
          'level_eligible_items',level_eligible_items
        ) order by weapon_family)
        from unrestricted_families
        where level_eligible_items>0
      ),'[]'::jsonb),
      'raw_catalog_family_status',coalesce((
        select jsonb_agg(jsonb_build_object(
          'weapon_family',weapon_family,
          'eligible',coalesce((candidate_result #>> '{summary,eligible}')::int,0),
          'incomplete',coalesce((candidate_result #>> '{summary,incomplete}')::int,0),
          'blocked',coalesce((candidate_result #>> '{summary,blocked}')::int,0)
        ) order by weapon_family)
        from family_eval
      ),'[]'::jsonb),
      'note','Canonical identity, explicit vocation restrictions and unrestricted catalog compatibility are intentionally separate.'
    ),
    'equipment',jsonb_build_object(
      'eligible_by_slot',coalesce((
        select jsonb_agg(jsonb_build_object(
          'slot_key',slot_key,'eligible',eligible,'catalog_items',catalog_items
        ) order by slot_key)
        from equipment_by_slot
      ),'[]'::jsonb),
      'loadout_compatibility_stage','loadout_compatibility_universal_v1'
    ),
    'spells',jsonb_build_object(
      'summary',(select j->'summary' from spells),
      'by_group',coalesce((
        select jsonb_agg(jsonb_build_object(
          'spell_group',spell_group,'returned',returned,'eligible',eligible,
          'incomplete',incomplete,'blocked',blocked
        ) order by spell_group)
        from spell_groups
      ),'[]'::jsonb),
      'eligible_by_element',coalesce((
        select jsonb_agg(jsonb_build_object('element',element,'eligible',eligible) order by element)
        from spell_elements where eligible>0
      ),'[]'::jsonb),
      'resource_key',(select resource_key from r)
    ),
    'community_evidence',jsonb_build_object(
      'observed_players',(select observed_players from community),
      'evidence_tier','C',
      'affects_identity',false
    ),
    'hunt_observation',
      case
        when p_hunt_key is null then jsonb_build_object('provided',false)
        else jsonb_build_object(
          'provided',true,
          'incoming_damage',(select j->'incoming_damage' from hunt_ctx),
          'community_observed_imbuement_usage',(select j->'community_observed_usage' from hunt_ctx),
          'affects_vocation_identity',false
        )
      end,
    'methodology',jsonb_build_object(
      'stage','vocation_composition_universal_v1',
      'category_first',true,
      'canonical_identity_separate_from_catalog_eligibility',true,
      'explicit_and_unrestricted_weapon_families_separate',true,
      'community_evidence_tier','C',
      'community_evidence_affects_identity',false,
      'ranking_applied',false,
      'final_optimizer_applied',false,
      'cross_vocation_score_applied',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_vocation_composition_universal(text,integer,jsonb,text)
from public,anon,authenticated;
grant execute on function public.huntnexus_vocation_composition_universal(text,integer,jsonb,text)
to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_vocation_composition_audit()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select jsonb_build_object(
  'summary',jsonb_build_object(
    'vocation_rules',(select count(*) from vocation_composition_rules),
    'represented_vocations',(select count(distinct vocation_code) from vocation_composition_rules),
    'vocations_with_spell_catalog',(select count(distinct vocation) from vw_spell_catalog_universal),
    'vocations_with_community_players',(select count(distinct vocation) from session_players),
    'monk_profile_contract_ready',
      (huntnexus_vocation_profile_contract_universal('EM') #>> '{vocation,code}')='EM',
    'profile_contract_ready',true,
    'weapon_identity_contract_ready',true,
    'equipment_slot_summary_ready',true,
    'spell_unlock_composition_ready',true,
    'hunt_observation_hook_ready',true,
    'cross_vocation_ranking_ready',false,
    'final_optimizer_ready',false
  ),
  'by_vocation',coalesce((
    select jsonb_agg(jsonb_build_object(
      'vocation_code',r.vocation_code,
      'primary_skill_mode',r.primary_skill_mode,
      'primary_skill_keys',r.primary_skill_keys,
      'canonical_weapon_families',r.canonical_weapon_families,
      'resource_key',r.resource_key,
      'spell_count',(select count(*) from vw_spell_catalog_universal s where s.vocation=r.vocation_code),
      'community_players',(select count(*) from session_players sp where sp.vocation=r.vocation_code)
    ) order by r.vocation_code)
    from vocation_composition_rules r
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','vocation_composition_audit_v1',
    'category_first',true,
    'identity_not_inferred_from_unrestricted_items',true,
    'optimizer_applied',false
  )
);
$function$
;

revoke all on function public.huntnexus_vocation_composition_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_vocation_composition_audit()
to service_role;
