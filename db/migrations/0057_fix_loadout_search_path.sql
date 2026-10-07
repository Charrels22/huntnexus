-- HuntNexus security hardening — fixed search_path for RPC exposed only to service_role.
alter function huntnexus_loadout_candidate_matrix(text,text,integer,integer)
  set search_path = public, extensions;
