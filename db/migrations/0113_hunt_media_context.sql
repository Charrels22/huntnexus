-- HuntNexus FE-01 — canonical media context for hunts.

create or replace function public.huntnexus_hunt_media_context(
  p_hunt_key text
)
returns jsonb
language sql
stable
set search_path to 'public','extensions'
as $function$
select case
  when hp.id is null then jsonb_build_object(
    'error','hunt_not_found',
    'hunt_key',p_hunt_key
  )
  else jsonb_build_object(
    'hunt_key',hp.slug,
    'hero_image_name',hp.structured_data->>'image',
    'wiki_url',hp.structured_data->>'wikiUrl',
    'map_files',to_jsonb(array_remove(array[
      hp.structured_data->>'map',
      hp.structured_data->>'map2',
      hp.structured_data->>'map3',
      hp.structured_data->>'map4'
    ],null)),
    'mapper_location',hp.location,
    'asset_policy',jsonb_build_object(
      'game_world_visuals_canonical_only',true,
      'generic_fantasy_fallback',false,
      'hero_source','hunt_infobox_image',
      'map_source','tibia_client_minimap_when_coordinates_available'
    ),
    'methodology',jsonb_build_object(
      'stage','hunt_media_context_v1',
      'source_table','tibia_hunting_places',
      'generated_game_art',false
    )
  )
end
from (
  select *
  from tibia_hunting_places
  where slug=p_hunt_key
  limit 1
) hp
right join (select 1 as anchor) a on true;
$function$;

revoke all on function public.huntnexus_hunt_media_context(text)
from public,anon,authenticated;
grant execute on function public.huntnexus_hunt_media_context(text)
to service_role;
