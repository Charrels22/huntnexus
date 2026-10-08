-- HuntNexus — batch contextual EK hand comparisons for result cards.

CREATE OR REPLACE FUNCTION public.huntnexus_ek_hand_context_batch(p_hunt_keys jsonb, p_level integer, p_character_profile jsonb, p_one_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_two_hand_active_perk_orders jsonb DEFAULT '[]'::jsonb, p_effective_magic_level integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with keys as (
  select value as hunt_key, ord::int as ord
  from jsonb_array_elements_text(
    case
      when jsonb_typeof(coalesce(p_hunt_keys,'[]'::jsonb))='array'
        then coalesce(p_hunt_keys,'[]'::jsonb)
      else '[]'::jsonb
    end
  ) with ordinality as x(value,ord)
  where nullif(trim(value),'') is not null
  order by ord
  limit 10
),
contexts as (
  select
    k.hunt_key,
    k.ord,
    huntnexus_ek_hand_context_comparison(
      k.hunt_key,
      p_level,
      coalesce(p_character_profile,'{}'::jsonb),
      coalesce(p_one_hand_active_perk_orders,'[]'::jsonb),
      coalesce(p_two_hand_active_perk_orders,'[]'::jsonb),
      p_effective_magic_level
    ) as context
  from keys k
)
select jsonb_build_object(
  'items',coalesce((
    select jsonb_object_agg(hunt_key,context order by ord)
    from contexts
  ),'{}'::jsonb),
  'requested_count',(select count(*) from keys),
  'methodology',jsonb_build_object(
    'stage','ek_hand_context_batch_v1',
    'max_hunts',10,
    'optimizer_effect_applied',false,
    'ranking_changed',false
  )
);
$function$
;

revoke all on function public.huntnexus_ek_hand_context_batch(jsonb,integer,jsonb,jsonb,jsonb,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_ek_hand_context_batch(jsonb,integer,jsonb,jsonb,jsonb,integer)
  to service_role;
