-- HuntNexus FE-08 — owned build options.
-- Option 1 is always the registered Main Set baseline.
-- Options 2/3 may use owned Backpack items only when they are contextual frontier candidates
-- and the resulting loadout is not Pareto-dominated by the Main baseline under an exact comparable vector.
-- External catalog items are never inserted into owned build options.

create or replace function public.huntnexus_player_owned_build_options(
  p_client_id uuid,
  p_hunt_key text,
  p_vocation text,
  p_level integer,
  p_proficiency_selections jsonb default '{}'::jsonb,
  p_character_profile jsonb default '{}'::jsonb,
  p_option_limit integer default 3
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with params as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    least(greatest(coalesce(p_option_limit,3),1),3) as option_limit,
    case
      when jsonb_typeof(coalesce(p_proficiency_selections,'{}'::jsonb))='object'
        then coalesce(p_proficiency_selections,'{}'::jsonb)
      else '{}'::jsonb
    end as prof_map,
    case
      when jsonb_typeof(coalesce(p_character_profile,'{}'::jsonb))='object'
        then coalesce(p_character_profile,'{}'::jsonb)
      else '{}'::jsonb
    end as char_profile
),
inv as (
  select i.id,i.storage_kind,i.selection_key,i.item_key,i.item_name
  from public.player_character_inventory i
  where i.client_id=p_client_id
),
baseline as (
  select coalesce(
    jsonb_object_agg(selection_key,item_key order by selection_key)
      filter (where storage_kind='main'),
    '{}'::jsonb
  ) as selection
  from inv
),
baseline_eval as (
  select
    b.selection,
    huntnexus_loadout_compatibility_universal(
      (select vocation_code from params),
      (select level_value from params),
      b.selection
    ) as validation,
    huntnexus_optimizer_set_vector_universal(
      jsonb_build_object('selection',b.selection),
      p_hunt_key,
      (select vocation_code from params),
      (select prof_map from params),
      (select char_profile from params)
    ) as vector
  from baseline b
),
review as (
  select huntnexus_player_inventory_hunt_review(
    p_client_id,
    p_hunt_key,
    (select vocation_code from params),
    (select level_value from params),
    (select prof_map from params),
    30
  ) as j
),
bp_frontier as (
  select
    x->>'selection_key' as selection_key,
    x->>'item_key' as item_key,
    x->>'item_name' as item_name
  from review
  cross join lateral jsonb_array_elements(coalesce(j->'frontier_candidates','[]'::jsonb)) x
  where x->>'ownership'='backpack'
),
single_variants as (
  select
    1 as replacement_count,
    jsonb_build_array(
      jsonb_build_object(
        'selection_key',b.selection_key,
        'item_key',b.item_key,
        'item_name',b.item_name
      )
    ) as replacements,
    (base.selection || jsonb_build_object(b.selection_key,b.item_key)) as selection
  from bp_frontier b
  cross join baseline base
  where base.selection ? b.selection_key
    and base.selection->>b.selection_key <> b.item_key
),
double_variants as (
  select
    2 as replacement_count,
    jsonb_build_array(
      jsonb_build_object(
        'selection_key',a.selection_key,
        'item_key',a.item_key,
        'item_name',a.item_name
      ),
      jsonb_build_object(
        'selection_key',b.selection_key,
        'item_key',b.item_key,
        'item_name',b.item_name
      )
    ) as replacements,
    (
      base.selection
      || jsonb_build_object(a.selection_key,a.item_key)
      || jsonb_build_object(b.selection_key,b.item_key)
    ) as selection
  from bp_frontier a
  join bp_frontier b
    on a.selection_key < b.selection_key
  cross join baseline base
  where base.selection ? a.selection_key
    and base.selection ? b.selection_key
    and base.selection->>a.selection_key <> a.item_key
    and base.selection->>b.selection_key <> b.item_key
),
raw_variants as (
  select * from single_variants
  union all
  select * from double_variants
),
dedup_variants as (
  select distinct on (selection)
    replacement_count,replacements,selection
  from raw_variants
  order by selection,replacement_count
),
evaluated as (
  select
    d.*,
    huntnexus_loadout_compatibility_universal(
      (select vocation_code from params),
      (select level_value from params),
      d.selection
    ) as validation,
    huntnexus_optimizer_set_vector_universal(
      jsonb_build_object('selection',d.selection),
      p_hunt_key,
      (select vocation_code from params),
      (select prof_map from params),
      (select char_profile from params)
    ) as vector
  from dedup_variants d
),
comparisons as (
  select
    e.*,
    (
      coalesce((b.vector->>'comparison_ready')::boolean,false)
      and coalesce((e.vector->>'comparison_ready')::boolean,false)
      and b.vector->'comparison_key'=e.vector->'comparison_key'
      and (
        select coalesce(array_agg(k order by k),array[]::text[])
        from jsonb_object_keys(coalesce(b.vector->'dimensions','{}'::jsonb)) k
      ) = (
        select coalesce(array_agg(k order by k),array[]::text[])
        from jsonb_object_keys(coalesce(e.vector->'dimensions','{}'::jsonb)) k
      )
    ) as exact_comparable,
    case
      when
        coalesce((b.vector->>'comparison_ready')::boolean,false)
        and coalesce((e.vector->>'comparison_ready')::boolean,false)
        and b.vector->'comparison_key'=e.vector->'comparison_key'
        and (
          select coalesce(array_agg(k order by k),array[]::text[])
          from jsonb_object_keys(coalesce(b.vector->'dimensions','{}'::jsonb)) k
        ) = (
          select coalesce(array_agg(k order by k),array[]::text[])
          from jsonb_object_keys(coalesce(e.vector->'dimensions','{}'::jsonb)) k
        )
      then
        not exists (
          select 1
          from jsonb_each(coalesce(b.vector->'dimensions','{}'::jsonb)) bd
          where (bd.value::text)::numeric
              < ((e.vector->'dimensions'->bd.key)::text)::numeric
        )
        and exists (
          select 1
          from jsonb_each(coalesce(b.vector->'dimensions','{}'::jsonb)) bd
          where (bd.value::text)::numeric
              > ((e.vector->'dimensions'->bd.key)::text)::numeric
        )
      else false
    end as dominated_by_main,
    case
      when
        coalesce((b.vector->>'comparison_ready')::boolean,false)
        and coalesce((e.vector->>'comparison_ready')::boolean,false)
        and b.vector->'comparison_key'=e.vector->'comparison_key'
        and (
          select coalesce(array_agg(k order by k),array[]::text[])
          from jsonb_object_keys(coalesce(b.vector->'dimensions','{}'::jsonb)) k
        ) = (
          select coalesce(array_agg(k order by k),array[]::text[])
          from jsonb_object_keys(coalesce(e.vector->'dimensions','{}'::jsonb)) k
        )
      then
        not exists (
          select 1
          from jsonb_each(coalesce(e.vector->'dimensions','{}'::jsonb)) ed
          where (ed.value::text)::numeric
              < ((b.vector->'dimensions'->ed.key)::text)::numeric
        )
        and exists (
          select 1
          from jsonb_each(coalesce(e.vector->'dimensions','{}'::jsonb)) ed
          where (ed.value::text)::numeric
              > ((b.vector->'dimensions'->ed.key)::text)::numeric
        )
      else false
    end as dominates_main
  from evaluated e
  cross join baseline_eval b
),
viable as (
  select *
  from comparisons
  where validation->>'status'='valid'
    and not dominated_by_main
),
ranked as (
  select
    v.*,
    row_number() over(
      order by
        case when dominates_main then 0 else 1 end,
        replacement_count,
        selection::text
    ) as rn
  from viable v
),
options as (
  select
    1 as option_order,
    'main'::text as option_type,
    'Em uso'::text as label,
    'Set Main cadastrado'::text as reason,
    '[]'::jsonb as replacements,
    b.selection,
    b.validation,
    b.vector,
    false as dominates_main,
    false as dominated_by_main,
    true as exact_comparable
  from baseline_eval b

  union all

  select
    (rn+1)::int as option_order,
    'owned_variant'::text as option_type,
    case rn when 1 then '2ª opção' else '3ª opção' end as label,
    case
      when dominates_main then 'Variação com itens da BP que domina o Main em dimensões exatamente comparáveis'
      when exact_comparable then 'Variação com itens da BP não dominada pelo Main'
      else 'Variação contextual da BP preservada como incomparável ao Main'
    end as reason,
    replacements,
    selection,
    validation,
    vector,
    dominates_main,
    dominated_by_main,
    exact_comparable
  from ranked
  where rn < (select option_limit from params)
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'hunt_key',p_hunt_key,
    'vocation',(select vocation_code from params),
    'level',(select level_value from params)
  ),
  'summary',jsonb_build_object(
    'main_items',(select count(*) from jsonb_object_keys((select selection from baseline))),
    'backpack_frontier_items',(select count(*) from bp_frontier),
    'raw_owned_variants',(select count(*) from dedup_variants),
    'valid_owned_variants',(select count(*) from comparisons where validation->>'status'='valid'),
    'discarded_as_main_dominated',(select count(*) from comparisons where dominated_by_main),
    'viable_owned_variants',(select count(*) from viable),
    'returned_options',(select count(*) from options)
  ),
  'options',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'option_order',option_order,
        'option_type',option_type,
        'label',label,
        'reason',reason,
        'replacements',replacements,
        'selection',selection,
        'validation',validation,
        'dominates_main',dominates_main,
        'dominated_by_main',dominated_by_main,
        'exact_comparable',exact_comparable
      )
      order by option_order
    )
    from options
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','player_owned_build_options_v1',
    'main_set_is_option_1',true,
    'owned_backpack_priority',true,
    'backpack_candidate_must_reach_context_frontier',true,
    'main_dominated_variants_removed_when_exactly_comparable',true,
    'external_items_used_in_owned_options',false,
    'maximum_replacements_per_owned_variant',2,
    'fewer_replacements_preferred_after_dominance',true,
    'cross_metric_score_applied',false,
    'single_best_forced',false
  )
);
$function$;

revoke all on function public.huntnexus_player_owned_build_options(uuid,text,text,integer,jsonb,jsonb,integer)
from public,anon,authenticated;
grant execute on function public.huntnexus_player_owned_build_options(uuid,text,text,integer,jsonb,jsonb,integer)
to service_role;
