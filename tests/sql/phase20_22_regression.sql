-- HuntNexus regression checks — recommendation preview v7.
-- Run after migrations through 0070.
-- These checks raise exceptions on invariant regressions.

do $$
declare
  v_health jsonb;
  v_rec jsonb;
  v_set jsonb;
  v_profiled jsonb;
  v_profiled_set jsonb;
  v_contract jsonb;
  v_imbues jsonb;
  v_magma jsonb;
begin
  v_health := huntnexus_api_health();
  if v_health #>> '{recommendation_stage}' <> 'preview_v7' then
    raise exception 'Expected recommendation stage preview_v7, got %',
      v_health #>> '{recommendation_stage}';
  end if;

  v_rec := huntnexus_recommendation_preview('EK',700,'xp',1,1,3);

  if jsonb_array_length(coalesce(v_rec->'results','[]'::jsonb)) < 1 then
    raise exception 'EK700 XP regression: expected at least one recommendation';
  end if;

  if v_rec #> '{results,0,ranking,ranking_score}' is null
     or v_rec #> '{results,0,ranking,confidence_score}' is null then
    raise exception 'Ranking score and confidence score must remain separate fields';
  end if;

  if v_rec #>> '{results,0,loadout_candidate_matrix,methodology,stage}'
     <> 'loadout_candidate_matrix_v5' then
    raise exception 'Expected loadout_candidate_matrix_v5';
  end if;

  v_set := v_rec #> '{results,0,loadout_set_preview}';

  if v_set #>> '{methodology,stage}' <> 'loadout_set_preview_v3' then
    raise exception 'Expected loadout_set_preview_v3';
  end if;

  if v_set #>> '{hand_analysis,methodology,stage}' <> 'ek_hand_options_v2' then
    raise exception 'Expected ek_hand_options_v2';
  end if;

  if v_set #>> '{imbuement_preview,methodology,stage}'
     <> 'loadout_imbuement_compatibility_v1' then
    raise exception 'Expected loadout_imbuement_compatibility_v1';
  end if;

  if lower(coalesce(v_set #>> '{hand_options,one_handed,main_hand,item_key}',''))
     = 'ice-rapier' then
    raise exception 'Ice Rapier must not be selected for sustained hunts';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(
      coalesce(v_set #> '{hand_analysis,excluded_from_sustained_hunt}','[]'::jsonb)
    ) x
    where x->>'item_key'='ice-rapier'
       and x->>'reason'='fragile_few_hit_weapon'
  ) then
    raise exception 'Expected Ice Rapier sustained-hunt exclusion evidence';
  end if;

  v_contract := huntnexus_character_combat_profile_contract('EK');
  if v_contract #>> '{stage}' <> 'character_combat_profile_contract_v1' then
    raise exception 'Character profile contract stage regression';
  end if;
  if v_contract #> '{vocation_specific,weapon_family,values}'
     <> '["sword","axe","club"]'::jsonb then
    raise exception 'EK weapon family contract regression: %',
      v_contract #> '{vocation_specific,weapon_family,values}';
  end if;

  v_profiled := huntnexus_recommendation_preview_profiled(
    'EK',700,'xp',1,1,3,
    '{"weapon_family":"sword","effective_weapon_skill":120,"effective_shielding":110}'::jsonb
  );
  if v_profiled #>> '{methodology,stage}'
     <> 'recommendation_preview_profiled_v1' then
    raise exception 'Profiled recommendation stage regression';
  end if;
  if coalesce((v_profiled #>> '{methodology,character_profile_applied}')::boolean,false)
     is not true then
    raise exception 'Character profile was not applied';
  end if;

  v_profiled_set := v_profiled #> '{results,0,loadout_set_preview}';
  if lower(coalesce(v_profiled_set #>> '{hand_options,one_handed,main_hand,weapon_type}',''))
     <> 'sword'
     or lower(coalesce(v_profiled_set #>> '{hand_options,two_handed,item,weapon_type}',''))
     <> 'sword' then
    raise exception 'Profiled Sword recommendation leaked another weapon family';
  end if;
  if (v_profiled_set #>> '{hand_analysis,one_handed,offense_options,0,effective_weapon_skill_with_items}')::int
     <> 127
     or (v_profiled_set #>> '{hand_analysis,two_handed,offense_options,0,effective_weapon_skill_with_item}')::int
     <> 124 then
    raise exception 'Profiled effective skill context regression';
  end if;

  v_imbues := huntnexus_imbuement_candidates('cobra-bastion','EK');
  if v_imbues #>> '{methodology,stage}' <> 'imbuement_candidates_v2' then
    raise exception 'Expected imbuement_candidates_v2';
  end if;
  if coalesce(
    (v_imbues #>> '{methodology,community_observed_usage_affects_priority}')::boolean,
    true
  ) is not false then
    raise exception 'Tier C community usage must not alter imbuement priority';
  end if;
  if jsonb_typeof(v_imbues->'community_observed_usage') <> 'array' then
    raise exception 'Expected community_observed_usage array';
  end if;

  if (select count(*) from community_session_profile_state where status='completed') <> 100
     or (select count(*) from community_session_profile_state where status='error') <> 0 then
    raise exception 'HuntAnalyser player-profile parser regression';
  end if;
  if (select count(*) from session_player_combat_stats) <> 2193
     or (select count(*) from session_player_equipment) <> 918 then
    raise exception 'Normalized player profile row-count regression';
  end if;
  if (select count(*) from session_player_equipment where item_key is null) <> 1 then
    raise exception 'Equipment canonical resolution regression';
  end if;

  if huntnexus_resolve_creature_exact('demongoblin') <> 'demon-goblin' then
    raise exception 'demongoblin alias regression';
  end if;

  if exists (
    select 1
    from hunting_place_creatures hpc
    where huntnexus_resolve_creature_exact(hpc.monster_slug) is null
  ) then
    raise exception 'Expected all hunt-creature links to resolve canonically';
  end if;

  v_magma := huntnexus_boss_build_preview('magma-bubble','EK',700);
  if coalesce((v_magma #>> '{readiness,final_build_blocked}')::boolean,false) is not true
     or coalesce((v_magma #>> '{final_build_available}')::boolean,true) is not false then
    raise exception 'Magma Bubble guard regression';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'recommendation_stage',huntnexus_api_health() #>> '{recommendation_stage}',
  'hunt_creature_links_total',(select count(*) from hunting_place_creatures),
  'hunt_creature_links_unresolved',(
    select count(*) from hunting_place_creatures
    where huntnexus_resolve_creature_exact(monster_slug) is null
  )
) as regression_summary;
