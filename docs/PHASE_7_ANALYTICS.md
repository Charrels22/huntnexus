# Phase 7 — HuntNexus Analytics factual foundation

Phase 7 begins analytics without pretending that base/reference data is observed performance.

## Views

### vw_hunt_monster_element_profile
One row per hunt × monster × element.

### vw_hunt_element_summary
Aggregates species-level elemental responses:
- average modifier;
- minimum and maximum modifier;
- weak monster count;
- neutral monster count;
- resistant monster count;
- immune monster count.

This summary is intentionally **unweighted**. It does not know how frequently each monster spawns or how many are killed per hour, so it is evidence — not a final recommendation.

### vw_equipment_protection_catalog
Normalized protection effects by item, vocation and required level.

### vw_equipment_combat_effects
All normalized combat effects by item.

## Function

`huntnexus_hunt_factual_profile(hunt_key)`

Returns:
- hunt metadata;
- canonical monsters;
- elemental profile;
- methodology flags.

The function explicitly reports:
- `weighted_by_kills=false`;
- `final_recommendation=false`.

Observed community sessions will later provide kill weighting, XP/h, profit/h, damage/healing and modifier context.
