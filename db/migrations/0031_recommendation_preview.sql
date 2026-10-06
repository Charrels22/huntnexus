-- HuntNexus Analytics — Phase 12.1 recommendation evidence composition.
-- Composes validated evidence layers without collapsing them into a premature final score.

create or replace function huntnexus_recommendation_preview(
  p_vocation text,
  p_level int,
  p_objective text default 'balanced',
  p_party_size int default 1,
  p_limit int default 5,
  p_defensive_items_per_slot int default 3
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_rank jsonb;
  v_result jsonb := '[]'::jsonb;
  v_row jsonb;
  v_hunt_key text;
  v_defensive jsonb;
  v_observed jsonb;
  v_factual jsonb;
begin
  v_rank := huntnexus_rank_observed_hunts(
    p_vocation,p_level,p_objective,p_party_size,p_limit
  );

  for v_row in
    select value
    from jsonb_array_elements(coalesce(v_rank->'results','[]'::jsonb))
  loop
    v_hunt_key := v_row->>'hunt_key';

    v_observed := huntnexus_hunt_observed_profile(v_hunt_key);
    v_factual := huntnexus_hunt_factual_profile(v_hunt_key);
    v_defensive := huntnexus_defensive_item_candidates(
      v_hunt_key,p_vocation,p_level,p_defensive_items_per_slot
    );

    v_result := v_result || jsonb_build_array(
      jsonb_build_object(
        'ranking',v_row,
        'factual_profile',v_factual,
        'observed_profile',v_observed,
        'defensive_candidates',v_defensive
      )
    );
  end loop;

  return jsonb_build_object(
    'query',v_rank->'query',
    'results',v_result,
    'methodology',jsonb_build_object(
      'stage','recommendation_preview',
      'final_recommendation',false,
      'ranking_layer','community_observations',
      'factual_layer','tibia_factual',
      'defensive_layer','community_observations + tibia_factual',
      'rubinot_overlay_applied_to_output',false,
      'boss_mechanics_applied',false,
      'spell_rotation_applied',false,
      'offensive_item_optimizer_applied',false,
      'note','Composition endpoint for HuntNexus development. Keeps evidence layers separate so the UI/API can show why a hunt or item appears.'
    )
  );
end;
$$;

revoke all on function huntnexus_recommendation_preview(text,int,text,int,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_recommendation_preview(text,int,text,int,int,int)
  to service_role;
