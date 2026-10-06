# Phase 12 — Defensive equipment candidates

Phase 12 connects two existing HuntNexus layers:

1. observed incoming damage by element (Tier C);
2. normalized item protection effects (Tier B).

For a hunt, vocation and level, each eligible item receives a weighted protection score:

`sum(observed_damage_share[element] × item_protection_percent[element])`

Items are then ranked inside their equipment slot.

This is intentionally not a final set optimizer.

It does not yet optimize:
- offensive skill/magic bonuses;
- weapon damage;
- imbuements;
- armor/defense tradeoffs;
- item price/availability;
- duplicate/conflicting slots;
- set interactions;
- RubinOT exact overrides;
- boss-specific mechanics.

The output is a defensible shortlist of protective items that the final build engine can combine with offensive and mechanical requirements.
