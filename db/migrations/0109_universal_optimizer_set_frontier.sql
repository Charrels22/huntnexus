-- HuntNexus — conservative Pareto frontier across validated proficiency-aware concrete sets.
-- Only explicitly safe additive dimensions are summed. Protection stacking and synthetic cross-metric scores remain disabled.
-- Comparison is partitioned by structural signatures; unresolved proficiency inputs remain incomparable.

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_set_vector_universal(p_set jsonb, p_hunt_key text, p_vocation text, p_proficiency_selections jsonb DEFAULT '{}'::jsonb, p_character_profile jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with normalized as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    coalesce(p_set->'selection','{}'::jsonb) as selection,
    case
      when jsonb_typeof(coalesce(p_proficiency_selections,'{}'::jsonb))='object'
        then coalesce(p_proficiency_selections,'{}'::jsonb)
      else '{}'::jsonb
    end as prof_map
),
selected as (
  select e.key as slot_key,e.value as item_key
  from normalized n
  cross join lateral jsonb_each_text(n.selection) e
  where e.key in ('weapon','offhand','head','body','legs','feet','neck','ring')
),
item_meta as (
  select
    s.slot_key,s.item_key,
    coalesce(w.weapon_family,e.equipment_family) as item_family,
    w.hands as weapon_hands
  from selected s
  left join vw_weapon_catalog_universal w on s.slot_key='weapon' and w.item_key=s.item_key
  left join vw_equipment_catalog_universal e on s.slot_key<>'weapon' and e.item_key=s.item_key
),
item_vectors as (
  select
    m.slot_key,m.item_key,m.item_family,m.weapon_hands,
    huntnexus_optimizer_item_vector_universal(
      m.item_key,p_hunt_key,(select vocation_code from normalized)
    ) as vector
  from item_meta m
),
dims as (
  select
    iv.slot_key,
    iv.item_key,
    d.key as dim_key,
    d.value::text::numeric as dim_value
  from item_vectors iv
  cross join lateral jsonb_each(iv.vector->'dimensions') d
),
additive as (
  select
    dim_key,
    sum(dim_value)::numeric as dim_value
  from dims
  where dim_key in (
      'core/armor',
      'core/imbue_slots',
      'effect/defense/magic_shield_capacity_flat'
    )
    or dim_key like 'effect/skill/%'
  group by dim_key
),
slot_specific as (
  select
    'slot/'||slot_key||'/'||dim_key as dim_key,
    dim_value
  from dims
  where not (
    dim_key in (
      'core/armor',
      'core/imbue_slots',
      'effect/defense/magic_shield_capacity_flat'
    )
    or dim_key like 'effect/skill/%'
  )
),
ammo as (
  select a.*
  from normalized n
  join ammunition_catalog a on a.item_key=n.selection->>'ammunition'
),
ammo_dims as (
  select *
  from (
    select 'ammunition/attack/physical'::text as dim_key,coalesce(a.physical_attack,0)::numeric as dim_value from ammo a
    union all select 'ammunition/attack/fire',case when a.element='fire' then coalesce(a.elemental_attack,0) else 0 end::numeric from ammo a
    union all select 'ammunition/attack/ice',case when a.element='ice' then coalesce(a.elemental_attack,0) else 0 end::numeric from ammo a
    union all select 'ammunition/attack/earth',case when a.element='earth' then coalesce(a.elemental_attack,0) else 0 end::numeric from ammo a
    union all select 'ammunition/attack/energy',case when a.element='energy' then coalesce(a.elemental_attack,0) else 0 end::numeric from ammo a
    union all select 'ammunition/attack/death',case when a.element='death' then coalesce(a.elemental_attack,0) else 0 end::numeric from ammo a
    union all select 'ammunition/attack/holy',case when a.element='holy' then coalesce(a.elemental_attack,0) else 0 end::numeric from ammo a
  ) x
),
prof as (
  select
    n.selection->>'weapon' as weapon_key,
    n.prof_map,
    (n.prof_map ? (n.selection->>'weapon')) as selection_key_present,
    case
      when jsonb_typeof(n.prof_map->(n.selection->>'weapon'))='array'
        then n.prof_map->(n.selection->>'weapon')
      else '[]'::jsonb
    end as active_orders,
    huntnexus_first_int(coalesce(p_character_profile,'{}'::jsonb)->>'effective_weapon_skill') as effective_weapon_skill,
    huntnexus_first_int(coalesce(p_character_profile,'{}'::jsonb)->>'effective_magic_level') as effective_magic_level
  from normalized n
),
prof_impact as (
  select
    p.*,
    exists(select 1 from weapon_proficiency_trees t where t.item_key=p.weapon_key) as tree_available,
    case when exists(select 1 from weapon_proficiency_trees t where t.item_key=p.weapon_key)
      then huntnexus_weapon_proficiency_impact_preview(
        p.weapon_key,p.active_orders,p.effective_weapon_skill,p.effective_magic_level
      )
      else null
    end as impact
  from prof p
),
prof_dims as (
  select 'proficiency/'||e.key as dim_key,e.value::text::numeric as dim_value
  from prof_impact p
  cross join lateral jsonb_each(p.impact->'impact_vector') e
  where p.selection_key_present
    and jsonb_typeof(e.value)='number'
),
all_dims as (
  select dim_key,dim_value from additive
  union all select dim_key,dim_value from slot_specific
  union all select dim_key,dim_value from ammo_dims
  union all select dim_key,dim_value from prof_dims
),
dimension_json as (
  select coalesce(jsonb_object_agg(dim_key,dim_value order by dim_key),'{}'::jsonb) as j
  from all_dims
),
families as (
  select coalesce(jsonb_object_agg(slot_key,item_family order by slot_key),'{}'::jsonb) as j
  from item_meta
  where slot_key<>'weapon'
),
weapon_meta as (
  select item_family as weapon_family,weapon_hands
  from item_meta
  where slot_key='weapon'
),
offhand_meta as (
  select item_family as offhand_family
  from item_meta
  where slot_key='offhand'
),
comparison as (
  select jsonb_build_object(
    'weapon_family',(select weapon_family from weapon_meta),
    'weapon_hands',(select weapon_hands from weapon_meta),
    'offhand_family',coalesce((select offhand_family from offhand_meta),'none'),
    'ammunition_family',coalesce((select ammunition_family from ammo),'none'),
    'ammunition_pattern',coalesce((select attack_pattern from ammo),'none'),
    'equipment_families',(select j from families),
    'proficiency_state',case
      when (select selection_key_present from prof_impact) then 'explicit'
      else 'not_supplied'
    end
  ) as j
)
select jsonb_build_object(
  'selection',(select selection from normalized),
  'comparison_key',(select j from comparison),
  'dimensions',(select j from dimension_json),
  'dimension_count',(select count(*) from all_dims),
  'comparison_ready',
    case
      when (select selection_key_present from prof_impact)
       and coalesce(jsonb_array_length((select impact->'unresolved_inputs' from prof_impact)),0)>0
        then false
      else true
    end,
  'proficiency',jsonb_build_object(
    'weapon_key',(select weapon_key from prof_impact),
    'tree_available',(select tree_available from prof_impact),
    'selection_key_present',(select selection_key_present from prof_impact),
    'active_perk_orders',(select active_orders from prof_impact),
    'unresolved_inputs',coalesce((select impact->'unresolved_inputs' from prof_impact),'[]'::jsonb)
  ),
  'aggregation_contract',jsonb_build_object(
    'summed_dimensions',jsonb_build_array(
      'core/armor',
      'core/imbue_slots',
      'effect/skill/*',
      'effect/defense/magic_shield_capacity_flat'
    ),
    'slot_scoped_for_non_additive_dimensions',true,
    'protection_stacking_formula_applied',false,
    'cross_metric_score_applied',false,
    'ammunition_pattern_partitions_comparison',true,
    'equipment_family_signature_partitions_comparison',true
  ),
  'methodology',jsonb_build_object(
    'stage','optimizer_set_vector_universal_v1',
    'higher_is_better_dimensions_only',true,
    'unknown_proficiency_inputs_block_comparison',true,
    'winner_selected',false
  )
);
$function$
;

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_set_frontier_universal(p_hunt_key text, p_vocation text, p_level integer, p_hand_per_source integer DEFAULT 3, p_per_body_slot integer DEFAULT 2, p_set_limit integer DEFAULT 200, p_frontier_limit integer DEFAULT 200, p_proficiency_selections jsonb DEFAULT '{}'::jsonb, p_character_profile jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    least(greatest(coalesce(p_frontier_limit,200),1),1000) as frontier_limit,
    case
      when jsonb_typeof(coalesce(p_proficiency_selections,'{}'::jsonb))='object'
        then coalesce(p_proficiency_selections,'{}'::jsonb)
      else '{}'::jsonb
    end as prof_map,
    huntnexus_first_int(coalesce(p_character_profile,'{}'::jsonb)->>'effective_weapon_skill') as effective_weapon_skill,
    huntnexus_first_int(coalesce(p_character_profile,'{}'::jsonb)->>'effective_magic_level') as effective_magic_level
),
base as (
  select huntnexus_optimizer_concrete_sets_with_proficiency_universal(
    p_hunt_key,p_vocation,p_level,p_hand_per_source,p_per_body_slot,p_set_limit,
    p_proficiency_selections,p_character_profile
  ) as j
),
sets as (
  select
    (x->>'set_order')::int as set_order,
    x as set_json,
    x->'selection' as selection,
    x->'selection'->>'weapon' as weapon_key,
    x->'selection'->>'ammunition' as ammunition_key
  from base
  cross join lateral jsonb_array_elements(coalesce(j->'sets','[]'::jsonb)) x
  where x #>> '{validation,status}'='valid'
),
selection_rows as (
  select s.set_order,e.key as slot_key,e.value as item_key
  from sets s
  cross join lateral jsonb_each_text(s.selection) e
  where e.key in ('weapon','offhand','head','body','legs','feet','neck','ring')
),
unique_items as (
  select distinct item_key from selection_rows
),
item_vectors as (
  select
    u.item_key,
    huntnexus_optimizer_item_vector_universal(
      u.item_key,p_hunt_key,(select vocation_code from p)
    ) as vector
  from unique_items u
),
selection_dims as (
  select
    sr.set_order,sr.slot_key,d.key as dim_key,d.value::text::numeric as dim_value
  from selection_rows sr
  join item_vectors iv using(item_key)
  cross join lateral jsonb_each(iv.vector->'dimensions') d
),
additive as (
  select
    set_order,
    dim_key,
    sum(dim_value)::numeric as dim_value
  from selection_dims
  where dim_key in (
      'core/armor',
      'core/imbue_slots',
      'effect/defense/magic_shield_capacity_flat'
    )
    or dim_key like 'effect/skill/%'
  group by set_order,dim_key
),
slot_specific as (
  select
    set_order,
    'slot/'||slot_key||'/'||dim_key as dim_key,
    dim_value
  from selection_dims
  where not (
    dim_key in (
      'core/armor',
      'core/imbue_slots',
      'effect/defense/magic_shield_capacity_flat'
    )
    or dim_key like 'effect/skill/%'
  )
),
ammo as (
  select s.set_order,a.*
  from sets s
  join ammunition_catalog a on a.item_key=s.ammunition_key
),
ammo_dims as (
  select set_order,dim_key,dim_value
  from (
    select set_order,'ammunition/attack/physical'::text as dim_key,coalesce(physical_attack,0)::numeric as dim_value from ammo
    union all select set_order,'ammunition/attack/fire',case when element='fire' then coalesce(elemental_attack,0) else 0 end::numeric from ammo
    union all select set_order,'ammunition/attack/ice',case when element='ice' then coalesce(elemental_attack,0) else 0 end::numeric from ammo
    union all select set_order,'ammunition/attack/earth',case when element='earth' then coalesce(elemental_attack,0) else 0 end::numeric from ammo
    union all select set_order,'ammunition/attack/energy',case when element='energy' then coalesce(elemental_attack,0) else 0 end::numeric from ammo
    union all select set_order,'ammunition/attack/death',case when element='death' then coalesce(elemental_attack,0) else 0 end::numeric from ammo
    union all select set_order,'ammunition/attack/holy',case when element='holy' then coalesce(elemental_attack,0) else 0 end::numeric from ammo
  ) x
),
unique_weapons as (
  select distinct weapon_key from sets where weapon_key is not null
),
prof_weapon as (
  select
    w.weapon_key,
    (p.prof_map ? w.weapon_key) as selection_key_present,
    case
      when jsonb_typeof(p.prof_map->w.weapon_key)='array'
        then p.prof_map->w.weapon_key
      else '[]'::jsonb
    end as active_orders,
    exists(select 1 from weapon_proficiency_trees t where t.item_key=w.weapon_key) as tree_available,
    case
      when exists(select 1 from weapon_proficiency_trees t where t.item_key=w.weapon_key)
        then huntnexus_weapon_proficiency_impact_preview(
          w.weapon_key,
          case when jsonb_typeof(p.prof_map->w.weapon_key)='array'
               then p.prof_map->w.weapon_key else '[]'::jsonb end,
          p.effective_weapon_skill,
          p.effective_magic_level
        )
      else null
    end as impact
  from unique_weapons w
  cross join p
),
prof_dims as (
  select
    s.set_order,
    'proficiency/'||e.key as dim_key,
    e.value::text::numeric as dim_value
  from sets s
  join prof_weapon pw on pw.weapon_key=s.weapon_key
  cross join lateral jsonb_each(pw.impact->'impact_vector') e
  where pw.selection_key_present
    and jsonb_typeof(e.value)='number'
),
all_dims as (
  select * from additive
  union all select * from slot_specific
  union all select * from ammo_dims
  union all select * from prof_dims
),
dimension_json as (
  select
    set_order,
    jsonb_object_agg(dim_key,dim_value order by dim_key) as dims,
    count(*)::int as dimension_count
  from all_dims
  group by set_order
),
item_meta as (
  select
    sr.set_order,sr.slot_key,sr.item_key,
    coalesce(w.weapon_family,e.equipment_family) as item_family,
    w.hands as weapon_hands
  from selection_rows sr
  left join vw_weapon_catalog_universal w on sr.slot_key='weapon' and w.item_key=sr.item_key
  left join vw_equipment_catalog_universal e on sr.slot_key<>'weapon' and e.item_key=sr.item_key
),
equipment_family_json as (
  select
    set_order,
    jsonb_object_agg(slot_key,item_family order by slot_key) as families
  from item_meta
  where slot_key<>'weapon'
  group by set_order
),
comparison_keys as (
  select
    s.set_order,
    jsonb_build_object(
      'weapon_family',(select im.item_family from item_meta im where im.set_order=s.set_order and im.slot_key='weapon'),
      'weapon_hands',(select im.weapon_hands from item_meta im where im.set_order=s.set_order and im.slot_key='weapon'),
      'offhand_family',coalesce((select im.item_family from item_meta im where im.set_order=s.set_order and im.slot_key='offhand'),'none'),
      'ammunition_family',coalesce(a.ammunition_family,'none'),
      'ammunition_pattern',coalesce(a.attack_pattern,'none'),
      'equipment_families',coalesce(ef.families,'{}'::jsonb),
      'proficiency_state',case when pw.selection_key_present then 'explicit' else 'not_supplied' end
    ) as comparison_key,
    case
      when pw.selection_key_present
       and coalesce(jsonb_array_length(pw.impact->'unresolved_inputs'),0)>0
        then false
      else true
    end as comparison_ready,
    jsonb_build_object(
      'weapon_key',s.weapon_key,
      'tree_available',coalesce(pw.tree_available,false),
      'selection_key_present',coalesce(pw.selection_key_present,false),
      'active_perk_orders',coalesce(pw.active_orders,'[]'::jsonb),
      'unresolved_inputs',coalesce(pw.impact->'unresolved_inputs','[]'::jsonb)
    ) as proficiency
  from sets s
  left join ammo a on a.set_order=s.set_order
  left join equipment_family_json ef on ef.set_order=s.set_order
  left join prof_weapon pw on pw.weapon_key=s.weapon_key
),
prepared as (
  select
    s.set_order,s.set_json,
    dj.dims,dj.dimension_count,
    ck.comparison_key,ck.comparison_ready,ck.proficiency,
    array(select k from jsonb_object_keys(dj.dims) k order by k) as dim_keys
  from sets s
  join dimension_json dj using(set_order)
  join comparison_keys ck using(set_order)
),
dominance as (
  select
    b.set_order as dominated_set_order,
    a.set_order as dominator_set_order
  from prepared a
  join prepared b
    on a.set_order<>b.set_order
   and a.comparison_ready
   and b.comparison_ready
   and a.comparison_key=b.comparison_key
   and a.dim_keys=b.dim_keys
  where not exists (
    select 1
    from jsonb_each_text(b.dims) bd
    join jsonb_each_text(a.dims) ad on ad.key=bd.key
    where ad.value::numeric < bd.value::numeric
  )
  and exists (
    select 1
    from jsonb_each_text(b.dims) bd
    join jsonb_each_text(a.dims) ad on ad.key=bd.key
    where ad.value::numeric > bd.value::numeric
  )
),
frontier as (
  select pp.*
  from prepared pp
  where not exists(
    select 1 from dominance d where d.dominated_set_order=pp.set_order
  )
),
limited as (
  select *
  from frontier
  order by set_order
  limit (select frontier_limit from p)
)
select case
  when (select j ? 'error' from base) then (select j from base)
  else jsonb_build_object(
    'query',jsonb_build_object(
      'hunt_key',p_hunt_key,
      'vocation',(select vocation_code from p),
      'level',greatest(coalesce(p_level,1),1),
      'hand_per_source',p_hand_per_source,
      'per_body_slot',p_per_body_slot,
      'set_limit',p_set_limit,
      'frontier_limit',(select frontier_limit from p)
    ),
    'source_summary',(select j->'summary' from base),
    'summary',jsonb_build_object(
      'valid_sets_considered',(select count(*) from prepared),
      'comparison_ready_sets',(select count(*) from prepared where comparison_ready),
      'incomparable_unready_sets',(select count(*) from prepared where not comparison_ready),
      'frontier_sets',(select count(*) from frontier),
      'dominated_sets',(select count(distinct dominated_set_order) from dominance),
      'returned',(select count(*) from limited),
      'truncated',(select count(*) from frontier)>(select frontier_limit from p)
    ),
    'frontier',coalesce((
      select jsonb_agg(
        l.set_json || jsonb_build_object(
          'set_vector',jsonb_build_object(
            'comparison_key',l.comparison_key,
            'dimensions',l.dims,
            'dimension_count',l.dimension_count,
            'comparison_ready',l.comparison_ready,
            'proficiency',l.proficiency,
            'aggregation_contract',jsonb_build_object(
              'summed_dimensions',jsonb_build_array(
                'core/armor','core/imbue_slots','effect/skill/*',
                'effect/defense/magic_shield_capacity_flat'
              ),
              'slot_scoped_for_non_additive_dimensions',true,
              'protection_stacking_formula_applied',false,
              'cross_metric_score_applied',false,
              'ammunition_pattern_partitions_comparison',true,
              'equipment_family_signature_partitions_comparison',true
            ),
            'methodology',jsonb_build_object(
              'stage','optimizer_set_vector_universal_v1',
              'higher_is_better_dimensions_only',true,
              'unknown_proficiency_inputs_block_comparison',true,
              'winner_selected',false
            )
          ),
          'dominates_count',(
            select count(distinct d.dominated_set_order)
            from dominance d
            where d.dominator_set_order=l.set_order
          )
        )
        order by l.set_order
      )
      from limited l
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','optimizer_set_frontier_universal_v1',
      'validated_sets_only',true,
      'unique_item_vectors_reused',true,
      'same_comparison_key_required_for_dominance',true,
      'equal_dimension_keyset_required_for_dominance',true,
      'missing_or_unresolved_dimension_makes_set_incomparable',true,
      'protection_stacking_formula_applied',false,
      'cross_metric_sum_applied',false,
      'ranking_score_applied',false,
      'pareto_only',true,
      'winner_selected',false,
      'final_optimizer_applied',false
    )
  )
end;
$function$
;

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_audit()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select jsonb_build_object(
  'summary',jsonb_build_object(
    'weapon_contract_ready',
      coalesce((huntnexus_slot_compatibility_audit() #>> '{summary,weapon_offhand_dependency_ready}')::boolean,false),
    'equipment_contract_ready',
      coalesce((huntnexus_vocation_composition_audit() #>> '{summary,equipment_slot_summary_ready}')::boolean,false),
    'imbuement_contract_ready',
      coalesce((huntnexus_imbuement_category_audit() #>> '{summary,defensive_hunt_context_ready}')::boolean,false),
    'effect_contract_ready',
      coalesce((huntnexus_effect_category_audit() #>> '{summary,hunt_protection_alignment_ready}')::boolean,false),
    'slot_contract_ready',
      coalesce((huntnexus_slot_compatibility_audit() #>> '{summary,slot_contract_ready}')::boolean,false),
    'spell_contract_ready',
      coalesce((huntnexus_spell_category_audit() #>> '{summary,special_unlock_rules_ready}')::boolean,false),
    'vocation_contract_ready',
      coalesce((huntnexus_vocation_composition_audit() #>> '{summary,profile_contract_ready}')::boolean,false),
    'candidate_envelope_ready',true,
    'item_vector_ready',true,
    'pareto_frontier_ready',true,
    'frontier_envelope_ready',true,
    'hand_package_generation_ready',true,
    'concrete_set_generation_ready',true,
    'set_validation_ready',true,
    'proficiency_context_ready',true,
    'set_vector_ready',true,
    'set_frontier_ready',true,
    'set_selection_ready',false,
    'final_optimizer_ready',false
  ),
  'known_blockers',jsonb_build_array(
    jsonb_build_object(
      'key','set_selection_policy',
      'status','next',
      'note','Validated proficiency-aware sets now have a conservative Pareto frontier; no factual policy yet chooses one surviving set over another.'
    ),
    jsonb_build_object(
      'key','cross_type_imbuement_priority',
      'status','pending',
      'note','Defensive Imbuement context is ready; offense/sustain/skill Imbuements remain unranked across types.'
    ),
    jsonb_build_object(
      'key','final_formula',
      'status','pending',
      'note','No invented DPS/healing or universal cross-metric scalar is allowed.'
    )
  ),
  'methodology',jsonb_build_object(
    'stage','optimizer_audit_v5',
    'category_first',true,
    'legacy_ek_optimizer_not_used_as_universal_selector',true,
    'cross_metric_score_applied',false,
    'pareto_only_for_item_pruning',true,
    'concrete_sets_universally_validated',true,
    'proficiency_item_key_binding_required',true,
    'proficiency_selection_inheritance_applied',false,
    'set_pareto_frontier_applied',true,
    'protection_stacking_formula_applied',false
  )
);
$function$
;


revoke all on function public.huntnexus_optimizer_set_vector_universal(jsonb,text,text,jsonb,jsonb)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_set_vector_universal(jsonb,text,text,jsonb,jsonb)
to service_role;

revoke all on function public.huntnexus_optimizer_set_frontier_universal(text,text,integer,integer,integer,integer,integer,jsonb,jsonb)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_set_frontier_universal(text,text,integer,integer,integer,integer,integer,jsonb,jsonb)
to service_role;

revoke all on function public.huntnexus_optimizer_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_audit()
to service_role;

