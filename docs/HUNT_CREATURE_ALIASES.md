# Hunt-creature alias resolution

Hunting-place source strings occasionally differ from canonical creature names or contain source markup.

HuntNexus preserves the original source value in metadata and resolves only explicit, auditable mappings.

Current alias examples:
- Crystal Crusher → Crystalcrusher
- Blood Crab (Underwater) → Blood Crab
- Crypt Shambler with inline comment → Crypt Shambler
- Bone Beast → Bonebeast
- Carniphilia → Carniphila
- Overcharged Energy Elemental → Overcharged Energy Element

Malformed source values containing multiple creatures are split into separate links:
- Stalker | Green Djinn | Efreet
- Quara Mantassin Scout | Quara Pincher Scout

No guessed mapping is created for names without a defensible canonical counterpart.
