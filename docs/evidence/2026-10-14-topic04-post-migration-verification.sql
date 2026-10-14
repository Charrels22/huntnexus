-- Read-only verification for migration 0162. Zero rows in violation queries is PASS.

select jsonb_build_object(
  'accounts',(select count(*) from public.huntnexus_accounts),
  'bindings',(select count(*) from public.player_account_bindings),
  'characters',(select count(*) from public.player_characters),
  'accounts_without_active_character',(
    select count(*) from public.huntnexus_accounts where active_character_id is null
  ),
  'bindings_without_account',(
    select count(*) from public.player_account_bindings where account_id is null
  )
) as migration_counts;

select a.id as account_id,a.active_character_id
from public.huntnexus_accounts a
left join public.player_characters c
  on c.account_id=a.id and c.id=a.active_character_id
where c.id is null;

select 'profiles' domain,p.client_id,p.character_id
from public.player_character_profiles p
left join public.player_characters c
  on c.legacy_client_id=p.client_id and c.id=p.character_id
where p.character_id is not null and c.id is null
union all
select 'inventory',i.client_id,i.character_id
from public.player_character_inventory i
left join public.player_characters c
  on c.legacy_client_id=i.client_id and c.id=i.character_id
where i.character_id is not null and c.id is null
union all
select 'choices',b.client_id,b.character_id
from public.player_hunt_build_choices b
left join public.player_characters c
  on c.legacy_client_id=b.client_id and c.id=b.character_id
where b.character_id is not null and c.id is null
union all
select 'sessions',s.client_id,s.character_id
from public.player_hunt_sessions s
left join public.player_characters c
  on c.legacy_client_id=s.client_id and c.id=s.character_id
where s.character_id is not null and c.id is null
union all
select 'revisions',r.client_id,r.character_id
from public.player_session_parse_revisions r
left join public.player_characters c
  on c.legacy_client_id=r.client_id and c.id=r.character_id
where r.character_id is not null and c.id is null;

select p.proname,
       has_function_privilege('anon',p.oid,'execute') anon_execute,
       has_function_privilege('authenticated',p.oid,'execute') authenticated_execute,
       has_function_privilege('service_role',p.oid,'execute') service_role_execute
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in(
  'huntnexus_account_characters','huntnexus_character_create',
  'huntnexus_character_set_active','huntnexus_character_scope'
)
order by p.proname;
