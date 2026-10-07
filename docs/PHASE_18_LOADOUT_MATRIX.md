# Phase 18 — Transparent loadout matrix

The HuntNexus hunt recommendation now exposes a per-slot equipment matrix without pretending that offense, defense and imbue capacity are the same thing.

For each eligible item/slot the matrix keeps:

- observed-damage-weighted elemental protection;
- vocation-relevant offensive skill/magic bonuses;
- offensive special effects already normalized;
- imbue slot count;
- armor/defense and level eligibility;
- independent rank per dimension.

Candidate selection is the union of the top items per slot in each independent dimension.

There is deliberately no combined equipment score yet.

This gives the future UI/build optimizer enough evidence to explain choices such as:
- “best protection for this hunt”;
- “best offensive bonus in this slot”;
- “more imbue capacity at the cost of protection”.

The final set optimizer remains a separate step.
