-- FE-39: READ ONLY parity against the established 459-entry audit.
-- Validate two factual hunts plus the first incomplete source-core example.
do $fe39$
declare
  v_entry jsonb;
  v_proof jsonb;
  v_hunt text;
  v_key text;
  v_missing jsonb;
begin
  for v_entry in
    select value from jsonb_array_elements(
      public.huntnexus_hunt_catalog_readiness_audit()->'entries'
    ) as e(value)
    where value->>'hunt_key' in ('cobra-bastion','forest-of-life')
      or value->>'hunt_key'=(
        select p.value->>'hunt_key' from jsonb_array_elements(
          public.huntnexus_hunt_catalog_readiness_audit()->'entries'
        ) as p(value)
        where p.value->>'readiness_status'='source_core_incomplete'
        limit 1
      )
  loop
    v_hunt:=v_entry->>'hunt_key';
    v_proof:=public.huntnexus_hunt_evidence_context(v_hunt);
    if v_proof->>'hunt_key'<>v_hunt or v_proof->>'error' is not null then
      raise exception 'FE39 missing scoped hunt: %',v_hunt;
    end if;
    if coalesce((v_proof->>'source_core_complete')::boolean,false)
       is distinct from coalesce((v_entry->>'source_core_complete')::boolean,false) then
      raise exception 'FE39 source core differs from established audit: %',v_hunt;
    end if;
    foreach v_key in array array[
      'creature_count','creatures_with_elements','creatures_with_detail',
      'creatures_with_abilities','creatures_with_loot',
      'elements_complete','creature_detail_complete','abilities_complete','loot_complete'
    ] loop
      if (v_proof->'coverage'->v_key) is distinct from (v_entry->'coverage'->v_key) then
        raise exception 'FE39 dimension % differs for %',v_key,v_hunt;
      end if;
    end loop;
    if (v_proof->'methodology'->>'scoped_to_one_hunt')<>'true'
       or v_proof->'source'?'snapshot_id'
       or v_proof->'source'?'id' then
      raise exception 'FE39 privacy/source methodology invalid';
    end if;
  end loop;
  v_missing:=public.huntnexus_hunt_evidence_context('missing-fe39-fixture');
  if v_missing->>'error'<>'hunt_not_found' then
    raise exception 'FE39 missing hunt must not inherit another source';
  end if;
  raise notice 'FE39 scoped evidence parity passed: complete, incomplete and missing';
end;
$fe39$;
