-- HuntNexus — universal protection/effect contract across weapons and equipment.
-- Static item effects and conditional Weapon Proficiency effects remain distinct.
-- Negative protections are preserved as vulnerabilities; no stacking/final-damage formula is inferred.

create or replace view public.vw_combat_item_effects_universal
with (security_invoker=true)
as
 WITH items AS (
         SELECT w.item_id,
            w.item_key,
            w.name,
            'weapon'::text AS item_domain,
            w.weapon_family AS item_family,
            NULL::text AS slot_key
           FROM vw_weapon_catalog_universal w
        UNION ALL
         SELECT e.item_id,
            e.item_key,
            e.name,
            'equipment'::text AS item_domain,
            e.equipment_family AS item_family,
            e.slot_key
           FROM vw_equipment_catalog_universal e
        )
 SELECT i.item_id,
    i.item_key,
    i.name,
    i.item_domain,
    i.item_family,
    i.slot_key,
    ie.id AS effect_id,
    'item_base'::text AS source_layer,
    ie.effect_type,
    ie.effect_key,
    ie.numeric_value,
    ie.unit,
    ie.raw_value,
    ie.context,
    ie.source_field,
    ie.source_id,
    ie.snapshot_id,
    ie.observed_at,
        CASE
            WHEN ie.effect_type = 'protection'::text THEN 'protection'::text
            WHEN ie.effect_type = 'defense'::text AND ie.effect_key = 'damage_reflection'::text THEN 'reflection'::text
            WHEN ie.effect_type = 'defense'::text AND (ie.effect_key = ANY (ARRAY['magic_shield_capacity_flat'::text, 'magic_shield_capacity_percent'::text])) THEN 'magic_shield'::text
            WHEN ie.effect_type = 'leech'::text THEN 'leech'::text
            WHEN ie.effect_type = 'movement'::text THEN 'movement'::text
            WHEN ie.effect_type = 'offense'::text THEN 'offense'::text
            WHEN ie.effect_type = 'skill'::text THEN 'skill'::text
            WHEN ie.effect_type = 'magic_skill'::text THEN 'magic_skill'::text
            WHEN ie.effect_type = 'special'::text THEN 'special'::text
            ELSE ie.effect_type
        END AS semantic_group,
        CASE
            WHEN ie.effect_type = 'protection'::text THEN 'positive=protection; negative=vulnerability'::text
            WHEN ie.effect_type = 'movement'::text AND ie.effect_key = 'speed'::text THEN 'signed movement modifier'::text
            WHEN ie.effect_type = 'offense'::text AND ie.effect_key = 'hit_modifier'::text THEN 'signed hit modifier'::text
            WHEN ie.effect_type = 'skill'::text AND ie.effect_key = 'shielding'::text THEN 'signed skill modifier'::text
            WHEN ie.unit = 'boolean'::text THEN 'boolean fact'::text
            ELSE 'numeric fact; utility direction not inferred globally'::text
        END AS value_semantics,
        CASE
            WHEN ie.effect_type = 'protection'::text THEN ie.effect_key
            ELSE NULL::text
        END AS context_element,
    ie.numeric_value < 0::numeric AS is_negative_value
   FROM items i
     JOIN item_effects ie ON ie.item_id = i.item_id;

