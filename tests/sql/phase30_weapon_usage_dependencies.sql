-- Focused regression for universal weapon usage dependencies.

do $$
declare
  v_bow jsonb;
  v_crossbow jsonb;
  v_throwing jsonb;
  v_rod jsonb;
  v_wand jsonb;
  v_one jsonb;
  v_two jsonb;
begin
  v_bow := huntnexus_weapon_usage_context('moonsilver-bow','RP',1000);
  v_crossbow := huntnexus_weapon_usage_context('moonsilver-crossbow','RP',1000);
  v_throwing := huntnexus_weapon_usage_context('assassin-star','RP',700);
  v_rod := huntnexus_weapon_usage_context('moonsilver-sceptre','ED',1000);
  v_wand := huntnexus_weapon_usage_context('moonsilver-channeler','MS',1000);
  v_one := huntnexus_weapon_usage_context('grand-sanguine-blade','EK',700);
  v_two := huntnexus_weapon_usage_context('grand-sanguine-razor','EK',700);

  if v_bow #>> '{usage,offhand_policy}' <> 'quiver_required'
     or coalesce((v_bow #>> '{usage,requires_quiver}')::boolean,false) is not true
     or v_bow #>> '{dependencies,ammunition,family}' <> 'arrow'
     or v_bow #>> '{dependencies,ammunition,catalog_status}' <> 'missing'
     or (v_bow #>> '{dependencies,quiver,eligible_count}')::int <> 8 then
    raise exception 'Bow dependency regression';
  end if;

  if v_crossbow #>> '{usage,offhand_policy}' <> 'quiver_required'
     or v_crossbow #>> '{dependencies,ammunition,family}' <> 'bolt'
     or v_crossbow #>> '{dependencies,ammunition,catalog_status}' <> 'missing' then
    raise exception 'Crossbow dependency regression';
  end if;

  if v_throwing #>> '{usage,offhand_policy}' <> 'optional_shield_offhand'
     or coalesce((v_throwing #>> '{usage,requires_quiver}')::boolean,true) is not false then
    raise exception 'Throwing off-hand regression';
  end if;

  if v_rod #>> '{usage,offhand_policy}' <> 'optional_shield_or_spellbook'
     or v_wand #>> '{usage,offhand_policy}' <> 'optional_shield_or_spellbook' then
    raise exception 'Caster off-hand regression';
  end if;

  if v_one #>> '{usage,offhand_policy}' <> 'optional_shield_offhand'
     or v_two #>> '{usage,offhand_policy}' <> 'blocked_by_two_handed_weapon' then
    raise exception 'Melee hand compatibility regression';
  end if;

  if (select count(*) from vw_quiver_catalog_universal) <> 8 then
    raise exception 'Expected exactly 8 usable quivers';
  end if;

  if has_table_privilege('anon','public.weapon_usage_rules','SELECT')
     or has_table_privilege('authenticated','public.weapon_usage_rules','SELECT')
     or has_table_privilege('anon','public.vw_quiver_catalog_universal','SELECT')
     or has_table_privilege('authenticated','public.vw_quiver_catalog_universal','SELECT') then
    raise exception 'Weapon dependency catalog must remain server-only';
  end if;
end
$$;

select jsonb_build_object(
  'status','ok',
  'stage','weapon_usage_dependencies',
  'quivers',(select count(*) from vw_quiver_catalog_universal),
  'rule_families',(select count(*) from weapon_usage_rules),
  'ammunition_catalog_ready',false
) as regression_summary;
