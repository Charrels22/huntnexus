-- HuntNexus FE-12 — personalized final planner envelope.
-- Hunt ranking remains universal/observed. Ownership only enriches each hunt result.

create or replace function public.huntnexus_optimizer_final_personalized(
  p_client_id uuid,
  p_vocation text,
  p_level integer,
  p_hunt_objective text default 'balanced',
  p_set_objective text default 'balanced',
  p_party_size integer default 1,
  p_hunt_limit integer default 3,
  p_hand_per_source integer default 3,
  p_per_body_slot integer default 2,
  p_set_limit integer default 100,
  p_frontier_limit integer default 100,
  p_selection_limit integer default 20,
  p_unlocked_requirement_keys jsonb default '[]'::jsonb,
  p_proficiency_selections jsonb default '{}'::jsonb,
  p_character_profile jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_base jsonb;
  v_results jsonb := '[]'::jsonb;
  v_row jsonb;
  v_hunt_key text;
  v_owned jsonb;
  v_choice jsonb;
  v_owned_hunts integer := 0;
  v_saved_choices integer := 0;
begin
  v_base := huntnexus_optimizer_final_universal(
    p_vocation,
    p_level,
    p_hunt_objective,
    p_set_objective,
    p_party_size,
    p_hunt_limit,
    p_hand_per_source,
    p_per_body_slot,
    p_set_limit,
    p_frontier_limit,
    p_selection_limit,
    p_unlocked_requirement_keys,
    p_proficiency_selections,
    p_character_profile
  );

  for v_row in
    select value
    from jsonb_array_elements(coalesce(v_base->'results','[]'::jsonb))
  loop
    v_hunt_key := v_row #>> '{hunt,hunt_key}';

    if p_client_id is not null and v_hunt_key is not null then
      v_owned := huntnexus_player_owned_build_options_v2(
        p_client_id,
        v_hunt_key,
        p_vocation,
        p_level,
        p_proficiency_selections,
        p_character_profile,
        3
      );

      v_choice := huntnexus_player_hunt_build_choice_get(
        p_client_id,
        v_hunt_key,
        p_vocation
      );

      if coalesce((v_owned #>> '{summary,main_items}')::int,0) > 0 then
        v_owned_hunts := v_owned_hunts + 1;
      end if;

      if coalesce((v_choice->>'exists')::boolean,false) then
        v_saved_choices := v_saved_choices + 1;
      end if;

      v_row := v_row || jsonb_build_object(
        'owned_builds',v_owned,
        'saved_owned_choice',v_choice
      );
    else
      v_row := v_row || jsonb_build_object(
        'owned_builds',null,
        'saved_owned_choice',jsonb_build_object('exists',false,'choice',null)
      );
    end if;

    v_results := v_results || jsonb_build_array(v_row);
  end loop;

  return
    v_base
    || jsonb_build_object(
      'results',v_results,
      'personalization_summary',jsonb_build_object(
        'client_scope_available',p_client_id is not null,
        'ranked_hunts',jsonb_array_length(v_results),
        'hunts_with_registered_main_set',v_owned_hunts,
        'hunts_with_saved_build_choice',v_saved_choices
      ),
      'methodology',
        coalesce(v_base->'methodology','{}'::jsonb)
        || jsonb_build_object(
          'stage','optimizer_final_personalized_v1',
          'hunt_ranking_reordered_by_inventory',false,
          'ownership_affects_hunt_rank',false,
          'owned_builds_enrich_results_only',true,
          'external_items_used_in_owned_options',false,
          'main_set_is_baseline',true
        )
    );
end;
$function$;

revoke all on function public.huntnexus_optimizer_final_personalized(
  uuid,text,integer,text,text,integer,integer,integer,integer,integer,integer,integer,jsonb,jsonb,jsonb
) from public,anon,authenticated;

grant execute on function public.huntnexus_optimizer_final_personalized(
  uuid,text,integer,text,text,integer,integer,integer,integer,integer,integer,integer,jsonb,jsonb,jsonb
) to service_role;
