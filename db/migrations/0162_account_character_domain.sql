-- HuntNexus Topic 4 — account 1:N characters, additive legacy migration.
-- Authentication methods are intentionally unchanged. The Worker remains the
-- only caller that turns a verified Supabase auth user into p_auth_user_id.
-- client_id remains a compatibility scope while character_id becomes the
-- ownership key for account-managed private data.

set lock_timeout='5s';
set statement_timeout='60s';

create table if not exists public.huntnexus_accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique,
  active_character_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table if not exists public.player_characters (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.huntnexus_accounts(id) on delete cascade,
  legacy_client_id uuid not null unique default gen_random_uuid(),
  character_name text,
  world_name text,
  vocation text,
  level integer check (level is null or level between 1 and 5000),
  status text not null default 'active' check (status in ('active','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (account_id,id),
  unique (legacy_client_id,id),
  check (
    (status='active' and archived_at is null)
    or (status='archived' and archived_at is not null)
  )
);

create unique index if not exists player_characters_account_identity_uq
  on public.player_characters(
    account_id,
    lower(coalesce(world_name,'')),
    lower(character_name)
  )
  where status='active' and character_name is not null;

create index if not exists player_characters_account_status_idx
  on public.player_characters(account_id,status,updated_at desc);

do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conname='huntnexus_accounts_active_character_owner_fk'
      and conrelid='public.huntnexus_accounts'::regclass
  ) then
    alter table public.huntnexus_accounts
      add constraint huntnexus_accounts_active_character_owner_fk
      foreign key (id,active_character_id)
      references public.player_characters(account_id,id)
      deferrable initially deferred;
  end if;
end $$;

create index if not exists huntnexus_accounts_active_character_idx
  on public.huntnexus_accounts(active_character_id)
  where active_character_id is not null;

alter table public.huntnexus_accounts enable row level security;
alter table public.player_characters enable row level security;
revoke all on table public.huntnexus_accounts from public,anon,authenticated;
revoke all on table public.player_characters from public,anon,authenticated;
grant select,insert,update,delete on table public.huntnexus_accounts to service_role;
grant select,insert,update,delete on table public.player_characters to service_role;

alter table public.player_account_bindings
  add column if not exists account_id uuid;

alter table public.player_character_profiles
  add column if not exists character_id uuid;
alter table public.player_character_inventory
  add column if not exists character_id uuid;
alter table public.player_hunt_build_choices
  add column if not exists character_id uuid;
alter table public.player_hunt_sessions
  add column if not exists character_id uuid;
alter table public.player_session_parse_revisions
  add column if not exists character_id uuid;

-- Every existing authenticated binding becomes one account with one initial
-- character. Profile identity is copied when available; no game value is
-- inferred for missing profiles.
insert into public.huntnexus_accounts(auth_user_id,created_at,updated_at,last_seen_at)
select b.auth_user_id,b.created_at,b.updated_at,b.last_seen_at
from public.player_account_bindings b
on conflict (auth_user_id) do update set
  last_seen_at=greatest(public.huntnexus_accounts.last_seen_at,excluded.last_seen_at),
  updated_at=greatest(public.huntnexus_accounts.updated_at,excluded.updated_at);

insert into public.player_characters(
  account_id,legacy_client_id,character_name,world_name,vocation,level,
  status,created_at,updated_at
)
select
  a.id,b.client_id,p.character_name,p.world_name,p.vocation,p.level,
  'active',coalesce(p.created_at,b.created_at),greatest(b.updated_at,coalesce(p.updated_at,b.updated_at))
from public.player_account_bindings b
join public.huntnexus_accounts a on a.auth_user_id=b.auth_user_id
left join public.player_character_profiles p on p.client_id=b.client_id
on conflict (legacy_client_id) do nothing;

update public.player_account_bindings b
set account_id=a.id
from public.huntnexus_accounts a
where a.auth_user_id=b.auth_user_id
  and b.account_id is distinct from a.id;

update public.huntnexus_accounts a
set active_character_id=c.id,
    updated_at=greatest(a.updated_at,c.updated_at)
from public.player_characters c
where c.account_id=a.id
  and a.active_character_id is null;

update public.player_character_profiles p
set character_id=c.id
from public.player_characters c
where c.legacy_client_id=p.client_id and p.character_id is null;

update public.player_character_inventory i
set character_id=c.id
from public.player_characters c
where c.legacy_client_id=i.client_id and i.character_id is null;

update public.player_hunt_build_choices b
set character_id=c.id
from public.player_characters c
where c.legacy_client_id=b.client_id and b.character_id is null;

update public.player_hunt_sessions s
set character_id=c.id
from public.player_characters c
where c.legacy_client_id=s.client_id and s.character_id is null;

update public.player_session_parse_revisions r
set character_id=c.id
from public.player_characters c
where c.legacy_client_id=r.client_id and r.character_id is null;

alter table public.player_account_bindings
  alter column account_id set not null;
do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conname='player_account_bindings_account_fk'
      and conrelid='public.player_account_bindings'::regclass
  ) then
    alter table public.player_account_bindings
      add constraint player_account_bindings_account_fk
      foreign key (account_id) references public.huntnexus_accounts(id) on delete restrict;
  end if;
  if not exists(
    select 1 from pg_constraint
    where conname='player_account_bindings_account_uq'
      and conrelid='public.player_account_bindings'::regclass
  ) then
    alter table public.player_account_bindings
      add constraint player_account_bindings_account_uq unique (account_id);
  end if;
