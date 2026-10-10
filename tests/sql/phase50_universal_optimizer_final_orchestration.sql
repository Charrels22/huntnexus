-- Phase 50 — final universal optimizer orchestration regression.
-- Validates hunt/set objective separation, end-to-end orchestration, co-winners, and server-only exposure.

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_final_universal(
    'EK',700,'balanced','offense',1,1,3,2,80,80,20,
    '[]'::jsonb,'{}'::jsonb,'{}'::jsonb
  );
  if v #>> '{methodology,stage}' <> 'optimizer_final_universal_v1'
     or v #>> '{results,0,hunt,hunt_key}' <> 'cobra-bastion'
     or (v #>> '{results,0,set_selection,summary,co_winners}')::int <> 4
     or coalesce((v #>> '{methodology,final_optimizer_applied}')::boolean,false) is not true
     or coalesce((v #>> '{methodology,hunt_objective_and_set_objective_separate}')::boolean,false) is not true
     or coalesce((v #>> '{methodology,hunt_score_not_reused_as_set_score}')::boolean,false) is not true
     or coalesce((v #>> '{methodology,single_winner_forced}')::boolean,true) is not false then
    raise exception 'EK final optimizer regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_final_universal(
    'RP',700,'balanced','offense',1,1,3,2,80,80,20,
    '[]'::jsonb,
    '{"grand-sanguine-crossbow":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":130,"effective_magic_level":35}'::jsonb
  );
  if v #>> '{results,0,hunt,hunt_key}' <> 'iksupan-last-stand'
     or (v #>> '{results,0,set_selection,summary,co_winners}')::int <> 4 then
    raise exception 'RP final optimizer regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_final_universal(
    'ED',700,'balanced','offense',1,1,3,2,80,80,20,
    '[]'::jsonb,
    '{"amber-rod":[1,2,3]}'::jsonb,
    '{"effective_magic_level":130}'::jsonb
  );
  if v #>> '{results,0,hunt,hunt_key}' <> 'nimmersatts-breeding-ground'
     or (v #>> '{results,0,set_selection,summary,co_winners}')::int <> 8 then
    raise exception 'ED final optimizer regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_final_universal(
    'MS',700,'balanced','offense',1,1,3,2,80,80,20,
    '[]'::jsonb,
    '{"amber-wand":[1,2,3]}'::jsonb,
    '{"effective_magic_level":130}'::jsonb
  );
  if v #>> '{results,0,hunt,hunt_key}' <> 'podzilla'
     or (v #>> '{results,0,set_selection,summary,co_winners}')::int <> 4 then
    raise exception 'MS final optimizer regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_final_universal(
    'EM',700,'balanced','offense',1,1,3,2,100,100,20,
    '[]'::jsonb,
    '{"grand-sanguine-claws":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":120,"effective_magic_level":20}'::jsonb
  );
  if v #>> '{results,0,hunt,hunt_key}' <> 'grounds-of-undeath'
     or (v #>> '{results,0,set_selection,summary,co_winners}')::int <> 4
     or (v #>> '{summary,ranked_hunts}')::int <> 1
     or (v #>> '{summary,hunts_with_set_selection}')::int <> 1
     or (v #>> '{summary,total_returned_sets}')::int <> 4 then
    raise exception 'EM final optimizer regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_final_universal(
    'EM',700,'xp','defense',1,1,3,2,50,50,10,
    '[]'::jsonb,
    '{"grand-sanguine-claws":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":120,"effective_magic_level":20}'::jsonb
  );
  if v #>> '{query,hunt_objective}' <> 'xp'
     or v #>> '{query,set_objective}' <> 'defense'
     or coalesce((v #>> '{methodology,xp_profit_not_inferred_from_loadout}')::boolean,false) is not true then
    raise exception 'Objective separation regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_final_universal(
    'UNKNOWN',700,'balanced','balanced',1,1,3,1,20,20,5,
    '[]'::jsonb,'{}'::jsonb,'{}'::jsonb
  );
  if v->>'error' <> 'unsupported_vocation' then
    raise exception 'Unsupported vocation regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_audit();
  if v #>> '{methodology,stage}' <> 'optimizer_audit_v7'
     or coalesce((v #>> '{summary,set_selection_ready}')::boolean,false) is not true
     or coalesce((v #>> '{summary,final_optimizer_ready}')::boolean,false) is not true then
    raise exception 'Optimizer audit v7 regression';
  end if;

  if has_function_privilege(
       'anon',
       'public.huntnexus_optimizer_final_universal(text,integer,text,text,integer,integer,integer,integer,integer,integer,integer,jsonb,jsonb,jsonb)',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.huntnexus_optimizer_final_universal(text,integer,text,text,integer,integer,integer,integer,integer,integer,integer,jsonb,jsonb,jsonb)',
       'EXECUTE'
     ) then
    raise exception 'Final optimizer function must remain server-only';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_optimizer_final_orchestration',
  'audit_stage',huntnexus_optimizer_audit() #>> '{methodology,stage}',
  'set_selection_ready',(huntnexus_optimizer_audit() #>> '{summary,set_selection_ready}')::boolean,
  'final_optimizer_ready',(huntnexus_optimizer_audit() #>> '{summary,final_optimizer_ready}')::boolean
) as regression_summary;
