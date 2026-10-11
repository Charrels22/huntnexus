-- PERF-02: Same-keyset dominance, with direct jsonb field lookups for
-- a.dimensions instead of rebuilding two JSON sets per comparison.
-- Structural partitions, numeric exactness and strict Pareto inequality
-- remain unchanged. Hashes checked before/after application.
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
    where (a.dims->>bd.key)::numeric < bd.value::numeric
  )
  and exists (
    select 1
    from jsonb_each_text(b.dims) bd
    where (a.dims->>bd.key)::numeric > bd.value::numeric
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
$function$;

revoke all on function public.huntnexus_optimizer_pareto_frontier_universal(text,text,integer,text,text,integer)
from public,anon,authenticated;
grant execute on function public.huntnexus_optimizer_pareto_frontier_universal(text,text,integer,text,text,integer)
to service_role;
