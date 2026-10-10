-- HuntNexus — universal Pareto/frontier layer for final optimizer.
-- Prunes clearly dominated item candidates without a synthetic cross-metric score.
-- Dominance requires the same factual dimension keyset, >= on every dimension and > on at least one.
-- Missing structural dimensions make a pair incomparable.

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_item_vector_universal(p_item_key text, p_hunt_key text, p_vocation text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code
),
vr as (
  select *
  from vocation_composition_rules
  where vocation_code=(select vocation_code from p)
),
item as (
  select
    w.item_id,w.item_key,w.name,'weapon'::text as item_domain,
    w.weapon_family as item_family,null::text as slot_key,
    w.defense,w.defense_mod,w.range_value,w.imbue_slots,
    null::integer as armor,w.attack_components
  from vw_weapon_catalog_universal w
  where w.item_key=p_item_key
  union all
  select
    e.item_id,e.item_key,e.name,'equipment'::text as item_domain,
    e.equipment_family as item_family,e.slot_key,
    e.defense,e.defense_mod,null::integer as range_value,e.imbue_slots,
    e.armor,'{}'::jsonb as attack_components
  from vw_equipment_catalog_universal e
  where e.item_key=p_item_key
  limit 1
),
observed_elements as (
  select distinct d.element
  from vw_hunt_observed_incoming_damage d
  where d.hunt_key=p_hunt_key
    and d.vocation=(select vocation_code from p)
),
relevant_skills as (
  select value as effect_key
  from vr
  cross join lateral jsonb_array_elements_text(
    coalesce(vr.primary_skill_keys,'[]'::jsonb) ||
    coalesce(vr.secondary_skill_keys,'[]'::jsonb)
  )
  union
  select x.effect_key
  from (values
    ('ED'::text,'fire_magic_level'::text),
    ('ED','ice_magic_level'),
    ('ED','earth_magic_level'),
    ('ED','energy_magic_level'),
    ('ED','death_magic_level'),
    ('ED','holy_magic_level'),
    ('ED','healing_magic_level'),
    ('MS','fire_magic_level'),
    ('MS','ice_magic_level'),
    ('MS','earth_magic_level'),
    ('MS','energy_magic_level'),
    ('MS','death_magic_level'),
    ('MS','holy_magic_level'),
    ('MS','healing_magic_level'),
    ('EM','healing_magic_level')
  ) x(vocation_code,effect_key)
  where x.vocation_code=(select vocation_code from p)
),
core_dims as (
  select k,v
  from item
  cross join lateral (values
    ('core/armor'::text,armor::numeric),
    ('core/defense',defense::numeric),
    ('core/defense_mod',defense_mod::numeric),
    ('core/range',range_value::numeric),
    ('core/imbue_slots',coalesce(imbue_slots,0)::numeric)
  ) d(k,v)
  where v is not null
),
attack_dims as (
  select 'attack/'||e.element as k,
         coalesce((i.attack_components->>e.element)::numeric,0) as v
  from item i
  cross join (values
    ('physical'::text),('fire'),('ice'),('earth'),('energy'),('death'),('holy')
  ) e(element)
  where i.item_domain='weapon'
    and (
      exists(select 1 from jsonb_object_keys(i.attack_components))
      or i.item_family in ('sword','axe','club','fist','throwing')
    )
),
skill_dims as (
  select 'effect/skill/'||s.effect_key as k,
         coalesce((
           select sum(ie.numeric_value)
           from item_effects ie
           join item i2 on i2.item_id=ie.item_id
           where ie.effect_type in ('skill','magic_skill')
             and ie.effect_key=s.effect_key
         ),0)::numeric as v
  from relevant_skills s
),
directional_effect_keys as (
  select * from (values
    ('effect/defense/damage_reflection'::text,'defense'::text,'damage_reflection'::text),
    ('effect/defense/magic_shield_capacity_flat','defense','magic_shield_capacity_flat'),
    ('effect/defense/magic_shield_capacity_percent','defense','magic_shield_capacity_percent'),
    ('effect/leech/life_leech','leech','life_leech'),
    ('effect/movement/speed','movement','speed'),
    ('effect/offense/attack_modifier','offense','attack_modifier'),
    ('effect/offense/cleave','offense','cleave'),
    ('effect/offense/critical_extra_damage','offense','critical_extra_damage'),
    ('effect/offense/critical_hit_chance','offense','critical_hit_chance'),
    ('effect/offense/hit_modifier','offense','hit_modifier'),
    ('effect/offense/perfect_shot','offense','perfect_shot')
  ) x(k,effect_type,effect_key)
),
utility_dims as (
  select d.k,
         coalesce((
           select sum(ie.numeric_value)
           from item_effects ie
           join item i2 on i2.item_id=ie.item_id
           where ie.effect_type=d.effect_type
             and ie.effect_key=d.effect_key
         ),0)::numeric as v
  from directional_effect_keys d
),
protection_dims as (
  select 'protection/'||oe.element as k,
         coalesce((
           select sum(ie.numeric_value)
           from item_effects ie
           join item i2 on i2.item_id=ie.item_id
           where ie.effect_type='protection'
             and ie.effect_key=oe.element
         ),0)::numeric as v
  from observed_elements oe
),
dims as (
  select * from core_dims
  union all select * from attack_dims
  union all select * from skill_dims
  union all select * from utility_dims
  union all select * from protection_dims
),
dimension_json as (
  select coalesce(jsonb_object_agg(k,v order by k),'{}'::jsonb) as j
  from dims
)
select coalesce((
  select jsonb_build_object(
    'item',jsonb_build_object(
      'item_key',i.item_key,'name',i.name,'item_domain',i.item_domain,
      'item_family',i.item_family,'slot_key',i.slot_key
    ),
    'dimensions',(select j from dimension_json),
    'dimension_count',(select count(*) from dims),
    'direction','higher_is_better',
    'excluded_from_dominance',jsonb_build_array(
      'special effects without universal direction',
      'Weapon Proficiency perks unless explicitly activated',
      'community usage frequency',
      'price/economy',
      'final DPS/healing'
    ),
    'methodology',jsonb_build_object(
      'stage','optimizer_item_vector_universal_v1',
      'category_first',true,
      'cross_metric_sum_applied',false,
      'observed_hunt_elements_only_for_protection',true,
      'absent_listed_effect_means_zero',true,
      'unknown_core_value_imputed',false
    )
  )
  from item i
),jsonb_build_object(
  'error','item_not_found',
  'item_key',p_item_key,
  'methodology',jsonb_build_object('stage','optimizer_item_vector_universal_v1')
));
$function$
;

