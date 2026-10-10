# HuntNexus Frontend Architecture v1

## Product principle

HuntNexus is a player-facing Tibia/RubinOT companion, not a technical dashboard.

The frontend must answer, visually and quickly:

1. Where should I hunt with my character?
2. What setup should I use there?
3. How did my own hunt session perform?
4. What can I improve next time?

Technical optimizer internals, SQL stages, Pareto vectors and audit payloads remain behind the UI.

## Visual rules

- Use official Tibia/RubinOT visual assets for monsters, items, maps, hunt locations and game-world references whenever available and legally usable.
- Do not replace canonical Tibia creatures/items/locations with generic fantasy art.
- Character presentation may be visually enhanced/stylized, but must remain recognizable as Tibia/RubinOT.
- Interface should be dark, game-oriented and image-forward.
- Avoid static walls of text.
- Use cards, transitions, charts, hover states, tabs, progressive disclosure, animated counters and contextual tooltips.
- Motion must support comprehension, not distract.
- Evidence/confidence must be visible but secondary to the player decision.

---

# Global navigation

Desktop shell:

- HuntNexus logo
- Global search: hunts, creatures, items
- Main navigation:
  - Hunt Planner
  - Session Analyzer
  - Hunts
  - Loadouts
  - Creatures
  - Bosses
  - Community
- Player/Profile shortcut
- Recent hunts/session history

Recommended sidebar:

1. Dashboard
2. Hunt Planner
3. Session Analyzer
4. Loadouts
5. Creatures
6. Bosses
7. Analytics
8. Profile

---

# Route map

## / — Dashboard

Purpose:
Give the player one useful starting point.

Main areas:

### Character strip
- Vocation
- Level
- Party size
- Hunt objective
- Set objective
- Optional saved character profile

### Quick actions
- Find a Hunt
- Analyze Session
- Compare Loadouts

### Recommended Hunts
Image-rich cards with:
- official hunt/location visual
- hunt name
- XP/h
- Profit/h
- confidence
- difficulty / evidence quality
- strongest relevant elements
- party/solo indicator
- View Hunt / View Setup

### Recent Sessions
- date
- hunt
- duration
- XP/h
- profit/h
- short trend indicator
- Analyze button

---

## /planner — Hunt Planner

Purpose:
The main optimizer experience.

Inputs:

### Character
- Vocation: EK / RP / ED / MS / EM
- Level
- Party size
- Character profile
- effective skills / magic level when available
- Weapon Proficiency selections
- special unlocks

### Hunt objective
- XP
- Profit
- Balanced

### Set objective
- Offense
- Defense
- Sustain
- Utility
- Balanced

CTA:
Find Hunts

Results:
- ranked hunt cards
- confidence separated from performance
- no fake single "best" set
- selected hunt opens detail drawer/page

Backend source:
huntnexus_optimizer_final_universal()

---

## /hunts/:huntKey — Hunt Detail

Purpose:
Everything the player needs to understand a hunt before entering it.

Hero:
- official/canonical location visual
- hunt name
- recommended level context
- solo/party information
- confidence/evidence
- XP / profit observed medians

Tabs:

### Overview
- XP/h
- Profit/h
- confidence
- session count
- difficulty/evidence labels
- main risks

### Creatures
- official creature sprites/images
- names
- elemental profile
- important mechanics when documented

### Map
- Tibia map representation
- entrance / route / relevant zones when data exists

### Damage
- incoming damage composition
- elemental risk
- physical vs elemental
- protectable damage

### Setup
- selected co-winner loadouts
- equipment grid
- why each set survived
- offense/defense/sustain/utility alternatives

### Spells & Proficiency
- eligible spells
- locked/incomplete spells visibly separated
- exact Weapon Proficiency context
- no inferred unlocks

### Imbuements
- defensive priorities from observed incoming damage
- observed community usage shown separately
- no cross-type invented ranking

### Community
- real sessions
- level/vocation context
- evidence quality
- recent performance distribution

---

# /session — Session Analyzer

Purpose:
Analyze a hunt the player actually participated in.

This is the Hunt Analyzer equivalent in HuntNexus layout.

Data ingestion:
- paste/import supported Hunt Analyzer session information
- load previously stored session
- future automatic imports if supported

The four main tabs are the same conceptual categories as the source analyzer:

## Hunt Analyse

Primary session economy/performance.

Show:
- session duration
- raw XP
- XP/h
- loot
- supplies
- balance/profit
- profit/h
- kills
- relevant bonuses
- comparison with player's history when available

Visuals:
- KPI counters
- XP timeline
- profit timeline
- session efficiency cards
- history comparison

## Misc

Auxiliary session data.

Show whichever source fields are available, including:
- consumables
- supplies
- healing/mana usage
- loot details
- tasks / auxiliary counters
- session metadata

Do not invent unsupported fields.

## Damage

Combat analysis for the player's session.

Show:
- damage dealt
- damage received
- damage/h
- damage by element
- damage by spell/source when available
- charm damage
- charm contribution
- incoming damage by element
- healing when present
- largest/most relevant sources

Visuals:
- damage donut
- stacked element bars
- dealt vs received
- charm contribution cards
- source/spell breakdown

## Party Hunt

Only when party data exists.

Show:
- party members
- vocation
- level when available
- damage contribution
- healing contribution
- XP/share relevant data
- contribution percentages
- party total
- individual comparisons

