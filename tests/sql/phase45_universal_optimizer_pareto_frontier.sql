-- Focused regression for universal optimizer Pareto/frontier.

do $$
declare
  v_vec jsonb;
  v_ek_sword jsonb;
  v_rp_bow jsonb;
  v_ed_rod jsonb;
  v_ms_wand jsonb;
  v_em_fist jsonb;
  v_ek_body jsonb;
  v_env jsonb;
  v_audit jsonb;
begin
  v_vec := huntnexus_optimizer_item_vector_universal(
    'grand-sanguine-claws','grounds-of-undeath','EM'
  );

  if v_vec #>> '{methodology,stage}' <> 'optimizer_item_vector_universal_v1'
     or (v_vec #>> '{dimensions,attack/physical}')::numeric <> 45
     or (v_vec #>> '{dimensions,core/imbue_slots}')::numeric <> 3
     or (v_vec #>> '{dimensions,effect/skill/fist_fighting}')::numeric <> 4
     or (v_vec #>> '{dimensions,effect/skill/magic_level}')::numeric <> 2
     or coalesce((v_vec #>> '{methodology,cross_metric_sum_applied}')::boolean,true) is not false
     or coalesce((v_vec #>> '{methodology,unknown_core_value_imputed}')::boolean,true) is not false then
    raise exception 'Universal optimizer item vector regression';
  end if;

  v_ek_sword := huntnexus_optimizer_pareto_frontier_universal(
    'cobra-bastion','EK',700,'weapon','sword',100
  );
  v_rp_bow := huntnexus_optimizer_pareto_frontier_universal(
    'iksupan-last-stand','RP',700,'weapon','bow',100
  );
  v_ed_rod := huntnexus_optimizer_pareto_frontier_universal(
    'nimmersatts-breeding-ground','ED',700,'weapon','rod',100
  );
  v_ms_wand := huntnexus_optimizer_pareto_frontier_universal(
    'podzilla','MS',700,'weapon','wand',100
  );
  v_em_fist := huntnexus_optimizer_pareto_frontier_universal(
    'grounds-of-undeath','EM',700,'weapon','fist',100
  );
  v_ek_body := huntnexus_optimizer_pareto_frontier_universal(
    'cobra-bastion','EK',700,'equipment','body',100
  );

  if (v_ek_sword #>> '{summary,eligible_candidates}')::int <> 185
     or (v_ek_sword #>> '{summary,frontier_candidates}')::int <> 47
     or (v_ek_sword #>> '{summary,dominated_candidates}')::int <> 138 then
    raise exception 'EK Sword Pareto summary regression';
  end if;

  if (v_rp_bow #>> '{summary,eligible_candidates}')::int <> 57
     or (v_rp_bow #>> '{summary,frontier_candidates}')::int <> 12
     or (v_rp_bow #>> '{summary,dominated_candidates}')::int <> 45 then
    raise exception 'RP Bow Pareto summary regression';
  end if;

  if (v_ed_rod #>> '{summary,eligible_candidates}')::int <> 54
     or (v_ed_rod #>> '{summary,frontier_candidates}')::int <> 10
     or (v_ed_rod #>> '{summary,dominated_candidates}')::int <> 44 then
    raise exception 'ED Rod Pareto summary regression';
  end if;

  if (v_ms_wand #>> '{summary,eligible_candidates}')::int <> 72
     or (v_ms_wand #>> '{summary,frontier_candidates}')::int <> 9
     or (v_ms_wand #>> '{summary,dominated_candidates}')::int <> 63 then
    raise exception 'MS Wand Pareto summary regression';
  end if;

  if (v_em_fist #>> '{summary,eligible_candidates}')::int <> 34
     or (v_em_fist #>> '{summary,frontier_candidates}')::int <> 5
     or (v_em_fist #>> '{summary,dominated_candidates}')::int <> 29
     or not exists (
       select 1
       from jsonb_array_elements(v_em_fist->'frontier') x
       where x->>'item_key'='grand-sanguine-claws'
         and (x->>'dominates_count')::int=29
     ) then
    raise exception 'EM Fist Pareto frontier regression';
  end if;

  if (v_ek_body #>> '{summary,eligible_candidates}')::int <> 84
     or (v_ek_body #>> '{summary,frontier_candidates}')::int <> 13
     or (v_ek_body #>> '{summary,dominated_candidates}')::int <> 71
     or not exists (
       select 1
       from jsonb_array_elements(v_ek_body->'frontier') x
       where x->>'item_key'='spiritthorn-armor'
     ) then
    raise exception 'EK Body Pareto frontier regression';
  end if;

  if coalesce((v_em_fist #>> '{methodology,pareto_only}')::boolean,false) is not true
     or coalesce((v_em_fist #>> '{methodology,cross_metric_sum_applied}')::boolean,true) is not false
     or coalesce((v_em_fist #>> '{methodology,ranking_score_applied}')::boolean,true) is not false
     or coalesce((v_em_fist #>> '{methodology,missing_dimension_makes_pair_incomparable}')::boolean,false) is not true
     or coalesce((v_em_fist #>> '{methodology,equal_dimension_keyset_required_for_dominance}')::boolean,false) is not true then
    raise exception 'Pareto methodology regression';
  end if;

  if huntnexus_optimizer_pareto_frontier_universal(
       'cobra-bastion','UNKNOWN',700,'weapon','sword',20
     )->>'error' <> 'unsupported_vocation' then
    raise exception 'Pareto unsupported vocation regression';
  end if;

  if huntnexus_optimizer_pareto_frontier_universal(
       'cobra-bastion','EK',700,'invalid','sword',20
     )->>'error' <> 'unsupported_item_domain' then
    raise exception 'Pareto unsupported domain regression';
  end if;

  v_env := huntnexus_optimizer_frontier_envelope_universal(
    'EM',700,'balanced',1,1,5,'[]'::jsonb
  );

  if v_env #>> '{methodology,stage}' <> 'optimizer_frontier_envelope_universal_v1'
     or v_env #>> '{results,0,hunt,hunt_key}' <> 'grounds-of-undeath'
     or jsonb_array_length(v_env #> '{results,0,weapon_frontiers}') <> 1
     or (select count(*) from jsonb_object_keys(v_env #> '{results,0,equipment_frontiers}')) <> 7
     or coalesce((v_env #>> '{results,0,decision_state,pareto_frontier_applied}')::boolean,false) is not true
     or coalesce((v_env #>> '{results,0,decision_state,concrete_sets_generated}')::boolean,true) is not false
     or coalesce((v_env #>> '{results,0,decision_state,set_selected}')::boolean,true) is not false
     or coalesce((v_env #>> '{methodology,cross_metric_sum_applied}')::boolean,true) is not false then
    raise exception 'Optimizer frontier envelope regression';
  end if;

  v_audit := huntnexus_optimizer_audit();

  if v_audit #>> '{methodology,stage}' <> 'optimizer_audit_v2'
     or coalesce((v_audit #>> '{summary,item_vector_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,pareto_frontier_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,frontier_envelope_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,concrete_set_generation_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,set_validation_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,set_selection_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_optimizer_ready}')::boolean,true) is not false then
    raise exception 'Optimizer audit v2 semantics regression';
  end if;

  if has_function_privilege(
       'anon',
       'public.huntnexus_optimizer_item_vector_universal(text,text,text)',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.huntnexus_optimizer_pareto_frontier_universal(text,text,integer,text,text,integer)',
       'EXECUTE'
     )
     or has_function_privilege(
       'anon',
       'public.huntnexus_optimizer_frontier_envelope_universal(text,integer,text,integer,integer,integer,jsonb)',
       'EXECUTE'
     ) then
    raise exception 'Optimizer frontier functions must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_optimizer_pareto_frontier',
  'ek_sword_frontier',(huntnexus_optimizer_pareto_frontier_universal(
    'cobra-bastion','EK',700,'weapon','sword',100
  ) #>> '{summary,frontier_candidates}')::int,
  'rp_bow_frontier',(huntnexus_optimizer_pareto_frontier_universal(
    'iksupan-last-stand','RP',700,'weapon','bow',100
  ) #>> '{summary,frontier_candidates}')::int,
  'ed_rod_frontier',(huntnexus_optimizer_pareto_frontier_universal(
    'nimmersatts-breeding-ground','ED',700,'weapon','rod',100
  ) #>> '{summary,frontier_candidates}')::int,
  'ms_wand_frontier',(huntnexus_optimizer_pareto_frontier_universal(
    'podzilla','MS',700,'weapon','wand',100
  ) #>> '{summary,frontier_candidates}')::int,
  'em_fist_frontier',(huntnexus_optimizer_pareto_frontier_universal(
    'grounds-of-undeath','EM',700,'weapon','fist',100
  ) #>> '{summary,frontier_candidates}')::int,
  'pareto_frontier_ready',(huntnexus_optimizer_audit() #>> '{summary,pareto_frontier_ready}')::boolean,
  'set_selection_ready',(huntnexus_optimizer_audit() #>> '{summary,set_selection_ready}')::boolean
) as regression_summary;
