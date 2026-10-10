-- HuntNexus — special spell unlocks and universal proficiency-to-spell modifier linkage.
-- Level eligibility, quest/Wheel unlocks and modifier linkage stay distinct.
-- Equipment-specific spell modifier parsing remains explicitly pending.

insert into public.spell_definitions(
  spell_key,name,words,vocation,min_level,spell_group,mana_cost,
  cooldown_seconds,group_cooldown_seconds,base_power,scaling,element,
  area_type,max_targets,lever_boss_restricted,effect_summary,
  source_id,source_url,observed_at
) values
  ('avatar-of-balance','Avatar of Balance','uteta res tio','EM',300,'support',1200,7200,2,null,null,null,'self',1,false,'Wheel Revelation support spell; transforms Monk for 15 seconds with staged damage reduction and critical benefits.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Avatar_of_Balance','2026-10-10 00:00:00+00'::timestamptz),
  ('executioners-throw','Executioner''s Throw','exori amp kor','EK',1,'attack',225,18,2,60,'weapon + melee skill','physical','chain',null,false,'Wheel Revelation weapon throw causing physical damage and bouncing to nearby enemies.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Executioner%27s_Throw','2026-10-10 00:00:00+00'::timestamptz),
  ('focus-harmony','Focus Harmony','utevo nia','EM',275,'support',500,120,2,null,null,null,'self',1,false,'Instantly grants maximum Harmony.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Focus_Harmony','2026-10-10 00:00:00+00'::timestamptz),
  ('forceful-uppercut','Forceful Uppercut','exori gran pug','EM',110,'attack',325,60,2,130,'weapon + fist fighting','physical','single',1,false,'High physical melee single-target Monk attack; increases Harmony.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Forceful_Uppercut','2026-10-10 00:00:00+00'::timestamptz),
  ('great-death-beam','Great Death Beam','exevo max mort','MS',66,'attack',140,6,2,155,'magic level','death','beam',null,false,'Death-damage beam; Wheel Beam Mastery can further modify it.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Great_Death_Beam','2026-10-10 00:00:00+00'::timestamptz),
  ('groundshaker','Groundshaker','exori mas','EK',33,'attack',200,8,2,32,'weapon + melee skill','physical','around',null,false,'Physical area attack; enchanted weapon can convert part of its damage.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Groundshaker','2026-10-10 00:00:00+00'::timestamptz),
  ('heal-friend','Heal Friend','exura sio','ED',18,'healing',120,1,1,260,'magic level',null,'ally',1,false,'Targeted Druid heal.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Heal_Friend','2026-10-10 00:00:00+00'::timestamptz),
  ('ice-burst','Ice Burst','exevo ulus frigo','ED',1,'attack',230,22,2,115,'magic level','ice','around',null,false,'Wheel Revelation Ice attack around the Druid.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Ice_Burst','2026-10-10 00:00:00+00'::timestamptz),
  ('mystic-repulse','Mystic Repulse','exori amp pug','EM',30,'attack',150,8,2,85,'weapon + fist fighting','physical','single',1,false,'High physical single-target Monk attack; increases Harmony.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Mystic_Repulse','2026-10-10 00:00:00+00'::timestamptz),
  ('spiritual-outburst','Spiritual Outburst','exori gran mas nia','EM',1,'attack',425,24,2,42,'weapon + fist fighting',null,'chain',8,false,'Wheel Revelation spell; spends all Harmony and hits up to eight enemies in two moments.','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Spiritual_Outburst','2026-10-10 00:00:00+00'::timestamptz)
on conflict(spell_key) do update set
  name=excluded.name,words=excluded.words,vocation=excluded.vocation,min_level=excluded.min_level,
  spell_group=excluded.spell_group,mana_cost=excluded.mana_cost,cooldown_seconds=excluded.cooldown_seconds,
  group_cooldown_seconds=excluded.group_cooldown_seconds,base_power=excluded.base_power,scaling=excluded.scaling,
  element=excluded.element,area_type=excluded.area_type,max_targets=excluded.max_targets,
  lever_boss_restricted=excluded.lever_boss_restricted,effect_summary=excluded.effect_summary,
  source_id=excluded.source_id,source_url=excluded.source_url,observed_at=excluded.observed_at;

