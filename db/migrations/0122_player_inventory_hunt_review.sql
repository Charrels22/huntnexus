-- HuntNexus FE-07 — owned-first hunt equipment review.
-- Main set remains baseline. Backpack and external Pareto candidates are advisory only.

create or replace function public.huntnexus_player_inventory_hunt_review(
  p_client_id uuid,
  p_hunt_key text,
  p_vocation text,
  p_level integer,
  p_proficiency_selections jsonb default '{}'::jsonb,
  p_frontier_limit integer default 12
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with inv as (
  select
    i.id,
    i.storage_kind,
    i.selection_key,
    i.item_key,
    i.item_name,
    c.item_domain,
    c.item_family
  from public.player_character_inventory i
  left join public.vw_loadout_item_catalog_universal c
    on c.item_key=i.item_key and c.selection_key=i.selection_key
  where i.client_id=p_client_id
),
main_items as (
  select *
  from inv
  where storage_kind='main'
),
targets as (
  select distinct
    item_domain,
    case
      when item_domain='weapon' then item_family
      when item_domain='ammunition' then item_family
      else selection_key
    end as selector_key,
    selection_key
  from main_items
  where item_domain is not null
),
frontier_json as (
  select
    t.item_domain,
    t.selector_key,
    t.selection_key,
    huntnexus_optimizer_pareto_frontier_universal(
      p_hunt_key,
      p_vocation,
      p_level,
      t.item_domain,
      t.selector_key,
      least(greatest(coalesce(p_frontier_limit,12),1),30)
    ) as j
  from targets t
),
frontier_items as (
  select
    f.item_domain,
    f.selector_key,
    f.selection_key,
    x->>'item_key' as item_key,
    x->>'name' as item_name,
    x->>'item_family' as item_family,
    x->'vector' as vector,
    coalesce((x->>'dominates_count')::int,0) as dominates_count
  from frontier_json f
  cross join lateral jsonb_array_elements(coalesce(f.j->'frontier','[]'::jsonb)) x
),
classified as (
  select
    fi.*,
    case
      when exists(select 1 from inv i where i.storage_kind='main' and i.item_key=fi.item_key) then 'main'
      when exists(select 1 from inv i where i.storage_kind='backpack' and i.item_key=fi.item_key) then 'backpack'
      else 'external'
    end as ownership
  from frontier_items fi
),
owned_context as (
  select
    i.storage_kind,
    i.selection_key,
    i.item_key,
    i.item_name,
    i.item_domain,
    i.item_family,
    huntnexus_item_effect_hunt_context_universal(
      i.item_key,
      p_hunt_key,
      p_vocation,
      case
        when jsonb_typeof(coalesce(p_proficiency_selections,'{}'::jsonb))='object'
          then coalesce(p_proficiency_selections->i.item_key,'[]'::jsonb)
        else '[]'::jsonb
      end
    ) as hunt_context,
    exists(
      select 1 from frontier_items f
      where f.item_key=i.item_key
        and f.selection_key=i.selection_key
    ) as on_context_frontier
  from inv i
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'hunt_key',p_hunt_key,
    'vocation',huntnexus_normalize_vocation(p_vocation),
    'level',greatest(coalesce(p_level,1),1)
  ),
  'baseline',jsonb_build_object(
    'main_set',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'selection_key',selection_key,
          'item_key',item_key,
          'item_name',item_name,
          'item_domain',item_domain,
          'item_family',item_family,
          'on_context_frontier',on_context_frontier,
          'hunt_context',hunt_context
        )
        order by selection_key
      )
      from owned_context
      where storage_kind='main'
    ),'[]'::jsonb)
  ),
  'owned_alternatives',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'selection_key',o.selection_key,
        'item_key',o.item_key,
        'item_name',o.item_name,
        'item_domain',o.item_domain,
        'item_family',o.item_family,
        'on_context_frontier',o.on_context_frontier,
        'hunt_context',o.hunt_context
      )
      order by o.selection_key,o.item_name
    )
    from owned_context o
    where o.storage_kind='backpack'
  ),'[]'::jsonb),
  'frontier_candidates',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'selection_key',selection_key,
        'selector_key',selector_key,
        'item_domain',item_domain,
        'item_key',item_key,
        'item_name',item_name,
        'item_family',item_family,
        'ownership',ownership,
        'dominates_count',dominates_count,
        'vector',vector
      )
      order by
        case ownership when 'main' then 0 when 'backpack' then 1 else 2 end,
        selection_key,
        item_name
    )
    from classified
  ),'[]'::jsonb),
  'summary',jsonb_build_object(
    'main_items',(select count(*) from inv where storage_kind='main'),
    'backpack_items',(select count(*) from inv where storage_kind='backpack'),
    'main_items_on_context_frontier',(select count(*) from owned_context where storage_kind='main' and on_context_frontier),
    'backpack_frontier_candidates',(select count(*) from classified where ownership='backpack'),
    'external_frontier_candidates',(select count(*) from classified where ownership='external')
  ),
  'methodology',jsonb_build_object(
    'stage','player_inventory_hunt_review_v1',
    'main_set_is_baseline',true,
    'automatic_main_replacement',false,
    'backpack_substitution_is_advisory',true,
    'external_items_are_advisory_only',true,
    'frontier_means_contextual_pareto_candidate_not_single_best',true,
    'cross_metric_score_applied',false,
    'full_set_compatibility_not_recomputed_here',true
  )
);
$function$;

revoke all on function public.huntnexus_player_inventory_hunt_review(uuid,text,text,integer,jsonb,integer)
from public,anon,authenticated;
grant execute on function public.huntnexus_player_inventory_hunt_review(uuid,text,text,integer,jsonb,integer)
to service_role;
