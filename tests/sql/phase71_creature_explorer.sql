-- Phase 71 — Creature Explorer read contract regression.

do $$
declare
  v_search jsonb;
  v_key text;
  v_detail jsonb;
begin
  v_search := public.huntnexus_search_creatures('cobra',10);

  if v_search #>> '{methodology,stage}' <> 'creature_search_v1'
     or coalesce((v_search #>> '{summary,returned}')::int,0) < 1 then
    raise exception 'Creature search regression';
  end if;

  v_key := v_search #>> '{creatures,0,creature_key}';

  if nullif(v_key,'') is null then
    raise exception 'Creature search returned no key';
  end if;

  v_detail := public.huntnexus_creature_detail(v_key);

  if v_detail #>> '{methodology,stage}' <> 'creature_detail_v1'
     or v_detail #>> '{creature,creature_key}' <> v_key
     or nullif(v_detail #>> '{creature,name}','') is null
     or jsonb_typeof(coalesce(v_detail->'vulnerabilities','[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(v_detail->'abilities','[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(v_detail->'loot','[]'::jsonb)) <> 'array' then
    raise exception 'Creature detail regression';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','creature_explorer_read_contract'
) as regression_summary;
