-- Topic 5: server-only gate for active Supabase sessions and enrolled MFA.
-- Read-only over auth schema; this migration does not change Auth users,
-- providers, passwords, factors or project configuration.

set lock_timeout = '5s';
set statement_timeout = '60s';

create or replace function public.huntnexus_auth_session_gate(
  p_auth_user_id uuid,
  p_session_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','auth','extensions'
as $function$
  select jsonb_build_object(
    'active_session',
      p_auth_user_id is not null
      and p_session_id is not null
      and exists(
        select 1
        from auth.sessions s
        where s.id=p_session_id
          and s.user_id=p_auth_user_id
          and (s.not_after is null or s.not_after>now())
      ),
    'verified_factor_count',(
      select count(*)
      from auth.mfa_factors f
      where f.user_id=p_auth_user_id
        and f.status::text='verified'
        and f.factor_type::text in('totp','phone','webauthn')
    ),
    'requires_aal2',true
  );
$function$;

revoke all on function public.huntnexus_auth_session_gate(uuid,uuid)
  from public,anon,authenticated;
grant execute on function public.huntnexus_auth_session_gate(uuid,uuid)
  to service_role;

comment on function public.huntnexus_auth_session_gate(uuid,uuid) is
  'Server-only Topic 5 gate. Confirms a validated JWT session still exists and the user has a verified second factor.';

reset lock_timeout;
reset statement_timeout;
