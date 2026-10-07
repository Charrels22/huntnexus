-- HuntNexus compatibility alias.
-- Preserve the raw hunting-place slug "demongoblin" while resolving it to the
-- canonical creature key "demon-goblin" (Demon (Goblin)).

insert into public.entity_aliases(
  entity_type,
  alias_key,
  canonical_key,
  reason,
  confidence,
  source_note
)
values (
  'creature',
  'demongoblin',
  'demon-goblin',
  'source slug compatibility',
  1.0,
  'Hunting-place source uses demongoblin; canonical creature catalog key is demon-goblin (Demon (Goblin)).'
)
on conflict (entity_type, alias_key)
do update set
  canonical_key = excluded.canonical_key,
  reason = excluded.reason,
  confidence = excluded.confidence,
  source_note = excluded.source_note;
