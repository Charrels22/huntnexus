-- Focused regression for universal weapon eligibility.

do $$
declare
  v_ek jsonb;
  v_rp jsonb;
  v_ed jsonb;
  v_ms jsonb;
  v_em jsonb;
  v_item jsonb;
begin
  v_ek := huntnexus_weapon_candidates_universal('EK',700,null,'sword',250);
  v_rp := huntnexus_weapon_candidates_universal('RP',700,'distance',null,250);
  v_ed := huntnexus_weapon_candidates_universal('ED',700,'caster','rod',250);
  v_ms := huntnexus_weapon_candidates_universal('MS',700,'caster','wand',250);
  v_em := huntnexus_weapon_candidates_universal('EM',700,'melee','fist',250);

  if v_ek #>> '{methodology,stage}' <> 'weapon_candidates_universal_v1'
     or v_rp #>> '{methodology,stage}' <> 'weapon_candidates_universal_v1'
     or v_ed #>> '{methodology,stage}' <> 'weapon_candidates_universal_v1'
     or v_ms #>> '{methodology,stage}' <> 'weapon_candidates_universal_v1'
     or v_em #>> '{methodology,stage}' <> 'weapon_candidates_universal_v1' then
    raise exception 'Universal weapon candidate stage regression';
  end if;

  if (v_ek #>> '{summary,eligible}')::int <= 0
     or (v_rp #>> '{summary,eligible}')::int <= 0
     or (v_ed #>> '{summary,eligible}')::int <= 0
     or (v_ms #>> '{summary,eligible}')::int <= 0
     or (v_em #>> '{summary,eligible}')::int <= 0 then
    raise exception 'Expected eligible candidates for every supported vocation';
  end if;

  select value into v_item
  from jsonb_array_elements(v_ek->'items')
  where value->>'item_key'='grand-sanguine-blade'
  limit 1;
  if v_item->>'eligibility_status' <> 'eligible' then
    raise exception 'Grand Sanguine Blade should be eligible for EK 700';
  end if;

  select value into v_item
  from jsonb_array_elements(v_ek->'items')
  where value->>'item_key'='moonsilver-claymore'
  limit 1;
  if v_item->>'eligibility_status' <> 'blocked'
     or not (v_item->'blocking_reasons' ? 'level_requirement') then
    raise exception 'Moonsilver Claymore level block regression';
  end if;

  select value into v_item
  from jsonb_array_elements(
    huntnexus_weapon_candidates_universal('RP',1000,null,'sword',250)->'items'
  )
  where value->>'item_key'='grand-sanguine-blade'
  limit 1;
  if v_item->>'eligibility_status' <> 'blocked'
     or not (v_item->'blocking_reasons' ? 'vocation_restriction') then
    raise exception 'Cross-vocation weapon block regression';
  end if;

  if huntnexus_weapon_candidates_universal('UNKNOWN',700,null,null,10) #>> '{error}'
     <> 'unsupported_vocation' then
    raise exception 'Unsupported vocation regression';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_weapon_candidates',
  'ek_sword_eligible',(huntnexus_weapon_candidates_universal('EK',700,null,'sword',20) #>> '{summary,eligible}')::int,
  'rp_distance_eligible',(huntnexus_weapon_candidates_universal('RP',700,'distance',null,20) #>> '{summary,eligible}')::int,
  'ed_rod_eligible',(huntnexus_weapon_candidates_universal('ED',700,'caster','rod',20) #>> '{summary,eligible}')::int,
  'ms_wand_eligible',(huntnexus_weapon_candidates_universal('MS',700,'caster','wand',20) #>> '{summary,eligible}')::int,
  'em_fist_eligible',(huntnexus_weapon_candidates_universal('EM',700,'melee','fist',20) #>> '{summary,eligible}')::int
) as regression_summary;