alter table public.spell_resource_mechanics drop constraint if exists spell_resource_mechanics_resource_action_check;
alter table public.spell_resource_mechanics add constraint spell_resource_mechanics_resource_action_check
check (resource_action = any(array['builder'::text,'spender_all'::text,'set_max'::text,'none'::text]));
alter table public.spell_resource_mechanics drop constraint if exists spell_resource_mechanics_amount_mode_check;
alter table public.spell_resource_mechanics add constraint spell_resource_mechanics_amount_mode_check
check (amount_mode = any(array['source_unspecified'::text,'all'::text,'max'::text,'none'::text]));

insert into public.spell_resource_mechanics(
  spell_key,resource_key,resource_action,amount_mode,source_tier,source_id,source_url,observed_at,notes
) values
  ('focus-harmony','harmony','set_max','max','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Focus_Harmony','2026-10-10 00:00:00+00'::timestamptz,'Sets Harmony to maximum.'),
  ('forceful-uppercut','harmony','builder','source_unspecified','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Forceful_Uppercut','2026-10-10 00:00:00+00'::timestamptz,'Source states that the spell increases Harmony; exact amount is not inferred.'),
  ('mystic-repulse','harmony','builder','source_unspecified','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Mystic_Repulse','2026-10-10 00:00:00+00'::timestamptz,'Source states that the spell increases Harmony; exact amount is not inferred.'),
  ('spiritual-outburst','harmony','spender_all','all','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Spiritual_Outburst','2026-10-10 00:00:00+00'::timestamptz,'Consumes all current Harmony.')
on conflict(spell_key,resource_key) do update set
 resource_action=excluded.resource_action,amount_mode=excluded.amount_mode,source_tier=excluded.source_tier,
 source_id=excluded.source_id,source_url=excluded.source_url,observed_at=excluded.observed_at,notes=excluded.notes;

create table if not exists public.spell_unlock_requirements (
  requirement_key text primary key,
  spell_key text not null references public.spell_definitions(spell_key) on delete cascade,
  requirement_type text not null check(requirement_type in ('quest_shrine','wheel_revelation')),
  system_key text not null,
  progress_value integer,
  requirement_label text not null,
  source_tier text not null,
  source_id uuid references public.sources(id),
  source_url text not null,
  observed_at timestamptz not null,
  notes text
);

alter table public.spell_unlock_requirements enable row level security;
revoke all on public.spell_unlock_requirements from public,anon,authenticated;
grant select on public.spell_unlock_requirements to service_role;

insert into public.spell_unlock_requirements(
  requirement_key,spell_key,requirement_type,system_key,progress_value,
  requirement_label,source_tier,source_id,source_url,observed_at,notes
) values
  ('way-of-monk-shrine-10','focus-harmony','quest_shrine','the-way-of-the-monk',10,'10th Shrine - Shrine of Eternity','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Focus_Harmony','2026-10-10 00:00:00+00'::timestamptz,'Learned at the tenth shrine.'),
  ('way-of-monk-shrine-3','mystic-repulse','quest_shrine','the-way-of-the-monk',3,'3rd Shrine - Shrine of Respect','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Mystic_Repulse','2026-10-10 00:00:00+00'::timestamptz,'Learned at the third shrine.'),
  ('way-of-monk-shrine-8','forceful-uppercut','quest_shrine','the-way-of-the-monk',8,'8th Shrine - Shrine of Knowledge','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Forceful_Uppercut','2026-10-10 00:00:00+00'::timestamptz,'Learned at the eighth shrine.'),
  ('wheel-revelation-avatar-of-balance','avatar-of-balance','wheel_revelation','wheel-of-destiny',null,'Wheel Revelation: Avatar of Balance','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Avatar_of_Balance','2026-10-10 00:00:00+00'::timestamptz,'Wheel of Destiny Revelation.'),
  ('wheel-revelation-executioners-throw','executioners-throw','wheel_revelation','wheel-of-destiny',null,'Wheel of Destiny Revelation: Executioner''s Throw','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Executioner%27s_Throw','2026-10-10 00:00:00+00'::timestamptz,'Revelation ability granted through the Wheel of Destiny.'),
  ('wheel-revelation-spiritual-outburst','spiritual-outburst','wheel_revelation','wheel-of-destiny',null,'Wheel Revelation: Spiritual Outburst','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Spiritual_Outburst','2026-10-10 00:00:00+00'::timestamptz,'Wheel of Destiny Revelation.'),
  ('wheel-revelation-twin-bursts-ice','ice-burst','wheel_revelation','wheel-of-destiny',null,'Wheel Revelation: Twin Bursts / Ice Burst','B','53148ef0-b2d6-44fd-b205-59e6fd33b9ea'::uuid,'https://www.tibiawiki.com.br/wiki/Ice_Burst','2026-10-10 00:00:00+00'::timestamptz,'Ice Burst granted through Twin Bursts.')
