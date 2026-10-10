-- Focused regression for objective-aware set selection.
-- Hunt objective and set objective remain separate; no weighted score is introduced.

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_selection_universal(
    'cobra-bastion','EK',700,'offense',3,2,100,100,100,'{}'::jsonb,'{}'::jsonb
  );
  if (v #>> '{summary,frontier_sets_considered}')::int <> 64
     or (v #>> '{summary,co_winners}')::int <> 5
     or (v #>> '{summary,objective_dominated_sets}')::int <> 59 then
    raise exception 'EK offense selection regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_selection_universal(
    'iksupan-last-stand','RP',700,'offense',3,2,100,100,100,
    '{"grand-sanguine-crossbow":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":130,"effective_magic_level":35}'::jsonb
  );
  if (v #>> '{summary,frontier_sets_considered}')::int <> 32
     or (v #>> '{summary,co_winners}')::int <> 4
     or (v #>> '{summary,objective_dominated_sets}')::int <> 28 then
    raise exception 'RP offense selection regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_selection_universal(
    'nimmersatts-breeding-ground','ED',700,'offense',3,2,100,100,100,
    '{"amber-rod":[1,2,3]}'::jsonb,
    '{"effective_magic_level":130}'::jsonb
  );
  if (v #>> '{summary,frontier_sets_considered}')::int <> 100
     or (v #>> '{summary,co_winners}')::int <> 8
     or (v #>> '{summary,objective_dominated_sets}')::int <> 92 then
    raise exception 'ED offense selection regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_selection_universal(
    'podzilla','MS',700,'offense',3,2,100,100,100,
    '{"amber-wand":[1,2,3]}'::jsonb,
    '{"effective_magic_level":130}'::jsonb
  );
  if (v #>> '{summary,frontier_sets_considered}')::int <> 16
     or (v #>> '{summary,co_winners}')::int <> 4
     or (v #>> '{summary,objective_dominated_sets}')::int <> 12 then
    raise exception 'MS offense selection regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_selection_universal(
    'grounds-of-undeath','EM',700,'offense',3,2,100,100,100,
    '{"grand-sanguine-claws":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":120,"effective_magic_level":20}'::jsonb
  );
  if (v #>> '{summary,frontier_sets_considered}')::int <> 48
     or (v #>> '{summary,co_winners}')::int <> 4
     or (v #>> '{summary,objective_dominated_sets}')::int <> 44 then
    raise exception 'EM offense selection regression';
  end if;

  if coalesce((v #>> '{methodology,objective_dimensions_not_summed}')::boolean,false) is not true
     or coalesce((v #>> '{methodology,objective_dimensions_not_weighted}')::boolean,false) is not true
     or coalesce((v #>> '{methodology,xp_profit_not_inferred_from_loadout}')::boolean,false) is not true
     or coalesce((v #>> '{methodology,single_winner_forced}')::boolean,true) is not false then
    raise exception 'Set selection methodology regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_set_selection_universal(
    'grounds-of-undeath','EM',700,'balanced',3,2,100,100,100,
    '{"grand-sanguine-claws":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":120,"effective_magic_level":20}'::jsonb
  );
  if (v #>> '{summary,frontier_sets_considered}')::int <> 48
     or (v #>> '{summary,co_winners}')::int <> 48
     or (v #>> '{summary,objective_dominated_sets}')::int <> 0 then
    raise exception 'Balanced preservation regression';
  end if;
end $$;

do $$
declare v jsonb;
begin
  v := huntnexus_optimizer_audit();
  if v #>> '{methodology,stage}' <> 'optimizer_audit_v6'
     or coalesce((v #>> '{summary,set_selection_ready}')::boolean,false) is not true
     or coalesce((v #>> '{summary,final_optimizer_ready}')::boolean,true) is not false then
    raise exception 'Optimizer audit v6 regression';
  end if;

  if has_function_privilege(
       'anon',
       'public.huntnexus_optimizer_set_selection_universal(text,text,integer,text,integer,integer,integer,integer,integer,jsonb,jsonb)',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.huntnexus_optimizer_set_selection_universal(text,text,integer,text,integer,integer,integer,integer,integer,jsonb,jsonb)',
       'EXECUTE'
     ) then
    raise exception 'Set selection function must remain server-only';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_optimizer_set_selection',
  'audit_stage',huntnexus_optimizer_audit() #>> '{methodology,stage}',
  'set_selection_ready',(huntnexus_optimizer_audit() #>> '{summary,set_selection_ready}')::boolean,
  'final_optimizer_ready',(huntnexus_optimizer_audit() #>> '{summary,final_optimizer_ready}')::boolean
) as regression_summary;
