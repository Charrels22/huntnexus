-- Focused regression for bounded concrete set generation + universal validation.

do $$
declare
  v_ek_hands jsonb;
  v_rp_hands jsonb;
  v_ek jsonb;
  v_rp jsonb;
  v_ed jsonb;
  v_ms jsonb;
  v_em jsonb;
  v_ek_trunc jsonb;
  v_audit jsonb;
begin
  v_ek_hands := huntnexus_optimizer_hand_packages_universal(
    'cobra-bastion','EK',700,3,100
  );
  v_rp_hands := huntnexus_optimizer_hand_packages_universal(
    'iksupan-last-stand','RP',700,3,100
  );

  if (v_ek_hands #>> '{summary,frontier_weapons_considered}')::int <> 9
     or (v_ek_hands #>> '{summary,valid_packages}')::int <> 24
     or (v_ek_hands #>> '{summary,blocked_packages}')::int <> 0
     or (v_ek_hands #>> '{summary,incomplete_packages}')::int <> 0 then
    raise exception 'EK hand package summary regression';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_ek_hands->'packages') x
    where x->>'weapon_hands'='Two'
      and not (x->'selection' ? 'offhand')
      and x #>> '{validation,status}'='valid'
  ) then
    raise exception 'EK two-handed no-offhand package regression';
  end if;

  if (v_rp_hands #>> '{summary,frontier_weapons_considered}')::int <> 6
     or (v_rp_hands #>> '{summary,valid_packages}')::int <> 18
     or exists (
       select 1 from jsonb_array_elements(v_rp_hands->'packages') x
       where x #>> '{validation,status}' <> 'valid'
          or not (x->'selection' ? 'offhand')
          or not (x->'selection' ? 'ammunition')
          or x->>'offhand_family' <> 'quiver'
     ) then
    raise exception 'RP quiver/ammunition hand package regression';
  end if;

  if coalesce((v_rp_hands #>> '{methodology,slice_order_is_not_ranking}')::boolean,false) is not true
     or coalesce((v_rp_hands #>> '{methodology,set_score_applied}')::boolean,true) is not false
     or coalesce((v_rp_hands #>> '{methodology,winner_selected}')::boolean,true) is not false then
    raise exception 'Hand package methodology regression';
  end if;

  v_ek := huntnexus_optimizer_concrete_sets_universal('cobra-bastion','EK',700,2,1,100);
  v_rp := huntnexus_optimizer_concrete_sets_universal('iksupan-last-stand','RP',700,2,1,100);
  v_ed := huntnexus_optimizer_concrete_sets_universal('nimmersatts-breeding-ground','ED',700,2,1,100);
  v_ms := huntnexus_optimizer_concrete_sets_universal('podzilla','MS',700,2,1,100);
  v_em := huntnexus_optimizer_concrete_sets_universal('grounds-of-undeath','EM',700,2,1,100);

  if (v_ek #>> '{summary,valid_sets}')::int <> 12
     or (v_rp #>> '{summary,valid_sets}')::int <> 8
     or (v_ed #>> '{summary,valid_sets}')::int <> 10
     or (v_ms #>> '{summary,valid_sets}')::int <> 10
     or (v_em #>> '{summary,valid_sets}')::int <> 2 then
    raise exception 'Five-vocation concrete set count regression';
  end if;

  if (v_ek #>> '{summary,blocked_sets}')::int <> 0
     or (v_rp #>> '{summary,blocked_sets}')::int <> 0
     or (v_ed #>> '{summary,blocked_sets}')::int <> 0
     or (v_ms #>> '{summary,blocked_sets}')::int <> 0
     or (v_em #>> '{summary,blocked_sets}')::int <> 0
     or (v_ek #>> '{summary,incomplete_sets}')::int <> 0
     or (v_rp #>> '{summary,incomplete_sets}')::int <> 0
     or (v_ed #>> '{summary,incomplete_sets}')::int <> 0
     or (v_ms #>> '{summary,incomplete_sets}')::int <> 0
     or (v_em #>> '{summary,incomplete_sets}')::int <> 0 then
    raise exception 'Concrete set validation regression';
  end if;

  if not (
    (v_rp #> '{sets,0,selection}') ? 'weapon'
    and (v_rp #> '{sets,0,selection}') ? 'offhand'
    and (v_rp #> '{sets,0,selection}') ? 'ammunition'
    and (v_rp #> '{sets,0,selection}') ? 'head'
    and (v_rp #> '{sets,0,selection}') ? 'body'
    and (v_rp #> '{sets,0,selection}') ? 'legs'
    and (v_rp #> '{sets,0,selection}') ? 'feet'
    and (v_rp #> '{sets,0,selection}') ? 'neck'
    and (v_rp #> '{sets,0,selection}') ? 'ring'
  ) or v_rp #>> '{sets,0,validation,status}' <> 'valid' then
    raise exception 'RP complete concrete selection regression';
  end if;

  v_ek_trunc := huntnexus_optimizer_concrete_sets_universal(
    'cobra-bastion','EK',700,2,2,50
  );

  if (v_ek_trunc #>> '{source_summary,theoretical_combinations}')::int <> 768
     or (v_ek_trunc #>> '{summary,generated_for_validation}')::int <> 50
     or (v_ek_trunc #>> '{summary,valid_sets}')::int <> 50
     or coalesce((v_ek_trunc #>> '{summary,truncated}')::boolean,false) is not true
     or coalesce((v_ek_trunc #>> '{methodology,slice_order_is_not_ranking}')::boolean,false) is not true
     or coalesce((v_ek_trunc #>> '{methodology,set_ranking_applied}')::boolean,true) is not false
     or coalesce((v_ek_trunc #>> '{methodology,winner_selected}')::boolean,true) is not false
     or coalesce((v_ek_trunc #>> '{methodology,final_optimizer_applied}')::boolean,true) is not false then
    raise exception 'Bounded enumeration/truncation methodology regression';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_ek_trunc->'sets') x
    where x #>> '{validation,status}' <> 'valid'
  ) then
    raise exception 'Every returned bounded EK set must pass universal validation';
  end if;

  if huntnexus_optimizer_concrete_sets_universal(
       'cobra-bastion','UNKNOWN',700,2,1,20
     )->>'error' <> 'unsupported_vocation' then
    raise exception 'Concrete set unsupported vocation regression';
  end if;

  v_audit := huntnexus_optimizer_audit();

  if v_audit #>> '{methodology,stage}' <> 'optimizer_audit_v3'
     or coalesce((v_audit #>> '{summary,hand_package_generation_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,concrete_set_generation_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,set_validation_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,set_selection_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_optimizer_ready}')::boolean,true) is not false then
    raise exception 'Optimizer audit v3 semantics regression';
  end if;

  if has_function_privilege(
       'anon',
       'public.huntnexus_optimizer_hand_packages_universal(text,text,integer,integer,integer)',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.huntnexus_optimizer_concrete_sets_universal(text,text,integer,integer,integer,integer)',
       'EXECUTE'
     ) then
    raise exception 'Concrete optimizer functions must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_optimizer_concrete_set_validation',
  'ek_sets',(huntnexus_optimizer_concrete_sets_universal(
    'cobra-bastion','EK',700,2,1,100
  ) #>> '{summary,valid_sets}')::int,
  'rp_sets',(huntnexus_optimizer_concrete_sets_universal(
    'iksupan-last-stand','RP',700,2,1,100
  ) #>> '{summary,valid_sets}')::int,
  'ed_sets',(huntnexus_optimizer_concrete_sets_universal(
    'nimmersatts-breeding-ground','ED',700,2,1,100
  ) #>> '{summary,valid_sets}')::int,
  'ms_sets',(huntnexus_optimizer_concrete_sets_universal(
    'podzilla','MS',700,2,1,100
  ) #>> '{summary,valid_sets}')::int,
  'em_sets',(huntnexus_optimizer_concrete_sets_universal(
    'grounds-of-undeath','EM',700,2,1,100
  ) #>> '{summary,valid_sets}')::int,
  'set_validation_ready',(huntnexus_optimizer_audit() #>> '{summary,set_validation_ready}')::boolean,
  'set_selection_ready',(huntnexus_optimizer_audit() #>> '{summary,set_selection_ready}')::boolean
) as regression_summary;
