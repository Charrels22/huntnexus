# RubinOT changelog reconciliation queue

Recent official changelog entries are first recorded as **change candidates**, not immediately as overrides.

This prevents a qualitative statement such as “spell frequency reduced” from being turned into a fabricated numeric value.

Current candidate examples:
- global monster chase/return behavior changes in server v13.8;
- Magma Bubble mechanics rework;
- Soul War boss mechanics rework;
- Biscuit Barrier effect-description correction;
- Phantasmal Axe attack-property correction;
- Bloodjaw spell-frequency reduction;
- Spit Nettle behavior revision;
- Book World loot improvements.

A candidate can become a `rubinot_overrides` row only when an exact current value/state can be supported by an official source.

Statuses:
- `pending`: needs reconciliation;
- `needs_exact_value`: change direction/type known, exact override still unknown;
- `resolved`: linked to an applied versioned override;
- `not_applicable`: relevant change but not represented as a data override.
