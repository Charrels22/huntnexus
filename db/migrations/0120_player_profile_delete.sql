-- HuntNexus FE-05 — private player profile deletion.

create or replace function public.huntnexus_player_profile_delete(
  p_client_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_count integer;
begin
  delete from public.player_character_profiles
  where client_id=p_client_id;

  get diagnostics v_count = row_count;

  return jsonb_build_object(
    'deleted',v_count=1,
    'client_id',p_client_id
  );
end;
$function$;

revoke all on function public.huntnexus_player_profile_delete(uuid) from public,anon,authenticated;
grant execute on function public.huntnexus_player_profile_delete(uuid) to service_role;
