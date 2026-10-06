# Phase 15 — Core spells and boss/hunt spell candidates

The curated core spell catalogue stores factual spell metadata:
- vocation and minimum level;
- words;
- mana;
- individual/group cooldown;
- base power;
- scaling;
- element;
- area type;
- known lever-boss restrictions.

The candidate function separates:
- single-target attacks;
- multi-target attacks;
- healing;
- support.

For elemental spells, HuntNexus exposes an element-adjusted base-power proxy using the observed kill-weighted hunt vulnerability.

It is not final DPS and not a final rotation.

Knight weapon-based spells remain linked to the separate weapon-element layer.

Boss context automatically excludes support spells explicitly documented as unavailable against lever bosses.
