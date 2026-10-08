-- Focused regression for item-key-bound Weapon Proficiency selections.

do $$
declare
  v jsonb;
  v_cobra jsonb;
  v_wz3 jsonb;
  v_murky jsonb;
begin
  v := huntnexus_recommendation_preview_contextual_items(
    'EK',700,'xp',1,5,3,
    '{"weapon_family":"sword","effective_weapon_skill":120,"effective_magic_level":20,"effective_shielding":110}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"gnome-sword":[1,2],"naga-sword":[4,7],"soulshredder":[1,2,11,13]}'::jsonb
  );

  if v #>> '{methodology,stage}' <> 'recommendation_preview_contextual_v4' then
    raise exception 'Expected contextual v4';
  end if;

  select value into v_cobra
  from jsonb_array_elements(v->'results')
  where value #>> '{ranking,hunt_key}'='cobra-bastion'
  limit 1;

  if coalesce((v_cobra #>> '{actual_weapon_proficiency,one_handed,active_perk_count}')::int,0) <> 0
     or coalesce((v_cobra #>> '{actual_weapon_proficiency,two_handed,active_perk_count}')::int,0) <> 0 then
    raise exception 'Perk selections leaked into Cobra Grand Sanguine trees';
  end if;

  select value into v_wz3
  from jsonb_array_elements(v->'results')
  where value #>> '{ranking,hunt_name}'='Warzone 3'
  limit 1;

  if coalesce((v_wz3 #>> '{actual_weapon_proficiency,one_handed,active_perk_count}')::int,0) <> 2
     or v_wz3 #>> '{actual_weapon_proficiency,selection_binding,one_handed_selection_source}' <> 'item_key' then
    raise exception 'Gnome Sword item-key selection regression';
  end if;

  select value into v_murky
  from jsonb_array_elements(v->'results')
  where value #>> '{ranking,hunt_name}'='Murky Caverns'
  limit 1;

  if v_murky is not null then
    if coalesce((v_murky #>> '{actual_weapon_proficiency,one_handed,active_perk_count}')::int,0) <> 2
       or coalesce((v_murky #>> '{actual_weapon_proficiency,two_handed,active_perk_count}')::int,0) <> 4
       or v_murky #>> '{actual_weapon_proficiency,selection_binding,one_handed_selection_source}' <> 'item_key'
       or v_murky #>> '{actual_weapon_proficiency,selection_binding,two_handed_selection_source}' <> 'item_key'
       or coalesce((v_murky #>> '{hand_context_comparison,comparison,extended_comparison_ready}')::boolean,false) is not true then
      raise exception 'Murky Caverns item-key proficiency regression';
    end if;
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','item_key_proficiency_selection'
) as regression_summary;
