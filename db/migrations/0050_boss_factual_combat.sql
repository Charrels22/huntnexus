-- HuntNexus Brain — Phase 19 factual boss combat profile.
-- Reuses already-ingested Tier B creature details; no new collection.

create or replace view vw_boss_factual_combat_profile as
select
  bp.boss_key,
  bp.name,
  bp.canonical_monster_key,
  ca.attack_type,
  ca.abilities_raw,
  ca.max_damage,
  ca.uses_spells,
  ca.source_id,
  ca.snapshot_id,
  ca.observed_at
from boss_profiles bp
left join creature_abilities ca
  on ca.monster_key=bp.canonical_monster_key
where bp.canonical_monster_key is not null;

create or replace function huntnexus_boss_room_profile(
  p_boss_key text,
  p_vocation text,
  p_level int
)
returns jsonb
language sql
stable
as $$
select jsonb_build_object(
  'boss',(
    select jsonb_build_object(
      'boss_key',bp.boss_key,
      'name',bp.name,
      'canonical_monster_key',bp.canonical_monster_key,
      'hunting_place_key',bp.hunting_place_key,
      'encounter_type',bp.encounter_type,
      'party_size_min',bp.party_size_min,
      'party_size_max',bp.party_size_max,
      'recommended_level_text',bp.recommended_level_text
    )
    from boss_profiles bp
    where bp.boss_key=p_boss_key
  ),
  'factual_combat',(
    select jsonb_build_object(
      'attack_type',f.attack_type,
      'abilities_raw',f.abilities_raw,
      'max_damage',f.max_damage,
      'uses_spells',f.uses_spells,
      'observed_at',f.observed_at,
      'methodology',jsonb_build_object(
        'layer','tibia_factual',
        'tier','B',
        'rubinot_override_applied',false
      )
    )
    from vw_boss_factual_combat_profile f
    where f.boss_key=p_boss_key
  ),
  'element_profile',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'element',element,
        'entity_count',entity_count,
        'avg_modifier_percent',avg_modifier_percent,
        'min_modifier_percent',min_modifier_percent,
        'max_modifier_percent',max_modifier_percent,
        'weak_entities',weak_entities,
        'neutral_entities',neutral_entities,
        'resistant_entities',resistant_entities,
        'immune_entities',immune_entities
      )
      order by avg_modifier_percent desc,element
    )
    from vw_boss_element_profile
    where boss_key=p_boss_key
  ),'[]'::jsonb),
  'adds',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'add_key',add_key,
        'name',raw_name,
        'canonical_monster_key',canonical_monster_key,
        'phase_key',phase_key,
        'role',role,
        'required',required
      )
      order by coalesce(phase_key,''),raw_name
    )
    from boss_room_adds
    where boss_key=p_boss_key
  ),'[]'::jsonb),
  'mechanics',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'mechanic_key',mechanic_key,
        'phase_key',phase_key,
        'type',mechanic_type,
        'title',title,
        'description',description,
        'element',element,
        'severity',severity,
        'exact_values',exact_values,
        'required_action',required_action,
        'avoid_action',avoid_action,
        'source_tier',source_tier,
        'patch_version',patch_version,
        'confidence',confidence
      )
      order by coalesce(phase_key,''),mechanic_key
    )
    from vw_boss_current_mechanics
    where boss_key=p_boss_key
  ),'[]'::jsonb),
  'spell_guidance',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'spell_key',g.spell_key,
        'spell_name',s.name,
        'words',s.words,
        'guidance_type',g.guidance_type,
        'phase_key',g.phase_key,
        'rationale',g.rationale,
        'confidence',g.confidence
      )
      order by g.guidance_type,s.name
    )
    from boss_room_spell_guidance g
    left join spell_definitions s on s.spell_key=g.spell_key
    where g.boss_key=p_boss_key
      and g.vocation=huntnexus_normalize_vocation(p_vocation)
      and (s.min_level is null or s.min_level<=p_level)
  ),'[]'::jsonb),
  'item_guidance',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'guidance_type',guidance_type,
        'effect_key',effect_key,
        'priority',priority,
        'rationale',rationale,
        'patch_version',patch_version,
        'confidence',confidence
      )
      order by coalesce(priority,999),guidance_type,effect_key
    )
    from boss_room_item_guidance
    where boss_key=p_boss_key
      and vocation=huntnexus_normalize_vocation(p_vocation)
  ),'[]'::jsonb),
  'methodology',jsonb_build_object(
    'stage','boss_room_profile_v2',
    'final_build',false,
    'version_sensitive',true,
    'rubinot_overrides_can_supersede_tibia_base',true,
    'note','Boss-room output keeps factual combat, mechanics, elemental evidence and build/spell guidance versioned and separately sourced.'
  )
);
$$;

revoke all on function huntnexus_boss_room_profile(text,text,int)
  from public,anon,authenticated;
grant execute on function huntnexus_boss_room_profile(text,text,int)
  to service_role;
