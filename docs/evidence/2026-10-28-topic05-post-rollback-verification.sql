-- Topic 5 rollback verification. Read-only; run only after the 0164 rollback.
-- Row counts must be compared with the baseline captured immediately before
-- applying the migration. This query never lists user or factor identities.

with rollback_checks as (
  select
    to_regprocedure('public.huntnexus_auth_session_gate(uuid,uuid)') is null as function_absent,
    to_regclass('auth.sessions')::text as sessions_table,
    to_regclass('auth.mfa_factors')::text as factors_table,
    (select pg_catalog.count(*) from auth.users) as auth_user_rows,
    (select pg_catalog.count(*) from auth.sessions) as auth_session_rows,
    (select pg_catalog.count(*) from auth.mfa_factors) as auth_factor_rows
)
select
  rollback_checks.*,
  function_absent
    and sessions_table='auth.sessions'
    and factors_table='auth.mfa_factors' as verification_pass
from rollback_checks;

-- Expected:
-- exactly one row;
-- function_absent and verification_pass = true;
-- all three counts equal the pre-migration baseline captured in the runbook.
