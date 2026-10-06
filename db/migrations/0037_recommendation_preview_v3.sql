-- HuntNexus Analytics — Phase 15.1 recommendation preview v3.
-- Adds spell candidates to hunt recommendations.

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
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
begin
  v_rank := huntnexus_rank_observed_hunts(
    p_vocation,p_level,p_objective,p_party_size,p_limit
  );

  for v_row in
    select value
    from jsonb_array_elements(coalesce(v_rank->'results','[]'::jsonb))
  loop
    v_hunt_key := v_row->>'hunt_key';

    v_result := v_result || jsonb_build_array(
      jsonb_build_object(
        'ranking',v_row,
        'factual_profile',huntnexus_hunt_factual_profile(v_hunt_key),
        'observed_profile',huntnexus_hunt_observed_profile(v_hunt_key),
        'defensive_candidates',
          huntnexus_defensive_item_candidates(
            v_hunt_key,p_vocation,p_level,p_defensive_items_per_slot
          ),
        'offensive_stat_candidates',
          huntnexus_offensive_stat_candidates(v_hunt_key,p_vocation,p_level,20),
        'ek_weapon_candidates',
          case when v_vocation='EK'
            then huntnexus_ek_weapon_candidates(v_hunt_key,p_level,5)
            else null
          end,
        'imbuement_candidates',
          huntnexus_imbuement_candidates(v_hunt_key,p_vocation),
        'spell_candidates',
          huntnexus_spell_candidates(v_hunt_key,p_vocation,p_level,'hunt')
      )
    );
  end loop;

  return jsonb_build_object(
    'query',v_rank->'query',
    'results',v_result,
    'methodology',jsonb_build_object(
      'stage','recommendation_preview_v3',
      'final_recommendation',false,
      'spell_layer_applied',true,
      'boss_mechanics_applied',false,
      'rubinot_overlay_applied_to_output',false,
      'final_build_optimizer_applied',false,
      'note','Preview combines factual, observed, defensive, offensive, imbuement and spell evidence. Final rotations/builds still require boss/mechanic context and exact RubinOT reconciliation.'
    )
  );
end;
$$;

revoke all on function huntnexus_recommendation_preview(text,int,text,int,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_recommendation_preview(text,int,text,int,int,int)
  to service_role;