revoke all on public.vw_combat_item_effects_universal from public,anon,authenticated;
grant select on public.vw_combat_item_effects_universal to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_item_effect_profile_universal(p_item_key text, p_proficiency_selection jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with item as (
  select
    w.item_key,w.name,'weapon'::text as item_domain,w.weapon_family as item_family,
    null::text as slot_key,w.proficiency_tree_available,w.proficiency_perk_count
  from vw_weapon_catalog_universal w
  where w.item_key=p_item_key

  union all

  select
    e.item_key,e.name,'equipment'::text as item_domain,e.equipment_family as item_family,
    e.slot_key,false as proficiency_tree_available,0::int as proficiency_perk_count
  from vw_equipment_catalog_universal e
  where e.item_key=p_item_key
  limit 1
),
base_effects as (
  select *
  from vw_combat_item_effects_universal
  where item_key=p_item_key
),
protection as (
  select effect_key,sum(numeric_value)::numeric as value
  from base_effects
  where effect_type='protection' and numeric_value is not null
  group by effect_key
),
prof as (
  select case
    when exists(select 1 from item where item_domain='weapon' and proficiency_tree_available)
      and jsonb_typeof(p_proficiency_selection)='array'
    then huntnexus_weapon_proficiency_preview(p_item_key,p_proficiency_selection)
    else null
  end as preview
),
conditional_pierce as (
  select
    p.perk_order,p.effect_key,p.numeric_value,p.unit,p.scope,p.description_raw,
    p.metadata,p.source_url,p.source_tier
  from weapon_proficiency_perks p
  where p.item_key=p_item_key
    and p.effect_key ilike '%pierce%'
),
active_prof as (
  select perk
  from prof
  cross join lateral jsonb_array_elements(coalesce(preview->'perks','[]'::jsonb)) perk
  where coalesce((perk->>'active')::boolean,false)
)
select coalesce((
  select jsonb_build_object(
    'item',jsonb_build_object(
      'item_key',i.item_key,
      'name',i.name,
      'item_domain',i.item_domain,
      'item_family',i.item_family,
      'slot_key',i.slot_key
    ),
    'static_effects',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'effect_type',effect_type,
          'effect_key',effect_key,
          'semantic_group',semantic_group,
          'value',numeric_value,
          'unit',unit,
          'raw_value',raw_value,
          'context',context,
          'value_semantics',value_semantics,
          'context_element',context_element,
          'is_negative_value',is_negative_value,
          'source_layer',source_layer
        )
        order by semantic_group,effect_type,effect_key
      )
      from base_effects
    ),'[]'::jsonb),
    'groups',jsonb_build_object(
      'protection',coalesce((
        select jsonb_object_agg(effect_key,value order by effect_key) from protection
      ),'{}'::jsonb),
      'vulnerabilities',coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'element',effect_key,
            'value',value,
            'unit','percent'
          )
          order by value,effect_key
        )
        from protection
        where value<0
      ),'[]'::jsonb),
      'reflection',coalesce((
        select jsonb_agg(jsonb_build_object(
          'effect_key',effect_key,'value',numeric_value,'unit',unit
        ) order by effect_key)
        from base_effects where semantic_group='reflection'
      ),'[]'::jsonb),
      'magic_shield',coalesce((
        select jsonb_agg(jsonb_build_object(
          'effect_key',effect_key,'value',numeric_value,'unit',unit
        ) order by effect_key)
        from base_effects where semantic_group='magic_shield'
      ),'[]'::jsonb),
      'leech',coalesce((
        select jsonb_agg(jsonb_build_object(
          'effect_key',effect_key,'value',numeric_value,'unit',unit
        ) order by effect_key)
        from base_effects where semantic_group='leech'
      ),'[]'::jsonb),
      'movement',coalesce((
        select jsonb_agg(jsonb_build_object(
          'effect_key',effect_key,'value',numeric_value,'unit',unit,
          'is_negative_value',is_negative_value
        ) order by effect_key)
        from base_effects where semantic_group='movement'
      ),'[]'::jsonb),
      'offense',coalesce((
        select jsonb_agg(jsonb_build_object(
          'effect_key',effect_key,'value',numeric_value,'unit',unit,
          'is_negative_value',is_negative_value
        ) order by effect_key)
        from base_effects where semantic_group='offense'
      ),'[]'::jsonb),
      'skill',coalesce((
        select jsonb_agg(jsonb_build_object(
          'effect_key',effect_key,'value',numeric_value,'unit',unit,
          'is_negative_value',is_negative_value
        ) order by effect_key)
        from base_effects where semantic_group='skill'
      ),'[]'::jsonb),
      'magic_skill',coalesce((
        select jsonb_agg(jsonb_build_object(
          'effect_key',effect_key,'value',numeric_value,'unit',unit
        ) order by effect_key)
        from base_effects where semantic_group='magic_skill'
      ),'[]'::jsonb),
      'special',coalesce((
        select jsonb_agg(jsonb_build_object(
          'effect_key',effect_key,'value',numeric_value,'unit',unit,
          'raw_value',raw_value,'context',context
        ) order by effect_key)
        from base_effects where semantic_group='special'
      ),'[]'::jsonb)
    ),
    'proficiency',jsonb_build_object(
      'tree_available',i.proficiency_tree_available,
      'perk_count',i.proficiency_perk_count,
      'selection_applied',coalesce(jsonb_typeof(p_proficiency_selection)='array',false),
      'selection',case when (select preview from prof) is null then null
                       else (select preview->'selection' from prof) end,
      'conditional_pierce_perks',coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'perk_order',perk_order,
            'effect_key',effect_key,
            'value',numeric_value,
            'unit',unit,
            'scope',scope,
            'description',description_raw,
            'metadata',metadata,
            'source_url',source_url,
            'source_tier',source_tier,
            'activation_state','conditional'
          )
          order by perk_order
        )
        from conditional_pierce
      ),'[]'::jsonb),
      'active_effects',coalesce((
        select jsonb_agg(perk order by (perk->>'perk_order')::int)
        from active_prof
      ),'[]'::jsonb),
      'active_pierce_effects',coalesce((
        select jsonb_agg(perk order by (perk->>'perk_order')::int)
        from active_prof
        where perk->>'effect_key' ilike '%pierce%'
      ),'[]'::jsonb)
    ),
    'methodology',jsonb_build_object(
      'stage','item_effect_profile_universal_v1',
      'category_first',true,
      'static_and_proficiency_layers_kept_separate',true,
      'proficiency_requires_explicit_selection_for_active_state',true,
      'negative_protection_preserved_as_vulnerability',true,
      'stacking_formula_applied',false,
      'cross_effect_score_applied',false,
      'higher_is_better_inferred',false
    )
  )
  from item i
),jsonb_build_object(
  'error','item_not_found',
  'item_key',p_item_key,
  'methodology',jsonb_build_object('stage','item_effect_profile_universal_v1')
));
$function$
;

