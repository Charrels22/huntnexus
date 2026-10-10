-- Phase 51 — Session Analyzer normalized read contract regression.

do $$
declare
  v_list jsonb;
  v_detail jsonb;
  v_session_id uuid;
begin
  v_list := huntnexus_session_analyzer_list(5,null);

  if coalesce((v_list #>> '{summary,returned}')::int,0) < 1 then
    raise exception 'Session Analyzer list returned no sessions';
  end if;

  select (x->>'session_id')::uuid
  into v_session_id
  from jsonb_array_elements(v_list->'sessions') x
  limit 1;

  v_detail := huntnexus_session_analyzer_detail(v_session_id);

  if v_detail ? 'error' then
    raise exception 'Session Analyzer detail returned error';
  end if;

  if v_detail #>> '{methodology,stage}' <> 'session_analyzer_detail_v1'
     or coalesce((v_detail #>> '{methodology,normalized_tables_only}')::boolean,false) is not true
     or coalesce((v_detail #>> '{methodology,raw_payload_exposed}')::boolean,true) is not false
     or coalesce((v_detail #>> '{methodology,missing_charm_data_invented}')::boolean,true) is not false then
    raise exception 'Session Analyzer methodology regression';
  end if;

  if not (v_detail ? 'hunt_analyse')
     or not (v_detail ? 'misc')
     or not (v_detail ? 'damage')
     or not (v_detail ? 'party_hunt') then
    raise exception 'Session Analyzer tab contract regression';
  end if;

  if has_function_privilege(
       'anon',
       'public.huntnexus_session_analyzer_list(integer,text)',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.huntnexus_session_analyzer_detail(uuid)',
       'EXECUTE'
     ) then
    raise exception 'Session Analyzer RPCs must remain server-only';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','session_analyzer_read_contract',
  'sample_count',(huntnexus_session_analyzer_list(5,null) #>> '{summary,returned}')::int,
  'list_stage',huntnexus_session_analyzer_list(1,null) #>> '{methodology,stage}'
) as regression_summary;
