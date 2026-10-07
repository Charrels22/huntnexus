# Checkpoint — 2026-10-07 — Cloudflare + Supabase independence

## Infrastructure

The HuntNexus production architecture no longer depends on Lovable Cloud:

- GitHub: Charrels22/huntnexus — canonical source
- Cloudflare Worker: huntnexus
- Supabase project: HuntNexus (sa-east-1)
- Lovable: optional UI prototyping/reference only

Cloudflare runtime secrets are configured:
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

## New Supabase bootstrap

Applied migrations:
- 0001 through 0050
- 0051 native TibiaData catalog ingestion
- 0052 async detail ingestion
- 0053 ingestion performance indexes
- 0054 post-load hunt creature alias reconciliation
- 0055 canonical slug compatibility
- 0056 loadout candidate hygiene
- 0057 server-only security hardening

## Factual catalog

Current authoritative refresh:
- creatures: 2,193
- hunting places: 459
- items: 6,470
- creature detail completed: 2,193 / 2,193
- hunt detail completed: 459 / 459
- current combat/equipment item details: 1,600
- hunt-creature links: 3,745
- resolved hunt-creature links: 3,743
- unresolved: 2 occurrences of demongoblin
- creature abilities: 2,193
- creature loot rows: 18,675
- monster vulnerabilities: 21,831
- item effects: 1,658
- items with normalized effects: 695
- item effect parse issues: 0
- bosses: 548
- Soul War boss group members: 8
- spells: 39

### Why vulnerabilities differ by 3 from the old Lovable snapshot

The old snapshot contained 21,834 vulnerability rows.
The new current source contains 21,831.

All three differences belong to TibiaData creature external_id 1751, Sugar Mommy:
- old source lastUpdated: 2026-10-05
- current source lastUpdated: 2026-10-06
- old detail had drown/healing/life_drain = 100
- current detail omits all three fields

This is a source update, not a migration loss.

### Why current combat item detail count is 1,600 instead of old 1,610

Ten items were reclassified by current TibiaData on 2026-10-07 from prior combat-filter categories to Creature Products:
- Claw of 'The Noxious Spawn'
- Dark Rosary
- Deepling Breaktime Snack
- Deepling Claw
- Deepling Guard Belt Buckle
- Deepling Ridge
- Deepling Scales
- Deepling Warts
- Deeptags
- Essence of a Bad Dream

Normalized effects still exactly match the old validated total:
- 1,658 effects
- 695 items with effects
- 0 parse issues

## Canonical slug compatibility

Native SQL ingestion initially treated apostrophes as separators, unlike the original TypeScript collector.

Migration 0055 restored the canonical behavior:
- apostrophes are removed before slug normalization
- creature mismatches: 0
- hunt mismatches: 0
- Goshnar's Hatred key restored to goshnars-hatred
- Soul War guard works again

## Community sample — current public pages

The public HuntAnalyser top-100 sample was re-ingested from the current source:
- sessions: 100
- detail completed: 100
- detail errors: 0
- player rows: 201
- creature rows: 414
- resolved hunts: 65
- unresolved hunts: 35
- incoming-damage sessions parsed: 100
- subjects with Input Damage: 80
- elemental rows: 390
- monster-source rows: 289
- unresolved session creatures: 2
- unresolved incoming-damage sources: 2
- hunts with observed incoming damage: 23

These totals legitimately differ from the old 100-session snapshot because the public top pages changed.

Source remains Tier C / review with terms_review_status=pending.
Do not bulk-scale beyond the existing 100-session sample until terms/permission review is resolved.

## Analytics smoke

Health:
- product: HuntNexus
- status: ok
- recommendation stage: preview_v4
- RubinOT server: v13.9
- RubinOT client: v4.064

EK 700 / XP / Solo:
- first hunt: Cobra Bastion
- ranking_score: 0.794
- confidence_score: 0.920

Boss guards:
- Magma Bubble blocked by RubinOT v13.8 guard
- Goshnar's Hatred synchronized under canonical key
- Soul War group guard blocks final build

## Loadout hygiene

0056 removes category/header/consumable pseudo-items that have no:
- equipment slot
- imbue capacity
- normalized effects
- attack/defense/armor/weapon evidence

Smoke confirms 0 known header candidates.

## Security

0057 makes Supabase server-only for application data:
- anon table access: revoked
- authenticated table access: revoked
- PUBLIC function execution: revoked
- service_role table/function access retained
- mutable function search_path warnings removed

Supabase security advisor has one remaining warning:
- pg_net extension is in public schema

The installed pg_net extension reports extrelocatable=false, so it cannot be moved with ALTER EXTENSION. This is an accepted infrastructure exception while async ingestion uses pg_net.

## Cloudflare

Connection is authenticated and Worker is visible via Cloudflare API:
- worker id: huntnexus
- compatibility date: 2026-10-07
- nodejs_compat enabled
- assets/modules enabled
- observability/log persistence enabled
- workers.dev subdomain enabled
- runtime secrets confirmed by name:
  - SUPABASE_URL
  - SUPABASE_SERVICE_ROLE_KEY

Do not publish Lovable. Cloudflare is now the primary hosting path.
