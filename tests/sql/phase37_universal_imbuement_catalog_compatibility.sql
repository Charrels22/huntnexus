-- Focused regression for universal Imbuement catalog/compatibility.

do $$
declare
  v_fist jsonb;
  v_helmet jsonb;
  v_armor jsonb;
  v_spellbook jsonb;
  v_boots jsonb;
  v_low_rod jsonb;
  v_high_rod jsonb;
  v_audit jsonb;
begin
  if (select count(*) from imbuement_definitions) <> 24 then
    raise exception 'Expected 24 current Powerful imbuement definitions';
  end if;

  if (select count(*) from imbuement_applicability_rules) <> 86 then
    raise exception 'Imbuement applicability rule count regression';
  end if;

  if exists (
    select 1
    from imbuement_definitions d
    where not exists (
      select 1 from imbuement_applicability_rules r
      where r.imbuement_key=d.imbuement_key
    )
  ) then
    raise exception 'Every imbuement definition must have applicability evidence';
  end if;

  if not exists (
    select 1 from imbuement_definitions
    where imbuement_key='punch'
      and effect_key='fist_fighting'
      and powerful_value=4
  ) or not exists (
    select 1 from imbuement_applicability_rules
    where imbuement_key='punch'
      and target_domain='weapon'
      and target_family='fist'
  ) then
    raise exception 'Punch/Fist applicability regression';
  end if;

  if (select count(*) from imbuement_definitions where category='damage_conversion') <> 5
     or exists (
       select 1 from imbuement_definitions
       where category='damage_conversion' and powerful_value<>50
     ) then
    raise exception 'Elemental damage-conversion catalog regression';
  end if;

  v_fist := huntnexus_item_imbuement_compatibility_universal('grand-sanguine-claws');
  if (v_fist #>> '{summary,eligible}')::int <> 1
     or not exists (
       select 1 from jsonb_array_elements(v_fist->'candidates') x
       where x->>'imbuement_key'='punch'
         and x->>'eligibility_status'='eligible'
     )
     or v_fist #>> '{coverage,source_scope_note}' is null then
    raise exception 'Fist source-strict compatibility regression';
  end if;

  v_helmet := huntnexus_item_imbuement_compatibility_universal('falcon-coif');
  if (v_helmet #>> '{summary,eligible}')::int <> 8
     or not exists (
       select 1 from jsonb_array_elements(v_helmet->'candidates') x
       where x->>'imbuement_key'='void'
     )
     or not exists (
       select 1 from jsonb_array_elements(v_helmet->'candidates') x
       where x->>'imbuement_key'='punch'
     ) then
    raise exception 'Helmet compatibility regression';
  end if;

  v_armor := huntnexus_item_imbuement_compatibility_universal('lion-plate');
  if (v_armor #>> '{summary,eligible}')::int <> 7
     or not exists (
       select 1 from jsonb_array_elements(v_armor->'candidates') x
       where x->>'imbuement_key'='vampirism'
     )
     or (select count(*) from jsonb_array_elements(v_armor->'candidates') x
         where x->>'category'='protection') <> 6 then
    raise exception 'Armor compatibility regression';
  end if;

  v_spellbook := huntnexus_item_imbuement_compatibility_universal('lion-spellbook');
  if (v_spellbook #>> '{summary,eligible}')::int <> 7
     or not exists (
       select 1 from jsonb_array_elements(v_spellbook->'candidates') x
       where x->>'imbuement_key'='blockade'
     ) then
    raise exception 'Spellbook normalized-family compatibility regression';
  end if;

  v_boots := huntnexus_item_imbuement_compatibility_universal('depth-calcei');
  if (v_boots #>> '{summary,eligible}')::int <> 2
     or not exists (
       select 1 from jsonb_array_elements(v_boots->'candidates') x
       where x->>'imbuement_key'='swiftness' and (x->>'powerful_value')::numeric=30
     )
     or not exists (
       select 1 from jsonb_array_elements(v_boots->'candidates') x
       where x->>'imbuement_key'='vibrancy' and (x->>'powerful_value')::numeric=50
     ) then
    raise exception 'Boot support imbuement regression';
  end if;

  v_low_rod := huntnexus_item_imbuement_compatibility_universal('jungle-rod');
  if not exists (
    select 1 from jsonb_array_elements(v_low_rod->'candidates') x
    where x->>'imbuement_key'='strike'
      and x->>'eligibility_status'='blocked'
      and (x->'blocking_reasons') ? 'minimum_item_level'
      and (x->>'min_item_level')::int=200
  ) then
    raise exception 'Rod Strike minimum-level regression';
  end if;

  v_high_rod := huntnexus_item_imbuement_compatibility_universal('soulhexer');
  if not exists (
    select 1 from jsonb_array_elements(v_high_rod->'candidates') x
    where x->>'imbuement_key'='strike'
      and x->>'eligibility_status'='eligible'
  ) then
    raise exception 'High-level Rod Strike regression';
  end if;

  v_audit := huntnexus_imbuement_category_audit();
  if coalesce((v_audit #>> '{summary,source_catalog_complete_for_current_24}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,factual_compatibility_ready}')::boolean,false) is not true
     or coalesce((v_audit #>> '{summary,hunt_context_priority_ready}')::boolean,true) is not false
     or coalesce((v_audit #>> '{summary,final_assignment_ready}')::boolean,true) is not false then
    raise exception 'Imbuement category audit semantics regression';
  end if;

  if has_table_privilege('anon','public.imbuement_applicability_rules','SELECT')
     or has_table_privilege('authenticated','public.imbuement_applicability_rules','SELECT')
     or has_table_privilege('anon','public.vw_imbuement_catalog_universal','SELECT')
     or has_table_privilege('authenticated','public.vw_imbuement_catalog_universal','SELECT') then
    raise exception 'Universal Imbuement catalog must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','universal_imbuement_catalog_compatibility',
  'powerful_definitions',(select count(*) from imbuement_definitions),
  'applicability_rules',(select count(*) from imbuement_applicability_rules),
  'factual_compatibility_ready',(
    huntnexus_imbuement_category_audit() #>> '{summary,factual_compatibility_ready}'
  )::boolean
) as regression_summary;
