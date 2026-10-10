-- HuntNexus — universal spell/combat contract and first current Monk core.
-- Adds factual Monk combat/healing spells and Harmony resource mechanics.
-- Base Power remains a relative spell reference; no DPS/rotation/final formula is inferred.

insert into public.spell_definitions(
  spell_key,name,words,vocation,min_level,spell_group,mana_cost,
  cooldown_seconds,group_cooldown_seconds,base_power,scaling,element,
  area_type,max_targets,lever_boss_restricted,effect_summary,
  source_id,source_url,observed_at
) values
  ('swift-jab','Swift Jab','exori infir pug','EM',1,'attack',3,2,2,12,'weapon + fist fighting','physical','single',1,false,'Single-target physical Builder spell; increases Harmony.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Swift_Jab','2026-10-09 00:00:00+00'::timestamptz),
  ('tiger-clash','Tiger Clash','exori infir nia','EM',1,'attack',18,8,2,15,'weapon + fist fighting','physical','single',1,false,'Single-target physical Spender spell; spends all Harmony.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Tiger_Clash','2026-10-09 00:00:00+00'::timestamptz),
  ('double-jab','Double Jab','exori pug','EM',14,'attack',30,4,2,40,'weapon + fist fighting','physical','single',1,false,'Single-target physical Builder spell; increases Harmony.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Double_Jab','2026-10-09 00:00:00+00'::timestamptz),
  ('restore-balance','Restore Balance','exura tio sio','EM',18,'healing',120,2,1,425,'magic level',null,'ally',1,false,'Targeted Monk heal.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Restore_Balance','2026-10-09 00:00:00+00'::timestamptz),
  ('flurry-of-blows','Flurry of Blows','exori mas pug','EM',35,'attack',110,4,2,55,'weapon + fist fighting','physical','around_directional',null,false,'Physical area Builder spell; increases Harmony.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Flurry_of_Blows','2026-10-09 00:00:00+00'::timestamptz),
  ('sweeping-takedown','Sweeping Takedown','exori mas nia','EM',60,'attack',195,8,2,48,'weapon + fist fighting','physical','frontal_area',null,false,'Physical area Spender spell; spends all Harmony.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Sweeping_Takedown','2026-10-09 00:00:00+00'::timestamptz),
  ('chained-penance','Chained Penance','exori med pug','EM',70,'attack',180,4,2,70,'weapon + fist fighting','physical','chain',6,false,'Physical chain Builder spell hitting up to six creatures with current behavior.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Chained_Penance','2026-10-09 00:00:00+00'::timestamptz),
  ('spirit-mend','Spirit Mend','exura gran tio','EM',80,'healing',210,1,1,250,'magic level',null,'self',1,false,'Primary Monk self-heal.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Spirit_Mend','2026-10-09 00:00:00+00'::timestamptz),
  ('thousand-fist-blows','Thousand Fist Blows','exori mas amp pug','EM',120,'attack',145,8,2,62,'weapon + fist fighting','physical','target_aoe',null,false,'Physical area Builder spell with multiple aiming modes.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Thousand_Fist_Blows','2026-10-09 00:00:00+00'::timestamptz),
  ('devastating-knockout','Devastating Knockout','exori gran nia','EM',125,'attack',210,8,2,62,'weapon + fist fighting','physical','single',1,false,'High-impact single-target physical Spender spell; spends all Harmony.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Devastating_Knockout','2026-10-09 00:00:00+00'::timestamptz),
  ('mass-spirit-mend','Mass Spirit Mend','exura mas nia','EM',150,'healing',400,12,1,800,'magic level',null,'party_aoe',null,false,'Area healing spell for caster and nearby allies/summons; current 2026 version is no longer a Spender.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Mass_Spirit_Mend','2026-10-09 00:00:00+00'::timestamptz)
