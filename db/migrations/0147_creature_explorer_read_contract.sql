-- HuntNexus FE-15 — Creature Explorer read contracts.

create or replace function public.huntnexus_search_creatures(
  p_query text default '',
  p_limit integer default 30
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with params as (
  select
    trim(coalesce(p_query,'')) as q,
    least(greatest(coalesce(p_limit,30),1),100) as lim
),
rows as (
  select
    e.entity_key as creature_key,
    e.name,
    nullif(e.attributes->>'hitpoints','')::numeric as hitpoints,
    nullif(e.attributes->>'experience','')::numeric as experience,
    e.attributes #>> '{structuredData,infobox,creatureClass}' as creature_class,
    e.attributes #>> '{structuredData,infobox,primaryType}' as primary_type,
    e.attributes #>> '{structuredData,infobox,location}' as location,
    coalesce((e.attributes #>> '{structuredData,combatProperties,isBoss}')::boolean,false) as is_boss,
    e.observed_at
  from public.tibia_entities e
  cross join params p
  where e.entity_type='creature'
    and not coalesce((e.attributes #>> '{structuredData,combatProperties,isBoss}')::boolean,false)
    and (
      p.q=''
      or e.name ilike '%'||p.q||'%'
      or e.entity_key ilike '%'||replace(lower(p.q),' ','-')||'%'
    )
  order by
    case
      when p.q<>'' and lower(e.name)=lower(p.q) then 0
      when p.q<>'' and lower(e.name) like lower(p.q)||'%' then 1
      else 2
    end,
    e.name
  limit (select lim from params)
)
select jsonb_build_object(
  'query',(select q from params),
  'creatures',coalesce((
    select jsonb_agg(to_jsonb(rows) order by name)
    from rows
  ),'[]'::jsonb),
  'summary',jsonb_build_object(
    'returned',(select count(*) from rows)
  ),
  'methodology',jsonb_build_object(
    'stage','creature_search_v1',
    'bosses_excluded',true,
    'canonical_entity_source',true
  )
);
$function$;

create or replace function public.huntnexus_creature_detail(
  p_creature_key text
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with creature as (
  select
    e.entity_key as creature_key,
    e.name,
    e.attributes,
    e.observed_at
  from public.tibia_entities e
  where e.entity_type='creature'
    and e.entity_key=p_creature_key
  order by e.observed_at desc
  limit 1
),
vulnerabilities as (
  select
    element,
    modifier_percent,
    patch_version,
    observed_at
  from public.monster_vulnerability
  where monster_key=p_creature_key
    and valid_to is null
  order by element
),
abilities as (
  select
    attack_type,
    abilities_raw,
    max_damage,
    uses_spells,
    observed_at
  from public.creature_abilities
  where monster_key=p_creature_key
  order by coalesce(max_damage,0) desc,attack_type,abilities_raw
),
loot as (
  select
    item_name,
    chance,
    rarity,
    raw_text,
    observed_at
  from public.creature_loot
  where monster_key=p_creature_key
  order by
    case lower(coalesce(rarity,'')) when 'very rare' then 0 when 'rare' then 1 when 'semi-rare' then 2 else 3 end,
    item_name
)
select case
  when not exists(select 1 from creature) then
    jsonb_build_object('error','creature_not_found')
  else
    jsonb_build_object(
      'creature',(
        select jsonb_build_object(
          'creature_key',creature_key,
          'name',name,
          'hitpoints',nullif(attributes->>'hitpoints','')::numeric,
          'experience',nullif(attributes->>'experience','')::numeric,
          'creature_class',attributes #>> '{structuredData,infobox,creatureClass}',
          'primary_type',attributes #>> '{structuredData,infobox,primaryType}',
          'location',attributes #>> '{structuredData,infobox,location}',
          'notes',attributes #>> '{structuredData,infobox,notes}',
          'strategy',attributes #>> '{structuredData,infobox,strategy}',
          'behaviour',attributes #>> '{structuredData,infobox,behaviour}',
          'implemented',attributes #>> '{structuredData,infobox,implemented}',
          'speed',attributes #>> '{structuredData,infobox,speed}',
          'armor',attributes #>> '{structuredData,infobox,armor}',
          'max_damage',attributes #>> '{structuredData,infobox,maxDamage}',
          'spawn_type',attributes #>> '{structuredData,infobox,spawnType}',
          'resistance_summary',coalesce(attributes #> '{structuredData,resistanceSummary}','{}'::jsonb),
          'combat_properties',coalesce(attributes #> '{structuredData,combatProperties}','{}'::jsonb),
          'observed_at',observed_at
        )
        from creature
      ),
      'vulnerabilities',coalesce((
        select jsonb_agg(to_jsonb(vulnerabilities) order by element)
        from vulnerabilities
      ),'[]'::jsonb),
      'abilities',coalesce((
        select jsonb_agg(to_jsonb(abilities) order by coalesce(max_damage,0) desc,attack_type)
        from abilities
      ),'[]'::jsonb),
      'loot',coalesce((
        select jsonb_agg(to_jsonb(loot) order by item_name)
        from loot
      ),'[]'::jsonb),
      'summary',jsonb_build_object(
        'vulnerability_rows',(select count(*) from vulnerabilities),
        'ability_rows',(select count(*) from abilities),
        'loot_rows',(select count(*) from loot)
      ),
      'methodology',jsonb_build_object(
        'stage','creature_detail_v1',
        'canonical_entity_source',true,
        'raw_unknown_values_not_inferred',true
      )
    )
end;
$function$;

revoke all on function public.huntnexus_search_creatures(text,integer)
from public,anon,authenticated;
revoke all on function public.huntnexus_creature_detail(text)
from public,anon,authenticated;

grant execute on function public.huntnexus_search_creatures(text,integer) to service_role;
grant execute on function public.huntnexus_creature_detail(text) to service_role;
