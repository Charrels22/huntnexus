-- HuntNexus Brain — Phase 26 server-only database hardening.
-- The public app reaches Supabase exclusively through the Cloudflare Worker using service_role.

-- Remove direct Data API access for browser/client roles.
revoke usage on schema public from anon, authenticated;
revoke all privileges on all tables in schema public from anon, authenticated;
revoke all privileges on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

-- Ensure the server-side role retains the capabilities used by the Worker and ingestion jobs.
grant usage on schema public to service_role;
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

-- Future objects created by postgres should remain server-only by default.
alter default privileges for role postgres in schema public
  revoke all privileges on tables from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke all privileges on sequences from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

alter default privileges for role postgres in schema public
  grant all privileges on tables to service_role;

alter default privileges for role postgres in schema public
  grant all privileges on sequences to service_role;

alter default privileges for role postgres in schema public
  grant execute on functions to service_role;

-- Pin search_path for HuntNexus-owned functions to remove mutable-search-path risk.
do $$
declare
  r record;
begin
  for r in
    select
      n.nspname,
      p.proname,
      pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and (
        p.proname like 'huntnexus_%'
        or p.proname='guard_rubinot_override_update'
      )
  loop
    execute format(
      'alter function %I.%I(%s) set search_path = public, extensions, net',
      r.nspname,r.proname,r.args
    );
  end loop;
end;
$$;
