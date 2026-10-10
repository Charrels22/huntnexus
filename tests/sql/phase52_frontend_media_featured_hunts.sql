-- Phase 52 — frontend media + featured hunts regression.

do $$
declare
  v_media jsonb;
  v_featured jsonb;
begin
  v_media := huntnexus_hunt_media_context('cobra-bastion');

  if v_media #>> '{methodology,stage}' <> 'hunt_media_context_v1'
     or v_media #>> '{hero_image_name}' <> 'Cobra Assassin'
     or coalesce((v_media #>> '{asset_policy,game_world_visuals_canonical_only}')::boolean,false) is not true
     or coalesce((v_media #>> '{asset_policy,generic_fantasy_fallback}')::boolean,true) is not false then
    raise exception 'Hunt media contract regression';
  end if;

  v_featured := huntnexus_frontend_featured_hunts(4);

  if v_featured #>> '{methodology,stage}' <> 'frontend_featured_hunts_v1'
     or coalesce((v_featured #>> '{methodology,recommendation}')::boolean,true) is not false
     or coalesce((v_featured #>> '{methodology,universal_best_inferred}')::boolean,true) is not false
     or coalesce((v_featured #>> '{summary,returned}')::int,0) < 1 then
    raise exception 'Featured hunts contract regression';
  end if;

  if has_function_privilege('anon','public.huntnexus_hunt_media_context(text)','EXECUTE')
     or has_function_privilege('authenticated','public.huntnexus_frontend_featured_hunts(integer)','EXECUTE') then
    raise exception 'Frontend data RPCs must remain server-only';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','frontend_media_and_featured_hunts',
  'featured_count',(huntnexus_frontend_featured_hunts(4) #>> '{summary,returned}')::int,
  'cobra_hero',huntnexus_hunt_media_context('cobra-bastion') #>> '{hero_image_name}'
) as regression_summary;
