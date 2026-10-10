-- HuntNexus — universal slot/restriction compatibility contract.
-- Validates canonical loadout slots, item level/vocation restrictions, hand conflicts,
-- Bow/Crossbow quiver+ammunition dependencies and explicit out-of-scope container support.
-- No ranking or final optimizer is introduced.

create table if not exists public.loadout_slot_rules (
  selection_key text primary key,
  role_type text not null check (role_type in ('body_slot','weapon_slot','offhand_slot','dependency','out_of_scope')),
  target_domain text,
  allowed_families jsonb not null default '[]'::jsonb,
  source_tier text not null,
  source_url text,
  observed_at timestamptz not null,
  notes text
);

alter table public.loadout_slot_rules enable row level security;
revoke all on public.loadout_slot_rules from public,anon,authenticated;
grant select on public.loadout_slot_rules to service_role;

insert into public.loadout_slot_rules(
  selection_key,role_type,target_domain,allowed_families,source_tier,source_url,observed_at,notes
) values
  ('ammunition','dependency','ammunition','["arrow","bolt"]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Aljavas','2026-10-09 00:00:00+00'::timestamptz,'Modeled as Bow/Crossbow dependency, not as an independent body-equipment slot.'),
  ('body','body_slot','equipment','["armor"]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Invent%C3%A1rio','2026-10-09 00:00:00+00'::timestamptz,'Single torso/body slot.'),
  ('container','out_of_scope','container','["backpack"]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Manual%3AInterface','2026-10-09 00:00:00+00'::timestamptz,'Inventory container slot exists, but backpack catalog is outside the current HuntNexus equipment layer.'),
  ('feet','body_slot','equipment','["boots"]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Invent%C3%A1rio','2026-10-09 00:00:00+00'::timestamptz,'Single feet slot.'),
  ('head','body_slot','equipment','["helmet"]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Invent%C3%A1rio','2026-10-09 00:00:00+00'::timestamptz,'Single head slot.'),
  ('legs','body_slot','equipment','["legs"]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Invent%C3%A1rio','2026-10-09 00:00:00+00'::timestamptz,'Single legs slot.'),
  ('neck','body_slot','equipment','["amulet_necklace"]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Invent%C3%A1rio','2026-10-09 00:00:00+00'::timestamptz,'Single amulet/necklace slot.'),
  ('offhand','offhand_slot','equipment','["shield","spellbook","quiver"]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Manual%3AInterface','2026-10-09 00:00:00+00'::timestamptz,'Shield slot may carry shield, spellbook or quiver when item/vocation requirements allow.'),
  ('ring','body_slot','equipment','["ring"]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Invent%C3%A1rio','2026-10-09 00:00:00+00'::timestamptz,'Single ring slot.'),
  ('weapon','weapon_slot','weapon','[]'::jsonb,'B','https://www.tibiawiki.com.br/wiki/Manual%3AInterface','2026-10-09 00:00:00+00'::timestamptz,'Weapon slot; one/two-hand semantics are resolved from the selected weapon.')
on conflict(selection_key) do update set
  role_type=excluded.role_type,
  target_domain=excluded.target_domain,
  allowed_families=excluded.allowed_families,
  source_tier=excluded.source_tier,
  source_url=excluded.source_url,
  observed_at=excluded.observed_at,
  notes=excluded.notes;

create or replace view public.vw_loadout_item_catalog_universal
with (security_invoker=true)
as
 SELECT w.item_key,
    w.name,
    'weapon'::text AS selection_key,
    'weapon'::text AS item_domain,
    w.weapon_family AS item_family,
    w.level_required,
    w.vocation_scope,
    w.vocation_keys,
    w.hands,
    w.weapon_class,
    w.imbue_slots,
    w.wiki_url
   FROM vw_weapon_catalog_universal w