end $$;

-- A mapped row cannot pair one legacy client scope with another character.
-- NULL character_id remains valid only for legacy guest data that has not been
-- attached to an authenticated account yet.
do $$
begin
  if not exists(select 1 from pg_constraint where conname='player_character_profiles_scope_fk' and conrelid='public.player_character_profiles'::regclass) then
    alter table public.player_character_profiles add constraint player_character_profiles_scope_fk
      foreign key (client_id,character_id) references public.player_characters(legacy_client_id,id) not valid;
  end if;
  if not exists(select 1 from pg_constraint where conname='player_character_inventory_scope_fk' and conrelid='public.player_character_inventory'::regclass) then
    alter table public.player_character_inventory add constraint player_character_inventory_scope_fk
      foreign key (client_id,character_id) references public.player_characters(legacy_client_id,id) not valid;
  end if;
  if not exists(select 1 from pg_constraint where conname='player_hunt_build_choices_scope_fk' and conrelid='public.player_hunt_build_choices'::regclass) then
    alter table public.player_hunt_build_choices add constraint player_hunt_build_choices_scope_fk
      foreign key (client_id,character_id) references public.player_characters(legacy_client_id,id) not valid;
  end if;
  if not exists(select 1 from pg_constraint where conname='player_hunt_sessions_scope_fk' and conrelid='public.player_hunt_sessions'::regclass) then
    alter table public.player_hunt_sessions add constraint player_hunt_sessions_scope_fk
      foreign key (client_id,character_id) references public.player_characters(legacy_client_id,id) not valid;
  end if;
  if not exists(select 1 from pg_constraint where conname='player_session_parse_revisions_scope_fk' and conrelid='public.player_session_parse_revisions'::regclass) then
    alter table public.player_session_parse_revisions add constraint player_session_parse_revisions_scope_fk
      foreign key (client_id,character_id) references public.player_characters(legacy_client_id,id) not valid;
  end if;
end $$;

alter table public.player_character_profiles validate constraint player_character_profiles_scope_fk;
alter table public.player_character_inventory validate constraint player_character_inventory_scope_fk;
alter table public.player_hunt_build_choices validate constraint player_hunt_build_choices_scope_fk;
alter table public.player_hunt_sessions validate constraint player_hunt_sessions_scope_fk;
alter table public.player_session_parse_revisions validate constraint player_session_parse_revisions_scope_fk;

create unique index if not exists player_character_profiles_character_uq
  on public.player_character_profiles(character_id)
  where character_id is not null;
create unique index if not exists player_character_inventory_character_main_slot_uq
  on public.player_character_inventory(character_id,selection_key)
  where character_id is not null and storage_kind='main';
create unique index if not exists player_character_inventory_character_backpack_item_uq
  on public.player_character_inventory(character_id,selection_key,item_key)
  where character_id is not null and storage_kind='backpack';
create index if not exists player_character_inventory_character_idx
  on public.player_character_inventory(character_id,storage_kind,selection_key)
  where character_id is not null;
create unique index if not exists player_hunt_build_choices_character_uq
  on public.player_hunt_build_choices(character_id,hunt_key,vocation)
  where character_id is not null;
create index if not exists player_hunt_sessions_character_created_idx
  on public.player_hunt_sessions(character_id,created_at desc)
  where character_id is not null;
create index if not exists player_session_parse_revisions_character_session_idx
  on public.player_session_parse_revisions(character_id,session_id,revised_at desc)
  where character_id is not null;

create or replace function public.huntnexus_private_character_scope()
returns trigger
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
begin
  if new.character_id is null then
    select c.id into new.character_id
    from public.player_characters c
    where c.legacy_client_id=new.client_id
    limit 1;
  end if;
  return new;
