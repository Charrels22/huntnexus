-- Topic 4 follow-up: cover the foreign keys introduced by migration 0162.
-- Additive and reversible; no rows or authentication settings are changed.

set lock_timeout = '5s';
set statement_timeout = '60s';

create index if not exists huntnexus_accounts_active_character_owner_idx
  on public.huntnexus_accounts(id,active_character_id);

create index if not exists player_character_profiles_scope_idx
  on public.player_character_profiles(client_id,character_id);

create index if not exists player_character_inventory_scope_idx
  on public.player_character_inventory(client_id,character_id);

create index if not exists player_hunt_build_choices_scope_idx
  on public.player_hunt_build_choices(client_id,character_id);

create index if not exists player_hunt_sessions_scope_idx
  on public.player_hunt_sessions(client_id,character_id);

create index if not exists player_session_parse_revisions_scope_idx
  on public.player_session_parse_revisions(client_id,character_id);

reset lock_timeout;
reset statement_timeout;
