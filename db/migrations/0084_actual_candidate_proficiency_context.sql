-- HuntNexus — expose normalized proficiency coverage for the actual candidate pair.

CREATE OR REPLACE FUNCTION public.huntnexus_weapon_proficiency_pair_for_items(p_one_item_key text, p_two_item_key text, p_one_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_two_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_effective_weapon_skill integer DEFAULT NULL::integer, p_effective_magic_level integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select jsonb_build_object(
  'one_handed',
    case when exists(
      select 1 from weapon_proficiency_trees where item_key=p_one_item_key
    ) then huntnexus_weapon_proficiency_impact_preview(
      p_one_item_key,
      coalesce(p_one_hand_active_perk_orders,'[]'::jsonb),
      p_effective_weapon_skill,
      p_effective_magic_level
    ) else null end,
  'two_handed',
    case when exists(
      select 1 from weapon_proficiency_trees where item_key=p_two_item_key
    ) then huntnexus_weapon_proficiency_impact_preview(
      p_two_item_key,
      coalesce(p_two_hand_active_perk_orders,'[]'::jsonb),
      p_effective_weapon_skill,
      p_effective_magic_level
    ) else null end,
  'coverage',jsonb_build_object(
    'one_handed_tree_available',exists(
      select 1 from weapon_proficiency_trees where item_key=p_one_item_key
    ),
    'two_handed_tree_available',exists(
      select 1 from weapon_proficiency_trees where item_key=p_two_item_key
    )
  ),
  'methodology',jsonb_build_object(
    'stage','weapon_proficiency_pair_for_items_v1',
    'actual_candidate_items_used',true,
    'optimizer_effect_applied',false,
    'ranking_changed',false
  )
);
$function$
;

revoke all on function public.huntnexus_weapon_proficiency_pair_for_items(text,text,jsonb,jsonb,integer,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_weapon_proficiency_pair_for_items(text,text,jsonb,jsonb,integer,integer)
  to service_role;
