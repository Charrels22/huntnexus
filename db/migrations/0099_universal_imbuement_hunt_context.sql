-- HuntNexus — contextual Imbuement layer using observed hunt damage and Tier-C community evidence.
-- Defensive elemental protection may be prioritized from observed incoming damage.
-- Offense/sustain/skill candidates remain unranked across types; no final slot assignment.

CREATE OR REPLACE FUNCTION public.huntnexus_imbuement_hunt_context_universal(p_hunt_key text, p_vocation text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select huntnexus_normalize_vocation(p_vocation) as vocation_code
),
valid as (
  select vocation_code,
         vocation_code in ('EK','RP','ED','MS','EM') as supported
  from p
),
damage as (
  select element,sum(observed_damage)::numeric as observed_damage
  from vw_hunt_observed_incoming_damage
  where hunt_key=p_hunt_key
    and vocation=(select vocation_code from valid)
    and (select supported from valid)
  group by element
),
totals as (
  select
    coalesce(sum(observed_damage),0)::numeric as total_damage,
    coalesce(sum(observed_damage) filter(
      where exists (
        select 1
        from imbuement_definitions d
        where d.category='protection'
          and d.effect_key=damage.element
      )
    ),0)::numeric as protectable_damage
  from damage
),
elements as (
  select
    x.element,x.observed_damage,
    case when t.total_damage>0
      then x.observed_damage/t.total_damage else null end as total_damage_share,
    exists (
      select 1 from imbuement_definitions d
      where d.category='protection' and d.effect_key=x.element
    ) as has_protection_imbuement,
    case when t.protectable_damage>0 and exists (
      select 1 from imbuement_definitions d
      where d.category='protection' and d.effect_key=x.element
    ) then x.observed_damage/t.protectable_damage else null end as protectable_damage_share
  from damage x cross join totals t
),
defensive as (
  select
    d.imbuement_key,d.name,d.effect_key as element,d.powerful_value,d.unit,
    e.observed_damage,e.total_damage_share,e.protectable_damage_share,
    case when e.total_damage_share is not null
      then e.total_damage_share*d.powerful_value end as weighted_priority_total_damage,
    case when e.protectable_damage_share is not null
      then e.protectable_damage_share*d.powerful_value end as weighted_priority_protectable_damage
  from imbuement_definitions d
  join elements e on e.element=d.effect_key
  where d.category='protection' and e.observed_damage>0
),
community as (
  select
    u.imbuement_key,u.imbuement_name,u.eligible_profiles,u.observed_profiles,
    u.observed_instances,u.observed_profile_share,u.avg_instances_when_observed
  from vw_hunt_observed_imbuement_usage u
  where u.hunt_key=p_hunt_key
    and u.vocation=(select vocation_code from valid)
    and (select supported from valid)
)
select case
  when not (select supported from valid) then
    jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'supported_vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
      'methodology',jsonb_build_object(
        'stage','imbuement_hunt_context_universal_v1'
      )
    )
  else jsonb_build_object(
    'context',jsonb_build_object(
      'hunt_key',p_hunt_key,
      'vocation',(select vocation_code from valid)
    ),
    'incoming_damage',jsonb_build_object(
      'available',(select total_damage>0 from totals),
      'total_observed_damage',(select total_damage from totals),
      'protectable_observed_damage',(select protectable_damage from totals),
      'elements',coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'element',element,
            'observed_damage',observed_damage,
            'total_damage_share',round(total_damage_share,6),
            'has_protection_imbuement',has_protection_imbuement,
            'protectable_damage_share',
              case when protectable_damage_share is null then null
                   else round(protectable_damage_share,6) end
          )
          order by observed_damage desc,element
        ) from elements
      ),'[]'::jsonb)
    ),
    'defensive_priority',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'imbuement_key',imbuement_key,
          'name',name,
          'element',element,
          'powerful_value',powerful_value,
          'unit',unit,
          'observed_damage',observed_damage,
          'total_damage_share',round(total_damage_share,6),
          'protectable_damage_share',round(protectable_damage_share,6),
          'weighted_priority_total_damage',round(weighted_priority_total_damage,4),
          'weighted_priority_protectable_damage',round(weighted_priority_protectable_damage,4),
          'priority_basis','observed_incoming_damage'
        )
        order by weighted_priority_total_damage desc,observed_damage desc,name
      ) from defensive
    ),'[]'::jsonb),
    'community_observed_usage',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'imbuement_key',imbuement_key,
          'name',imbuement_name,
          'eligible_profiles',eligible_profiles,
          'observed_profiles',observed_profiles,
          'observed_instances',observed_instances,
          'observed_profile_share',observed_profile_share,
          'avg_instances_when_observed',avg_instances_when_observed,
          'evidence_tier','C',
          'affects_priority',false
        )
        order by observed_profile_share desc nulls last,
                 observed_instances desc nulls last,
                 imbuement_name
      ) from community
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','imbuement_hunt_context_universal_v1',
      'category_first',true,
      'defensive_priority_is_data_driven',true,
      'protectable_and_total_damage_shares_exposed_separately',true,
      'community_usage_evidence_tier','C',
      'community_usage_affects_priority',false,
      'offense_sustain_cross_type_priority_inferred',false,
      'final_assignment',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_imbuement_hunt_context_universal(text,text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_imbuement_hunt_context_universal(text,text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_item_imbuement_context_universal(p_item_key text, p_hunt_key text, p_vocation text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with comp as (
  select huntnexus_item_imbuement_compatibility_universal(p_item_key) as j
),
ctx as (
  select huntnexus_imbuement_hunt_context_universal(p_hunt_key,p_vocation) as j
),
eligible as (
  select x as candidate
  from comp,lateral jsonb_array_elements(j->'candidates') x
  where x->>'eligibility_status'='eligible'
),
defensive_context as (
  select e.candidate,d as priority
  from eligible e
  join ctx on true
  join lateral jsonb_array_elements(ctx.j->'defensive_priority') d
    on d->>'imbuement_key'=e.candidate->>'imbuement_key'
),
community_context as (
  select e.candidate,u as usage
  from eligible e
  join ctx on true
  join lateral jsonb_array_elements(ctx.j->'community_observed_usage') u
    on u->>'imbuement_key'=e.candidate->>'imbuement_key'
)
select case
  when (select j->>'error' from comp) is not null then (select j from comp)
  when (select j->>'error' from ctx) is not null then (select j from ctx)
  else jsonb_build_object(
    'item',(select j->'item' from comp),
    'compatibility_summary',(select j->'summary' from comp),
    'coverage',(select j->'coverage' from comp),
    'hunt_context',jsonb_build_object(
      'hunt_key',p_hunt_key,
      'vocation',(select j #>> '{context,vocation}' from ctx),
      'incoming_damage',(select j->'incoming_damage' from ctx)
    ),
    'defensive_priority_for_item',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'imbuement_key',candidate->>'imbuement_key',
          'name',candidate->>'name',
          'element',candidate->>'effect_key',
          'powerful_value',(candidate->>'powerful_value')::numeric,
          'unit',candidate->>'unit',
          'observed_damage',(priority->>'observed_damage')::numeric,
          'total_damage_share',(priority->>'total_damage_share')::numeric,
          'protectable_damage_share',(priority->>'protectable_damage_share')::numeric,
          'weighted_priority_total_damage',
            (priority->>'weighted_priority_total_damage')::numeric,
          'weighted_priority_protectable_damage',
            (priority->>'weighted_priority_protectable_damage')::numeric,
          'priority_basis','observed_incoming_damage'
        )
        order by (priority->>'weighted_priority_total_damage')::numeric desc,
                 candidate->>'name'
      ) from defensive_context
    ),'[]'::jsonb),
    'eligible_nondefensive_candidates',coalesce((
      select jsonb_agg(candidate order by candidate->>'category',candidate->>'name')
      from eligible where candidate->>'category'<>'protection'
    ),'[]'::jsonb),
    'community_evidence_for_eligible_candidates',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'imbuement_key',candidate->>'imbuement_key',
          'name',candidate->>'name',
          'observed_usage',usage,
          'affects_priority',false
        )
        order by (usage->>'observed_profile_share')::numeric desc nulls last,
                 candidate->>'name'
      ) from community_context
    ),'[]'::jsonb),
    'unmatched_community_usage',(select coalesce(jsonb_agg(u),'[]'::jsonb)
      from ctx,lateral jsonb_array_elements(ctx.j->'community_observed_usage') u
      where not exists (
        select 1 from eligible e
        where e.candidate->>'imbuement_key'=u->>'imbuement_key'
      )
    ),
    'methodology',jsonb_build_object(
      'stage','item_imbuement_context_universal_v1',
      'category_first',true,
      'factual_compatibility_applied',true,
      'defensive_priority_uses_observed_incoming_damage',true,
      'community_usage_evidence_tier','C',
      'community_usage_affects_priority',false,
      'cross_type_priority_inferred',false,
      'slot_assignment_applied',false,
      'final_assignment',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_item_imbuement_context_universal(text,text,text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_item_imbuement_context_universal(text,text,text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_imbuement_category_audit()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select jsonb_build_object(
  'summary',jsonb_build_object(
    'powerful_definitions',(select count(*) from imbuement_definitions),
    'applicability_rules',(select count(*) from imbuement_applicability_rules),
    'definitions_without_rules',(
      select count(*) from imbuement_definitions d
      where not exists (
        select 1 from imbuement_applicability_rules r
        where r.imbuement_key=d.imbuement_key
      )
    ),
    'categories',(select count(distinct category) from imbuement_definitions),
    'source_catalog_complete_for_current_24',(
      (select count(*) from imbuement_definitions)=24
      and (
        select count(*) from imbuement_definitions d
        where not exists (
          select 1 from imbuement_applicability_rules r
          where r.imbuement_key=d.imbuement_key
        )
      )=0
    ),
    'factual_compatibility_ready',true,
    'hunt_context_priority_ready',true,
    'defensive_hunt_context_ready',true,
    'cross_type_priority_ready',false,
    'final_assignment_ready',false,
    'observed_damage_contexts',(
      select count(*) from (
        select distinct hunt_key,vocation
        from vw_hunt_observed_incoming_damage
        where hunt_key is not null
      ) x
    ),
    'community_usage_contexts',(
      select count(*) from (
        select distinct hunt_key,vocation
        from vw_hunt_observed_imbuement_usage
        where hunt_key is not null
      ) x
    )
  ),
  'scope',jsonb_build_object(
    'priority_scope','defensive_only',
    'weapon_families',coalesce((
      select jsonb_agg(distinct target_family order by target_family)
      from imbuement_applicability_rules where target_domain='weapon'
    ),'[]'::jsonb),
    'equipment_families',coalesce((
      select jsonb_agg(distinct target_family order by target_family)
      from imbuement_applicability_rules where target_domain='equipment'
    ),'[]'::jsonb),
    'container_families',coalesce((
      select jsonb_agg(distinct target_family order by target_family)
      from imbuement_applicability_rules where target_domain='container'
    ),'[]'::jsonb),
    'current_catalog_outside_scope',jsonb_build_array('backpack')
  ),
  'known_caveats',jsonb_build_array(
    jsonb_build_object(
      'key','fist_applicability',
      'status','source_strict',
      'note','Punch is explicitly confirmed for Fist weapons. Other imbuements are not inferred without explicit current applicability evidence.'
    ),
    jsonb_build_object(
      'key','powerful_only',
      'status','intentional',
      'note','Current normalized definition layer stores Powerful values; Basic/Intricate tier modeling remains separate future work.'
    ),
    jsonb_build_object(
      'key','priority_scope',
      'status','intentional',
      'note','Only elemental protection is prioritized from observed incoming damage. Offense, sustain, skills and community usage are not cross-ranked.'
    )
  ),
  'methodology',jsonb_build_object(
    'stage','imbuement_category_audit_v2',
    'category_first',true,
    'legacy_functions_preserved',true,
    'source_driven_applicability',true,
    'defensive_priority_data_driven',true,
    'community_usage_evidence_tier','C',
    'community_usage_affects_priority',false,
    'cross_type_priority_inferred',false,
    'final_assignment_applied',false
  )
);
$function$
;

revoke all on function public.huntnexus_imbuement_category_audit()
  from public,anon,authenticated;
grant execute on function public.huntnexus_imbuement_category_audit()
  to service_role;
