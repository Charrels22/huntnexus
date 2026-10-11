-- FE-20 / Phase 72: evidence-backed, non-personal hunt observations for EK/RP/ED/MS/EM.
-- This is a live-source audit of curated community sessions (Tier C).
-- Private player_hunt_sessions are not read or promoted to community content.
do $$
declare
  v_case record;
  v_observed jsonb;
  v_number integer;
  v_samples integer;
  v_source_count integer;
begin
  for v_case in
    select * from (values
      ('EK','cobra-bastion'),
      ('RP','iksupan-last-stand'),
      ('ED','nimmersatts-breeding-ground'),
      ('MS','podzilla'),
      ('EM','grounds-of-undeath')
    ) as cases(vocation,hunt_key)
  loop
    select count(distinct cs.id),count(distinct cs.source_url)
      into v_samples,v_source_count
    from public.community_sessions cs
    join public.session_players sp on sp.session_id=cs.id
    where cs.hunt_key=v_case.hunt_key
      and sp.vocation=v_case.vocation
      and cs.source_url is not null
      and cs.duration_seconds > 0
      and cs.xp_per_hour is not null;

    if v_samples < 1 or v_source_count < 1 then
      raise exception 'Missing real source-backed evidence for % / %',v_case.vocation,v_case.hunt_key;
    end if;

    v_observed := public.huntnexus_hunt_observed_profile(v_case.hunt_key);
    if v_observed #>> '{methodology,layer}' <> 'community_observations' then
      raise exception 'Tier C label missing for %',v_case.hunt_key;
    end if;
    if v_observed #>> '{methodology,final_recommendation}' <> 'false' then
      raise exception 'Observation incorrectly marked as final recommendation for %',v_case.hunt_key;
    end if;
    v_number := nullif(v_observed #>> '{performance,session_count}','')::integer;
    if v_number is null or v_number < v_samples then
      raise exception 'Observed session count cannot be lower than sourced sample for %',v_case.hunt_key;
    end if;
    if nullif(v_observed #>> '{performance,median_xp_per_hour}','') is null then
      raise exception 'Observed median XP is missing for %',v_case.hunt_key;
    end if;
  end loop;

  v_observed := public.huntnexus_hunt_observed_profile('nonexistent-hunt-no-community-evidence-2026');
  if v_observed->'performance' <> 'null'::jsonb
    or jsonb_array_length(coalesce(v_observed->'elements','[]'::jsonb)) > 0 then
    raise exception 'Missing community observations must stay missing, not zero-valued';
  end if;
end $$;

select jsonb_build_object(
  'status','ok',
  'stage','real_community_evidence_five_vocations_v1',
  'vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
  'tier','community_observations',
  'raw_private_sessions_promoted',false,
  'synthetic_session_data_used',false,
  'human_playtest_complete',false
) as result;
