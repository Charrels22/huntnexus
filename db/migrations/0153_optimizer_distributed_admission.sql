-- HuntNexus FE-19: distributed, transactional admission control for the
-- expensive explicit universal optimizer endpoint.
-- Service-role only, RLS on, no raw IP or client identifiers stored.
-- Every admitted job receives a short expiring lease; finally releases it.
-- PG advisory xact lock serializes admission across all Cloudflare isolates.

create table if not exists public.huntnexus_optimizer_rate_state (
  subject_hash text primary key check (subject_hash ~ '^[0-9a-f]{64}$'),
  window_start timestamptz not null,
  started_count integer not null default 0 check (started_count >= 0)
);

create table if not exists public.huntnexus_optimizer_leases (
  lease_id uuid primary key default gen_random_uuid(),
  subject_hash text not null check (subject_hash ~ '^[0-9a-f]{64}$'),
  started_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null
);

create index if not exists idx_huntnexus_optimizer_leases_expiration
  on public.huntnexus_optimizer_leases (expires_at);
create index if not exists idx_huntnexus_optimizer_leases_subject
  on public.huntnexus_optimizer_leases (subject_hash);

alter table public.huntnexus_optimizer_rate_state enable row level security;
alter table public.huntnexus_optimizer_leases enable row level security;

revoke all on table public.huntnexus_optimizer_rate_state
  from public, anon, authenticated;
revoke all on table public.huntnexus_optimizer_leases
  from public, anon, authenticated;
grant select, insert, update, delete on table public.huntnexus_optimizer_rate_state to service_role;
grant select, insert, update, delete on table public.huntnexus_optimizer_leases to service_role;

create or replace function public.huntnexus_optimizer_admit(p_subject_hash text)
returns jsonb
language plpgsql
security invoker
set search_path = public, extensions
as $function$
declare
  v_now timestamptz := clock_timestamp();
  v_state public.huntnexus_optimizer_rate_state%rowtype;
  v_global_active integer;
  v_subject_active integer;
  v_retry integer;
  v_lease uuid;
begin
  if p_subject_hash is null or p_subject_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('allowed',false,'reason','invalid_subject','retry_after',60);
  end if;

  -- A single short transaction lock, never held during the expensive RPC.
  perform pg_advisory_xact_lock(492817, 173204);
  delete from public.huntnexus_optimizer_leases where expires_at <= v_now;
  delete from public.huntnexus_optimizer_rate_state
    where window_start < v_now - interval '24 hours';

  select * into v_state
  from public.huntnexus_optimizer_rate_state
  where subject_hash = p_subject_hash;

  if found and v_state.window_start > v_now - interval '10 minutes'
    and v_state.started_count >= 12 then
    v_retry := greatest(1, ceil(extract(epoch from
      (v_state.window_start + interval '10 minutes' - v_now)))::integer);
    return jsonb_build_object(
      'allowed',false,'reason','rate_limit','retry_after',v_retry,
      'methodology','distributed_optimizer_admission_v1'
    );
  end if;

  select count(*) into v_subject_active
  from public.huntnexus_optimizer_leases
  where subject_hash = p_subject_hash;
  if v_subject_active >= 1 then
    return jsonb_build_object(
      'allowed',false,'reason','subject_busy','retry_after',10,
      'methodology','distributed_optimizer_admission_v1'
    );
  end if;

  select count(*) into v_global_active
  from public.huntnexus_optimizer_leases;
  if v_global_active >= 2 then
    return jsonb_build_object(
      'allowed',false,'reason','global_busy','retry_after',10,
      'methodology','distributed_optimizer_admission_v1'
    );
  end if;

  insert into public.huntnexus_optimizer_leases(subject_hash,expires_at)
  values(p_subject_hash,v_now + interval '35 seconds')
  returning lease_id into v_lease;

  insert into public.huntnexus_optimizer_rate_state(subject_hash,window_start,started_count)
  values(p_subject_hash,v_now,1)
  on conflict (subject_hash) do update
  set window_start = case
        when public.huntnexus_optimizer_rate_state.window_start <= v_now - interval '10 minutes'
        then v_now else public.huntnexus_optimizer_rate_state.window_start end,
      started_count = case
        when public.huntnexus_optimizer_rate_state.window_start <= v_now - interval '10 minutes'
        then 1 else public.huntnexus_optimizer_rate_state.started_count + 1 end;

  return jsonb_build_object(
    'allowed',true,'lease_id',v_lease,
    'methodology','distributed_optimizer_admission_v1',
    'limits',jsonb_build_object('max_active_global',2,'max_active_subject',1,
      'max_subject_starts_per_10_minutes',12,'lease_seconds',35)
  );
end;
$function$;

create or replace function public.huntnexus_optimizer_release(
  p_lease_id uuid,p_subject_hash text
)
returns boolean
language sql
security invoker
set search_path = public, extensions
as $function$
  with removed as (
    delete from public.huntnexus_optimizer_leases
    where lease_id=p_lease_id and subject_hash=p_subject_hash
    returning lease_id
  )
  select exists(select 1 from removed);
$function$;

revoke all on function public.huntnexus_optimizer_admit(text)
  from public, anon, authenticated;
grant execute on function public.huntnexus_optimizer_admit(text) to service_role;
revoke all on function public.huntnexus_optimizer_release(uuid,text)
  from public, anon, authenticated;
grant execute on function public.huntnexus_optimizer_release(uuid,text) to service_role;
