-- HuntNexus Brain — Phase 25 normalization compatibility + safe creature aliases.

create or replace function huntnexus_normalize_label(p_value text)
returns text
language sql
immutable
as $$
  with decoded as (
    select replace(
             replace(
               replace(
                 replace(
                   replace(coalesce(p_value,''),'&#39;',chr(39)),
                 '&#x27;',chr(39)),
               '&amp;','&'),
             '&quot;','"'),
           '&#34;','"') as v
  )
  select trim(both '-' from lower(
    regexp_replace(
      translate(
        replace(replace(v,'''',''),'’',''),
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'
      ),
      '[^a-zA-Z0-9]+','-','g'
    )
  ))
  from decoded;
$$;

insert into entity_aliases(
  entity_type,alias_key,canonical_key,reason,confidence,source_note
)
values
  (
    'creature','icicle','icicle-creature',
    'catalog disambiguation suffix',1.0,
    'Community/source label omits the TibiaData parenthetical suffix "(Creature)".'
  ),
  (
    'creature','sabretooth','sabretooth-creature',
    'catalog disambiguation suffix',1.0,
    'Community/source label omits the TibiaData parenthetical suffix "(Creature)".'
  )
on conflict(entity_type,alias_key) do update set
  canonical_key=excluded.canonical_key,
  reason=excluded.reason,
  confidence=excluded.confidence,
  source_note=excluded.source_note;

-- Re-resolve community hunt aliases after normalization compatibility fix.
select huntnexus_resolve_community_hunts_exact('HuntAnalyser Public Hunts');

-- Re-resolve unresolved session creatures/damage sources only through exact/explicit alias rules.
update session_creatures sc
set monster_key=huntnexus_resolve_creature_exact(sc.monster_name_raw),
    resolution_status=case
      when huntnexus_resolve_creature_exact(sc.monster_name_raw) is null then 'unresolved'
      else 'resolved_exact_or_alias'
    end
where sc.monster_key is null;

update session_incoming_damage_sources s
set monster_key=huntnexus_resolve_creature_exact(s.monster_name_raw)
where s.monster_key is null;
