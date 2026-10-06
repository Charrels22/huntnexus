-- HuntNexus Brain — Phase 9.1 safe HuntAnalyser hunt aliases.
-- Only high-confidence title variants are mapped automatically.
-- Ambiguous subareas such as Energy Library / Fire Library remain unresolved.

insert into community_hunt_aliases(
  source_id,raw_name_normalized,canonical_hunt_key,confidence,resolution_method,notes
)
select s.id,x.raw_name_normalized,x.canonical_hunt_key,x.confidence,'manual_high_confidence',x.notes
from sources s
cross join (
  values
    ('podzilla-quaras','podzilla',0.99,'Community label clearly references the canonical Podzilla hunting place.'),
    ('azzilon-castle-4-man','azzilon-castle',1.00,'Party-size suffix only.'),
    ('azzilion-x3','azzilon-castle',0.98,'Spelling variant + party-size suffix.'),
    ('azzilion-x4','azzilon-castle',0.98,'Spelling variant + party-size suffix.'),
    ('azzilon-castle-ek-em-duo','azzilon-castle',1.00,'Vocation/party suffix only.'),
    ('gloom-pillar','gloom-pillars',0.99,'Singular community label for canonical Gloom Pillars.'),
    ('gloom-pillar-evento','gloom-pillars',0.99,'Event suffix only.'),
    ('gloom-pillar-evento-exaltation','gloom-pillars',0.99,'Event suffix only.'),
    ('brain-grounds-flimsy-lost-souls-solo','brain-grounds',1.00,'Monster/solo descriptor appended to canonical hunt name.'),
    ('nimmersatts-breeding-ground','nimmersatts-breeding-ground',1.00,'Exact canonical hunt after HTML entity normalization.'),
    ('nimmersatts-breeding-ground-7','nimmersatts-breeding-ground',0.99,'Floor suffix only.'),
    ('nimmersatts-breeding-ground-forked-only','nimmersatts-breeding-ground',0.99,'Modifier suffix only.'),
    ('nimmersatts-breeding-ground-x4','nimmersatts-breeding-ground',0.99,'Party-size suffix only.')
) as x(raw_name_normalized,canonical_hunt_key,confidence,notes)
where s.name='HuntAnalyser Public Hunts'
on conflict(source_id,raw_name_normalized) do update set
  canonical_hunt_key=excluded.canonical_hunt_key,
  confidence=excluded.confidence,
  resolution_method=excluded.resolution_method,
  notes=excluded.notes,
  observed_at=now();

-- Re-run explicit + exact reconciliation after loading aliases.
select huntnexus_resolve_community_hunts_exact('HuntAnalyser Public Hunts');