end;
$function$;

drop trigger if exists player_character_profiles_character_scope on public.player_character_profiles;
create trigger player_character_profiles_character_scope
before insert or update of client_id,character_id on public.player_character_profiles
for each row execute function public.huntnexus_private_character_scope();

create or replace function public.huntnexus_profile_character_identity_sync()
returns trigger
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
begin
  if new.character_id is not null then
    update public.player_characters
    set character_name=new.character_name,
        world_name=new.world_name,
        vocation=new.vocation,
        level=new.level,
        updated_at=now()
    where id=new.character_id;
  end if;
  return new;
end;
$function$;

drop trigger if exists player_character_profiles_identity_sync on public.player_character_profiles;
create trigger player_character_profiles_identity_sync
after insert or update of character_name,world_name,vocation,level,character_id
on public.player_character_profiles
for each row execute function public.huntnexus_profile_character_identity_sync();

drop trigger if exists player_character_inventory_character_scope on public.player_character_inventory;
create trigger player_character_inventory_character_scope
before insert or update of client_id,character_id on public.player_character_inventory
for each row execute function public.huntnexus_private_character_scope();

drop trigger if exists player_hunt_build_choices_character_scope on public.player_hunt_build_choices;
create trigger player_hunt_build_choices_character_scope
before insert or update of client_id,character_id on public.player_hunt_build_choices
for each row execute function public.huntnexus_private_character_scope();

drop trigger if exists player_hunt_sessions_character_scope on public.player_hunt_sessions;
create trigger player_hunt_sessions_character_scope
before insert or update of client_id,character_id on public.player_hunt_sessions
for each row execute function public.huntnexus_private_character_scope();

drop trigger if exists player_session_parse_revisions_character_scope on public.player_session_parse_revisions;
create trigger player_session_parse_revisions_character_scope
before insert or update of client_id,character_id on public.player_session_parse_revisions
for each row execute function public.huntnexus_private_character_scope();

-- Preserve account_resolve compatibility: insertion into the legacy binding
-- provisions the account/default character and maps any pre-existing guest data.
create or replace function public.huntnexus_account_binding_provision()
returns trigger
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_account_id uuid;
  v_character_id uuid;
begin
  insert into public.huntnexus_accounts(auth_user_id,created_at,updated_at,last_seen_at)
  values(new.auth_user_id,coalesce(new.created_at,now()),coalesce(new.updated_at,now()),coalesce(new.last_seen_at,now()))
  on conflict (auth_user_id) do update set
    last_seen_at=greatest(public.huntnexus_accounts.last_seen_at,excluded.last_seen_at),
    updated_at=greatest(public.huntnexus_accounts.updated_at,excluded.updated_at)
  returning id into v_account_id;

  new.account_id:=v_account_id;

  insert into public.player_characters(
    account_id,legacy_client_id,character_name,world_name,vocation,level,status
  )
  select
    v_account_id,new.client_id,p.character_name,p.world_name,p.vocation,p.level,'active'
  from (select 1) anchor
  left join public.player_character_profiles p on p.client_id=new.client_id
  on conflict (legacy_client_id) do nothing;

  select c.id into v_character_id
  from public.player_characters c
  where c.legacy_client_id=new.client_id and c.account_id=v_account_id;

  if v_character_id is null then
    raise exception 'legacy_client_scope_owned_by_another_account';
  end if;

  update public.huntnexus_accounts
  set active_character_id=coalesce(active_character_id,v_character_id),updated_at=now()
  where id=v_account_id;

  update public.player_character_profiles set character_id=v_character_id
    where client_id=new.client_id and character_id is null;
  update public.player_character_inventory set character_id=v_character_id
    where client_id=new.client_id and character_id is null;
  update public.player_hunt_build_choices set character_id=v_character_id
    where client_id=new.client_id and character_id is null;
  update public.player_hunt_sessions set character_id=v_character_id
    where client_id=new.client_id and character_id is null;
  update public.player_session_parse_revisions set character_id=v_character_id
    where client_id=new.client_id and character_id is null;

  return new;
end;
$function$;

drop trigger if exists player_account_bindings_provision on public.player_account_bindings;
create trigger player_account_bindings_provision
before insert or update of auth_user_id,client_id on public.player_account_bindings
for each row execute function public.huntnexus_account_binding_provision();