Visuals:
- member cards
- contribution bars
- party composition
- damage/healing comparison

Important:
Hunt Analyse / Misc / Damage / Party Hunt are not recommendation categories. They are views over an actual player hunt session.

---

# /sessions — Session History

Purpose:
Player history and progression.

- filters by hunt/date/vocation/party
- XP/h trend
- profit/h trend
- damage dealt/received trend
- best session
- recent sessions
- open full Session Analyzer

---

# /loadouts — Loadout Explorer

Purpose:
Inspect and compare optimizer-valid setups outside one hunt detail page.

Features:
- hunt selector
- vocation / level
- set objective
- co-winner loadouts
- equipment slot grid
- compare two sets
- factual differences only
- no synthetic universal score

---

# /creatures — Creature Explorer

- search
- official Tibia creature visual
- elements
- weaknesses/resistances
- hunt locations
- related sessions
- known mechanics
- source/evidence

---

# /bosses — Boss Explorer

Existing boss work should remain available but redesigned into the same visual system.

- boss search
- vocation / level
- elemental profile
- candidate spells
- restricted spells separately
- reconciliation guards visible
- no fabricated final build when unavailable

---

# /community — Community Hunts

Purpose:
Use real hunt sessions as evidence without mixing community observation with canonical facts.

- recent community sessions
- hunt
- vocation
- level
- XP/h
- profit/h
- party
- equipment when available
- evidence tier

---

# /profile — Character Profile

Saved player context:

- character name
- vocation
- level
- effective skills
- effective magic level
- preferred weapon family where applicable
- Weapon Proficiency selections
- unlocked requirements
- default party size
- default hunt objective
- default set objective

Future:
- multiple characters

---

# Core reusable components

## Shell
- AppShell
- TopNavigation
- Sidebar
- GlobalSearch
- PlayerMenu

## Hunt
- HuntCard
- HuntHero
- HuntMetrics
- ElementRisk
- ConfidenceBadge
- CreatureStrip
- HuntMap
- CommunityEvidence

## Optimizer
- PlannerForm
- CharacterInputs
- HuntObjectiveSelector
- SetObjectiveSelector
- LoadoutGrid
- LoadoutCard
- CoWinnerSwitcher
- SelectionReason
- ProficiencyPanel
- SpellPanel
- ImbuementPanel

## Session Analyzer
- SessionImport
- SessionHeader
- AnalyzerTabs
- HuntAnalysePanel
- MiscPanel
- DamagePanel
- PartyHuntPanel
- SessionKpi
- DamageChart
- ElementBreakdown
- CharmBreakdown
- PartyContribution
- SessionHistoryComparison

## Shared
- AnimatedCounter
- MetricCard
- DonutChart
- ProgressBar
- DataConfidence
- EvidenceTooltip
- ItemIcon
- CreatureIcon
- EmptyState
- LoadingSkeleton

---

# Data / UX contract

## Frontend must not expose raw optimizer internals by default

Do not display:
- SQL function names
- Pareto dimension keys
- audit stages
- raw JSON
- database terminology

Those can exist in developer/debug mode only.

## Player-facing explanation examples

Instead of:
"dominates_count = 44"

Use:
"This setup remains one of the strongest offensive options for this hunt."

Instead of:
"comparison_key / dimension set mismatch"

Use:
"These setups play differently and cannot be fairly reduced to one winner."

## Confidence

Show:
- High confidence
- Medium confidence
- Limited data

Expandable tooltip may reveal:
- number of sessions
- observed levels
- evidence source
- canonical vs community data

---

# Motion / interaction rules

Use:
- smooth route transitions
- card hover elevation/glow
- animated KPI count-up
- chart reveal animation
- tab transitions
- equipment hover detail
- skeleton loading states
- animated selection change between co-winners
- subtle map/monster image movement where appropriate

Avoid:
- constant looping animations everywhere
- excessive neon
- motion that makes reading harder
- decorative effects with no interaction purpose

---

# Asset policy

Preferred hierarchy:

1. official Tibia/RubinOT asset or canonical sprite/image
2. faithful crop/composition from canonical game visual
3. generated/stylized player-character presentation only when needed

Do not use generic AI fantasy replacements for:
- creatures
- equipment
- maps
- hunt locations
- canonical game-world objects

---

# Implementation direction

Current web/app/src/routes/index.tsx is too large and should not become the final architecture.

Recommended route/component split:

src/
  routes/
    __root.tsx
    index.tsx
    planner.tsx
    session.tsx
    sessions.tsx
    hunts.$huntKey.tsx
    loadouts.tsx
    creatures.tsx
    bosses.tsx
    community.tsx
    profile.tsx

  components/
    shell/
    hunt/
    optimizer/
    analyzer/
    loadout/
    charts/
    shared/

  lib/
    api/
    types/
    formatters/
    assets/

---

# Initial implementation milestone

Milestone FE-01:

1. New application shell
2. Dashboard
3. Hunt Planner
4. Hunt Detail shell
5. Session Analyzer shell with exact tabs:
   - Hunt Analyse
   - Misc
   - Damage
   - Party Hunt
6. Official/canonical asset pipeline placeholder
7. Reusable charts/cards
8. Real final optimizer API adapter
9. Session Analyzer data adapter against existing HuntNexus session tables
10. Responsive desktop-first layout

No publishing during this milestone.
