# Phase 3 — creature and hunting-place details

Source: ByteWizards TibiaData (Tier B).

## Creature detail endpoint

`GET /api/v1/creatures/{id|name}`

The current API contract exposes:

- id, name, hitpoints, experience, lastUpdated;
- structuredData.infobox;
- structuredData.resistanceSummary;
- structuredData.combatProperties;
- lootStatistics;
- images.

### Normalization rules

- Full response remains in the raw snapshot and in `tibia_entities.attributes`.
- `resistanceSummary` is normalized into `monster_vulnerability`.
- `combatProperties` remains in attributes; maxDamage/usesSpells are also copied to `creature_abilities`.
- `infobox.abilities` and `infobox.attackType` are preserved as raw source text.
- HuntNexus must **not** infer individual attack damage, attack element or frequency unless the source exposes them unambiguously.
- `lootStatistics` is normalized into `creature_loot`.
- Fetch status is tracked in `creature_detail_state`.

## Hunting-place detail endpoint

`GET /api/v1/hunting-places/{id|name}`

Full responses update `tibia_hunting_places.structured_data`.
Creature membership is normalized into `hunting_place_creatures`.

## Incremental refresh

Use source `/sync/by-date` endpoints so later runs only refetch changed records.
