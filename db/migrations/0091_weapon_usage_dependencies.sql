-- HuntNexus — universal weapon usage/dependency rules.
-- Tier-B mechanics are kept separate from item catalog facts.

create table if not exists public.weapon_usage_rules (
  weapon_family text primary key,
  weapon_class text not null,
  hand_model text not null,
  offhand_policy text not null,
  requires_quiver boolean not null default false,
  ammunition_family text,
  ammunition_required boolean not null default false,
  source_tier text not null,
  source_url text,
  observed_at timestamptz not null default now(),
  notes text
);

alter table public.weapon_usage_rules enable row level security;
revoke all on public.weapon_usage_rules from public, anon, authenticated;
grant select on public.weapon_usage_rules to service_role;

insert into public.weapon_usage_rules(
  weapon_family,weapon_class,hand_model,offhand_policy,
  requires_quiver,ammunition_family,ammunition_required,
  source_tier,source_url,observed_at,notes
)
values
  ('sword','melee','source_hands','one_hand_optional_offhand_two_hand_blocked',false,null,false,
   'catalog',null,'2026-10-09T00:00:00Z',
   'Hand compatibility is driven by each item hands value; no external family-wide combat rule is inferred.'),
  ('axe','melee','source_hands','one_hand_optional_offhand_two_hand_blocked',false,null,false,
   'catalog',null,'2026-10-09T00:00:00Z',
   'Hand compatibility is driven by each item hands value; no external family-wide combat rule is inferred.'),
  ('club','melee','source_hands','one_hand_optional_offhand_two_hand_blocked',false,null,false,
   'catalog',null,'2026-10-09T00:00:00Z',
   'Hand compatibility is driven by each item hands value; no external family-wide combat rule is inferred.'),
  ('fist','melee','source_hands','one_hand_optional_offhand_two_hand_blocked',false,null,false,
   'catalog',null,'2026-10-09T00:00:00Z',
   'Hand compatibility is driven by each item hands value; no external family-wide combat rule is inferred.'),
  ('bow','distance','two_handed_plus_quiver_slot','quiver_required',true,'arrow',true,
   'B','https://www.tibiawiki.com.br/wiki/Aljavas','2026-10-09T00:00:00Z',
   'Bows require a quiver to use ammunition properly.'),
  ('crossbow','distance','two_handed_plus_quiver_slot','quiver_required',true,'bolt',true,
   'B','https://www.tibiawiki.com.br/wiki/Aljavas','2026-10-09T00:00:00Z',
   'Crossbows require a quiver to use ammunition properly.'),
  ('throwing','distance','one_handed','optional_shield_offhand',false,null,false,
   'B','https://www.tibiawiki.com.br/wiki/Dist%C3%A2ncia','2026-10-09T00:00:00Z',
   'Throwing weapons can be used with a shield/off-hand.'),
  ('wand','caster','one_handed','optional_shield_or_spellbook',false,null,false,
   'B','https://www.tibiawiki.com.br/Wands','2026-10-09T00:00:00Z',
   'Wands are one-handed and may be used with shield or spellbook.'),
  ('rod','caster','one_handed','optional_shield_or_spellbook',false,null,false,
   'B','https://www.tibiawiki.com.br/Rods','2026-10-09T00:00:00Z',
   'Rods are one-handed and may be used with shield or spellbook.')
on conflict (weapon_family) do update set
  weapon_class=excluded.weapon_class,
  hand_model=excluded.hand_model,
  offhand_policy=excluded.offhand_policy,
  requires_quiver=excluded.requires_quiver,
  ammunition_family=excluded.ammunition_family,
  ammunition_required=excluded.ammunition_required,
  source_tier=excluded.source_tier,
  source_url=excluded.source_url,
  observed_at=excluded.observed_at,
  notes=excluded.notes;

create or replace view public.vw_quiver_catalog_universal
with (security_invoker = true)
as
select
  i.id as item_id,
  i.slug as item_key,
  i.name,
  'quiver'::text as equipment_family,
  'shield_slot'::text as slot_key,
  'paladin'::text as primary_vocation_key,
  case when huntnexus_first_int(i.level_required) is null then 0
       else huntnexus_first_int(i.level_required) end as level_required,
  case when huntnexus_first_int(i.level_required) is null then 'tier_b_zero_level'
       else 'source' end as level_basis,
  coalesce(e.effects,'[]'::jsonb) as effects,
  i.wiki_url,
  i.source_id,
  i.snapshot_id,
  i.source_last_updated,
  i.observed_at
from tibia_items i
left join lateral (
  select jsonb_agg(
    jsonb_build_object(
      'effect_type',ie.effect_type,
      'effect_key',ie.effect_key,
      'value',ie.numeric_value,
      'unit',ie.unit,
      'raw_value',ie.raw_value
    )
    order by ie.effect_type,ie.effect_key
  ) as effects
  from item_effects ie
  where ie.item_id=i.id
) e on true
where i.category='Quivers'
  and i.slug<>'quivers';

revoke all on public.vw_quiver_catalog_universal from public,anon,authenticated;
grant select on public.vw_quiver_catalog_universal to service_role;

create or replace function public.huntnexus_weapon_usage_context(
  p_item_key text,
  p_vocation text,
  p_level integer
)
returns jsonb
language sql
stable
set search_path = public, extensions
as $$
with w as (
  select *
  from vw_weapon_catalog_universal
  where item_key=p_item_key
),
r as (
  select ur.*
  from w
  join weapon_usage_rules ur on ur.weapon_family=w.weapon_family
),
p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
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
    order by
      case eligibility_status when 'eligible' then 0 else 1 end,
      level_required desc,name
  ),'[]'::jsonb) as items
  from quivers
)
select case
  when not exists(select 1 from w) then jsonb_build_object(
    'error','weapon_not_found',
    'item_key',p_item_key,
    'methodology',jsonb_build_object('stage','weapon_usage_context_v1')
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
        case when (select ammunition_required from r) then 'missing'
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
            'catalog_status','missing',
            'candidate_selection_ready',false
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
      'stage','weapon_usage_context_v1',
      'category_first',true,
      'combat_score_applied',false,
      'compatibility_only',true,
      'missing_ammunition_not_inferred',true
    )
  )
end;
$$;

revoke all on function public.huntnexus_weapon_usage_context(text,text,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_weapon_usage_context(text,text,integer)
  to service_role;
