-- Focused regression for item-key-bound Weapon Proficiency context on concrete sets.

do $$
declare
  v_ed jsonb;
  v_ms jsonb;
  v_rp jsonb;
  v_em jsonb;
  v_empty jsonb;
  v_bad jsonb;
  v_audit jsonb;
begin
  v_ed := huntnexus_optimizer_concrete_sets_with_proficiency_universal(
    'nimmersatts-breeding-ground','ED',700,3,1,100,
    '{"amber-rod":[1,2,3]}'::jsonb,
    '{"effective_magic_level":130}'::jsonb
  );
  v_ms := huntnexus_optimizer_concrete_sets_with_proficiency_universal(
    'podzilla','MS',700,3,1,100,
    '{"amber-wand":[1,2,3]}'::jsonb,
    '{"effective_magic_level":130}'::jsonb
  );
  v_rp := huntnexus_optimizer_concrete_sets_with_proficiency_universal(
    'iksupan-last-stand','RP',700,3,1,100,
    '{"grand-sanguine-crossbow":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":130,"effective_magic_level":35}'::jsonb
  );
  v_em := huntnexus_optimizer_concrete_sets_with_proficiency_universal(
    'grounds-of-undeath','EM',700,3,1,100,
    '{"grand-sanguine-claws":[1,2,3]}'::jsonb,
    '{"effective_weapon_skill":120,"effective_magic_level":20}'::jsonb
  );

  if (v_ed #>> '{proficiency_summary,sets_with_active_perks}')::int <> 7
     or (v_ms #>> '{proficiency_summary,sets_with_active_perks}')::int <> 7
     or (v_rp #>> '{proficiency_summary,sets_with_active_perks}')::int <> 3
     or (v_em #>> '{proficiency_summary,sets_with_active_perks}')::int <> 1 then
    raise exception 'Universal proficiency activation count regression';
  end if;

  if (v_ed #>> '{proficiency_summary,sets_with_unresolved_inputs}')::int <> 0
     or (v_ms #>> '{proficiency_summary,sets_with_unresolved_inputs}')::int <> 0
     or (v_rp #>> '{proficiency_summary,sets_with_unresolved_inputs}')::int <> 0
     or (v_em #>> '{proficiency_summary,sets_with_unresolved_inputs}')::int <> 0 then
    raise exception 'Proficiency inputs unexpectedly unresolved';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_em->'sets') x
    where x->'selection'->>'weapon' <> 'grand-sanguine-claws'
      and x #>> '{weapon_proficiency,selection_source}' <> 'none'
  ) then
    raise exception 'Proficiency selection leaked to another weapon';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_em->'sets') x
    where x->'selection'->>'weapon'='grand-sanguine-claws'
      and x #>> '{weapon_proficiency,selection_source}'='item_key'
      and (x #>> '{weapon_proficiency,impact,active_perk_count}')::int=3
  ) then
    raise exception 'Grand Sanguine Claws explicit selection not applied';
  end if;

  v_empty := huntnexus_optimizer_concrete_sets_with_proficiency_universal(
    'grounds-of-undeath','EM',700,3,1,100,'[]'::jsonb,'{}'::jsonb
  );

  if (v_empty #>> '{proficiency_summary,sets_with_explicit_selection}')::int <> 0
     or (v_empty #>> '{proficiency_summary,sets_with_active_perks}')::int <> 0 then
    raise exception 'Non-object proficiency input must not activate selections';
  end if;

  if coalesce((v_em #>> '{methodology,proficiency_selection_inheritance_applied}')::boolean,true) is not false
     or coalesce((v_em #>> '{methodology,proficiency_changes_set_order}')::boolean,true) is not false
     or coalesce((v_em #>> '{methodology,set_ranking_applied}')::boolean,true) is not false
     or coalesce((v_em #>> '{methodology,winner_selected}')::boolean,true) is not false then
    raise exception 'Proficiency methodology regression';
  end if;

  v_bad := huntnexus_optimizer_concrete_sets_with_proficiency_universal(
    'cobra-bastion','UNKNOWN',700,2,1,20,'{}'::jsonb,'{}'::jsonb
  );

  if v_bad->>'error' <> 'unsupported_vocation' then
    raise exception 'Unsupported vocation passthrough regression';
  end if;

  v_audit := huntnexus_optimizer_audit();

  if v_audit #>> '{methodology,stage}' <> 'optimizer_audit_v4'
     or coalesce((v_audit #>> '{summary,proficiency_context_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,set_validation_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,set_selection_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_optimizer_ready}')::boolean,true) is not false then
    raise exception 'Optimizer audit v4 regression';
  end if;

  if has_function_privilege(
       'anon',
       'public.huntnexus_optimizer_concrete_sets_with_proficiency_universal(text,text,integer,integer,integer,integer,jsonb,jsonb)',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.huntnexus_optimizer_concrete_sets_with_proficiency_universal(text,text,integer,integer,integer,integer,jsonb,jsonb)',
       'EXECUTE'
     ) then
    raise exception 'Proficiency-aware optimizer function must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_optimizer_proficiency_context',
  'audit_stage',huntnexus_optimizer_audit() #>> '{methodology,stage}',
  'proficiency_context_ready',(huntnexus_optimizer_audit() #>> '{summary,proficiency_context_ready}')::boolean,
  'set_selection_ready',(huntnexus_optimizer_audit() #>> '{summary,set_selection_ready}')::boolean
) as regression_summary;
