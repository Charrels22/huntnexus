# Lovable implementation prompt — HuntNexus MVP UI

Apply the HuntNexus product UI on the existing project. Do not publish.

## Source of truth

GitHub repository: Charrels22/huntnexus.

Copy/implement:
- supabase/functions/huntnexus-api/index.ts
- migrations 0034 through current latest
- web/lovable-patch/src/routes/index.tsx as the replacement for the current Brain Status placeholder.

The database already contains the current HuntNexus Brain data. Do not recreate tables or discard existing data.

## UI requirements

Replace the internal placeholder home page with two tabs:

1. Hunts
- vocation: EK / RP / ED / MS
- level
- objective: XP / Profit / Balanced
- party size
- call Edge Function action recommend
- display ranking score and confidence separately
- Raw XP/h, XP/h and Balance/h medians
- strongest observed attack element
- observed incoming damage
- defensive item candidates
- defensive imbuement priorities
- spell candidates
- visible RubinOT reconciliation warnings

2. Bosses
- search bosses through action search_bosses
- select vocation and level
- action boss_build
- show elemental profile and candidate spells
- show boss-restricted spells separately
- prominently show reconciliation guards
- when final_build_available=false, never fabricate or display a final build

## Product rules

- Product name: HuntNexus.
- "HuntNexus Brain" is internal only.
- Do not call the product RubinOT Brain.
- Keep evidence/confidence visible.
- Do not merge Tier C observations into official facts.
- Do not present Magma Bubble or Soul War final boss builds while their RubinOT guards remain active.
- Do not publish the project.
- Keep current Supabase integration.
- Preserve existing infrastructure and files unless replacement is required for this UI.
