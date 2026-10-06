# Canonical boss synchronization

Boss identities are not maintained manually.

HuntNexus reads the fully detailed TibiaData creature payload and selects creatures whose:

`structuredData.combatProperties.isBoss = true`

Those entities are synchronized into `boss_profiles`.

Boss mechanics remain separate because:
- a creature being a boss does not reveal room mechanics;
- room adds and phases need their own evidence;
- RubinOT can change mechanics independently of base Tibia.

`vw_boss_rubinot_reconciliation_queue` exposes RubinOT changelog candidates that affect bosses/boss groups so they can be reconciled before old base mechanics are treated as current.
