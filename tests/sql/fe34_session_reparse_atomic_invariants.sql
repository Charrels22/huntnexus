-- FE-34 integration: run as database owner in isolated DO transaction.
-- Only ephemeral randomly identified synthetic data, no live user session.
-- An exception rolls back every statement; success cleans up its own fixture.
do $fe34$
declare
  v_owner uuid := gen_random_uuid();
  v_other uuid := gen_random_uuid();
  v_id uuid := gen_random_uuid();
  v_raw jsonb := jsonb_build_object(
    'hunt',E'Session: 00:43h\nXP Gain: 8,600\nDamage: 2,700',
    'party','', 'input','', 'misc',''
  );
  v_before jsonb := jsonb_build_object(
    'hunt_analyse',jsonb_build_object('duration_seconds',null,'xp_gain',8600),
    'validation',jsonb_build_object('recognized_metric_count',1,'has_primary_hunt_analyzer',true),
    'methodology',jsonb_build_object('stage','session_parser_v1'),
    'metadata',jsonb_build_object('rare_drops_raw','FE34 synthetic only')
  );
  v_after jsonb;
  v_snapshot jsonb := jsonb_build_object(
    'source','main_default','selection',jsonb_build_object('weapon','test-only'),
    'items',jsonb_build_array(jsonb_build_object('item_key','test-only')),
    'captured_at','2026-10-12T00:00:00Z'
  );
  v_source jsonb;
  v_result jsonb;
  v_actual record;
  v_revisions integer;
begin
  insert into public.player_hunt_sessions(
    id,client_id,observation,status,raw_blocks,parsed_data,parser_version,loadout_snapshot
  ) values(
    v_id,v_owner,'FE34 SQL synthetic audit; never player data','parsed',
    v_raw,v_before,'session_parser_v1',v_snapshot
  );
  v_source := public.huntnexus_player_session_reparse_source(v_owner,v_id);
  if v_source->'raw_blocks' <> v_raw or
     v_source->'parsed_data' <> v_before or
     length(v_source->>'fingerprint') <> 32 then
    raise exception 'FE34: owner source or fingerprint incorrect';
  end if;
  v_result := public.huntnexus_player_session_reparse_source(v_other,v_id);
  if v_result->>'error' <> 'session_not_found' then
    raise exception 'FE34: foreign owner read permitted';
  end if;
  v_after := v_before ||
    jsonb_build_object(
      'hunt_analyse',jsonb_build_object('duration_seconds',2580,'xp_gain',8600),
      'methodology',jsonb_build_object('stage','session_parser_v2')
    );
  v_result := public.huntnexus_player_session_reparse_apply(
    v_owner,v_id,v_source->>'fingerprint',v_after,false);
  if v_result->>'error' <> 'reparse_confirmation_required' then
    raise exception 'FE34: confirmation guard absent';
  end if;
  v_result := public.huntnexus_player_session_reparse_apply(
    v_other,v_id,v_source->>'fingerprint',v_after,true);
  if v_result->>'error' <> 'session_not_found' then
    raise exception 'FE34: foreign owner update permitted';
  end if;
  v_result := public.huntnexus_player_session_reparse_apply(
    v_owner,v_id,repeat('0',32),v_after,true);
  if v_result->>'error' <> 'reparse_preview_stale' then
    raise exception 'FE34: stale token guard absent';
  end if;
  v_result := public.huntnexus_player_session_reparse_apply(
    v_owner,v_id,v_source->>'fingerprint',v_after,true);
  if coalesce((v_result->>'updated')::boolean,false) <> true or
     v_result->>'raw_blocks_preserved' <> 'true' or
     v_result->>'loadout_snapshot_preserved' <> 'true' then
    raise exception 'FE34: confirmed update failed: %',v_result;
  end if;
  select raw_blocks,loadout_snapshot,parsed_data,parser_version
    into v_actual from public.player_hunt_sessions where id=v_id;
  if v_actual.raw_blocks <> v_raw or v_actual.loadout_snapshot <> v_snapshot or
     v_actual.parsed_data <> v_after or v_actual.parser_version <> 'session_parser_v2' then
    raise exception 'FE34: unexpected change to raw blocks or immutable setup';
  end if;
  select count(*) into v_revisions
    from public.player_session_parse_revisions
    where session_id=v_id and client_id=v_owner and
      previous_parsed_data=v_before and previous_parser_version='session_parser_v1';
  if v_revisions <> 1 then
    raise exception 'FE34: audit revision missing';
  end if;
  v_result := public.huntnexus_player_session_reparse_apply(
    v_owner,v_id,v_source->>'fingerprint',v_after,true);
  if v_result->>'error' <> 'reparse_preview_stale' then
    raise exception 'FE34: stale replay after update not denied';
  end if;
  delete from public.player_hunt_sessions where id=v_id and client_id=v_owner;
  select count(*) into v_revisions from public.player_session_parse_revisions where session_id=v_id;
  if v_revisions <> 0 then
    raise exception 'FE34: synthetic audit residue remains';
  end if;
  raise notice 'FE34 synthetic SQL assertions passed; no persistent fixture';
end;
$fe34$;