on conflict(requirement_key) do update set
 spell_key=excluded.spell_key,requirement_type=excluded.requirement_type,system_key=excluded.system_key,
 progress_value=excluded.progress_value,requirement_label=excluded.requirement_label,source_tier=excluded.source_tier,
 source_id=excluded.source_id,source_url=excluded.source_url,observed_at=excluded.observed_at,notes=excluded.notes;

create or replace view public.vw_spell_modifier_links_universal
with (security_invoker=true)
as
 SELECT 'weapon_proficiency'::text AS source_layer,
    p.item_key AS source_item_key,
    w.name AS source_item_name,
    w.weapon_family AS source_item_family,
    p.perk_order AS source_order,
    p.effect_key AS modifier_key,
    p.numeric_value,
    p.unit,
    p.scope,
    p.description_raw,
        CASE
            WHEN p.scope = 'bestiary'::text THEN 'not_spell_modifier'::text
            WHEN p.spell_key IS NOT NULL THEN 'exact_spell'::text
            WHEN p.scope = 'spells'::text THEN 'generic_spells'::text
            WHEN p.scope = 'healing_spells'::text THEN 'healing_spells'::text
            WHEN p.scope = 'offensive_runes'::text THEN 'offensive_runes'::text
            WHEN p.scope ~~ '%_spells_runes'::text THEN 'element_spells_runes'::text
            ELSE 'other_scope'::text
        END AS target_type,
        CASE
            WHEN p.scope = 'bestiary'::text THEN NULL::text
            WHEN p.spell_key IS NOT NULL THEN p.spell_key
            ELSE p.scope
        END AS target_key,
        CASE
            WHEN p.scope <> 'bestiary'::text THEN s.spell_key
            ELSE NULL::text
        END AS linked_spell_key,
        CASE
            WHEN p.scope <> 'bestiary'::text THEN s.name
            ELSE NULL::text
        END AS linked_spell_name,
        CASE
            WHEN p.scope = 'bestiary'::text THEN 'excluded_non_spell_scope'::text
            WHEN p.spell_key IS NOT NULL AND s.spell_key IS NOT NULL THEN 'resolved'::text
            WHEN p.spell_key IS NOT NULL AND s.spell_key IS NULL THEN 'unresolved_spell_key'::text
            WHEN (p.scope = ANY (ARRAY['spells'::text, 'healing_spells'::text, 'offensive_runes'::text])) OR p.scope ~~ '%_spells_runes'::text THEN 'selector_only'::text
            ELSE 'unclassified_scope'::text
        END AS link_status,
    p.source_url,
    p.source_tier,
    p.metadata
   FROM weapon_proficiency_perks p
     JOIN vw_weapon_catalog_universal w ON w.item_key = p.item_key
     LEFT JOIN spell_definitions s ON s.spell_key = p.spell_key;

