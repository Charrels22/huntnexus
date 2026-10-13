-- FE-35 transactional regression: temp data only, no player session access.
do $fe35$
declare
 v_owner uuid := gen_random_uuid();
 v_other uuid := gen_random_uuid();
 v_sid uuid := gen_random_uuid();
 v_raw jsonb := '{"hunt":"Session: 00:43h\nXP Gain: 8,600","input":"","misc":"","party":""}'::jsonb;
 v_one jsonb := '{"hunt_analyse":{"xp_gain":8600,"duration_seconds":null},"validation":{"recognized_metric_count":1,"has_primary_hunt_analyzer":true},"methodology":{"stage":"session_parser_v1"}}'::jsonb;
 v_two jsonb := '{"hunt_analyse":{"xp_gain":8600,"duration_seconds":2580},"validation":{"recognized_metric_count":2,"has_primary_hunt_analyzer":true},"methodology":{"stage":"session_parser_v2"}}'::jsonb;
 v_setup jsonb := '{"source":"main_default","items":[{"item_name":"FE35 fixture"}],"captured_at":"2026-10-12T10:00:00Z"}'::jsonb;
 v_source jsonb;
 v_first jsonb;
 v_second jsonb;
 v_list jsonb;
 v_result jsonb;
 v_prior_id uuid;
 v_undo_id uuid;
 v_row record;
 v_revisions int;
begin
 insert into public.player_hunt_sessions(id,client_id,raw_blocks,parsed_data,parser_version,loadout_snapshot)
 values(v_sid,v_owner,v_raw,v_one,'session_parser_v1',v_setup);
 v_source := public.huntnexus_player_session_reparse_source(v_owner,v_sid);
 v_result := public.huntnexus_player_session_reparse_apply(
  v_owner,v_sid,v_source->>'fingerprint',v_two,true);
 if v_result->>'updated' <> 'true' then raise exception 'FE35 reparse source failed %',v_result; end if;
 v_prior_id := (v_result->>'revision_id')::uuid;
 v_result := public.huntnexus_player_session_revision_list(v_other,v_sid);
 if v_result->>'error' <> 'session_not_found' then raise exception 'FE35 foreign revision list exposed'; end if;
 v_list := public.huntnexus_player_session_revision_list(v_owner,v_sid);
 if jsonb_array_length(v_list->'revisions') <> 1 or
    v_list->'revisions'->0->>'revision_id' <> v_prior_id::text then
  raise exception 'FE35 list missing revision';
 end if;
 if v_list::text like '%8600%' or v_list::text like '%FE35 fixture%' then
  raise exception 'FE35 revision list exposed private data';
 end if;
 v_result := public.huntnexus_player_session_revision_restore_source(v_other,v_sid,v_prior_id);
 if v_result->>'error' <> 'revision_not_found' then raise exception 'FE35 foreign owner read permitted'; end if;
 v_first := public.huntnexus_player_session_revision_restore_source(v_owner,v_sid,v_prior_id);
 if v_first->'target_parsed_data' <> v_one then raise exception 'FE35 wrong restore payload'; end if;
 v_result := public.huntnexus_player_session_revision_restore(
   v_owner,v_sid,v_prior_id,v_first->>'fingerprint',false,true);
 if v_result->>'error' <> 'restore_confirmation_required' then raise exception 'FE35 confirmation absent'; end if;
 v_result := public.huntnexus_player_session_revision_restore(
   v_owner,v_sid,v_prior_id,v_first->>'fingerprint',true,false);
 if v_result->>'error' <> 'restore_accept_data_loss_required' then raise exception 'FE35 separate consent absent'; end if;
 v_result := public.huntnexus_player_session_revision_restore(
   v_other,v_sid,v_prior_id,v_first->>'fingerprint',true,true);
 if v_result->>'error' <> 'session_not_found' then raise exception 'FE35 foreign owner write permitted'; end if;
 v_result := public.huntnexus_player_session_revision_restore(
   v_owner,v_sid,gen_random_uuid(),v_first->>'fingerprint',true,true);
 if v_result->>'error' <> 'revision_not_found' then raise exception 'FE35 foreign revision accepted'; end if;
 v_result := public.huntnexus_player_session_revision_restore(
   v_owner,v_sid,v_prior_id,repeat('0',32),true,true);
 if v_result->>'error' <> 'restore_preview_stale' then raise exception 'FE35 bad fingerprint accepted'; end if;
 v_result := public.huntnexus_player_session_revision_restore(
   v_owner,v_sid,v_prior_id,v_first->>'fingerprint',true,true);
 if v_result->>'restored' <> 'true' then raise exception 'FE35 restore not applied: %',v_result; end if;
 v_undo_id := (v_result->>'undo_revision_id')::uuid;
 select raw_blocks,parsed_data,parser_version,loadout_snapshot into v_row
 from public.player_hunt_sessions where id=v_sid;
 if v_row.raw_blocks <> v_raw or v_row.parsed_data <> v_one or
    v_row.loadout_snapshot <> v_setup or v_row.parser_version <> 'session_parser_v1'
 then raise exception 'FE35 restore mutated raw, setup or wrong data'; end if;
 v_result := public.huntnexus_player_session_revision_restore(
   v_owner,v_sid,v_prior_id,v_first->>'fingerprint',true,true);
 if v_result->>'error' <> 'restore_preview_stale' then raise exception 'FE35 replay accepted'; end if;
 v_second := public.huntnexus_player_session_revision_restore_source(v_owner,v_sid,v_undo_id);
 if v_second->'target_parsed_data' <> v_two then raise exception 'FE35 undo not retained'; end if;
 v_result := public.huntnexus_player_session_revision_restore(
   v_owner,v_sid,v_undo_id,v_second->>'fingerprint',true,true);
 if v_result->>'restored' <> 'true' then raise exception 'FE35 undo failed'; end if;
 select raw_blocks,parsed_data,parser_version,loadout_snapshot into v_row
 from public.player_hunt_sessions where id=v_sid;
 if v_row.raw_blocks <> v_raw or v_row.parsed_data <> v_two or
    v_row.loadout_snapshot <> v_setup or v_row.parser_version <> 'session_parser_v2'
 then raise exception 'FE35 undo altered protected data'; end if;
 select count(*) into v_revisions from public.player_session_parse_revisions where session_id=v_sid;
 if v_revisions <> 3 then raise exception 'FE35 revision history not append-only'; end if;
 delete from public.player_hunt_sessions where id=v_sid and client_id=v_owner;
 select count(*) into v_revisions from public.player_session_parse_revisions where session_id=v_sid;
 if v_revisions <> 0 then raise exception 'FE35 synthetic audit residue'; end if;
 raise notice 'FE35 all owner/privacy/restore/undo invariants PASS';
end;
$fe35$;
