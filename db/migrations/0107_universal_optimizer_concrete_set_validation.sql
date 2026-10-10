-- HuntNexus — bounded concrete set generation + universal validation.
-- Hand packages are built from Pareto-frontier weapon/offhand/ammunition candidates.
-- Complete body selections are enumerated deterministically for validation only.
-- Enumeration order is explicitly not a ranking or recommendation.

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_hand_packages_universal(p_hunt_key text, p_vocation text, p_level integer, p_per_source integer DEFAULT 5, p_limit integer DEFAULT 200)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    least(greatest(coalesce(p_per_source,5),1),20) as per_source,
    least(greatest(coalesce(p_limit,200),1),1000) as limit_value
),
vr as (
  select *
  from vocation_composition_rules
  where vocation_code=(select vocation_code from p)
),
families as (
  select value as weapon_family
  from vr
  cross join lateral jsonb_array_elements_text(vr.canonical_weapon_families)
),
weapon_frontier as (
  select
    f.weapon_family,
    huntnexus_optimizer_pareto_frontier_universal(
      p_hunt_key,(select vocation_code from p),(select level_value from p),
      'weapon',f.weapon_family,100
    ) as j
  from families f
),
weapons_raw as (
  select
    wf.weapon_family,
    x->>'item_key' as weapon_key,
    x->>'name' as weapon_name,
    row_number() over(partition by wf.weapon_family order by x->>'item_key') as rn
  from weapon_frontier wf
  cross join lateral jsonb_array_elements(wf.j->'frontier') x
),
weapons as (
  select
    wr.*,
    w.hands,
    ur.offhand_policy,
    ur.requires_quiver,
    ur.ammunition_family,
    ur.ammunition_required
  from weapons_raw wr
  join vw_weapon_catalog_universal w on w.item_key=wr.weapon_key
  join weapon_usage_rules ur on ur.weapon_family=wr.weapon_family
  where wr.rn<=(select per_source from p)
),
offhand_frontier as (
  select huntnexus_optimizer_pareto_frontier_universal(
    p_hunt_key,(select vocation_code from p),(select level_value from p),
    'equipment','offhand',100
  ) as j
),
offhands_raw as (
  select
    x->>'item_key' as offhand_key,
    x->>'name' as offhand_name,
    x->>'item_family' as offhand_family,
    row_number() over(partition by x->>'item_family' order by x->>'item_key') as rn
  from offhand_frontier
  cross join lateral jsonb_array_elements(j->'frontier') x
),
offhands as (
  select *
  from offhands_raw
  where rn<=(select per_source from p)
),
weapon_options as (
  select
    w.*,
    o.offhand_key,
    o.offhand_name,
    o.offhand_family
  from weapons w
  left join offhands o
    on (
      (w.requires_quiver and o.offhand_family='quiver')
      or (
        not w.requires_quiver
        and w.hands<>'Two'
        and (
          (w.offhand_policy='optional_shield_or_spellbook' and o.offhand_family in ('shield','spellbook'))
          or (w.offhand_policy='optional_shield_offhand' and o.offhand_family='shield')
          or (w.offhand_policy='one_hand_optional_offhand_two_hand_blocked' and o.offhand_family in ('shield','spellbook'))
        )
      )
    )
  where
    (w.requires_quiver and o.offhand_key is not null)
    or (not w.requires_quiver)
),
weapon_options_with_empty as (
  select * from weapon_options
  union all
  select
    w.weapon_family,w.weapon_key,w.weapon_name,w.rn,w.hands,w.offhand_policy,
    w.requires_quiver,w.ammunition_family,w.ammunition_required,
    null::text,null::text,null::text
  from weapons w
  where not w.requires_quiver
    and w.hands<>'Two'
),
ammo as (
  select
    fam.ammunition_family,
    x->>'item_key' as ammo_key,
    x->>'name' as ammo_name,
    row_number() over(partition by fam.ammunition_family order by x->>'item_key') as rn
  from (
    select distinct ammunition_family
    from weapons
    where ammunition_required and ammunition_family is not null
  ) fam
  cross join lateral jsonb_array_elements(
    huntnexus_ammunition_candidates(
      fam.ammunition_family,(select level_value from p)
    )->'items'
  ) x
  where x->>'eligibility_status'='eligible'
),
raw_packages as (
  select
    wo.*,
    a.ammo_key,
    a.ammo_name
  from weapon_options_with_empty wo
  left join ammo a
    on wo.ammunition_required
   and a.ammunition_family=wo.ammunition_family
   and a.rn<=(select per_source from p)
  where
    (wo.ammunition_required and a.ammo_key is not null)
    or not wo.ammunition_required
),
selections as (
  select
    rp.*,
    jsonb_strip_nulls(jsonb_build_object(
      'weapon',rp.weapon_key,
      'offhand',rp.offhand_key,
      'ammunition',rp.ammo_key
    )) as selection
  from raw_packages rp
),
validated as (
  select
    s.*,
    huntnexus_loadout_compatibility_universal(
      (select vocation_code from p),(select level_value from p),s.selection
    ) as validation
  from selections s
),
numbered as (
  select
    v.*,
    row_number() over(
      order by weapon_family,weapon_key,coalesce(offhand_key,''),coalesce(ammo_key,'')
    ) as enumeration_order
  from validated v
),
limited as (
  select *
  from numbered
  where enumeration_order<=(select limit_value from p)
)
select case
  when not exists(select 1 from vr) then
    jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'methodology',jsonb_build_object('stage','optimizer_hand_packages_universal_v1')
    )
  else jsonb_build_object(
    'query',jsonb_build_object(
      'hunt_key',p_hunt_key,
      'vocation',(select vocation_code from p),
      'level',(select level_value from p),
      'per_source',(select per_source from p),
      'limit',(select limit_value from p)
    ),
    'summary',jsonb_build_object(
      'frontier_weapons_considered',(select count(*) from weapons),
      'raw_packages',(select count(*) from validated),
      'valid_packages',(select count(*) from validated where validation->>'status'='valid'),
      'incomplete_packages',(select count(*) from validated where validation->>'status'='incomplete'),
      'blocked_packages',(select count(*) from validated where validation->>'status'='blocked'),
      'returned',(select count(*) from limited),
      'truncated',(select count(*) from validated)>(select limit_value from p)
    ),
    'packages',coalesce((
      select jsonb_agg(jsonb_build_object(
        'enumeration_order',enumeration_order,
        'weapon_family',weapon_family,
        'weapon_key',weapon_key,
        'weapon_name',weapon_name,
        'weapon_hands',hands,
        'offhand_key',offhand_key,
        'offhand_name',offhand_name,
        'offhand_family',offhand_family,
        'ammunition_key',ammo_key,
        'ammunition_name',ammo_name,
        'selection',selection,
        'validation',validation
      ) order by enumeration_order)
      from limited
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','optimizer_hand_packages_universal_v1',
      'category_first',true,
      'frontier_items_only',true,
      'per_source_slice_order','item_key',
      'slice_order_is_not_ranking',true,
      'universal_loadout_validation_applied',true,
      'two_hand_rules_applied',true,
      'quiver_ammunition_rules_applied',true,
      'set_score_applied',false,
      'winner_selected',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_optimizer_hand_packages_universal(text,text,integer,integer,integer)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_hand_packages_universal(text,text,integer,integer,integer)
to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_concrete_sets_universal(p_hunt_key text, p_vocation text, p_level integer, p_hand_per_source integer DEFAULT 3, p_per_body_slot integer DEFAULT 2, p_set_limit integer DEFAULT 200)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    least(greatest(coalesce(p_hand_per_source,3),1),10) as hand_per_source,
    least(greatest(coalesce(p_per_body_slot,2),1),5) as per_body_slot,
    least(greatest(coalesce(p_set_limit,200),1),1000) as set_limit
),
hand_source as (
  select huntnexus_optimizer_hand_packages_universal(
    p_hunt_key,(select vocation_code from p),(select level_value from p),
    (select hand_per_source from p),1000
  ) as j
),
hands as (
  select
    (x->>'enumeration_order')::int as hand_order,
    x->'selection' as hand_selection,
    x as hand_package
  from hand_source
  cross join lateral jsonb_array_elements(j->'packages') x
  where x #>> '{validation,status}'='valid'
),
slot_names as (
  select * from (values
    ('head'::text),('body'),('legs'),('feet'),('neck'),('ring')
  ) s(slot_key)
),
slot_frontiers as (
  select
    s.slot_key,
    huntnexus_optimizer_pareto_frontier_universal(
      p_hunt_key,(select vocation_code from p),(select level_value from p),
      'equipment',s.slot_key,100
    ) as j
  from slot_names s
),
slot_items_raw as (
  select
    sf.slot_key,
    x->>'item_key' as item_key,
    x->>'name' as item_name,
    row_number() over(partition by sf.slot_key order by x->>'item_key') as rn
  from slot_frontiers sf
  cross join lateral jsonb_array_elements(sf.j->'frontier') x
),
slot_items as (
  select *
  from slot_items_raw
  where rn<=(select per_body_slot from p)
),
head as (select item_key,item_name from slot_items where slot_key='head'),
body as (select item_key,item_name from slot_items where slot_key='body'),
legs as (select item_key,item_name from slot_items where slot_key='legs'),
feet as (select item_key,item_name from slot_items where slot_key='feet'),
neck as (select item_key,item_name from slot_items where slot_key='neck'),
ring as (select item_key,item_name from slot_items where slot_key='ring'),
combinations as (
  select
    h.hand_order,
    h.hand_package,
    h.hand_selection ||
    jsonb_build_object(
      'head',hd.item_key,
      'body',bd.item_key,
      'legs',lg.item_key,
      'feet',ft.item_key,
      'neck',nk.item_key,
      'ring',rg.item_key
    ) as selection,
    hd.item_key as head_key,
    bd.item_key as body_key,
    lg.item_key as legs_key,
    ft.item_key as feet_key,
    nk.item_key as neck_key,
    rg.item_key as ring_key
  from hands h
  cross join head hd
  cross join body bd
  cross join legs lg
  cross join feet ft
  cross join neck nk
  cross join ring rg
),
numbered as (
  select
    c.*,
    row_number() over(
      order by hand_order,head_key,body_key,legs_key,feet_key,neck_key,ring_key
    ) as set_order
  from combinations c
),
bounded as (
  select *
  from numbered
  where set_order<=(select set_limit from p)
),
validated as (
  select
    b.*,
    huntnexus_loadout_compatibility_universal(
      (select vocation_code from p),(select level_value from p),b.selection
    ) as validation
  from bounded b
)
select case
  when (select vocation_code from p) not in ('EK','RP','ED','MS','EM') then
    jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'methodology',jsonb_build_object('stage','optimizer_concrete_sets_universal_v1')
    )
  when exists (
    select 1
    from slot_names s
    where not exists(select 1 from slot_items i where i.slot_key=s.slot_key)
  ) then
    jsonb_build_object(
      'error','missing_body_slot_frontier',
      'hunt_key',p_hunt_key,
      'vocation',(select vocation_code from p),
      'methodology',jsonb_build_object('stage','optimizer_concrete_sets_universal_v1')
    )
  else jsonb_build_object(
    'query',jsonb_build_object(
      'hunt_key',p_hunt_key,
      'vocation',(select vocation_code from p),
      'level',(select level_value from p),
      'hand_per_source',(select hand_per_source from p),
      'per_body_slot',(select per_body_slot from p),
      'set_limit',(select set_limit from p)
    ),
    'source_summary',jsonb_build_object(
      'valid_hand_packages',(select count(*) from hands),
      'body_slot_frontier_slice',coalesce((
        select jsonb_object_agg(slot_key,cnt order by slot_key)
        from (
          select slot_key,count(*)::int cnt
          from slot_items
          group by slot_key
        ) x
      ),'{}'::jsonb),
      'theoretical_combinations',(select count(*) from combinations)
    ),
    'summary',jsonb_build_object(
      'generated_for_validation',(select count(*) from bounded),
      'valid_sets',(select count(*) from validated where validation->>'status'='valid'),
      'incomplete_sets',(select count(*) from validated where validation->>'status'='incomplete'),
      'blocked_sets',(select count(*) from validated where validation->>'status'='blocked'),
      'returned',(select count(*) from validated),
      'truncated',(select count(*) from combinations)>(select set_limit from p)
    ),
    'sets',coalesce((
      select jsonb_agg(jsonb_build_object(
        'set_order',set_order,
        'selection',selection,
        'validation',validation,
        'hand_package',hand_package
      ) order by set_order)
      from validated
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','optimizer_concrete_sets_universal_v1',
      'category_first',true,
      'pareto_frontier_items_only',true,
      'deterministic_body_slice_order','item_key',
      'deterministic_hand_slice_order','item_key',
      'slice_order_is_not_ranking',true,
      'complete_body_slots_generated',true,
      'universal_loadout_validation_applied_to_every_returned_set',true,
      'set_score_applied',false,
      'set_ranking_applied',false,
      'winner_selected',false,
      'final_optimizer_applied',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_optimizer_concrete_sets_universal(text,text,integer,integer,integer,integer)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_concrete_sets_universal(text,text,integer,integer,integer,integer)
to service_role;

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
    'set_selection_ready',false,
    'final_optimizer_ready',false
  ),
  'known_blockers',jsonb_build_array(
    jsonb_build_object(
      'key','set_selection_policy',
      'status','next',
      'note','Concrete Pareto-derived sets are generated and validated, but no factual policy yet chooses one set over another.'
    ),
    jsonb_build_object(
      'key','proficiency_activation',
      'status','pending',
      'note','Base-item frontier excludes Weapon Proficiency perks unless explicit selections are provided at set context.'
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
    'stage','optimizer_audit_v3',
    'category_first',true,
    'legacy_ek_optimizer_not_used_as_universal_selector',true,
    'cross_metric_score_applied',false,
    'pareto_only_for_item_pruning',true,
    'concrete_sets_universally_validated',true
  )
);
$function$
;

revoke all on function public.huntnexus_optimizer_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_audit()
to service_role;
