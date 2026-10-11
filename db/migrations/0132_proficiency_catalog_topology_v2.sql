-- HuntNexus FE-17 — proficiency catalog v2 with source-backed topology metadata.

create or replace function public.huntnexus_player_profile_proficiency_catalog(
  p_vocation text,
  p_level integer,
  p_weapon_family text default null
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with ctx as (
  select
    upper(trim(coalesce(p_vocation,''))) as vocation,
    greatest(coalesce(p_level,1),1) as player_level,
    nullif(lower(trim(coalesce(p_weapon_family,''))),'') as weapon_family,
    case upper(trim(coalesce(p_vocation,'')))
      when 'EK' then 'knight'
      when 'RP' then 'paladin'
      when 'ED' then 'druid'
      when 'MS' then 'sorcerer'
      when 'EM' then 'monk'
      else null
    end as vocation_key
),
trees as (
  select
    t.item_key,
    i.name as item_name,
    i.weapon_family,
    i.level_required,
    i.vocation_keys,
    t.levels_declared,
    t.topology_status,
    t.perk_count,
    i.wiki_url,
    ts.source_kind,
    ts.source_repository,
    ts.source_revision,
    ts.source_path,
    ts.source_profile_name,
    ts.source_proficiency_id,
    ts.source_profile_version,
    ts.confidence as topology_confidence,
    ts.validation_status as topology_validation_status,
    ts.levels_json,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'perk_order',p.perk_order,
          'level_number',p.level_number,
          'position_in_level',p.position_in_level,
          'effect_key',p.effect_key,
          'numeric_value',p.numeric_value,
          'unit',p.unit,
          'scope',p.scope,
          'spell_key',p.spell_key,
          'description_raw',p.description_raw
        )
        order by p.perk_order
      ) filter (where p.item_key is not null),
      '[]'::jsonb
    ) as perks
  from public.weapon_proficiency_trees t
  join public.vw_weapon_catalog_universal i
    on i.item_key=t.item_key
  left join public.weapon_proficiency_perks p
    on p.item_key=t.item_key
  left join public.weapon_proficiency_topology_sources ts
    on ts.item_key=t.item_key
  cross join ctx c
  where
    (c.weapon_family is null or lower(i.weapon_family)=c.weapon_family)
    and (
      c.vocation_key is null
      or c.vocation_key=any(i.vocation_keys)
      or cardinality(i.vocation_keys)=0
    )
  group by
    t.item_key,i.name,i.weapon_family,i.level_required,i.vocation_keys,
    t.levels_declared,t.topology_status,t.perk_count,i.wiki_url,
    ts.source_kind,ts.source_repository,ts.source_revision,ts.source_path,
    ts.source_profile_name,ts.source_proficiency_id,ts.source_profile_version,
    ts.confidence,ts.validation_status,ts.levels_json
)
select jsonb_build_object(
  'query',jsonb_build_object(
    'vocation',(select vocation from ctx),
    'level',(select player_level from ctx),
    'weapon_family',(select weapon_family from ctx)
  ),
  'summary',jsonb_build_object(
    'tree_count',(select count(*) from trees),
    'eligible_tree_count',(select count(*) from trees where coalesce(level_required,0) <= (select player_level from ctx)),
    'locked_tree_count',(select count(*) from trees where coalesce(level_required,0) > (select player_level from ctx)),
    'source_backed_topology_count',(select count(*) from trees where topology_status='source_backed_level_position')
  ),
  'trees',coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'item_key',item_key,
          'item_name',item_name,
          'weapon_family',weapon_family,
          'level_required',level_required,
          'eligible',coalesce(level_required,0) <= (select player_level from ctx),
          'vocation_keys',to_jsonb(vocation_keys),
          'levels_declared',levels_declared,
          'topology_status',topology_status,
          'perk_count',perk_count,
          'wiki_url',wiki_url,
          'topology_source',case
            when source_profile_name is null then null
            else jsonb_build_object(
              'source_kind',source_kind,
              'repository',source_repository,
              'revision',source_revision,
              'path',source_path,
              'profile_name',source_profile_name,
              'proficiency_id',source_proficiency_id,
              'profile_version',source_profile_version,
              'confidence',topology_confidence,
              'validation_status',topology_validation_status,
              'levels',levels_json
            )
          end,
          'perks',perks
        )
        order by coalesce(level_required,0),item_name
      )
      from trees
    ),
    '[]'::jsonb
  ),
  'methodology',jsonb_build_object(
    'stage','player_profile_proficiency_catalog_v2',
    'item_key_binding_required',true,
    'perk_dependencies_inferred',false,
    'topology_inferred',false,
    'source_backed_level_position_supported',true,
    'one_active_per_known_level_required',true,
    'selection_inheritance_applied',false
  )
);
$function$;

revoke all on function public.huntnexus_player_profile_proficiency_catalog(text,integer,text)
from public,anon,authenticated;
grant execute on function public.huntnexus_player_profile_proficiency_catalog(text,integer,text)
to service_role;
