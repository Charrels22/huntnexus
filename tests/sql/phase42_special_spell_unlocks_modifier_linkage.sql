-- Focused regression for special spell unlocks and proficiency-to-spell linkage.

do $$
declare
  v_em_locked jsonb;
  v_em_unlocked jsonb;
  v_ed_locked jsonb;
  v_ed_unlocked jsonb;
  v_ek_locked jsonb;
  v_ek_unlocked jsonb;
  v_divine jsonb;
  v_monk jsonb;
  v_ice jsonb;
  v_audit jsonb;
begin
  if (select count(*) from vw_spell_catalog_universal) <> 60 then
    raise exception 'Universal spell catalog count regression';
  end if;

  if (select count(*) from vw_spell_catalog_universal where vocation='EM') <> 16 then
    raise exception 'Monk spell count regression';
  end if;

  if (select count(*) from spell_unlock_requirements) <> 7
     or (select count(distinct spell_key) from spell_unlock_requirements) <> 7 then
    raise exception 'Special unlock requirement count regression';
  end if;

  if not exists (
    select 1 from spell_unlock_requirements
    where spell_key='mystic-repulse'
      and requirement_key='way-of-monk-shrine-3'
      and requirement_type='quest_shrine'
      and progress_value=3
  ) or not exists (
    select 1 from spell_unlock_requirements
    where spell_key='forceful-uppercut'
      and requirement_key='way-of-monk-shrine-8'
      and progress_value=8
  ) or not exists (
    select 1 from spell_unlock_requirements
    where spell_key='focus-harmony'
      and requirement_key='way-of-monk-shrine-10'
      and progress_value=10
  ) then
    raise exception 'Monk shrine unlock regression';
  end if;

  if not exists (
    select 1 from spell_resource_mechanics
    where spell_key='focus-harmony'
      and resource_key='harmony'
      and resource_action='set_max'
      and amount_mode='max'
  ) or not exists (
    select 1 from spell_resource_mechanics
    where spell_key='spiritual-outburst'
      and resource_action='spender_all'
      and amount_mode='all'
  ) then
    raise exception 'Harmony special spell mechanic regression';
  end if;

  v_em_locked := huntnexus_spell_candidates_with_unlocks_universal(
    'EM',300,'[]'::jsonb,null,null,100
  );
  if (v_em_locked #>> '{summary,catalog_spells}')::int <> 16
     or (v_em_locked #>> '{summary,eligible}')::int <> 11
     or (v_em_locked #>> '{summary,incomplete}')::int <> 5
     or (v_em_locked #>> '{summary,blocked}')::int <> 0 then
    raise exception 'EM locked spell eligibility regression';
  end if;

  v_em_unlocked := huntnexus_spell_candidates_with_unlocks_universal(
    'EM',300,
    '["way-of-monk-shrine-3","way-of-monk-shrine-8","way-of-monk-shrine-10","wheel-revelation-spiritual-outburst","wheel-revelation-avatar-of-balance"]'::jsonb,
    null,null,100
  );
  if (v_em_unlocked #>> '{summary,eligible}')::int <> 16
     or (v_em_unlocked #>> '{summary,incomplete}')::int <> 0 then
    raise exception 'EM unlocked spell eligibility regression';
  end if;

  v_ed_locked := huntnexus_spell_candidates_with_unlocks_universal(
    'ED',100,'[]'::jsonb,'attack','ice',100
  );
  v_ed_unlocked := huntnexus_spell_candidates_with_unlocks_universal(
    'ED',100,'["wheel-revelation-twin-bursts-ice"]'::jsonb,'attack','ice',100
  );

  if (v_ed_locked #>> '{summary,catalog_spells}')::int <> 6
     or (v_ed_locked #>> '{summary,eligible}')::int <> 5
     or (v_ed_locked #>> '{summary,incomplete}')::int <> 1
     or (v_ed_unlocked #>> '{summary,eligible}')::int <> 6
     or (v_ed_unlocked #>> '{summary,incomplete}')::int <> 0 then
    raise exception 'Ice Burst unlock regression';
  end if;

  v_ek_locked := huntnexus_spell_candidates_with_unlocks_universal(
    'EK',700,'[]'::jsonb,'attack',null,100
  );
  v_ek_unlocked := huntnexus_spell_candidates_with_unlocks_universal(
    'EK',700,'["wheel-revelation-executioners-throw"]'::jsonb,'attack',null,100
  );
  if (v_ek_locked #>> '{summary,catalog_spells}')::int <> 6
     or (v_ek_locked #>> '{summary,eligible}')::int <> 5
     or (v_ek_locked #>> '{summary,incomplete}')::int <> 1
     or (v_ek_unlocked #>> '{summary,eligible}')::int <> 6 then
    raise exception 'Executioner Throw unlock regression';
  end if;

  if (select count(*) from vw_spell_modifier_links_universal
      where target_type='exact_spell' and link_status='resolved') <> 82 then
    raise exception 'Resolved exact proficiency-spell link count regression';
  end if;

  if exists (
    select 1 from vw_spell_modifier_links_universal
    where target_type='exact_spell' and link_status='unresolved_spell_key'
  ) then
    raise exception 'No exact proficiency-spell link should remain unresolved';
  end if;

  if (select count(*) from vw_spell_modifier_links_universal
      where link_status='selector_only') <> 69 then
    raise exception 'Generic proficiency spell selector count regression';
  end if;

  if (select count(*) from vw_spell_modifier_links_universal
      where link_status='excluded_non_spell_scope') <> 3 then
    raise exception 'Bestiary pseudo spell-key exclusion regression';
  end if;

  v_divine := huntnexus_spell_modifier_context_universal('divine-caldera');
  v_monk := huntnexus_spell_modifier_context_universal('sweeping-takedown');
  v_ice := huntnexus_spell_modifier_context_universal('ice-burst');

  if jsonb_array_length(v_divine->'exact_weapon_proficiency_modifiers') <> 10
     or jsonb_array_length(v_monk->'exact_weapon_proficiency_modifiers') <> 5
     or jsonb_array_length(v_ice->'exact_weapon_proficiency_modifiers') <> 2 then
    raise exception 'Exact spell modifier context regression';
  end if;

  if coalesce((v_divine #>> '{methodology,modifier_activation_applied}')::boolean,true) is not false
     or coalesce((v_divine #>> '{methodology,final_damage_formula_applied}')::boolean,true) is not false
     or coalesce((v_divine #>> '{methodology,equipment_specific_modifier_links_ready}')::boolean,true) is not false then
    raise exception 'Spell modifier methodology regression';
  end if;

  v_audit := huntnexus_spell_category_audit();
  if v_audit #>> '{methodology,stage}' <> 'spell_category_audit_v2'
     or (v_audit #>> '{summary,catalog_spells}')::int <> 60
     or (v_audit #>> '{summary,monk_spells}')::int <> 16
     or (v_audit #>> '{summary,special_unlock_requirements}')::int <> 7
     or (v_audit #>> '{summary,resolved_exact_proficiency_spell_links}')::int <> 82
     or (v_audit #>> '{summary,unresolved_exact_proficiency_spell_links}')::int <> 0
     or coalesce((v_audit #>> '{summary,special_unlock_rules_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,proficiency_spell_linkage_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,equipment_specific_modifier_links_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,rotation_model_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_damage_formula_ready}')::boolean,true) is not false then
    raise exception 'Spell category audit v2 semantics regression';
  end if;

  if has_table_privilege('anon','public.spell_unlock_requirements','SELECT')
     or has_table_privilege('authenticated','public.spell_unlock_requirements','SELECT')
     or has_table_privilege('anon','public.vw_spell_modifier_links_universal','SELECT')
     or has_table_privilege('authenticated','public.vw_spell_modifier_links_universal','SELECT') then
    raise exception 'Spell unlock/modifier objects must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','special_spell_unlocks_modifier_linkage',
  'catalog_spells',(select count(*) from vw_spell_catalog_universal),
  'monk_spells',(select count(*) from vw_spell_catalog_universal where vocation='EM'),
  'unlock_requirements',(select count(*) from spell_unlock_requirements),
  'resolved_exact_links',(select count(*) from vw_spell_modifier_links_universal
    where target_type='exact_spell' and link_status='resolved'),
  'unresolved_exact_links',(select count(*) from vw_spell_modifier_links_universal
    where target_type='exact_spell' and link_status='unresolved_spell_key'),
  'generic_selectors',(select count(*) from vw_spell_modifier_links_universal where link_status='selector_only')
) as regression_summary;