on conflict(spell_key) do update set
  name=excluded.name,
  words=excluded.words,
  vocation=excluded.vocation,
  min_level=excluded.min_level,
  spell_group=excluded.spell_group,
  mana_cost=excluded.mana_cost,
  cooldown_seconds=excluded.cooldown_seconds,
  group_cooldown_seconds=excluded.group_cooldown_seconds,
  base_power=excluded.base_power,
  scaling=excluded.scaling,
  element=excluded.element,
  area_type=excluded.area_type,
  max_targets=excluded.max_targets,
  lever_boss_restricted=excluded.lever_boss_restricted,
  effect_summary=excluded.effect_summary,
  source_id=excluded.source_id,
  source_url=excluded.source_url,
  observed_at=excluded.observed_at;

create table if not exists public.spell_resource_mechanics (
  spell_key text not null references public.spell_definitions(spell_key) on delete cascade,
  resource_key text not null,
  resource_action text not null check (resource_action in ('builder','spender_all','none')),
  amount_mode text not null check (amount_mode in ('source_unspecified','all','none')),
  source_tier text not null,
  source_id uuid references public.sources(id),
  source_url text not null,
  observed_at timestamptz not null,
  notes text,
  primary key(spell_key,resource_key)
);

alter table public.spell_resource_mechanics enable row level security;
revoke all on public.spell_resource_mechanics from public,anon,authenticated;
grant select on public.spell_resource_mechanics to service_role;

delete from public.spell_resource_mechanics where resource_key='harmony';

insert into public.spell_resource_mechanics(
  spell_key,resource_key,resource_action,amount_mode,source_tier,
  source_id,source_url,observed_at,notes
) values
  ('chained-penance','harmony','builder','source_unspecified','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Chained_Penance','2026-10-09 00:00:00+00'::timestamptz,'Source says the spell increases Harmony; exact amount is not inferred.'),
  ('devastating-knockout','harmony','spender_all','all','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Devastating_Knockout','2026-10-09 00:00:00+00'::timestamptz,'Consumes all current Harmony.'),
  ('double-jab','harmony','builder','source_unspecified','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Double_Jab','2026-10-09 00:00:00+00'::timestamptz,'Source says the spell increases Harmony; exact amount is not inferred.'),
  ('flurry-of-blows','harmony','builder','source_unspecified','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Flurry_of_Blows','2026-10-09 00:00:00+00'::timestamptz,'Source says the spell increases Harmony; exact amount is not inferred.'),
  ('mass-spirit-mend','harmony','none','none','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Mass_Spirit_Mend','2026-10-09 00:00:00+00'::timestamptz,'Current 2026 version is explicitly no longer a Spender spell.'),
  ('sweeping-takedown','harmony','spender_all','all','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Sweeping_Takedown','2026-10-09 00:00:00+00'::timestamptz,'Consumes all current Harmony.'),
  ('swift-jab','harmony','builder','source_unspecified','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Swift_Jab','2026-10-09 00:00:00+00'::timestamptz,'Source says the spell increases Harmony; exact amount is not inferred.'),
  ('thousand-fist-blows','harmony','builder','source_unspecified','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Thousand_Fist_Blows','2026-10-09 00:00:00+00'::timestamptz,'Current spell is explicitly described as Builder.'),
  ('tiger-clash','harmony','spender_all','all','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Tiger_Clash','2026-10-09 00:00:00+00'::timestamptz,'Consumes all current Harmony.');