UNION ALL
 SELECT e.item_key,
    e.name,
    e.slot_key AS selection_key,
    'equipment'::text AS item_domain,
    e.equipment_family AS item_family,
    e.level_required,
    e.vocation_scope,
    e.vocation_keys,
    NULL::text AS hands,
    NULL::text AS weapon_class,
    e.imbue_slots,
    e.wiki_url
   FROM vw_equipment_catalog_universal e
UNION ALL
 SELECT a.item_key,
    a.name,
    'ammunition'::text AS selection_key,
    'ammunition'::text AS item_domain,
    a.ammunition_family AS item_family,
    a.level_required,
    'unrestricted'::text AS vocation_scope,
    ARRAY[]::text[] AS vocation_keys,
    NULL::text AS hands,
    'distance_dependency'::text AS weapon_class,
    NULL::integer AS imbue_slots,
    a.source_url AS wiki_url
   FROM ammunition_catalog a;

revoke all on public.vw_loadout_item_catalog_universal from public,anon,authenticated;
grant select on public.vw_loadout_item_catalog_universal to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_loadout_compatibility_universal(p_vocation text, p_level integer, p_selection jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with params as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    case
      when jsonb_typeof(coalesce(p_selection,'{}'::jsonb))='object'
        then coalesce(p_selection,'{}'::jsonb)
      else '{}'::jsonb
    end as selection,
    jsonb_typeof(coalesce(p_selection,'{}'::jsonb))='object' as valid_object
),
mapped as (
  select *,
    case vocation_code
      when 'EK' then 'knight'
      when 'RP' then 'paladin'
      when 'ED' then 'druid'
      when 'MS' then 'sorcerer'
      when 'EM' then 'monk'
      else null
    end as vocation_key
  from params
),
selected as (
  select
    x.key as selected_slot,
    nullif(trim(x.value #>> '{}'),'') as item_key
  from mapped p
  cross join lateral jsonb_each(p.selection) x
  where x.value <> 'null'::jsonb
    and nullif(trim(x.value #>> '{}'),'') is not null
),
slot_rules as (
  select * from loadout_slot_rules
),
resolved as (
  select
    s.selected_slot,
    s.item_key,
    r.role_type,
    r.target_domain,
    r.allowed_families,
    c.name,
    c.selection_key as catalog_slot,
    c.item_domain,
    c.item_family,
    c.level_required,
    c.vocation_scope,
    c.vocation_keys,
    c.hands,
    c.weapon_class,
    c.imbue_slots,
    (r.selection_key is not null) as known_selection_key,
    (c.item_key is not null) as item_found,
    case
      when c.item_key is null then false
      when s.selected_slot='container' then false
      else c.selection_key=s.selected_slot
    end as slot_matches,
    case
      when c.item_key is null then false
      when c.level_required <= (select level_value from mapped) then true
      else false
    end as level_ok,
    case
      when c.item_key is null then false
      when c.vocation_scope<>'explicit' then true
      when (select vocation_key from mapped) = any(c.vocation_keys) then true
      else false
    end as vocation_ok
  from selected s
  left join slot_rules r on r.selection_key=s.selected_slot
  left join vw_loadout_item_catalog_universal c on c.item_key=s.item_key
),
slot_evaluation as (
  select
    *,
    array_remove(array[
      case when not known_selection_key then 'unknown_selection_key' end,
      case when known_selection_key and role_type='out_of_scope' then 'catalog_out_of_scope' end,
      case when known_selection_key and role_type<>'out_of_scope' and not item_found then 'item_not_found' end,
      case when item_found and known_selection_key and role_type<>'out_of_scope' and not slot_matches then 'wrong_slot' end,
      case when item_found and slot_matches and not level_ok then 'level_requirement' end,
      case when item_found and slot_matches and not vocation_ok then 'vocation_restriction' end
    ],null) as issues
  from resolved
),
weapon as (
  select * from slot_evaluation
  where selected_slot='weapon' and item_found
  limit 1
),
offhand as (
  select * from slot_evaluation
  where selected_slot='offhand' and item_found
  limit 1
),
ammo as (
  select * from slot_evaluation
  where selected_slot='ammunition' and item_found
  limit 1
),
combination_issues as (
  select issue,severity
  from (
    values
      (
        case
          when exists(select 1 from weapon where hands='Two' and item_family not in ('bow','crossbow'))
           and exists(select 1 from offhand)
          then 'two_handed_weapon_blocks_offhand'
        end,
        'blocked'::text
      ),
      (
        case
          when exists(select 1 from weapon where item_family in ('bow','crossbow'))
           and not exists(select 1 from offhand)
          then 'required_quiver_missing'
        end,
        'incomplete'::text
      ),
      (
        case
          when exists(select 1 from weapon where item_family in ('bow','crossbow'))
           and exists(select 1 from offhand where item_family<>'quiver')
          then 'quiver_required_for_bow_crossbow'
        end,
        'blocked'::text
      ),
      (
        case
          when exists(select 1 from weapon where item_family in ('bow','crossbow'))
           and not exists(select 1 from ammo)
          then 'required_ammunition_missing'
        end,
        'incomplete'::text
      ),
      (
        case
          when exists(select 1 from weapon where item_family='bow')
           and exists(select 1 from ammo where item_family<>'arrow')
          then 'ammunition_family_mismatch'
        end,
        'blocked'::text
      ),
      (
        case
          when exists(select 1 from weapon where item_family='crossbow')
           and exists(select 1 from ammo where item_family<>'bolt')
          then 'ammunition_family_mismatch'
        end,
        'blocked'::text
      ),
      (
        case
          when exists(select 1 from ammo)
           and not exists(select 1 from weapon)
          then 'ammunition_without_weapon'
        end,
        'blocked'::text
      ),
      (
        case
          when exists(select 1 from ammo)
           and exists(select 1 from weapon where item_family not in ('bow','crossbow'))
          then 'ammunition_not_used_by_weapon'
        end,
        'blocked'::text
      )
  ) x(issue,severity)
  where issue is not null
),
slot_blockers as (
  select count(*)::int as n
  from slot_evaluation
  where array_length(issues,1) is not null
),
hard_slot_blockers as (
  select count(*)::int as n
  from slot_evaluation
  where issues && array[
    'unknown_selection_key','item_not_found','wrong_slot',
    'level_requirement','vocation_restriction'
  ]::text[]
),
scope_gaps as (
  select count(*)::int as n
  from slot_evaluation
  where issues && array['catalog_out_of_scope']::text[]
),
combo_blockers as (
  select count(*)::int as n
  from combination_issues where severity='blocked'
),
combo_incomplete as (
  select count(*)::int as n
  from combination_issues where severity='incomplete'
),
dup_items as (
  select item_key,count(*)::int as uses
  from selected
  group by item_key
  having count(*)>1
),
duplicate_count as (
  select count(*)::int as n from dup_items
)
select case
  when not (select valid_object from mapped) then
    jsonb_build_object(
      'error','selection_must_be_object',
      'methodology',jsonb_build_object('stage','loadout_compatibility_universal_v1')
    )
  when (select vocation_key from mapped) is null then
    jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'supported_vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
      'methodology',jsonb_build_object('stage','loadout_compatibility_universal_v1')
    )
  else jsonb_build_object(
    'context',jsonb_build_object(
      'vocation',(select vocation_code from mapped),
      'vocation_key',(select vocation_key from mapped),
      'level',(select level_value from mapped)
    ),
    'selection',coalesce(p_selection,'{}'::jsonb),
    'status',
      case
        when (select n from hard_slot_blockers)>0
          or (select n from combo_blockers)>0
          or (select n from duplicate_count)>0
          then 'blocked'
        when (select n from scope_gaps)>0
          or (select n from combo_incomplete)>0
          then 'incomplete'
        else 'valid'
      end,
    'slot_evaluations',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'selected_slot',selected_slot,
          'item_key',item_key,
          'name',name,
          'role_type',role_type,
          'item_domain',item_domain,
          'item_family',item_family,
          'catalog_slot',catalog_slot,
          'hands',hands,
          'level_required',level_required,
          'vocation_scope',vocation_scope,
          'vocation_keys',to_jsonb(vocation_keys),
          'issues',to_jsonb(issues),
          'status',case
            when issues && array[
              'unknown_selection_key','item_not_found','wrong_slot',
              'level_requirement','vocation_restriction'
            ]::text[] then 'blocked'
            when issues && array['catalog_out_of_scope']::text[] then 'incomplete'
            else 'valid'
          end
        )
        order by selected_slot
      )
      from slot_evaluation
    ),'[]'::jsonb),
    'combination_issues',coalesce((
      select jsonb_agg(
        jsonb_build_object('issue',issue,'severity',severity)
        order by severity,issue
      )
      from combination_issues
    ),'[]'::jsonb),
    'duplicate_item_selections',coalesce((
      select jsonb_agg(
        jsonb_build_object('item_key',item_key,'uses',uses)
        order by item_key
      ) from dup_items
    ),'[]'::jsonb),
    'weapon_dependency_summary',jsonb_build_object(
      'weapon_selected',exists(select 1 from weapon),
      'weapon_family',(select item_family from weapon),
      'weapon_hands',(select hands from weapon),
      'offhand_selected',exists(select 1 from offhand),
      'offhand_family',(select item_family from offhand),
      'ammunition_selected',exists(select 1 from ammo),
      'ammunition_family',(select item_family from ammo),
      'complete',(
        (select n from combo_incomplete)=0
        and (select n from combo_blockers)=0
      )
    ),
    'scope',jsonb_build_object(
      'supported_selection_keys',(
        select jsonb_agg(selection_key order by selection_key)
        from loadout_slot_rules
        where role_type<>'out_of_scope'
      ),
      'out_of_scope_selection_keys',(
        select jsonb_agg(selection_key order by selection_key)
        from loadout_slot_rules
        where role_type='out_of_scope'
      )
    ),
    'methodology',jsonb_build_object(
      'stage','loadout_compatibility_universal_v1',
      'category_first',true,
      'single_item_score_applied',false,
      'loadout_score_applied',false,
      'final_optimizer_applied',false,
      'body_slots_optional_for_partial_validation',true,
      'weapon_dependencies_can_mark_selection_incomplete',true,
      'two_handed_bow_crossbow_quiver_exception_applied',true,
      'vocation_and_level_restrictions_applied',true,
      'container_catalog_modeled',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_loadout_compatibility_universal(text,integer,jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_loadout_compatibility_universal(text,integer,jsonb)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_slot_compatibility_audit()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select jsonb_build_object(
  'summary',jsonb_build_object(
    'selection_rules',(select count(*) from loadout_slot_rules),
    'supported_selection_keys',(
      select count(*) from loadout_slot_rules where role_type<>'out_of_scope'
    ),
    'out_of_scope_selection_keys',(
      select count(*) from loadout_slot_rules where role_type='out_of_scope'
    ),
    'weapon_families_with_usage_rules',(select count(*) from weapon_usage_rules),
    'equipment_slots',(select count(distinct slot_key) from vw_equipment_catalog_universal),
    'equipment_families',(select count(distinct equipment_family) from vw_equipment_catalog_universal),
    'ammunition_families',(select count(distinct ammunition_family) from ammunition_catalog),
    'slot_contract_ready',true,
    'weapon_offhand_dependency_ready',true,
    'vocation_level_restriction_ready',true,
    'container_catalog_ready',false,
    'final_loadout_optimizer_ready',false
  ),
  'methodology',jsonb_build_object(
    'stage','slot_compatibility_audit_v1',
    'category_first',true,
    'compatibility_only',true,
    'ranking_applied',false,
    'final_optimizer_applied',false
  )
);
$function$
;

revoke all on function public.huntnexus_slot_compatibility_audit()
  from public,anon,authenticated;
grant execute on function public.huntnexus_slot_compatibility_audit()
  to service_role;
