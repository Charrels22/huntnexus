# HuntAnalyser public detail smoke

After validating 100 public list sessions, HuntNexus can enrich a very small subset of public detail pages.

Smoke limit: **5 sessions**.

Detail fields parsed:
- party member vocation;
- level;
- damage;
- healing;
- supplies;
- member balance (metadata);
- killed creature name;
- kill count.

Privacy rule:
- public character names are not stored as plain player names;
- a lowercase SHA-256 hash is stored in `session_players.player_name_hash`.

Creature resolution:
- strict normalized exact name;
- explicit HuntNexus entity aliases;
- otherwise unresolved.

No fuzzy monster matching is used.

The original public detail HTML is retained as a provenance snapshot.
