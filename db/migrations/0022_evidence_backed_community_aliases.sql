-- HuntNexus Brain — Phase 9.2 evidence-backed community hunt aliases.
-- Alias decisions require strong semantic and/or observed kill-set evidence.

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
        v,
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'
      ),
      '[^a-zA-Z0-9]+','-','g'
    )
  ))
  from decoded;
$$;

insert into community_hunt_aliases(
  source_id,raw_name_normalized,canonical_hunt_key,confidence,resolution_method,notes
)
select s.id,x.raw_name_normalized,x.canonical_hunt_key,x.confidence,
       'name_plus_kill_evidence',x.notes
from sources s
cross join (
  values
    ('undead-dragon-hunt-exaltation-overlord','grounds-of-undeath',1.00,
      'All 4 observed monster types and 100% of kills match Grounds of Undeath.'),
    ('undead-dragons-blightwalker-bounty-hunt','grounds-of-undeath',1.00,
      'All 4 observed monster types and 100% of kills match Grounds of Undeath.'),
    ('bashmu-902','salt-caves',1.00,
      'Both observed monster types and 100% of kills match Salt Caves.'),
    ('bultaurs','bulltaur-lair',0.99,
      '3 canonical Bulltaur Lair monsters account for 99.9% of observed kills.'),
    ('burster-spectre-darashia','haunted-tomb',1.00,
      'Community title specifies Darashia; canonical Haunted Tomb is in Darashia and observed Burster Spectre coverage is complete.'),
    ('cobra-basement','cobra-bastion',1.00,
      'Basement is a community subarea label; all observed monsters match Cobra Bastion. Raw label remains preserved.'),
    ('falcons-frigo-ii-forked-glacier-bounty','falcon-bastion',1.00,
      'Observed monsters match Falcon Bastion and title explicitly identifies Falcons.'),
    ('iks-last-stand-entrance','iksupan-last-stand',1.00,
      'Explicit Last Stand label plus full observed kill-set compatibility.'),
    ('iks-occ-mitmah-seers','iksupan-occupied-sanctuary',1.00,
      'Community abbreviation OCC maps semantically to Occupied Sanctuary; observed monsters are compatible.'),
    ('iksupan-last-stand-forked-ii-bounty','iksupan-last-stand',1.00,
      'Explicit canonical hunt name with modifier suffix.'),
    ('issavi-sphinx-2','kilmaresh-catacombs',0.99,
      'Both observed monster types match Kilmaresh Catacombs; canonical location is under western Issavi.'),
    ('netherworld-port-hope-frigo-ii-glacier-i-bounty','netherworld',0.99,
      'Title explicitly names Netherworld; all observed monsters are compatible.'),
    ('nimersatt-s-dragon-lair-1','nimmersatts-breeding-ground',1.00,
      'All observed monsters match Nimmersatt''s Breeding Ground; community title is a naming variant.'),
    ('prison-3','roshamuul-prison',1.00,
      'All 6 observed monster types and 100% of kills match Roshamuul Prison.'),
    ('roshamuul-shock-heads','guzzlemaw-valley',0.99,
      'All 4 observed monster types and 100% of kills match Guzzlemaw Valley.'),
    ('warzone-5-forked-ii-bounty','warzone-5',1.00,
      'Explicit canonical hunt name with modifier suffix.'),
    ('warzone-5-frigo-hur-ii-forked-i','warzone-5',1.00,
      'Explicit canonical hunt name with modifier suffix.'),
    ('werecrocodiles','murky-caverns',0.99,
      'All 3 canonical Murky Caverns monsters cover 100% of observed kills.')
) as x(raw_name_normalized,canonical_hunt_key,confidence,notes)
where s.name='HuntAnalyser Public Hunts'
on conflict(source_id,raw_name_normalized) do update set
  canonical_hunt_key=excluded.canonical_hunt_key,
  confidence=excluded.confidence,
  resolution_method=excluded.resolution_method,
  notes=excluded.notes,
  observed_at=now();

select huntnexus_resolve_community_hunts_exact('HuntAnalyser Public Hunts');