create or replace view public.vw_spell_catalog_universal
with (security_invoker=true)
as
 SELECT spell_key,
    name,
    words,
    vocation,
    min_level,
    spell_group,
    mana_cost,
    cooldown_seconds,
    group_cooldown_seconds,
    base_power,
    scaling,
    element,
    area_type,
    max_targets,
    lever_boss_restricted,
    effect_summary,
        CASE
            WHEN lower(COALESCE(scaling, ''::text)) ~~ '%weapon%'::text THEN true
            ELSE false
        END AS scales_with_weapon,
        CASE
            WHEN lower(COALESCE(scaling, ''::text)) ~~ '%fist%'::text THEN true
            ELSE false
        END AS scales_with_fist_fighting,
        CASE
            WHEN lower(COALESCE(scaling, ''::text)) ~~ '%melee%'::text THEN true
            ELSE false
        END AS scales_with_melee_skill,
        CASE
            WHEN lower(COALESCE(scaling, ''::text)) ~~ '%distance%'::text THEN true
            ELSE false
        END AS scales_with_distance_fighting,
        CASE
            WHEN lower(COALESCE(scaling, ''::text)) ~~ '%magic level%'::text THEN true
            ELSE false
        END AS scales_with_magic_level,
        CASE
            WHEN lower(COALESCE(scaling, ''::text)) ~~ '%shielding%'::text THEN true
            ELSE false
        END AS scales_with_shielding,
        CASE
            WHEN element = 'weapon'::text THEN 'weapon_derived'::text
            WHEN element IS NOT NULL THEN 'explicit'::text
            ELSE 'none'::text
        END AS element_mode,
        CASE
            WHEN (spell_group = ANY (ARRAY['attack'::text, 'healing'::text])) AND base_power IS NOT NULL THEN 'relative_power_reference'::text
            WHEN (spell_group = ANY (ARRAY['attack'::text, 'healing'::text])) AND base_power IS NULL THEN 'base_power_missing'::text
            ELSE 'descriptive_non_power'::text
        END AS power_reference_status,
        CASE
            WHEN spell_group = ANY (ARRAY['attack'::text, 'healing'::text]) THEN 'Base Power is a relative spell power reference; final damage/healing is not calculated by this catalog.'::text
            ELSE 'No final quantitative combat formula is inferred for descriptive/support effects.'::text
        END AS base_power_semantics,
    COALESCE(( SELECT jsonb_agg(jsonb_build_object('resource_key', m.resource_key, 'resource_action', m.resource_action, 'amount_mode', m.amount_mode, 'source_tier', m.source_tier, 'source_url', m.source_url, 'notes', m.notes) ORDER BY m.resource_key) AS jsonb_agg
           FROM spell_resource_mechanics m
          WHERE m.spell_key = s.spell_key), '[]'::jsonb) AS resource_mechanics,
    source_id,
    source_url,
    observed_at
   FROM spell_definitions s;

