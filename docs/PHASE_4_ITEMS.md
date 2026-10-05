# Phase 4 — item detail enrichment

HuntNexus prioritizes combat/equipment-relevant items before non-combat catalogue items.

Current combat-relevant categories:
- weapons (club, sword, axe, fist, throwing, bow, crossbow, wand, rod);
- armors, helmets, shields, boots, legs;
- amulets/necklaces, rings;
- quivers, spellbooks;
- clothing accessories;
- enchanted and magical items.

At Phase 4 start this subset contains **1,610 items** of the 6,470-item catalogue.

Detail endpoint:
`GET /api/v1/items/{id}`

Preserved/normalized fields include attack, defense, armor, vocation, required level, imbue slots, elemental attacks, NPC values, weight, upgrade class and all additional attribute key/value entries.

The full response remains in `tibia_items.structured_data` and in a provenance-preserving raw snapshot.
