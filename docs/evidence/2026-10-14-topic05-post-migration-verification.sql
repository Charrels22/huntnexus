-- Topic 5 production verification. Read-only; run only after 0164 is applied.

with function_checks as (
  select
    p.oid::regprocedure::text as function_signature,
    p.prosecdef as security_definer,
    p.provolatile = 's' as stable,
    p.proconfig @> array['search_path=""'] as empty_search_path,
    exists (
      select 1
      from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
      where acl.grantee=0 and acl.privilege_type='EXECUTE'
    ) as public_execute,
    has_function_privilege('anon',p.oid,'execute') as anon_execute,
    has_function_privilege('authenticated',p.oid,'execute') as authenticated_execute,
    has_function_privilege('service_role',p.oid,'execute') as service_role_execute
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='huntnexus_auth_session_gate'
    and p.proargtypes='2950 2950'::oidvector
)
select
  function_checks.*,
  security_definer
    and stable
    and empty_search_path
    and not public_execute
    and not anon_execute
    and not authenticated_execute
    and service_role_execute as verification_pass
from function_checks;

with null_check as (
  select public.huntnexus_auth_session_gate(null,null) as null_input_result
)
select
  null_input_result,
  null_input_result=pg_catalog.jsonb_build_object(
    'active_session',false,
    'verified_factor_count',0,
    'requires_aal2',true
  ) as verification_pass
from null_check;

with schema_checks as (
  select
    to_regclass('auth.sessions')::text as sessions_table,
    to_regclass('auth.mfa_factors')::text as factors_table,
    exists (
      select 1 from information_schema.columns
      where table_schema='auth' and table_name='sessions' and column_name='not_after'
    ) as sessions_has_not_after,
    exists (
      select 1 from information_schema.columns
      where table_schema='auth' and table_name='mfa_factors' and column_name='status'
    ) as factors_has_status,
    exists (
      select 1 from information_schema.columns
      where table_schema='auth' and table_name='mfa_factors' and column_name='factor_type'
    ) as factors_has_type
)
select
  schema_checks.*,
  sessions_table='auth.sessions'
    and factors_table='auth.mfa_factors'
    and sessions_has_not_after
    and factors_has_status
    and factors_has_type as verification_pass
from schema_checks;

-- Expected:
-- exactly one function row;
-- security_definer, stable and empty_search_path = true;
-- public/anon/authenticated execute = false; service_role execute = true;
-- null_input_result = {"active_session":false,"verified_factor_count":0,"requires_aal2":true};
-- both tables and all three expected columns present.
-- every returned verification_pass = true.
