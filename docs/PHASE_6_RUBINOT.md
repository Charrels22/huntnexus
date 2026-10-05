# Phase 6 — RubinOT official mechanics

Phase 6 begins the Tier A RubinOT layer.

## Access behavior

The official RubinOT changelog is accessible through browser/web retrieval, but direct HTTP from the current Supabase/PostgreSQL environment receives Cloudflare 403. HuntNexus records this access method instead of bypassing the protection.

## Analytics-relevant official systems

### Huntfinder
Official Huntfinder supports:
- vocation and solo/duo/party filters;
- level/class hunt suggestions;
- recommended items, imbuements, sets and Charm Runes;
- XP/h and profit/h;
- XP/loot/both categories;
- kill tracking;
- rotation and map guidance.

These capabilities are treated as a useful official comparison target for HuntNexus recommendations, not copied as observed session data.

### Equipment Preset
Presets can represent contexts such as hunt and elemental resistance. Charged amulets/rings are not accepted, and switching has an activation delay.

### Guild Ascension
This system is dynamic and seasonal:
- 6 slots;
- slots 1–3 General Bonus;
- slot 4 Race Damage;
- slot 5 Elemental Damage;
- slot 6 Elemental Defense;
- 5 cumulative perk levels per slot;
- bonuses reset at Season end.

The official page explicitly states that its illustrative percentage table is **not** the real game values. HuntNexus therefore stores Guild Ascension values as dynamic session/player modifiers and never hardcodes the illustrative percentages.

### Linked Tasks
Tasks are repeatable after first completion; only one can be active per character, and first-completion rewards can differ from repeat rewards.
