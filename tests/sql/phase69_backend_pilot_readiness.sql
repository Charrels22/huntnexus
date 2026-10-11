-- Phase 69 — backend pilot readiness regression.

do $$
declare
  v jsonb;
begin
  v := public.huntnexus_product_readiness_audit();

  if v #>> '{methodology,stage}' <> 'product_readiness_audit_v2'
     or coalesce((v #>> '{summary,backend_pilot_ready}')::boolean,false) is not true
     or coalesce((v #>> '{summary,blocked}')::int,99) <> 0 then
    raise exception 'Backend pilot readiness regression';
  end if;

  if (v #>> '{summary,planner_eligible_hunts}')::int <> 454
     or (v #>> '{summary,planner_core_complete_hunts}')::int <> 454 then
    raise exception 'Canonical hunt readiness regression';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v->'checks') c
    where coalesce((c->>'ready')::boolean,false) is not true
  ) then
    raise exception 'A required backend readiness check is not green';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','backend_pilot_readiness',
  'required_backend_checks_green',true
) as regression_summary;