create or replace function public.huntnexus_account_binding_cleanup()
returns trigger
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
begin
  if not exists(
    select 1 from public.player_account_bindings b where b.account_id=old.account_id
  ) then
    update public.huntnexus_accounts set active_character_id=null where id=old.account_id;
    delete from public.huntnexus_accounts where id=old.account_id;
  end if;
  return old;
end;
$function$;

drop trigger if exists player_account_bindings_cleanup on public.player_account_bindings;
create trigger player_account_bindings_cleanup
after delete on public.player_account_bindings
for each row execute function public.huntnexus_account_binding_cleanup();

create or replace function public.huntnexus_account_characters(
  p_auth_user_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
with account as (
  select a.id,a.active_character_id,a.created_at,a.last_seen_at
  from public.huntnexus_accounts a
  where a.auth_user_id=p_auth_user_id
), characters as (
  select
    c.id as character_id,c.character_name,c.world_name,c.vocation,c.level,
    c.status,c.created_at,c.updated_at,
    c.id=a.active_character_id as active
  from account a
  join public.player_characters c on c.account_id=a.id
)
select case
  when not exists(select 1 from account) then
    jsonb_build_object('exists',false,'characters','[]'::jsonb,'active_character_id',null)
  else jsonb_build_object(
    'exists',true,
    'account_id',(select id from account),
    'active_character_id',(select active_character_id from account),
    'characters',coalesce((select jsonb_agg(to_jsonb(characters) order by active desc,updated_at desc) from characters),'[]'::jsonb)
  )
end;
$function$;

create or replace function public.huntnexus_character_create(
  p_auth_user_id uuid,
  p_character jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_account_id uuid;
  v_character_id uuid;
  v_legacy_client_id uuid;
  v_name text:=nullif(trim(p_character->>'character_name'),'');
  v_world text:=nullif(trim(p_character->>'world_name'),'');
  v_vocation text:=nullif(trim(p_character->>'vocation'),'');
  v_level integer;
begin
  if p_auth_user_id is null then
    return jsonb_build_object('error','auth_user_id_required');
  end if;
  if v_name is null or length(v_name)>120 then
    return jsonb_build_object('error','character_name_required');
  end if;
  if length(coalesce(v_world,''))>120 or length(coalesce(v_vocation,''))>20 then
    return jsonb_build_object('error','invalid_character_identity');
  end if;
  if coalesce(p_character->>'level','') ~ '^\d+$' then
    v_level:=(p_character->>'level')::integer;
    if v_level not between 1 and 5000 then
      return jsonb_build_object('error','invalid_character_level');
    end if;
  end if;

  select a.id into v_account_id
  from public.huntnexus_accounts a
  where a.auth_user_id=p_auth_user_id
  for update;

  if v_account_id is null then
    return jsonb_build_object('error','account_not_found');
  end if;

  if exists(
    select 1 from public.player_characters c
    where c.account_id=v_account_id and c.status='active'
      and lower(c.character_name)=lower(v_name)
      and lower(coalesce(c.world_name,''))=lower(coalesce(v_world,''))
  ) then
    return jsonb_build_object('error','character_already_exists');
  end if;

  insert into public.player_characters(
    account_id,character_name,world_name,vocation,level,status
  ) values(
    v_account_id,v_name,v_world,v_vocation,v_level,'active'
  ) returning id,legacy_client_id into v_character_id,v_legacy_client_id;

  insert into public.player_character_profiles(
    client_id,character_id,character_name,world_name,vocation,level,updated_at
  ) values(
    v_legacy_client_id,v_character_id,v_name,v_world,v_vocation,v_level,now()
  );

  update public.huntnexus_accounts
  set active_character_id=coalesce(active_character_id,v_character_id),updated_at=now()
  where id=v_account_id;

  return jsonb_build_object(
    'created',true,
    'character_id',v_character_id,
    'active_character_id',(select active_character_id from public.huntnexus_accounts where id=v_account_id)
  );
end;
$function$;

create or replace function public.huntnexus_character_set_active(
  p_auth_user_id uuid,
  p_character_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_account_id uuid;
begin
  select a.id into v_account_id
  from public.huntnexus_accounts a
  join public.player_characters c
    on c.account_id=a.id and c.id=p_character_id and c.status='active'
  where a.auth_user_id=p_auth_user_id
  for update of a;

  if v_account_id is null then
    return jsonb_build_object('error','character_not_found_or_not_owned');
  end if;

  update public.huntnexus_accounts
  set active_character_id=p_character_id,updated_at=now(),last_seen_at=now()
  where id=v_account_id;

  return jsonb_build_object('updated',true,'active_character_id',p_character_id);
end;
$function$;

create or replace function public.huntnexus_character_scope(
  p_auth_user_id uuid,
  p_character_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path to 'public','extensions'
as $function$
select case
  when c.id is null then jsonb_build_object('error','character_not_found_or_not_owned')
  else jsonb_build_object(
    'resolved',true,
    'account_id',a.id,
    'character_id',c.id,
    'legacy_client_id',c.legacy_client_id,
    'active',c.id=a.active_character_id
  )
end
from (
  select * from public.huntnexus_accounts where auth_user_id=p_auth_user_id limit 1
) a
left join public.player_characters c
  on c.account_id=a.id
 and c.id=coalesce(p_character_id,a.active_character_id)
 and c.status='active'
right join (select 1 anchor) x on true;
$function$;

-- Replace the legacy unbind guard with an account-aware equivalent. Login,
-- tokens and recovery do not change; the function only expands the private
-- data check from one canonical client_id to every owned character.
create or replace function public.huntnexus_account_unbind(
  p_auth_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_client uuid;
  v_account_id uuid;
  v_count integer;
begin
  if p_auth_user_id is null then
    return jsonb_build_object('unbound',false,'error','auth_user_id_required','private_data_deleted',false);
  end if;

  perform pg_advisory_xact_lock(20261011,hashtext(p_auth_user_id::text));

  select b.client_id,b.account_id into v_client,v_account_id
  from public.player_account_bindings b
  where b.auth_user_id=p_auth_user_id
  for update;

  if v_client is null then
    return jsonb_build_object('unbound',false,'private_data_deleted',false);
  end if;

  if exists(
       select 1 from public.player_character_profiles p
       join public.player_characters c on c.id=p.character_id
       where c.account_id=v_account_id
     )
     or exists(
       select 1 from public.player_character_inventory i
       join public.player_characters c on c.id=i.character_id
       where c.account_id=v_account_id
     )
     or exists(
       select 1 from public.player_hunt_build_choices b
       join public.player_characters c on c.id=b.character_id
       where c.account_id=v_account_id
     )
     or exists(
       select 1 from public.player_hunt_sessions s
       join public.player_characters c on c.id=s.character_id
       where c.account_id=v_account_id
     )
     or exists(select 1 from public.player_character_profiles where client_id=v_client and character_id is null)
     or exists(select 1 from public.player_character_inventory where client_id=v_client and character_id is null)
     or exists(select 1 from public.player_hunt_build_choices where client_id=v_client and character_id is null)
     or exists(select 1 from public.player_hunt_sessions where client_id=v_client and character_id is null)
  then
    return jsonb_build_object(
      'unbound',false,
      'error','private_data_present_unbind_blocked',
      'private_data_deleted',false,
      'canonical_client_id_still_protected',true,
      'account_characters_protected',true
    );
  end if;

  delete from public.player_account_bindings
  where auth_user_id=p_auth_user_id and account_id=v_account_id;
  get diagnostics v_count=row_count;

  return jsonb_build_object('unbound',v_count=1,'private_data_deleted',false);
end;
$function$;

revoke all on function public.huntnexus_private_character_scope() from public,anon,authenticated;
revoke all on function public.huntnexus_profile_character_identity_sync() from public,anon,authenticated;
revoke all on function public.huntnexus_account_binding_provision() from public,anon,authenticated;
revoke all on function public.huntnexus_account_binding_cleanup() from public,anon,authenticated;
revoke all on function public.huntnexus_account_characters(uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_character_create(uuid,jsonb) from public,anon,authenticated;
revoke all on function public.huntnexus_character_set_active(uuid,uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_character_scope(uuid,uuid) from public,anon,authenticated;
revoke all on function public.huntnexus_account_unbind(uuid) from public,anon,authenticated;

grant execute on function public.huntnexus_account_characters(uuid) to service_role;
grant execute on function public.huntnexus_character_create(uuid,jsonb) to service_role;
grant execute on function public.huntnexus_character_set_active(uuid,uuid) to service_role;
grant execute on function public.huntnexus_character_scope(uuid,uuid) to service_role;
grant execute on function public.huntnexus_account_unbind(uuid) to service_role;

comment on table public.huntnexus_accounts is
  'Authenticated HuntNexus ownership root. Auth method and recovery are outside migration 0162.';
comment on table public.player_characters is
  'Account-owned characters. legacy_client_id is compatibility only; new ownership uses character_id.';
comment on column public.player_character_profiles.character_id is
  'Account-owned character scope; NULL is retained only for unbound legacy guest data.';

reset lock_timeout;
reset statement_timeout;
