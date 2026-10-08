-- SYNTHETIC regression fixture for contextual hand-comparison semantics.
-- No live ranking/catalog assumptions are required.

do $$
declare
  v_mismatch jsonb;
  v_match jsonb;
begin
  v_mismatch := huntnexus_ek_hand_context_from_precomputed(
    'synthetic-hunt',
    '{
      "character_profile":{"weapon_family":"sword","effective_weapon_skill":120},
      "one_handed":{"offense_options":[{"weapon":{"item_key":"gnome-sword","name":"Synthetic One","effective_attack_proxy":50},"matching_weapon_skill_bonus":5,"displayed_effective_weapon_skill":120,"weighted_protection":2,"imbue_capacity":2}]},
      "two_handed":{"offense_options":[{"item_key":"grand-sanguine-razor","name":"Synthetic Two","effective_attack_proxy":55,"weapon_skill_bonus":4,"displayed_effective_weapon_skill":120,"weighted_protection":1,"imbue_capacity":3}]},
      "comparison":{"resolved_configuration":"two_handed"}
    }'::jsonb,
    '{
      "one_handed":{"item_key":"grand-sanguine-blade","resolved_effects":[]},
      "two_handed":{"item_key":"grand-sanguine-razor","resolved_effects":[]}
    }'::jsonb,
    '[1]'::jsonb,
    '[1]'::jsonb
  );

  if v_mismatch #>> '{comparison,status}' <> 'proficiency_weapon_mismatch' then
    raise exception 'Synthetic mismatch status regression';
  end if;
  if coalesce((v_mismatch #>> '{comparison,extended_comparison_ready}')::boolean,true) is not false then
    raise exception 'Synthetic mismatch must not be extended-comparison ready';
  end if;
  if v_mismatch #> '{comparison,contextual_pareto_dominance}' <> 'null'::jsonb then
    raise exception 'Synthetic mismatch must not expose contextual dominance';
  end if;
  if v_mismatch #>> '{comparison,base_pareto_dominance}' <> 'two_handed' then
    raise exception 'Synthetic base dominance must remain visible';
  end if;

  v_match := huntnexus_ek_hand_context_from_precomputed(
    'synthetic-hunt',
    '{
      "character_profile":{"weapon_family":"sword","effective_weapon_skill":120},
      "one_handed":{"offense_options":[{"weapon":{"item_key":"grand-sanguine-blade","name":"Synthetic One","effective_attack_proxy":50},"matching_weapon_skill_bonus":7,"displayed_effective_weapon_skill":120,"weighted_protection":2,"imbue_capacity":3}]},
      "two_handed":{"offense_options":[{"item_key":"grand-sanguine-razor","name":"Synthetic Two","effective_attack_proxy":54,"weapon_skill_bonus":4,"displayed_effective_weapon_skill":120,"weighted_protection":1,"imbue_capacity":3}]},
      "comparison":{"resolved_configuration":null}
    }'::jsonb,
    '{
      "one_handed":{"item_key":"grand-sanguine-blade","resolved_effects":[{"scope":"global","effect_family":"critical_chance","value":3,"unit":"percent"}]},
      "two_handed":{"item_key":"grand-sanguine-razor","resolved_effects":[{"scope":"global","effect_family":"critical_chance","value":3,"unit":"percent"}]}
    }'::jsonb,
    '[1]'::jsonb,
    '[1]'::jsonb
  );

  if coalesce((v_match #>> '{comparison,extended_comparison_ready}')::boolean,false) is not true then
    raise exception 'Synthetic full match must be extended-comparison ready';
  end if;
  if v_match #>> '{methodology,optimizer_effect_applied}' <> 'false' then
    raise exception 'Synthetic contextual comparison must never alter optimizer';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','contextual_hand_synthetic_regression',
  'fixture','SYNTHETIC'
) as regression_summary;
