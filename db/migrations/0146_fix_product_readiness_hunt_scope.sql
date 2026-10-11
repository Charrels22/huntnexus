-- HuntNexus PROD-03 — fix readiness gate to evaluate only Planner-eligible hunt entries.

create or replace function public.huntnexus_product_readiness_audit()
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with optimizer as (
  select public.huntnexus_optimizer_audit() as j
),
hunts as (
  select public.huntnexus_hunt_catalog_readiness_audit() as j
),
checks as (
  select * from (values
    (
      'optimizer_final_ready',
      coalesce(((select j #>> '{summary,final_optimizer_ready}' from optimizer))::boolean,false),
      'Universal final optimizer contract is ready.'
    ),
    (
      'hunt_catalog_core_ready',
      (
        coalesce((select (j #>> '{summary,planner_eligible_entries}')::int from hunts),0) > 0
        and not exists (
          select 1
          from hunts h
          cross join lateral jsonb_array_elements(coalesce(h.j->'entries','[]'::jsonb)) e
          where coalesce((e->>'planner_eligible')::boolean,false)
            and not coalesce((e->>'source_core_complete')::boolean,false)
        )
      ),
      'Every Planner-eligible hunt has complete source core; excluded catalog entries do not block readiness.'
    ),
    (
      'imbuement_catalog_ready',
      (select count(*)=24 from public.imbuement_definitions),
      'Current normalized Powerful Imbuement catalog contains 24 definitions.'
    ),
    (
      'proficiency_catalog_ready',
      (select count(*)>0 from public.weapon_proficiency_trees),
      'Weapon Proficiency trees are present.'
    ),
    (
      'private_profile_contract_ready',
      to_regprocedure('public.huntnexus_player_profile_get(uuid)') is not null
      and to_regprocedure('public.huntnexus_player_profile_save(uuid,jsonb)') is not null,
      'Private Profile read/write RPCs exist.'
    ),
    (
      'private_inventory_contract_ready',
      to_regprocedure('public.huntnexus_player_inventory_get(uuid)') is not null
      and to_regprocedure('public.huntnexus_player_inventory_put(uuid,text,text,integer)') is not null,
      'Main Set / Backpack contracts exist.'
    ),
    (
      'private_session_contract_ready',
      to_regprocedure('public.huntnexus_player_session_save(uuid,jsonb,jsonb,jsonb)') is not null
      and to_regprocedure('public.huntnexus_player_session_detail(uuid,uuid)') is not null
      and to_regprocedure('public.huntnexus_player_session_build_performance(uuid,text,text)') is not null,
      'Private Session Analyzer persistence and build performance contracts exist.'
    ),
    (
      'account_sync_contract_ready',
      to_regprocedure('public.huntnexus_account_resolve(uuid,uuid)') is not null
      and to_regprocedure('public.huntnexus_account_binding_status(uuid)') is not null,
      'Authenticated account-to-canonical-client binding exists.'
    ),
    (
      'private_tables_rls_ready',
      not exists (
        select 1
        from pg_class c
        join pg_namespace n on n.oid=c.relnamespace
        where n.nspname='public'
          and c.relname in (
            'player_character_profiles',
            'player_character_inventory',
            'player_hunt_sessions',
            'player_hunt_build_choices',
            'player_account_bindings'
          )
          and not c.relrowsecurity
      ),
      'All player-private tables have RLS enabled.'
    )
  ) as t(check_key,ready,note)
),
summary as (
  select
    count(*)::int as checks,
    count(*) filter (where ready)::int as ready,
    count(*) filter (where not ready)::int as blocked
  from checks
)
select jsonb_build_object(
  'summary',jsonb_build_object(
    'checks',(select checks from summary),
    'ready',(select ready from summary),
    'blocked',(select blocked from summary),
    'backend_pilot_ready',(select blocked=0 from summary),
    'planner_eligible_hunts',(select (j #>> '{summary,planner_eligible_entries}')::int from hunts),
    'planner_core_complete_hunts',(select (j #>> '{summary,source_core_complete}')::int from hunts),
    'powerful_imbuements',(select count(*) from public.imbuement_definitions),
    'proficiency_trees',(select count(*) from public.weapon_proficiency_trees)
  ),
  'checks',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'key',check_key,
        'ready',ready,
        'note',note
      )
      order by check_key
    )
    from checks
  ),'[]'::jsonb),
  'known_nonblocking_limits',jsonb_build_array(
    jsonb_build_object(
      'key','cross_type_imbuement_priority',
      'status','intentional_contextual',
      'note','Offense, sustain and skill Imbuements are not collapsed into a fabricated scalar priority.'
    ),
    jsonb_build_object(
      'key','final_combat_formula',
      'status','evidence_required',
      'note','HuntNexus does not invent final DPS/healing/mitigation formulas without validated RubinOT mechanics.'
    ),
    jsonb_build_object(
      'key','magic_link_redirect',
      'status','manual_environment_validation_required',
      'note','Supabase Auth redirect allow-list and real email delivery must be validated against the deployed frontend.'
    )
  ),
  'methodology',jsonb_build_object(
    'stage','product_readiness_audit_v2',
    'backend_contracts_only',true,
    'planner_readiness_scoped_to_eligible_entries',true,
    'frontend_visual_validation_included',false,
    'real_class_playtest_included',false,
    'external_pilot_included',false,
    'opaque_score_used',false
  )
);
$function$;
