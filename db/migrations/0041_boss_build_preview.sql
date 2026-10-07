-- HuntNexus Analytics — Phase 16.4 boss build preview.
-- Conservative output: final build is unavailable while a reconciliation guard is active.

create or replace function huntnexus_boss_build_preview(
  p_boss_key text,
  p_vocation text,
  p_level int
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_readiness jsonb;
  v_profile jsonb;
  v_spells jsonb;
  v_mechanics_count int;
  v_final_blocked boolean;
begin
  v_readiness := huntnexus_boss_recommendation_readiness(p_boss_key);
  v_profile := huntnexus_boss_room_profile(p_boss_key,p_vocation,p_level);
  v_spells := huntnexus_boss_spell_candidates(p_boss_key,p_vocation,p_level);

  v_mechanics_count := jsonb_array_length(coalesce(v_profile->'mechanics','[]'::jsonb));
  v_final_blocked := coalesce((v_readiness->>'final_build_blocked')::boolean,true);

  return jsonb_build_object(
    'query',jsonb_build_object(
      'boss_key',p_boss_key,
      'vocation',huntnexus_normalize_vocation(p_vocation),
      'level',p_level
    ),
    'readiness',v_readiness,
    'boss_profile',v_profile,
    'spell_evidence',v_spells,
    'final_build_available',
      (not v_final_blocked and v_mechanics_count>0),
    'methodology',jsonb_build_object(
      'stage','boss_build_preview',
      'final_build',false,
      'requires_current_mechanics',true,
      'mechanics_count',v_mechanics_count,
      'note',
        case
          when v_final_blocked
            then 'Final boss build is blocked by unresolved RubinOT-specific mechanic reconciliation.'
          when v_mechanics_count=0
            then 'No current sourced room mechanics are stored yet.'
          else 'Mechanic evidence exists, but final optimization is still a separate phase.'
        end
    )
  );
end;
$$;

revoke all on function huntnexus_boss_build_preview(text,text,int)
  from public,anon,authenticated;
grant execute on function huntnexus_boss_build_preview(text,text,int)
  to service_role;
