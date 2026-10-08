-- HuntNexus — Weapon Proficiency preview only.
-- Explicit perk_order selections may be compared, but no proficiency effect
-- changes ranking or hand choice at this stage.

CREATE OR REPLACE FUNCTION public.huntnexus_proficiency_effect_family(p_effect_key text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select case
  when p_effect_key like '%critical_extra_damage%' then 'critical_extra_damage'
  when p_effect_key like '%critical_chance%' then 'critical_chance'
  when p_effect_key like '%life_leech%' then 'life_leech'
  when p_effect_key like '%mana_leech%' then 'mana_leech'
  when p_effect_key='fierce_berserk_base_damage' then 'base_damage'
  when p_effect_key='powerful_foe_damage' then 'damage'
  else p_effect_key
end;
$function$
;

revoke all on function public.huntnexus_proficiency_effect_family(text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_proficiency_effect_family(text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_weapon_proficiency_preview(p_item_key text, p_active_perk_orders jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with tree as (
  select t.*,i.name,i.category,i.weapon_type,i.hands
  from weapon_proficiency_trees t
  join tibia_items i on i.slug=t.item_key
  where t.item_key=p_item_key
),
orders as (
  select distinct value::int as perk_order
  from jsonb_array_elements_text(
    case
      when jsonb_typeof(coalesce(p_active_perk_orders,'[]'::jsonb))='array'
        then coalesce(p_active_perk_orders,'[]'::jsonb)
      else '[]'::jsonb
    end
  )
  where value ~ '^[0-9]+$'
    and value::int between 1 and 100
),
perks as (
  select
    p.*,
    huntnexus_proficiency_effect_family(p.effect_key) as effect_family,
    exists(
      select 1 from orders o where o.perk_order=p.perk_order
    ) as active
  from weapon_proficiency_perks p
  where p.item_key=p_item_key
),
active_summary as (
  select
    scope,
    effect_family,
    unit,
    source_stat_key,
    spell_key,
    sum(numeric_value) as total_value,
    count(*) as active_perks
  from perks
  where active
  group by scope,effect_family,unit,source_stat_key,spell_key
)
select coalesce((
  select jsonb_build_object(
    'item',jsonb_build_object(
      'item_key',t.item_key,
      'name',t.name,
      'category',t.category,
      'weapon_type',t.weapon_type,
      'hands',t.hands
    ),
    'tree',jsonb_build_object(
      'levels_declared',t.levels_declared,
      'topology_status',t.topology_status,
      'perk_count',t.perk_count,
      'source_tier',t.source_tier,
      'source_url',t.source_url
    ),
    'selection',jsonb_build_object(
      'mode',
        case when exists(select 1 from orders)
          then 'explicit_perk_order'
          else 'reference_only'
        end,
      'active_perk_orders',
        coalesce((select jsonb_agg(perk_order order by perk_order) from orders),'[]'::jsonb),
      'active_perk_count',(select count(*) from perks where active),
      'inferred_from_level',false
    ),
    'perks',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'perk_order',perk_order,
          'level_number',level_number,
          'effect_key',effect_key,
          'effect_family',effect_family,
          'value',numeric_value,
          'unit',unit,
          'scope',scope,
          'spell_key',spell_key,
          'source_stat_key',source_stat_key,
          'description',description_raw,
          'active',active
        )
        order by perk_order
      )
      from perks
    ),'[]'::jsonb),
    'active_effect_summary',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'scope',scope,
          'effect_family',effect_family,
          'value',total_value,
          'unit',unit,
          'source_stat_key',source_stat_key,
          'spell_key',spell_key,
          'active_perks',active_perks
        )
        order by scope,effect_family
      )
      from active_summary
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','weapon_proficiency_preview_v1',
      'optimizer_effect_applied',false,
      'level_assignment_inferred',false,
      'explicit_perk_orders_required_for_active_effects',true,
      'note','Perk order is a source-order identifier only. Active effects are calculated only from explicitly supplied perk orders; no unlock level or tree branch is inferred.'
    )
  )
  from tree t
),jsonb_build_object(
  'item_key',p_item_key,
  'error','weapon_proficiency_tree_not_found',
  'methodology',jsonb_build_object(
    'stage','weapon_proficiency_preview_v1',
    'optimizer_effect_applied',false
  )
));
$function$
;

revoke all on function public.huntnexus_weapon_proficiency_preview(text,jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_weapon_proficiency_preview(text,jsonb)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_ek_proficiency_comparison(p_weapon_family text, p_one_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_two_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with pair as (
  select
    lower(trim(coalesce(p_weapon_family,''))) as weapon_family,
    case lower(trim(coalesce(p_weapon_family,'')))
      when 'sword' then 'grand-sanguine-blade'
      when 'axe' then 'grand-sanguine-hatchet'
      when 'club' then 'grand-sanguine-cudgel'
      else null
    end as one_hand_item_key,
    case lower(trim(coalesce(p_weapon_family,'')))
      when 'sword' then 'grand-sanguine-razor'
      when 'axe' then 'grand-sanguine-battleaxe'
      when 'club' then 'grand-sanguine-bludgeon'
      else null
    end as two_hand_item_key
)
select case
  when one_hand_item_key is null then
    jsonb_build_object(
      'weapon_family',weapon_family,
      'error','unsupported_ek_weapon_family',
      'supported_families',jsonb_build_array('sword','axe','club'),
      'methodology',jsonb_build_object(
        'stage','ek_weapon_proficiency_comparison_v1',
        'optimizer_effect_applied',false
      )
    )
  else
    jsonb_build_object(
      'weapon_family',weapon_family,
      'one_handed',
        huntnexus_weapon_proficiency_preview(
          one_hand_item_key,p_one_hand_active_perk_orders
        ),
      'two_handed',
        huntnexus_weapon_proficiency_preview(
          two_hand_item_key,p_two_hand_active_perk_orders
        ),
      'methodology',jsonb_build_object(
        'stage','ek_weapon_proficiency_comparison_v1',
        'optimizer_effect_applied',false,
        'ranking_changed',false,
        'hand_choice_changed',false,
        'level_assignment_inferred',false,
        'note','Side-by-side proficiency context only. It does not change weapon ranking or hand selection.'
      )
    )
end
from pair;
$function$
;

revoke all on function public.huntnexus_ek_proficiency_comparison(text,jsonb,jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_ek_proficiency_comparison(text,jsonb,jsonb)
  to service_role;
