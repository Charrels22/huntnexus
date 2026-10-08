-- HuntNexus — bind explicit perk-order selections to the weapon tree they
-- were entered for. Other actual candidates may expose their normalized tree
-- as reference, but do not inherit perk orders from another weapon.

CREATE OR REPLACE FUNCTION public.huntnexus_recommendation_preview_contextual(p_vocation text, p_level integer, p_objective text DEFAULT 'balanced'::text, p_party_size integer DEFAULT 1, p_limit integer DEFAULT 5, p_defensive_items_per_slot integer DEFAULT 3, p_character_profile jsonb DEFAULT '{}'::jsonb, p_one_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_two_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions', 'net'
AS $function$
declare
  v_base jsonb;
  v_result jsonb := '[]'::jsonb;
  v_row jsonb;
  v_hunt_key text;
  v_hand jsonb;
  v_prof_reference jsonb;
  v_prof_impact jsonb;
  v_one_item_key text;
  v_two_item_key text;
  v_bound_one_item_key text;
  v_bound_two_item_key text;
  v_one_orders jsonb := '[]'::jsonb;
  v_two_orders jsonb := '[]'::jsonb;
  v_family text := lower(nullif(trim(p_character_profile->>'weapon_family'),''));
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
  v_applied boolean := v_vocation='EK' and v_family in ('sword','axe','club');
begin
  v_base := huntnexus_recommendation_preview_profiled(
    p_vocation,
    p_level,
    p_objective,
    p_party_size,
    p_limit,
    p_defensive_items_per_slot,
    p_character_profile
  );

  if v_applied then
    v_bound_one_item_key := case v_family
      when 'sword' then 'grand-sanguine-blade'
      when 'axe' then 'grand-sanguine-hatchet'
      when 'club' then 'grand-sanguine-cudgel'
    end;
    v_bound_two_item_key := case v_family
      when 'sword' then 'grand-sanguine-razor'
      when 'axe' then 'grand-sanguine-battleaxe'
      when 'club' then 'grand-sanguine-bludgeon'
    end;

    v_prof_reference := huntnexus_ek_proficiency_comparison(
      v_family,
      coalesce(p_one_hand_active_perk_orders,'[]'::jsonb),
      coalesce(p_two_hand_active_perk_orders,'[]'::jsonb)
    );
  end if;

  for v_row in
    select value
    from jsonb_array_elements(coalesce(v_base->'results','[]'::jsonb))
  loop
    if v_applied then
      v_hunt_key := v_row #>> '{ranking,hunt_key}';
      v_hand := v_row #> '{loadout_set_preview,hand_analysis}';
      v_one_item_key := v_hand #>> '{one_handed,offense_options,0,weapon,item_key}';
      v_two_item_key := v_hand #>> '{two_handed,offense_options,0,item_key}';

      v_one_orders := case
        when v_one_item_key=v_bound_one_item_key
          then coalesce(p_one_hand_active_perk_orders,'[]'::jsonb)
        else '[]'::jsonb
      end;
      v_two_orders := case
        when v_two_item_key=v_bound_two_item_key
          then coalesce(p_two_hand_active_perk_orders,'[]'::jsonb)
        else '[]'::jsonb
      end;

      v_prof_impact := huntnexus_weapon_proficiency_pair_for_items(
        v_one_item_key,
        v_two_item_key,
        v_one_orders,
        v_two_orders,
        huntnexus_first_int(p_character_profile->>'effective_weapon_skill'),
        huntnexus_first_int(p_character_profile->>'effective_magic_level')
      );

      v_row := v_row || jsonb_build_object(
        'hand_context_comparison',
        huntnexus_ek_hand_context_from_precomputed(
          v_hunt_key,
          v_hand,
          v_prof_impact,
          v_one_orders,
          v_two_orders
        ),
        'actual_weapon_proficiency',
        v_prof_impact || jsonb_build_object(
          'selection_binding',jsonb_build_object(
            'one_handed_bound_item_key',v_bound_one_item_key,
            'two_handed_bound_item_key',v_bound_two_item_key,
            'one_handed_applied_to_actual_item',v_one_item_key=v_bound_one_item_key,
            'two_handed_applied_to_actual_item',v_two_item_key=v_bound_two_item_key
          )
        )
      );
    end if;

    v_result := v_result || jsonb_build_array(v_row);
  end loop;

  return v_base || jsonb_build_object(
    'results',v_result,
    'proficiency_preview',
      case when v_applied
        then v_prof_reference
        else null
      end,
    'methodology',
      coalesce(v_base->'methodology','{}'::jsonb)
      || jsonb_build_object(
        'stage','recommendation_preview_contextual_v3',
        'base_stage',v_base #>> '{methodology,stage}',
        'contextual_hand_comparison_applied',v_applied,
        'precomputed_hand_analysis_reused',v_applied,
        'actual_candidate_proficiency_reference_used',v_applied,
        'perk_orders_require_item_binding',true,
        'optimizer_effect_applied',false,
        'ranking_changed',false
      )
  );
end;
$function$
;

revoke all on function public.huntnexus_recommendation_preview_contextual(text,integer,text,integer,integer,integer,jsonb,jsonb,jsonb)
  from public,anon,authenticated;
grant execute on function public.huntnexus_recommendation_preview_contextual(text,integer,text,integer,integer,integer,jsonb,jsonb,jsonb)
  to service_role;
