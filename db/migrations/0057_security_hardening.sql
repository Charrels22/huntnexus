-- HuntNexus Brain — Phase 26 security hardening.

alter function public.huntnexus_normalize_label(text)
  set search_path = public, extensions, pg_temp;

alter function public.huntnexus_tibiadata_slug(text)
  set search_path = public, extensions, pg_temp;
