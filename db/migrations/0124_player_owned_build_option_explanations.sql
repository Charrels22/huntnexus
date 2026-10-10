-- HuntNexus FE-09 — explain owned build substitutions without scalar scoring.
-- Wraps owned build options v1 and enriches each BP replacement with factual item contexts.

create or replace function public.huntnexus_player_owned_build_options_v2(
  p_client_id uuid,
  p_hunt_key text,
  p_vocation text,
  p_level integer,
  p_proficiency_selections jsonb default '{}'::jsonb,
  p_character_profile jsonb default '{}'::jsonb,
  p_option_limit integer default 3
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with base as (
  select huntnexus_player_owned_build_options(
    p_client_id,
    p_hunt_key,
    p_vocation,
    p_level,
    p_proficiency_selections,
    p_character_profile,
    p_option_limit
  ) as j
),
options as (
  select
    o.ordinality as ord,
    o.value as option_json
  from base
  cross join lateral jsonb_array_elements(coalesce(j->'options','[]'::jsonb))
    with ordinality as o(value, ordinality)
),
enriched as (
  select
    ord,
    option_json || jsonb_build_object(
      'replacement_details',
      coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'selection_key',r.value->>'selection_key',
            'from_item_key',m.item_key,
            'from_item_name',m.item_name,
            'to_item_key',r.value->>'item_key',
            'to_item_name',r.value->>'item_name',
            'from_context',
              case
                when m.item_key is null then null
                else huntnexus_item_effect_hunt_context_universal(
                  m.item_key,
                  p_hunt_key,
                  p_vocation,
                  case
                    when jsonb_typeof(coalesce(p_proficiency_selections,'{}'::jsonb))='object'
                      then coalesce(p_proficiency_selections->m.item_key,'[]'::jsonb)
                    else '[]'::jsonb
                  end
                )
              end,
            'to_context',
              huntnexus_item_effect_hunt_context_universal(
                r.value->>'item_key',
                p_hunt_key,
                p_vocation,
                case
                  when jsonb_typeof(coalesce(p_proficiency_selections,'{}'::jsonb))='object'
                    then coalesce(p_proficiency_selections->(r.value->>'item_key'),'[]'::jsonb)
                  else '[]'::jsonb
                end
              )
          )
          order by r.ordinality
        )
        from jsonb_array_elements(coalesce(option_json->'replacements','[]'::jsonb))
          with ordinality as r(value, ordinality)
        left join public.player_character_inventory m
          on m.client_id=p_client_id
         and m.storage_kind='main'
         and m.selection_key=r.value->>'selection_key'
      ),'[]'::jsonb)
    ) as option_json
  from options
)
select
  b.j
  || jsonb_build_object(
    'options',
    coalesce(
      (select jsonb_agg(e.option_json order by e.ord) from enriched e),
      '[]'::jsonb
    ),
    'methodology',
    coalesce(b.j->'methodology','{}'::jsonb)
    || jsonb_build_object(
      'stage','player_owned_build_options_v2',
      'replacement_context_explanations',true,
      'replacement_explanation_is_factual_attributes',true,
      'missing_hunt_damage_context_does_not_infer_protection_priority',true
    )
  )
from base b;
$function$;

revoke all on function public.huntnexus_player_owned_build_options_v2(uuid,text,text,integer,jsonb,jsonb,integer)
from public,anon,authenticated;
grant execute on function public.huntnexus_player_owned_build_options_v2(uuid,text,text,integer,jsonb,jsonb,integer)
to service_role;
