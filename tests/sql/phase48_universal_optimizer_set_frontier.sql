-- Focused regression for conservative Pareto frontier across validated concrete sets.
-- Each scenario is a separate statement so database statement_timeout does not aggregate five optimizer runs.

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_frontier_universal(
    'cobra-bastion','EK',700,3,2,100,100,'{}'::jsonb,'{}'::jsonb
  );
  if (v #>> '{summary,valid_sets_considered}')::int <> 100
     or (v #>> '{summary,frontier_sets}')::int <> 64
     or (v #>> '{summary,dominated_sets}')::int <> 36 then
    raise exception 'EK set frontier regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_frontier_universal(
    'iksupan-last-stand','RP',700,3,2,100,100,
    '{"grand-sanguine-crossbow":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":130,"effective_magic_level":35}'::jsonb
  );
  if (v #>> '{summary,valid_sets_considered}')::int <> 100
     or (v #>> '{summary,frontier_sets}')::int <> 32
     or (v #>> '{summary,dominated_sets}')::int <> 68 then
    raise exception 'RP set frontier regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_frontier_universal(
    'nimmersatts-breeding-ground','ED',700,3,2,100,100,
    '{"amber-rod":[1,2,3]}'::jsonb,
    '{"effective_magic_level":130}'::jsonb
  );
  if (v #>> '{summary,valid_sets_considered}')::int <> 100
     or (v #>> '{summary,frontier_sets}')::int <> 100
     or (v #>> '{summary,dominated_sets}')::int <> 0 then
    raise exception 'ED conservative no-forced-pruning regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_frontier_universal(
    'podzilla','MS',700,3,2,100,100,
    '{"amber-wand":[1,2,3]}'::jsonb,
    '{"effective_magic_level":130}'::jsonb
  );
  if (v #>> '{summary,valid_sets_considered}')::int <> 100
     or (v #>> '{summary,frontier_sets}')::int <> 16
     or (v #>> '{summary,dominated_sets}')::int <> 84 then
    raise exception 'MS set frontier regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_frontier_universal(
    'grounds-of-undeath','EM',700,3,2,100,100,
    '{"grand-sanguine-claws":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":120,"effective_magic_level":20}'::jsonb
  );
  if (v #>> '{summary,valid_sets_considered}')::int <> 100
     or (v #>> '{summary,frontier_sets}')::int <> 48
     or (v #>> '{summary,dominated_sets}')::int <> 52 then
    raise exception 'EM set frontier regression';
  end if;

  if coalesce((v #>> '{methodology,cross_metric_sum_applied}')::boolean,true) is not false
     or coalesce((v #>> '{methodology,ranking_score_applied}')::boolean,true) is not false
     or coalesce((v #>> '{methodology,protection_stacking_formula_applied}')::boolean,true) is not false
     or coalesce((v #>> '{methodology,winner_selected}')::boolean,true) is not false then
    raise exception 'Set frontier methodology regression';
  end if;

  if exists (
    select 1 from jsonb_array_elements(v->'frontier') x
    where x #>> '{validation,status}' <> 'valid'
  ) then
    raise exception 'Set frontier contains non-valid set';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_frontier_universal(
    'nimmersatts-breeding-ground','ED',700,3,1,100,100,
    '{"amber-rod":[2]}'::jsonb,'{}'::jsonb
  );
  if (v #>> '{summary,valid_sets_considered}')::int <> 21
     or (v #>> '{summary,comparison_ready_sets}')::int <> 14
     or (v #>> '{summary,incomparable_unready_sets}')::int <> 7
     or (v #>> '{summary,dominated_sets}')::int <> 0 then
    raise exception 'Unresolved proficiency incomparability regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_audit();

  if v #>> '{methodology,stage}' <> 'optimizer_audit_v5'
     or coalesce((v #>> '{summary,set_vector_ready}')::boolean,false) is not true
     or coalesce((v #>> '{summary,set_frontier_ready}')::boolean,false) is not true
     or coalesce((v #>> '{summary,set_selection_ready}')::boolean,true) is not false
     or coalesce((v #>> '{summary,final_optimizer_ready}')::boolean,true) is not false then
    raise exception 'Optimizer audit v5 regression';
  end if;

  if has_function_privilege(
       'anon',
       'public.huntnexus_optimizer_set_vector_universal(jsonb,text,text,jsonb,jsonb)',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.huntnexus_optimizer_set_frontier_universal(text,text,integer,integer,integer,integer,integer,jsonb,jsonb)',
       'EXECUTE'
     ) then
    raise exception 'Set frontier optimizer functions must remain server-only';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_optimizer_set_frontier',
  'audit_stage',huntnexus_optimizer_audit() #>> '{methodology,stage}',
  'set_frontier_ready',(huntnexus_optimizer_audit() #>> '{summary,set_frontier_ready}')::boolean,
  'set_selection_ready',(huntnexus_optimizer_audit() #>> '{summary,set_selection_ready}')::boolean
) as regression_summary;
