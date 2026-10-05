# Phase 5 — normalized equipment effects

Phase 5 derives machine-readable combat effects from the 1,610 fully detailed combat/equipment items.

## Source semantics verified before parsing

- `resist` exists on 400 items.
- `resistPercent` exists on 94 items.
- All 94 items containing both fields have exactly the same value in both fields.
- The normalized layer therefore prefers `resistPercent` when present and otherwise uses `resist`, avoiding duplicate protection effects while retaining both raw source fields.

Verified `attrib` patterns include:
- magic level;
- elemental/healing magic levels;
- sword/axe/club/distance/fist fighting;
- shielding;
- speed;
- life leech;
- cleave;
- damage reflection;
- perfect shot with range;
- magic shield capacity;
- faster regeneration;
- magic shield;
- invisibility.

Structured additional attributes also expose critical chance/damage, attack modifier, hit modifier, charges and duration.

## Safety rule

Only verified patterns are normalized. Unknown `attrib` tokens are written to `item_effect_parse_issues` instead of being guessed. The original payload is always retained.