revoke all on function public.huntnexus_item_effect_profile_universal(text,jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_item_effect_profile_universal(text,jsonb)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_item_effect_hunt_context_universal(p_item_key text, p_hunt_key text, p_vocation text, p_proficiency_selection jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with profile as (
  select huntnexus_item_effect_profile_universal(
    p_item_key,p_proficiency_selection
  ) as j
),
ctx as (
  select huntnexus_imbuement_hunt_context_universal(
    p_hunt_key,p_vocation
  ) as j
),
protection as (
  select
    key as element,
    value::text::numeric as protection_percent
  from profile,
  lateral jsonb_each(profile.j #> '{groups,protection}')
),
damage as (
  select
    x->>'element' as element,
    (x->>'observed_damage')::numeric as observed_damage,
    (x->>'total_damage_share')::numeric as total_damage_share
  from ctx,
  lateral jsonb_array_elements(ctx.j #> '{incoming_damage,elements}') x
),
matched as (
  select
    d.element,d.observed_damage,d.total_damage_share,p.protection_percent,
    d.total_damage_share*p.protection_percent as signed_alignment_proxy
  from damage d
  join protection p using(element)
),
unmatched as (
  select d.*
  from damage d
  where not exists (
    select 1 from protection p where p.element=d.element
  )
)
select case
  when (select j->>'error' from profile) is not null then (select j from profile)
  when (select j->>'error' from ctx) is not null then (select j from ctx)
  else jsonb_build_object(
    'item',(select j->'item' from profile),
    'hunt_context',(select j->'context' from ctx),
    'incoming_damage',(select j->'incoming_damage' from ctx),
    'effect_profile',(select jsonb_build_object(
      'groups',j->'groups',
      'proficiency',j->'proficiency'
    ) from profile),
    'protection_alignment',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'element',element,
          'observed_damage',observed_damage,
          'total_damage_share',round(total_damage_share,6),
          'item_protection_percent',protection_percent,
          'signed_alignment_proxy',round(signed_alignment_proxy,6),
          'interpretation',case
            when protection_percent>0 then 'protection'
            when protection_percent<0 then 'vulnerability'
            else 'neutral'
          end
        )
        order by abs(signed_alignment_proxy) desc,observed_damage desc,element
      )
      from matched
    ),'[]'::jsonb),
    'unmatched_incoming_damage',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'element',element,
          'observed_damage',observed_damage,
          'total_damage_share',round(total_damage_share,6)
        )
        order by observed_damage desc,element
      )
      from unmatched
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','item_effect_hunt_context_universal_v1',
      'category_first',true,
      'signed_alignment_proxy_is_descriptive_only',true,
      'signed_alignment_proxy_formula','observed_damage_share * item_protection_percent',
      'final_damage_reduction_calculated',false,
      'stacking_formula_applied',false,
      'proficiency_pierce_target_context_applied',false,
      'cross_effect_score_applied',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_item_effect_hunt_context_universal(text,text,text,jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_item_effect_hunt_context_universal(text,text,text,jsonb)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_effect_category_audit()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select jsonb_build_object(
  'summary',jsonb_build_object(
    'static_effect_rows',(select count(*) from vw_combat_item_effects_universal),
    'items_with_static_effects',(
      select count(distinct item_key) from vw_combat_item_effects_universal
    ),
    'semantic_groups',(
      select count(distinct semantic_group) from vw_combat_item_effects_universal
    ),
    'protection_rows',(
      select count(*) from vw_combat_item_effects_universal
      where semantic_group='protection'
    ),
    'negative_protection_rows',(
      select count(*) from vw_combat_item_effects_universal
      where semantic_group='protection' and numeric_value<0
    ),
    'items_with_negative_protection',(
      select count(distinct item_key) from vw_combat_item_effects_universal
      where semantic_group='protection' and numeric_value<0
    ),
    'proficiency_pierce_perks',(
      select count(*) from weapon_proficiency_perks
      where effect_key ilike '%pierce%'
    ),
    'static_effect_contract_ready',true,
    'hunt_protection_alignment_ready',true,
    'proficiency_pierce_inventory_ready',true,
    'pierce_target_context_ready',false,
    'stacking_formula_ready',false,
    'cross_effect_utility_score_ready',false
  ),
  'effect_groups',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'semantic_group',semantic_group,
        'rows',rows,
        'items',items
      )
      order by semantic_group
    )
    from (
      select semantic_group,count(*)::int as rows,count(distinct item_key)::int as items
      from vw_combat_item_effects_universal
      group by semantic_group
    ) x
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','effect_category_audit_v1',
    'category_first',true,
    'static_and_conditional_effect_layers_separate',true,
    'negative_values_preserved',true,
    'final_combat_formula_applied',false,
    'ranking_applied',false
  )
);
$function$
;

revoke all on function public.huntnexus_effect_category_audit()
  from public,anon,authenticated;
grant execute on function public.huntnexus_effect_category_audit()
  to service_role;