revoke all on public.vw_spell_modifier_links_universal from public,anon,authenticated;
grant select on public.vw_spell_modifier_links_universal to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_spell_candidates_with_unlocks_universal(p_vocation text, p_level integer, p_unlocked_requirement_keys jsonb DEFAULT '[]'::jsonb, p_spell_group text DEFAULT NULL::text, p_element text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with p as (
  select huntnexus_normalize_vocation(p_vocation) vocation,
         greatest(coalesce(p_level,1),1) lvl,
         case when jsonb_typeof(coalesce(p_unlocked_requirement_keys,'[]'::jsonb))='array'
              then coalesce(p_unlocked_requirement_keys,'[]'::jsonb) else '[]'::jsonb end unlocks,
         lower(nullif(trim(p_spell_group),'')) grp,
         lower(nullif(trim(p_element),'')) elem,
         least(greatest(coalesce(p_limit,100),1),250) lim
),
m as (
  select s.*,
         coalesce(r.req_count,0) req_count,
         coalesce(r.sat_count,0) sat_count,
         coalesce(r.reqs,'[]'::jsonb) reqs
  from vw_spell_catalog_universal s
  cross join p
  left join lateral (
    select count(*)::int req_count,
           count(*) filter(where exists(
             select 1 from jsonb_array_elements_text(p.unlocks) u(v)
             where u.v=sr.requirement_key
           ))::int sat_count,
           jsonb_agg(jsonb_build_object(
             'requirement_key',sr.requirement_key,
             'requirement_type',sr.requirement_type,
             'system_key',sr.system_key,
             'progress_value',sr.progress_value,
             'requirement_label',sr.requirement_label,
             'satisfied',exists(
               select 1 from jsonb_array_elements_text(p.unlocks) u(v)
               where u.v=sr.requirement_key
             ),
             'source_url',sr.source_url
           ) order by sr.requirement_key) reqs
    from spell_unlock_requirements sr
    where sr.spell_key=s.spell_key
  ) r on true
  where s.vocation=p.vocation
    and (p.grp is null or lower(s.spell_group)=p.grp)
    and (p.elem is null or lower(coalesce(s.element,''))=p.elem)
),
e as (
  select *,
    case when min_level>(select lvl from p) then 'blocked'
         when req_count>sat_count then 'incomplete'
         else 'eligible' end status,
    array_remove(array[
      case when min_level>(select lvl from p) then 'level_requirement' end,
      case when min_level<=(select lvl from p) and req_count>sat_count then 'special_unlock_required' end
    ],null) reasons
  from m
),
l as (
  select * from e
  order by case status when 'eligible' then 0 when 'incomplete' then 1 else 2 end,
           min_level desc,name
  limit (select lim from p)
)
select case
  when (select vocation from p) not in ('EK','RP','ED','MS','EM') then
    jsonb_build_object('error','unsupported_vocation','input_vocation',p_vocation)
  else jsonb_build_object(
    'query',jsonb_build_object(
      'vocation',(select vocation from p),
      'level',(select lvl from p),
      'unlocked_requirement_keys',(select unlocks from p)
    ),
    'summary',jsonb_build_object(
      'catalog_spells',(select count(*) from e),
      'eligible',(select count(*) from e where status='eligible'),
      'incomplete',(select count(*) from e where status='incomplete'),
      'blocked',(select count(*) from e where status='blocked'),
      'returned',(select count(*) from l)
    ),
    'spells',coalesce((
      select jsonb_agg(jsonb_build_object(
        'spell_key',spell_key,'name',name,'min_level',min_level,'spell_group',spell_group,
        'mana_cost',mana_cost,'cooldown_seconds',cooldown_seconds,
        'group_cooldown_seconds',group_cooldown_seconds,'base_power',base_power,
        'base_power_semantics',base_power_semantics,'scaling',scaling,'element',element,
        'area_type',area_type,'resource_mechanics',resource_mechanics,
        'special_requirements',reqs,'eligibility_status',status,'blocking_reasons',to_jsonb(reasons),
        'source_url',source_url
      ) order by case status when 'eligible' then 0 when 'incomplete' then 1 else 2 end,min_level desc,name)
      from l
    ),'[]'::jsonb),
    'methodology',jsonb_build_object(
      'stage','spell_candidates_with_unlocks_universal_v1',
      'level_requirement_applied',true,
      'special_unlock_requirements_applied',true,
      'missing_unlock_state_is_not_assumed_unlocked',true,
      'dps_formula_applied',false,
      'rotation_score_applied',false
    )
  )
end;
$function$
;

revoke all on function public.huntnexus_spell_candidates_with_unlocks_universal(text,integer,jsonb,text,text,integer)
from public,anon,authenticated;
grant execute on function public.huntnexus_spell_candidates_with_unlocks_universal(text,integer,jsonb,text,text,integer)
to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_spell_modifier_context_universal(p_spell_key text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
with s as (
  select * from vw_spell_catalog_universal where spell_key=p_spell_key
),
exact as (
  select m.*
  from vw_spell_modifier_links_universal m
  where m.target_type='exact_spell' and m.target_key=p_spell_key
),
selectors as (
  select m.*
  from vw_spell_modifier_links_universal m
  cross join s
  where m.link_status='selector_only'
    and (
      m.target_type='generic_spells'
      or (m.target_type='healing_spells' and s.spell_group='healing')
      or (m.target_type='element_spells_runes' and s.element is not null and m.scope=s.element||'_spells_runes')
    )
)
select coalesce((
  select jsonb_build_object(
    'spell',jsonb_build_object('spell_key',s.spell_key,'name',s.name,'vocation',s.vocation,'spell_group',s.spell_group,'element',s.element),
    'exact_weapon_proficiency_modifiers',coalesce((
      select jsonb_agg(jsonb_build_object(
        'source_item_key',e.source_item_key,'source_item_name',e.source_item_name,
        'source_order',e.source_order,'modifier_key',e.modifier_key,'value',e.numeric_value,
        'unit',e.unit,'scope',e.scope,'description',e.description_raw,'source_url',e.source_url
      ) order by e.source_item_key,e.source_order) from exact e
    ),'[]'::jsonb),
    'generic_weapon_proficiency_selectors',coalesce((
      select jsonb_agg(jsonb_build_object(
        'source_item_key',g.source_item_key,'source_item_name',g.source_item_name,
        'source_order',g.source_order,'modifier_key',g.modifier_key,'value',g.numeric_value,
        'unit',g.unit,'scope',g.scope,'target_type',g.target_type,'description',g.description_raw,
        'source_url',g.source_url
      ) order by g.source_item_key,g.source_order) from selectors g
    ),'[]'::jsonb),
    'equipment_specific_modifier_evidence',jsonb_build_object(
      'parsed',false,'status','pending',
      'note','Current item_effects does not reliably encode spell-specific equipment modifiers; no equipment-to-spell link is invented.'
    ),
    'methodology',jsonb_build_object(
      'stage','spell_modifier_context_universal_v1',
      'exact_spell_links_resolved_from_spell_key',true,
      'generic_selectors_are_not_forced_into_exact_links',true,
      'equipment_specific_modifier_links_ready',false,
      'modifier_activation_applied',false,
      'final_damage_formula_applied',false
    )
  ) from s
),jsonb_build_object('error','spell_not_found','spell_key',p_spell_key));
$function$
;

revoke all on function public.huntnexus_spell_modifier_context_universal(text)
from public,anon,authenticated;
grant execute on function public.huntnexus_spell_modifier_context_universal(text)
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
    'monk_spells',(select count(*) from vw_spell_catalog_universal where vocation='EM'),
    'special_unlock_requirements',(select count(*) from spell_unlock_requirements),
    'spells_with_special_unlocks',(select count(distinct spell_key) from spell_unlock_requirements),
    'resolved_exact_proficiency_spell_links',(select count(*) from vw_spell_modifier_links_universal where target_type='exact_spell' and link_status='resolved'),
    'unresolved_exact_proficiency_spell_links',(select count(*) from vw_spell_modifier_links_universal where target_type='exact_spell' and link_status='unresolved_spell_key'),
    'generic_proficiency_spell_selectors',(select count(*) from vw_spell_modifier_links_universal where link_status='selector_only'),
    'vocation_level_contract_ready',true,
    'special_unlock_rules_ready',true,
    'proficiency_spell_linkage_ready',true,
    'equipment_specific_modifier_links_ready',false,
    'catalog_exhaustive',false,
    'rotation_model_ready',false,
    'final_damage_formula_ready',false
  ),
  'known_gaps',jsonb_build_array(
    jsonb_build_object('key','catalog_exhaustiveness','status','pending'),
    jsonb_build_object('key','equipment_spell_modifiers','status','pending'),
    jsonb_build_object('key','wheel_augments','status','partial'),
    jsonb_build_object('key','rotation_and_final_formula','status','pending')
  ),
  'methodology',jsonb_build_object(
    'stage','spell_category_audit_v2',
    'special_unlocks_separate_from_level',true,
    'generic_modifier_selectors_not_forced_to_exact_spells',true,
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