revoke all on public.vw_spell_catalog_universal from public,anon,authenticated;
grant select on public.vw_spell_catalog_universal to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_spell_candidates_universal(p_vocation text, p_level integer, p_spell_group text DEFAULT NULL::text, p_element text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select
    huntnexus_normalize_vocation(p_vocation) as vocation_code,
    greatest(coalesce(p_level,1),1) as level_value,
    lower(nullif(trim(p_spell_group),'')) as group_filter,
    lower(nullif(trim(p_element),'')) as element_filter,
    least(greatest(coalesce(p_limit,100),1),250) as limit_value
),
v as (
  select *,
    vocation_code in ('EK','RP','ED','MS','EM') as supported
  from p
),
matches as (
  select
    s.*,
    case when s.min_level <= (select level_value from v)
      then 'eligible' else 'blocked' end as eligibility_status,
    array_remove(array[
      case when s.min_level > (select level_value from v)
        then 'level_requirement' end
    ],null) as blocking_reasons
  from vw_spell_catalog_universal s
  where s.vocation=(select vocation_code from v)
    and ((select group_filter from v) is null
      or lower(s.spell_group)=(select group_filter from v))
    and ((select element_filter from v) is null
      or lower(coalesce(s.element,''))=(select element_filter from v))
),
limited as (
  select *
  from matches
  order by
    case eligibility_status when 'eligible' then 0 else 1 end,
    min_level desc,name,spell_key
  limit (select limit_value from v)
)
select case
  when not (select supported from v) then
    jsonb_build_object(
      'error','unsupported_vocation',
      'input_vocation',p_vocation,
      'supported_vocations',jsonb_build_array('EK','RP','ED','MS','EM'),
      'methodology',jsonb_build_object('stage','spell_candidates_universal_v1')
    )
  else jsonb_build_object(
    'query',jsonb_strip_nulls(jsonb_build_object(
      'vocation',(select vocation_code from v),
      'level',(select level_value from v),
      'spell_group',(select group_filter from v),
      'element',(select element_filter from v),
      'limit',(select limit_value from v)
    )),
    'summary',jsonb_build_object(
      'catalog_spells',(select count(*) from matches),
      'eligible',(select count(*) from matches where eligibility_status='eligible'),
      'blocked',(select count(*) from matches where eligibility_status='blocked'),
      'returned',(select count(*) from limited)
    ),
    'spells',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'spell_key',spell_key,
          'name',name,
          'words',words,
          'vocation',vocation,
          'min_level',min_level,
          'spell_group',spell_group,
          'mana_cost',mana_cost,
          'cooldown_seconds',cooldown_seconds,
          'group_cooldown_seconds',group_cooldown_seconds,
          'base_power',base_power,
          'base_power_semantics',base_power_semantics,
          'scaling',scaling,
          'element',element,
          'element_mode',element_mode,
          'area_type',area_type,
          'max_targets',max_targets,
          'lever_boss_restricted',lever_boss_restricted,
          'effect_summary',effect_summary,
          'resource_mechanics',resource_mechanics,
          'eligibility_status',eligibility_status,
          'blocking_reasons',to_jsonb(blocking_reasons),
          'source_url',source_url
        )
        order by
          case eligibility_status when 'eligible' then 0 else 1 end,
          min_level desc,name,spell_key
      )
      from limited
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','spell_candidates_universal_v1',
      'category_first',true,
      'eligibility_only',true,
      'base_power_is_not_final_damage',true,
      'rotation_score_applied',false,
      'dps_formula_applied',false,
      'support_effect_strength_inferred',false,
      'additional_unlock_rules_applied',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_spell_candidates_universal(text,integer,text,text,integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_spell_candidates_universal(text,integer,text,text,integer)
  to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_spell_category_audit()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select jsonb_build_object(
  'summary',jsonb_build_object(
    'catalog_spells',(select count(*) from vw_spell_catalog_universal),
    'represented_vocations',(select count(distinct vocation) from vw_spell_catalog_universal),
    'attack_spells',(select count(*) from vw_spell_catalog_universal where spell_group='attack'),
    'healing_spells',(select count(*) from vw_spell_catalog_universal where spell_group='healing'),
    'support_spells',(select count(*) from vw_spell_catalog_universal where spell_group='support'),
    'spells_with_base_power',(select count(*) from vw_spell_catalog_universal where base_power is not null),
    'spells_with_resource_mechanics',(select count(*) from vw_spell_catalog_universal where jsonb_array_length(resource_mechanics)>0),
    'monk_spells',(select count(*) from vw_spell_catalog_universal where vocation='EM'),
    'vocation_level_contract_ready',true,
    'base_power_contract_ready',true,
    'resource_mechanics_partial_ready',true,
    'catalog_exhaustive',false,
    'additional_unlock_rules_ready',false,
    'rotation_model_ready',false,
    'final_damage_formula_ready',false
  ),
  'by_vocation',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'vocation',vocation,
        'spells',spells,
        'attack',attack,
        'healing',healing,
        'support',support
      )
      order by vocation
    )
    from (
      select vocation,count(*)::int as spells,
             count(*) filter(where spell_group='attack')::int as attack,
             count(*) filter(where spell_group='healing')::int as healing,
             count(*) filter(where spell_group='support')::int as support
      from vw_spell_catalog_universal
      group by vocation
    ) x
  ),'[]'::jsonb),
  'known_gaps',jsonb_build_array(
    jsonb_build_object(
      'key','catalog_exhaustiveness',
      'status','pending',
      'note','The current spell table is a curated combat-relevant subset, not the complete magical archive.'
    ),
    jsonb_build_object(
      'key','special_unlocks',
      'status','pending',
      'note','Quest/Shrine/Wheel unlock requirements are not yet encoded in universal eligibility; spells needing those rules are not added to the Monk core subset in this block.'
    ),
    jsonb_build_object(
      'key','rotation_and_final_formula',
      'status','pending',
      'note','Base Power, cooldown and scaling are factual inputs only; no rotation or final damage/healing formula is inferred.'
    )
  ),
  'methodology',jsonb_build_object(
    'stage','spell_category_audit_v1',
    'category_first',true,
    'base_power_is_relative_reference',true,
    'final_damage_formula_applied',false,
    'rotation_ranking_applied',false
  )
);
$function$
;

revoke all on function public.huntnexus_spell_category_audit()
  from public,anon,authenticated;
grant execute on function public.huntnexus_spell_category_audit()
  to service_role;