revoke all on function public.huntnexus_optimizer_item_vector_universal(text,text,text)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_item_vector_universal(text,text,text)
to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_pareto_frontier_universal(p_hunt_key text, p_vocation text, p_level integer, p_item_domain text, p_selector_key text, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    lower(trim(coalesce(p_item_domain,''))) as item_domain,
    lower(trim(coalesce(p_selector_key,''))) as selector_key,
    least(greatest(coalesce(p_limit,50),1),100) as limit_value,
    case huntnexus_normalize_vocation(p_vocation)
      when 'EK' then 'knight'
      when 'RP' then 'paladin'
      when 'ED' then 'druid'
      when 'MS' then 'sorcerer'
      when 'EM' then 'monk'
      else null
    end as vocation_key
),
candidates as (
  select
    w.item_key,w.name,'weapon'::text as item_domain,w.weapon_family as item_family,
    null::text as slot_key,w.level_required,w.vocation_scope,w.vocation_keys
  from vw_weapon_catalog_universal w,p
  where p.item_domain='weapon'
    and w.weapon_family=p.selector_key
    and w.level_required<=p.level_value
    and (w.vocation_scope<>'explicit' or p.vocation_key=any(w.vocation_keys))
  union all
  select
    e.item_key,e.name,'equipment'::text,e.equipment_family,e.slot_key,
    e.level_required,e.vocation_scope,e.vocation_keys
  from vw_equipment_catalog_universal e,p
  where p.item_domain='equipment'
    and e.slot_key=p.selector_key
    and e.combat_relevance='combat_relevant'
    and e.level_required<=p.level_value
    and (e.vocation_scope<>'explicit' or p.vocation_key=any(e.vocation_keys))
),
vectors as (
  select
    c.*,
    huntnexus_optimizer_item_vector_universal(
      c.item_key,p_hunt_key,(select vocation_code from p)
    ) as vector
  from candidates c
),
prepared as (
  select
    v.*,
    v.vector->'dimensions' as dims,
    array(
      select k from jsonb_object_keys(v.vector->'dimensions') as k order by k
    ) as dim_keys
  from vectors v
),
dominance as (
  select
    b.item_key as dominated_item_key,
    a.item_key as dominator_item_key
  from prepared a
  join prepared b
    on a.item_key<>b.item_key
   and a.item_family=b.item_family
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
  where not exists (
    select 1 from dominance d where d.dominated_item_key=pp.item_key
  )
),
limited as (
  select *
  from frontier
  order by item_family,name,item_key
  limit (select limit_value from p)
)
select case
  when (select vocation_key from p) is null then
    jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'methodology',jsonb_build_object('stage','optimizer_pareto_frontier_universal_v1')
    )
  when (select item_domain from p) not in ('weapon','equipment') then
    jsonb_build_object(
      'error','unsupported_item_domain',
      'input_item_domain',p_item_domain,
      'supported_domains',jsonb_build_array('weapon','equipment'),
      'methodology',jsonb_build_object('stage','optimizer_pareto_frontier_universal_v1')
    )
  else jsonb_build_object(
    'query',jsonb_build_object(
      'hunt_key',p_hunt_key,
      'vocation',(select vocation_code from p),
      'level',(select level_value from p),
      'item_domain',(select item_domain from p),
      'selector_key',(select selector_key from p),
      'limit',(select limit_value from p)
    ),
    'summary',jsonb_build_object(
      'eligible_candidates',(select count(*) from prepared),
      'frontier_candidates',(select count(*) from frontier),
      'dominated_candidates',(select count(distinct dominated_item_key) from dominance),
      'returned',(select count(*) from limited)
    ),
    'frontier',coalesce((
      select jsonb_agg(jsonb_build_object(
        'item_key',l.item_key,
        'name',l.name,
        'item_family',l.item_family,
        'slot_key',l.slot_key,
        'vector',l.vector,
        'dominates_count',(
          select count(distinct d.dominated_item_key)
          from dominance d
          where d.dominator_item_key=l.item_key
        )
      ) order by l.item_family,l.name,l.item_key)
      from limited l
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','optimizer_pareto_frontier_universal_v1',
      'category_first',true,
      'partitioned_by_item_family',true,
      'all_dimensions_higher_is_better',true,
      'equal_dimension_keyset_required_for_dominance',true,
      'missing_dimension_makes_pair_incomparable',true,
      'cross_metric_sum_applied',false,
      'ranking_score_applied',false,
      'pareto_only',true
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_optimizer_pareto_frontier_universal(text,text,integer,text,text,integer)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_pareto_frontier_universal(text,text,integer,text,text,integer)
to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_optimizer_frontier_envelope_universal(p_vocation text, p_level integer, p_objective text DEFAULT 'balanced'::text, p_party_size integer DEFAULT 1, p_hunt_limit integer DEFAULT 1, p_frontier_limit integer DEFAULT 20, p_unlocked_requirement_keys jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
  v_level integer := greatest(coalesce(p_level,1),1);
  v_objective text := lower(coalesce(p_objective,'balanced'));
  v_hunt_limit integer := least(greatest(coalesce(p_hunt_limit,1),1),5);
  v_frontier_limit integer := least(greatest(coalesce(p_frontier_limit,20),1),50);
  v_unlocks jsonb := case
    when jsonb_typeof(coalesce(p_unlocked_requirement_keys,'[]'::jsonb))='array'
      then coalesce(p_unlocked_requirement_keys,'[]'::jsonb)
    else '[]'::jsonb
  end;
  v_rank jsonb;
  v_result jsonb := '[]'::jsonb;
  v_hunt jsonb;
  v_hunt_key text;
  v_family text;
  v_slot text;
  v_weapon_frontiers jsonb;
  v_equipment_frontiers jsonb;
  v_rule record;
begin
  if v_vocation not in ('EK','RP','ED','MS','EM') then
    return jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'supported_vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
      'methodology',jsonb_build_object('stage','optimizer_frontier_envelope_universal_v1')
    );
  end if;

  if v_objective not in ('xp','profit','balanced') then
    v_objective := 'balanced';
  end if;

  select * into v_rule
  from vocation_composition_rules
  where vocation_code=v_vocation;

  v_rank := huntnexus_rank_observed_hunts(
    v_vocation,v_level,v_objective,greatest(coalesce(p_party_size,1),1),v_hunt_limit
  );

  for v_hunt in
    select value from jsonb_array_elements(coalesce(v_rank->'results','[]'::jsonb))
  loop
    v_hunt_key := v_hunt->>'hunt_key';
    v_weapon_frontiers := '[]'::jsonb;

    for v_family in
      select value from jsonb_array_elements_text(v_rule.canonical_weapon_families)
    loop
      v_weapon_frontiers := v_weapon_frontiers || jsonb_build_array(
        jsonb_build_object(
          'weapon_family',v_family,
          'frontier',huntnexus_optimizer_pareto_frontier_universal(
            v_hunt_key,v_vocation,v_level,'weapon',v_family,v_frontier_limit
          )
        )
      );
    end loop;

    v_equipment_frontiers := '{}'::jsonb;
    foreach v_slot in array array['head','body','legs','feet','neck','ring','offhand']
    loop
      v_equipment_frontiers := v_equipment_frontiers || jsonb_build_object(
        v_slot,
        huntnexus_optimizer_pareto_frontier_universal(
          v_hunt_key,v_vocation,v_level,'equipment',v_slot,v_frontier_limit
        )
      );
    end loop;

    v_result := v_result || jsonb_build_array(
      jsonb_build_object(
        'hunt',v_hunt,
        'vocation_composition',huntnexus_vocation_composition_universal(
          v_vocation,v_level,v_unlocks,v_hunt_key
        ),
        'weapon_frontiers',v_weapon_frontiers,
        'equipment_frontiers',v_equipment_frontiers,
        'spell_candidates',huntnexus_spell_candidates_with_unlocks_universal(
          v_vocation,v_level,v_unlocks,null,null,250
        ),
        'imbuement_hunt_context',huntnexus_imbuement_hunt_context_universal(
          v_hunt_key,v_vocation
        ),
        'decision_state',jsonb_build_object(
          'hunt_ranked',true,
          'pareto_frontier_applied',true,
          'concrete_sets_generated',false,
          'set_validation_applied',false,
          'set_selected',false,
          'final_optimizer_applied',false
        )
      )
    );
  end loop;

  return jsonb_build_object(
    'query',jsonb_build_object(
      'vocation',v_vocation,
      'level',v_level,
      'objective',v_objective,
      'party_size',greatest(coalesce(p_party_size,1),1),
      'hunt_limit',v_hunt_limit,
      'frontier_limit',v_frontier_limit,
      'unlocked_requirement_keys',v_unlocks
    ),
    'results',v_result,
    'methodology',jsonb_build_object(
      'stage','optimizer_frontier_envelope_universal_v1',
      'category_first',true,
      'hunt_ranking_separate_from_item_frontier',true,
      'pareto_frontier_applied',true,
      'cross_metric_sum_applied',false,
      'ranking_score_applied_to_items',false,
      'weapon_frontiers_partitioned_by_family',true,
      'equipment_frontiers_partitioned_by_family',true,
      'missing_dimension_makes_pair_incomparable',true,
      'concrete_sets_generated',false,
      'set_selected',false,
      'final_optimizer_applied',false
    )
  );
end;
$function$
;

revoke all on function public.huntnexus_optimizer_frontier_envelope_universal(text,integer,text,integer,integer,integer,jsonb)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_frontier_envelope_universal(text,integer,text,integer,integer,integer,jsonb)
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
    'concrete_set_generation_ready',false,
    'set_validation_ready',false,
    'set_selection_ready',false,
    'final_optimizer_ready',false
  ),
  'known_blockers',jsonb_build_array(
    jsonb_build_object(
      'key','concrete_set_generation',
      'status','next',
      'note','Pareto frontiers are ready; the next stage must combine frontier items into concrete loadout candidates.'
    ),
    jsonb_build_object(
      'key','set_validation',
      'status','next',
      'note','Every concrete set must pass huntnexus_loadout_compatibility_universal before it can survive.'
    ),
    jsonb_build_object(
      'key','proficiency_activation',
      'status','pending',
      'note','Base-item Pareto vectors intentionally exclude Weapon Proficiency perks unless explicit selections are supplied in a later set-context stage.'
    ),
    jsonb_build_object(
      'key','cross_type_imbuement_priority',
      'status','pending',
      'note','Defensive Imbuement context is ready; offense/sustain/skill Imbuements remain intentionally unranked across types.'
    ),
    jsonb_build_object(
      'key','final_formula',
      'status','pending',
      'note','No invented DPS/healing or universal cross-metric scalar is allowed.'
    )
  ),
  'methodology',jsonb_build_object(
    'stage','optimizer_audit_v2',
    'category_first',true,
    'legacy_ek_optimizer_not_used_as_universal_selector',true,
    'cross_metric_score_applied',false,
    'pareto_only_for_item_pruning',true
  )
);
$function$
;

revoke all on function public.huntnexus_optimizer_audit()
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_audit()
to service_role;
