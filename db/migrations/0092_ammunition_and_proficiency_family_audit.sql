-- HuntNexus — canonical ammunition catalog + Weapon Proficiency family coverage audit.
-- Tier B ammunition source: TibiaWiki BR / Munição.
-- Tier B proficiency source: TibiaWiki BR / Weapon Proficiency.
-- Combat score/ranking is intentionally not introduced here.

create table if not exists public.ammunition_catalog (
  item_key text primary key,
  name text not null,
  ammunition_family text not null check (ammunition_family in ('arrow','bolt')),
  level_required integer not null default 0,
  source_attack integer not null,
  physical_attack integer,
  elemental_attack integer,
  element text,
  attack_pattern text not null default 'single_or_unspecified',
  source_tier text not null,
  source_url text not null,
  observed_at timestamptz not null,
  notes text
);

alter table public.ammunition_catalog enable row level security;
revoke all on public.ammunition_catalog from public,anon,authenticated;
grant select on public.ammunition_catalog to service_role;

insert into public.ammunition_catalog(
  item_key,name,ammunition_family,level_required,source_attack,
  physical_attack,elemental_attack,element,attack_pattern,
  source_tier,source_url,observed_at,notes
)
values
  ('arrow','Arrow','arrow',0,25,25,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('burst-arrow','Burst Arrow','arrow',0,27,27,null,null,'unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('crystalline-arrow','Crystalline Arrow','arrow',90,65,65,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('diamond-arrow','Diamond Arrow','arrow',150,37,37,null,null,'area','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00','TibiaWiki describes Diamond Arrow as area damage ammunition.'),
  ('earth-arrow','Earth Arrow','arrow',20,14,14,14,'earth','hybrid_elemental','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('envenomed-arrow','Envenomed Arrow','arrow',70,27,27,27,'earth','hybrid_elemental','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('firestorm-arrow','Firestorm Arrow','arrow',125,21,null,21,'fire','pure_elemental','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('flaming-arrow','Flaming Arrow','arrow',20,14,14,14,'fire','hybrid_elemental','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('flash-arrow','Flash Arrow','arrow',20,14,14,14,'energy','hybrid_elemental','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('froststorm-arrow','Froststorm Arrow','arrow',125,21,null,21,'ice','pure_elemental','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('onyx-arrow','Onyx Arrow','arrow',40,38,38,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('poison-arrow','Poison Arrow','arrow',0,23,23,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('shatterstorm-arrow','Shatterstorm Arrow','arrow',50,27,27,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('shiver-arrow','Shiver Arrow','arrow',20,14,14,14,'ice','hybrid_elemental','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('simple-arrow','Simple Arrow','arrow',0,20,20,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('sniper-arrow','Sniper Arrow','arrow',20,28,28,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('tarsal-arrow','Tarsal Arrow','arrow',30,33,33,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('terrastorm-arrow','Terrastorm Arrow','arrow',125,21,null,21,'earth','pure_elemental','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('thunderstorm-arrow','Thunderstorm Arrow','arrow',125,21,null,21,'energy','pure_elemental','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('bolt','Bolt','bolt',0,30,30,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('drill-bolt','Drill Bolt','bolt',70,56,56,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('infernal-bolt','Infernal Bolt','bolt',110,72,72,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('piercing-bolt','Piercing Bolt','bolt',30,33,33,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('power-bolt','Power Bolt','bolt',55,40,40,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('prismatic-bolt','Prismatic Bolt','bolt',90,66,66,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('spectral-bolt','Spectral Bolt','bolt',150,78,78,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null),
  ('vortex-bolt','Vortex Bolt','bolt',40,36,36,null,null,'single_or_unspecified','B','https://www.tibiawiki.com.br/Muni%C3%A7%C3%A3o','2026-10-09 00:00:00+00',null)
on conflict (item_key) do update set
  name=excluded.name,
  ammunition_family=excluded.ammunition_family,
  level_required=excluded.level_required,
  source_attack=excluded.source_attack,
  physical_attack=excluded.physical_attack,
  elemental_attack=excluded.elemental_attack,
  element=excluded.element,
  attack_pattern=excluded.attack_pattern,
  source_tier=excluded.source_tier,
  source_url=excluded.source_url,
  observed_at=excluded.observed_at,
  notes=excluded.notes;

CREATE OR REPLACE FUNCTION public.huntnexus_ammunition_candidates(p_family text, p_level integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    lower(trim(coalesce(p_family,''))) as family,
    greatest(coalesce(p_level,1),1) as level_value
),
rows as (
  select a.*,
    case when a.level_required <= p.level_value then 'eligible' else 'blocked' end as eligibility_status,
    case when a.level_required <= p.level_value then array[]::text[]
         else array['level_requirement']::text[] end as blocking_reasons
  from ammunition_catalog a
  cross join p
  where a.ammunition_family=p.family
)
select case
  when (select family from p) not in ('arrow','bolt') then
    jsonb_build_object(
      'error','unsupported_ammunition_family',
      'family',(select family from p),
      'supported_families',jsonb_build_array('arrow','bolt'),
      'methodology',jsonb_build_object('stage','ammunition_candidates_v1')
    )
  else jsonb_build_object(
    'family',(select family from p),
    'level',(select level_value from p),
    'summary',jsonb_build_object(
      'catalog_items',(select count(*) from rows),
      'eligible',(select count(*) from rows where eligibility_status='eligible'),
      'blocked',(select count(*) from rows where eligibility_status='blocked')
    ),
    'items',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'item_key',item_key,
          'name',name,
          'level_required',level_required,
          'source_attack',source_attack,
          'physical_attack',physical_attack,
          'elemental_attack',elemental_attack,
          'element',element,
          'attack_pattern',attack_pattern,
          'eligibility_status',eligibility_status,
          'blocking_reasons',to_jsonb(blocking_reasons),
          'source',jsonb_build_object(
            'tier',source_tier,
            'url',source_url,
            'observed_at',observed_at
          )
        )
        order by
          case eligibility_status when 'eligible' then 0 else 1 end,
          level_required desc,
          source_attack desc,
          name
      )
      from rows
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','ammunition_candidates_v1',
      'combat_formula_applied',false,
      'source_attack_is_not_final_damage',true,
      'physical_and_elemental_components_kept_separate',true
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_ammunition_candidates(text,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_ammunition_candidates(text,integer)
  to service_role;

create table if not exists public.weapon_proficiency_family_rules (
  weapon_family text primary key,
  system_status text not null check (system_status in ('supported','not_listed','unknown')),
  progression_group text,
  source_tier text not null,
  source_url text not null,
  observed_at timestamptz not null,
  notes text
);

alter table public.weapon_proficiency_family_rules enable row level security;
revoke all on public.weapon_proficiency_family_rules from public,anon,authenticated;
grant select on public.weapon_proficiency_family_rules to service_role;

insert into public.weapon_proficiency_family_rules(
  weapon_family,system_status,progression_group,source_tier,source_url,observed_at,notes
)
values
  ('axe','supported','melee_standard_or_knight_exclusive','B','https://www.tibiawiki.com.br/wiki/Weapon_Proficiency','2026-10-09 00:00:00+00',null),
  ('bow','supported','standard','B','https://www.tibiawiki.com.br/wiki/Weapon_Proficiency','2026-10-09 00:00:00+00',null),
  ('club','supported','melee_standard_or_knight_exclusive','B','https://www.tibiawiki.com.br/wiki/Weapon_Proficiency','2026-10-09 00:00:00+00',null),
  ('crossbow','supported','crossbow','B','https://www.tibiawiki.com.br/wiki/Weapon_Proficiency','2026-10-09 00:00:00+00',null),
  ('fist','supported','standard','B','https://www.tibiawiki.com.br/wiki/Weapon_Proficiency','2026-10-09 00:00:00+00',null),
  ('rod','supported','standard','B','https://www.tibiawiki.com.br/wiki/Weapon_Proficiency','2026-10-09 00:00:00+00',null),
  ('sword','supported','melee_standard_or_knight_exclusive','B','https://www.tibiawiki.com.br/wiki/Weapon_Proficiency','2026-10-09 00:00:00+00',null),
  ('throwing','not_listed',null,'B','https://www.tibiawiki.com.br/wiki/Weapon_Proficiency','2026-10-09 00:00:00+00','Throwing is not listed in the current Tier-B system family tables; do not infer support or non-support beyond that.'),
  ('wand','supported','standard','B','https://www.tibiawiki.com.br/wiki/Weapon_Proficiency','2026-10-09 00:00:00+00',null)
on conflict (weapon_family) do update set
  system_status=excluded.system_status,
  progression_group=excluded.progression_group,
  source_tier=excluded.source_tier,
  source_url=excluded.source_url,
  observed_at=excluded.observed_at,
  notes=excluded.notes;

create or replace view public.vw_weapon_proficiency_family_audit
with (security_invoker=true)
as
 SELECT f.weapon_family,
    f.system_status,
    f.progression_group,
    count(w.item_key)::integer AS catalog_weapons,
    count(w.item_key) FILTER (WHERE w.proficiency_tree_available)::integer AS normalized_trees,
    count(w.item_key) FILTER (WHERE NOT w.proficiency_tree_available)::integer AS weapons_without_normalized_tree,
        CASE
            WHEN f.system_status = 'supported'::text AND count(w.item_key) > 0 THEN round(100.0 * count(w.item_key) FILTER (WHERE w.proficiency_tree_available)::numeric / count(w.item_key)::numeric, 2)
            ELSE NULL::numeric
        END AS normalized_tree_coverage_percent,
    f.source_tier,
    f.source_url,
    f.observed_at,
    f.notes
   FROM weapon_proficiency_family_rules f
     LEFT JOIN vw_weapon_catalog_universal w ON w.weapon_family = f.weapon_family
  GROUP BY f.weapon_family, f.system_status, f.progression_group, f.source_tier, f.source_url, f.observed_at, f.notes;;

revoke all on public.vw_weapon_proficiency_family_audit from public,anon,authenticated;
grant select on public.vw_weapon_proficiency_family_audit to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_weapon_usage_context(p_item_key text, p_vocation text, p_level integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with w as (
  select * from vw_weapon_catalog_universal where item_key=p_item_key
),
r as (
  select ur.* from w
  join weapon_usage_rules ur on ur.weapon_family=w.weapon_family
),
p as (
  select huntnexus_normalize_vocation(p_vocation) as vocation_code,
         greatest(coalesce(p_level,1),1) as level_value
),
elig as (
  select huntnexus_weapon_candidates_universal(
    p_vocation,p_level,null,(select weapon_family from w),250
  ) as j
),
weapon_status as (
  select value as item
  from elig,lateral jsonb_array_elements(j->'items') value
  where value->>'item_key'=p_item_key
  limit 1
),
quivers as (
  select q.*,
    case
      when (select vocation_code from p)<>'RP' then 'blocked'
      when q.level_required>(select level_value from p) then 'blocked'
      else 'eligible'
    end as eligibility_status,
    array_remove(array[
      case when (select vocation_code from p)<>'RP' then 'vocation_restriction' end,
      case when q.level_required>(select level_value from p) then 'level_requirement' end
    ],null) as blocking_reasons
  from vw_quiver_catalog_universal q
),
qjson as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'item_key',item_key,
      'name',name,
      'level_required',level_required,
      'level_basis',level_basis,
      'eligibility_status',eligibility_status,
      'blocking_reasons',to_jsonb(blocking_reasons),
      'effects',effects,
      'wiki_url',wiki_url
    )
    order by case eligibility_status when 'eligible' then 0 else 1 end,
             level_required desc,name
  ),'[]'::jsonb) as items
  from quivers
),
ammo as (
  select
    case when (select ammunition_required from r)
      then huntnexus_ammunition_candidates(
        (select ammunition_family from r),
        (select level_value from p)
      )
      else null
    end as candidates
)
select case
  when not exists(select 1 from w) then jsonb_build_object(
    'error','weapon_not_found',
    'item_key',p_item_key,
    'methodology',jsonb_build_object('stage','weapon_usage_context_v2')
  )
  else jsonb_build_object(
    'weapon',jsonb_build_object(
      'item_key',(select item_key from w),
      'name',(select name from w),
      'weapon_class',(select weapon_class from w),
      'weapon_family',(select weapon_family from w),
      'hands',(select hands from w),
      'eligibility',coalesce((select item from weapon_status),'{}'::jsonb)
    ),
    'usage',jsonb_build_object(
      'hand_model',(select hand_model from r),
      'offhand_policy',
        case
          when (select weapon_family from w) in ('sword','axe','club','fist')
               and (select hands from w)='Two' then 'blocked_by_two_handed_weapon'
          when (select weapon_family from w) in ('sword','axe','club','fist')
               and (select hands from w)='One' then 'optional_shield_offhand'
          else (select offhand_policy from r)
        end,
      'requires_quiver',(select requires_quiver from r),
      'ammunition_required',(select ammunition_required from r),
      'ammunition_family',(select ammunition_family from r),
      'ammunition_catalog_status',
        case when (select ammunition_required from r) then 'available'
             else 'not_required' end
    ),
    'dependencies',jsonb_build_object(
      'quiver',
        case when (select requires_quiver from r)
          then jsonb_build_object(
            'required',true,
            'catalog_status','available',
            'eligible_count',(select count(*) from quivers where eligibility_status='eligible'),
            'items',(select items from qjson)
          )
          else jsonb_build_object('required',false)
        end,
      'ammunition',
        case when (select ammunition_required from r)
          then jsonb_build_object(
            'required',true,
            'family',(select ammunition_family from r),
            'catalog_status','available',
            'candidate_selection_ready',true,
            'candidates',(select candidates from ammo)
          )
          else jsonb_build_object('required',false,'catalog_status','not_required')
        end
    ),
    'source',jsonb_build_object(
      'tier',(select source_tier from r),
      'url',(select source_url from r),
      'observed_at',(select observed_at from r)
    ),
    'methodology',jsonb_build_object(
      'stage','weapon_usage_context_v2',
      'category_first',true,
      'combat_score_applied',false,
      'compatibility_only',true,
      'ammunition_catalog_integrated',true
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_weapon_usage_context(text,text,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_weapon_usage_context(text,text,integer)
  to service_role;
