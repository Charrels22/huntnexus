-- HuntNexus Analytics — transparent loadout set preview.
-- The production database was iterated first; this file is the canonical replayable DDL.
-- Fixed slots are selected by explicit objective policy. Competing hand configurations
-- remain unresolved when both are viable because their tradeoff is not yet modeled
-- in a common factual unit.

CREATE OR REPLACE FUNCTION public.huntnexus_pick_loadout_candidate(p_items jsonb, p_objective text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with candidates as (
  select value as item
  from jsonb_array_elements(coalesce(p_items,'[]'::jsonb))
),
ranked as (
  select
    item,
    coalesce((item #>> '{dimension_ranks,defense}')::int,9999) as defense_rank,
    coalesce((item #>> '{dimension_ranks,offense}')::int,9999) as offense_rank,
    coalesce((item #>> '{dimension_ranks,imbue_slots}')::int,9999) as imbue_rank
  from candidates
)
select item || jsonb_build_object(
  'selection_policy',
  case lower(coalesce(p_objective,'balanced'))
    when 'xp' then 'offense_then_defense_then_imbue'
    when 'profit' then 'defense_then_imbue_then_offense'
    else 'rank_consensus_minimax'
  end
)
from ranked
order by
  case when lower(coalesce(p_objective,'balanced'))='xp' then offense_rank end asc nulls last,
  case when lower(coalesce(p_objective,'balanced'))='xp' then defense_rank end asc nulls last,
  case when lower(coalesce(p_objective,'balanced'))='xp' then imbue_rank end asc nulls last,

  case when lower(coalesce(p_objective,'balanced'))='profit' then defense_rank end asc nulls last,
  case when lower(coalesce(p_objective,'balanced'))='profit' then imbue_rank end asc nulls last,
  case when lower(coalesce(p_objective,'balanced'))='profit' then offense_rank end asc nulls last,

  case when lower(coalesce(p_objective,'balanced')) not in ('xp','profit')
       then greatest(defense_rank,offense_rank,imbue_rank) end asc nulls last,
  case when lower(coalesce(p_objective,'balanced')) not in ('xp','profit')
       then defense_rank+offense_rank+imbue_rank end asc nulls last,
  case when lower(coalesce(p_objective,'balanced')) not in ('xp','profit') then defense_rank end asc nulls last,
  case when lower(coalesce(p_objective,'balanced')) not in ('xp','profit') then offense_rank end asc nulls last,
  case when lower(coalesce(p_objective,'balanced')) not in ('xp','profit') then imbue_rank end asc nulls last,
  item->>'name'
limit 1
$function$
;

revoke all on function huntnexus_pick_loadout_candidate(jsonb,text)
  from public,anon,authenticated;
grant execute on function huntnexus_pick_loadout_candidate(jsonb,text)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_loadout_set_preview(p_hunt_key text, p_vocation text, p_level integer, p_objective text DEFAULT 'balanced'::text, p_per_dimension integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_objective text := lower(coalesce(p_objective,'balanced'));
  v_matrix jsonb;
  v_slots jsonb;
  v_selected jsonb := '{}'::jsonb;
  v_key text;
  v_items jsonb;
  v_pick jsonb;
  v_two jsonb;
  v_main jsonb;
  v_off jsonb;
  v_one_available boolean;
  v_two_available boolean;
  v_hand_choice text;
begin
  if v_objective not in ('xp','profit','balanced') then
    v_objective := 'balanced';
  end if;

  v_matrix := huntnexus_loadout_candidate_matrix(
    p_hunt_key,p_vocation,p_level,greatest(3,least(coalesce(p_per_dimension,5),10))
  );
  v_slots := coalesce(v_matrix->'slots','{}'::jsonb);

  for v_key,v_items in
    select key,value
    from jsonb_each(v_slots)
    where key not in ('Weapon Hand','Both Hands','Shield Hand')
    order by key
  loop
    v_pick := huntnexus_pick_loadout_candidate(v_items,v_objective);
    if v_pick is not null then
      v_selected := v_selected || jsonb_build_object(v_key,v_pick);
    end if;
  end loop;

  v_two := huntnexus_pick_loadout_candidate(v_slots->'Both Hands',v_objective);
  v_main := huntnexus_pick_loadout_candidate(v_slots->'Weapon Hand',v_objective);
  v_off := huntnexus_pick_loadout_candidate(v_slots->'Shield Hand',v_objective);

  v_two_available := v_two is not null;
  v_one_available := v_main is not null;

  if v_two_available and not v_one_available then
    v_hand_choice := 'two_handed';
  elsif v_one_available and not v_two_available then
    v_hand_choice := 'one_handed';
  else
    v_hand_choice := null;
  end if;

  return jsonb_build_object(
    'query',jsonb_build_object(
      'hunt_key',p_hunt_key,
      'vocation',huntnexus_normalize_vocation(p_vocation),
      'level',greatest(coalesce(p_level,1),1),
      'objective',v_objective
    ),
    'selected_slots',v_selected,
    'hand_options',jsonb_build_object(
      'one_handed',jsonb_build_object(
        'available',v_one_available,
        'main_hand',v_main,
        'off_hand',v_off,
        'off_hand_available',v_off is not null
      ),
      'two_handed',jsonb_build_object(
        'available',v_two_available,
        'item',v_two
      )
    ),
    'recommended_hand_configuration',v_hand_choice,
    'incoming_damage',coalesce(v_matrix->'incoming_damage','[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','loadout_set_preview_v1',
      'final_set',false,
      'objective_policy',
        case v_objective
          when 'xp' then 'Lexicographic: offense rank, then defense rank, then imbue rank.'
          when 'profit' then 'Economy proxy: defense rank, then imbue flexibility, then offense rank.'
          else 'Transparent rank consensus: minimize worst dimension rank, then total rank.'
        end,
      'combined_numeric_score',false,
      'hand_configuration_resolved',v_hand_choice is not null,
      'hand_configuration_rule','A final choice between one-hand+offhand and two-hand is deferred when both are viable because their offensive/defensive tradeoff is not yet modeled in a common factual unit.',
      'known_gaps',jsonb_build_array(
        'item price and charges/duration',
        'current player inventory/equipment',
        'final imbuement assignment',
        'vocation-specific hand tradeoff model',
        'RubinOT exact item overrides'
      )
    )
  );
end;
$function$
;

revoke all on function huntnexus_loadout_set_preview(text,text,int,text,int)
  from public,anon,authenticated;
grant execute on function huntnexus_loadout_set_preview(text,text,int,text,int)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_recommendation_preview(p_vocation text, p_level integer, p_objective text DEFAULT 'balanced'::text, p_party_size integer DEFAULT 1, p_limit integer DEFAULT 5, p_defensive_items_per_slot integer DEFAULT 3)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions', 'net'
AS $function$
declare
  v_rank jsonb;
  v_result jsonb := '[]'::jsonb;
  v_row jsonb;
  v_hunt_key text;
  v_vocation text := huntnexus_normalize_vocation(p_vocation);
begin
  v_rank := huntnexus_rank_observed_hunts(
    p_vocation,p_level,p_objective,p_party_size,p_limit
  );

  for v_row in
    select value
    from jsonb_array_elements(coalesce(v_rank->'results','[]'::jsonb))
  loop
    v_hunt_key := v_row->>'hunt_key';

    v_result := v_result || jsonb_build_array(
      jsonb_build_object(
        'ranking',v_row,
        'factual_profile',huntnexus_hunt_factual_profile(v_hunt_key),
        'observed_profile',huntnexus_hunt_observed_profile(v_hunt_key),
        'defensive_candidates',
          huntnexus_defensive_item_candidates(
            v_hunt_key,p_vocation,p_level,p_defensive_items_per_slot
          ),
        'offensive_stat_candidates',
          huntnexus_offensive_stat_candidates(v_hunt_key,p_vocation,p_level,20),
        'ek_weapon_candidates',
          case when v_vocation='EK'
            then huntnexus_ek_weapon_candidates(v_hunt_key,p_level,5)
            else null
          end,
        'imbuement_candidates',
          huntnexus_imbuement_candidates(v_hunt_key,p_vocation),
        'spell_candidates',
          huntnexus_spell_candidates(v_hunt_key,p_vocation,p_level,'hunt'),
        'loadout_candidate_matrix',
          huntnexus_loadout_candidate_matrix(
            v_hunt_key,p_vocation,p_level,p_defensive_items_per_slot
          ),
        'loadout_set_preview',
          huntnexus_loadout_set_preview(
            v_hunt_key,p_vocation,p_level,p_objective,
            greatest(5,p_defensive_items_per_slot)
          )
      )
    );
  end loop;

  return jsonb_build_object(
    'query',v_rank->'query',
    'results',v_result,
    'methodology',jsonb_build_object(
      'stage','recommendation_preview_v5',
      'final_recommendation',false,
      'spell_layer_applied',true,
      'loadout_matrix_applied',true,
      'loadout_set_preview_applied',true,
      'final_set_optimizer_applied',false,
      'boss_mechanics_applied',false,
      'note','Preview v5 adds a transparent per-slot set preview and conflict-safe hand alternatives without inventing a cross-dimension equipment score.'
    )
  );
end;
$function$
;

revoke all on function huntnexus_recommendation_preview(text,int,text,int,int,int)
  from public,anon,authenticated;
grant execute on function huntnexus_recommendation_preview(text,int,text,int,int,int)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_api_health()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions', 'net'
AS $function$
select jsonb_build_object(
  'status','ok',
  'product','HuntNexus',
  'counts',jsonb_build_object(
    'creatures',(select count(*) from tibia_entities where entity_type='creature'),
    'hunts',(select count(*) from tibia_hunting_places),
    'items',(select count(*) from tibia_items),
    'bosses',(select count(*) from boss_profiles),
    'spells',(select count(*) from spell_definitions),
    'community_sessions',(select count(*) from community_sessions)
  ),
  'versions',jsonb_build_object(
    'latest_rubinot_server',(
      select version_label from game_versions
      where scope='rubinot_server'
      order by released_on desc,version_label desc
      limit 1
    ),
    'latest_rubinot_client',(
      select version_label from game_versions
      where scope='rubinot_client'
      order by released_on desc,version_label desc
      limit 1
    )
  ),
  'recommendation_stage','preview_v5',
  'final_recommendation_ready',false
);
$function$
;

revoke all on function huntnexus_api_health()
  from public,anon,authenticated;
grant execute on function huntnexus_api_health()
  to service_role;
