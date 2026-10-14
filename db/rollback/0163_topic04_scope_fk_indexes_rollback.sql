-- Reversible rollback for migration 0163. No data is removed.

drop index if exists public.player_session_parse_revisions_scope_idx;
drop index if exists public.player_hunt_sessions_scope_idx;
drop index if exists public.player_hunt_build_choices_scope_idx;
drop index if exists public.player_character_inventory_scope_idx;
drop index if exists public.player_character_profiles_scope_idx;
drop index if exists public.huntnexus_accounts_active_character_owner_idx;
