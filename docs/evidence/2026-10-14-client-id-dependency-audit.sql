-- Topic 4 dependency inventory — read-only, captured before migration 0162.

select c.table_name,c.column_name,c.data_type,c.is_nullable,c.column_default,
  (select string_agg(kcu.column_name,',' order by kcu.ordinal_position)
   from information_schema.table_constraints tc
   join information_schema.key_column_usage kcu
     on kcu.constraint_schema=tc.constraint_schema and kcu.constraint_name=tc.constraint_name
   where tc.table_schema='public' and tc.table_name=c.table_name and tc.constraint_type='PRIMARY KEY') as pk_columns,
  (select count(*) from pg_policies p where p.schemaname='public' and p.tablename=c.table_name) as policy_count
from information_schema.columns c
where c.table_schema='public' and c.column_name='client_id'
order by c.table_name;

select tablename,indexname,indexdef
from pg_indexes
where schemaname='public' and indexdef ilike '%client_id%'
order by tablename,indexname;

select routine_name,routine_type,data_type
from information_schema.routines
where routine_schema='public' and routine_definition ilike '%client_id%'
order by routine_name;

with private_clients as (
  select client_id from public.player_character_profiles
  union select client_id from public.player_character_inventory
  union select client_id from public.player_hunt_build_choices
  union select client_id from public.player_hunt_sessions
  union select client_id from public.player_session_parse_revisions
)
select count(*) private_client_count,
       count(*) filter(where b.client_id is not null) bound_private_clients,
       count(*) filter(where b.client_id is null) orphan_private_clients
from private_clients p
left join public.player_account_bindings b using(client_id);

select jsonb_build_object(
  'bindings',(select count(*) from public.player_account_bindings),
  'profiles',(select count(*) from public.player_character_profiles),
  'inventory',(select count(*) from public.player_character_inventory),
  'choices',(select count(*) from public.player_hunt_build_choices),
  'sessions',(select count(*) from public.player_hunt_sessions),
  'revisions',(select count(*) from public.player_session_parse_revisions)
) as private_counts;
