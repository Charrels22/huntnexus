-- Phase 70 — cross-vocation technical pilot matrix.
-- Backend regression only; final human playtest is a separate release gate.

do $$
declare
  v_vocations text[] := array['EK','RP','ED','MS','EM'];
  v_families text[] := array['sword','bow','rod','wand','fist'];
  v_idx integer;
  v_vocation text;
  v_family text;
  v_rank jsonb;
  v_envelope jsonb;
  v_prof jsonb;
begin
  for v_idx in 1..array_length(v_vocations,1) loop
    v_vocation := v_vocations[v_idx];
    v_family := v_families[v_idx];

    v_rank := public.huntnexus_rank_observed_hunts(
      v_vocation,700,'balanced',1,1
    );

    if jsonb_array_length(coalesce(v_rank->'results','[]'::jsonb)) <> 1
       or nullif(v_rank #>> '{results,0,hunt_key}','') is null then
      raise exception 'Observed hunt ranking missing for vocation %',v_vocation;
    end if;

    v_envelope := public.huntnexus_optimizer_candidate_envelope_universal(
      v_vocation,700,'balanced',1,1,2,'[]'::jsonb
    );

    if v_envelope #>> '{methodology,stage}' <> 'optimizer_candidate_envelope_universal_v1'
       or jsonb_array_length(coalesce(v_envelope->'results','[]'::jsonb)) <> 1
       or coalesce((v_envelope #>> '{results,0,decision_state,candidate_pool_built}')::boolean,false) is not true
       or coalesce((v_envelope #>> '{results,0,spell_candidates,summary,eligible}')::int,0) < 1 then
      raise exception 'Candidate envelope regression for vocation %',v_vocation;
    end if;

    v_prof := public.huntnexus_player_profile_proficiency_catalog(
      v_vocation,700,v_family
    );

    if coalesce((v_prof #>> '{summary,eligible_tree_count}')::int,0) < 1 then
      raise exception 'Proficiency family % missing for vocation %',v_family,v_vocation;
    end if;
  end loop;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','cross_vocation_technical_pilot_matrix',
  'vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
  'level',700,
  'human_playtest_complete',false
) as regression_summary;
