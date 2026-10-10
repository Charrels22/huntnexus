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
- Cadastrar Hunt
- Compare Loadouts

Do not place Hunt Analyse / Misc / Damage / Party Hunt as standalone Dashboard shortcuts. They belong inside a saved session.

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
Cadastrar/importar uma hunt em que o player participou.

This is an intake flow, not the analysis-result screen.

Primary import inputs:
- Hunt Analyzer
- Party Hunt
- Input Analyzer
- Miscellaneous

Additional optional context:
- character
- server
- vocation
- level
- location/hunt
- observation
- tags
- hunt type
- favorite
- publish/highscore preference
- rare drops

Flow:

1. Paste/import analyzer blocks
2. Detect/validate data
3. Add optional metadata
4. Save/register hunt
5. Open saved session analysis

Important:
Hunt Analyse / Misc / Damage / Party Hunt are views of a saved/registered session. They must not be the initial Session Analyzer landing screen.

---

# /sessions — Session History and Analysis

Purpose:
List saved sessions and open the full analysis of one registered hunt.

Inside a selected session show:

## Hunt Analyse
- duration
- raw XP
- XP/h
- loot
- supplies
- balance/profit
- profit/h
- kills
- bonuses when supported

## Misc
- consumables
- supplies
- healing/mana usage
- equipment
- auxiliary session metadata

## Damage
- damage dealt
- damage received
- damage/h
- damage by element/source
- charm damage when normalized
- incoming damage
- healing

## Party Hunt
- party members
- vocation/level when available
- damage contribution
- healing contribution
- share/contribution percentages

Visuals:
- KPI cards
- charts
- contribution bars
- item/creature sprites
- trend/history comparison



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
5. Session Analyzer intake flow:
   - Hunt Analyzer
   - Party Hunt
   - Input Analyzer
   - Miscellaneous
   - additional session metadata
6. Saved Session analysis:
   - Hunt Analyse
   - Misc
   - Damage
   - Party Hunt
7. Official/canonical asset pipeline placeholder
8. Reusable charts/cards
9. Real final optimizer API adapter
10. Session Analyzer data adapter against existing HuntNexus session tables
11. Responsive desktop-first layout

No publishing during this milestone.
