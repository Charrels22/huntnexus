-- Reversible Topic 5 rollback. No Auth or player data is changed.

drop function if exists public.huntnexus_auth_session_gate(uuid,uuid);
