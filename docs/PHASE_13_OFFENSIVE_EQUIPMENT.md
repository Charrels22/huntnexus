# Phase 13 — Offensive equipment evidence

HuntNexus keeps offensive evidence in separate dimensions.

## EK elemental weapon proxy

For melee weapons where TibiaData exposes physical and elemental attack components:

`effective attack proxy = Σ(component attack × hunt kill-weighted element modifier)`

This is useful for comparing the elemental fit of weapons against the observed monster mix.

It is **not DPS** because it does not include:
- the real combat damage formula;
- character skill;
- attack speed;
- spell rotation;
- crit/leech interactions;
- imbuements;
- RubinOT overrides.

Weapon skill bonus is returned separately.

## Offensive stat candidates

For all vocations, HuntNexus also lists factual item bonuses relevant to the vocation:
- EK: sword/axe/club/fist;
- RP: distance + magic/holy magic;
- ED: magic + ice/earth/healing;
- MS: magic + fire/energy/death;
- EM: magic + fist.

Critical, attack/hit modifiers, cleave and perfect shot are retained as explicit effects.

No arbitrary cross-vocation combined DPS score is produced.
