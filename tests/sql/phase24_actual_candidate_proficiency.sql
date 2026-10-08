-- Focused regression for actual-candidate proficiency coverage and item binding.

do $$
declare
  v jsonb;
  v_cobra jsonb;
  v_wz3 jsonb;
  v_murky jsonb;
begin
  v := huntnexus_recommendation_preview_contextual(
    'EK',700,'xp',1,5,3,
    '{"weapon_family":"sword","effective_weapon_skill":120,"effective_magic_level":20,"effective_shielding":110}'::jsonb,
    '[1,3,10,12,15]'::jsonb,
    '[1,2,10,12,15]'::jsonb
  );

  if v #>> '{methodology,stage}' <> 'recommendation_preview_contextual_v3' then
    raise exception 'Expected contextual v3';
  end if;

  select value into v_cobra
  from jsonb_array_elements(v->'results')
  where value #>> '{ranking,hunt_key}'='cobra-bastion'
  limit 1;

  if coalesce((v_cobra #>> '{actual_weapon_proficiency,selection_binding,one_handed_applied_to_actual_item}')::boolean,false) is not true
     or coalesce((v_cobra #>> '{actual_weapon_proficiency,selection_binding,two_handed_applied_to_actual_item}')::boolean,false) is not true then
    raise exception 'Cobra Grand Sanguine bindings regression';
  end if;

  select value into v_wz3
  from jsonb_array_elements(v->'results')
  where value #>> '{ranking,hunt_name}'='Warzone 3'
  limit 1;

  if coalesce((v_wz3 #>> '{actual_weapon_proficiency,coverage,one_handed_tree_available}')::boolean,false) is not true
     or coalesce((v_wz3 #>> '{actual_weapon_proficiency,selection_binding,one_handed_applied_to_actual_item}')::boolean,true) is not false
     or coalesce((v_wz3 #>> '{actual_weapon_proficiency,selection_binding,two_handed_applied_to_actual_item}')::boolean,false) is not true then
    raise exception 'Warzone 3 proficiency coverage/binding regression';
  end if;

  select value into v_murky
  from jsonb_array_elements(v->'results')
  where value #>> '{ranking,hunt_name}'='Murky Caverns'
  limit 1;

  if v_murky is not null then
    if coalesce((v_murky #>> '{actual_weapon_proficiency,coverage,one_handed_tree_available}')::boolean,false) is not true
       or coalesce((v_murky #>> '{actual_weapon_proficiency,coverage,two_handed_tree_available}')::boolean,false) is not true
       or coalesce((v_murky #>> '{actual_weapon_proficiency,selection_binding,one_handed_applied_to_actual_item}')::boolean,true) is not false
       or coalesce((v_murky #>> '{actual_weapon_proficiency,selection_binding,two_handed_applied_to_actual_item}')::boolean,true) is not false then
      raise exception 'Murky Caverns reference-only proficiency regression';
    end if;
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','actual_candidate_proficiency_binding'
) as regression_summary;
