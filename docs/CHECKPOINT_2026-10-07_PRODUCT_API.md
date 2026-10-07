# Checkpoint — 2026-10-07 — Product/API integration

## Database confirmed

- 548 canonical boss profiles synchronized from TibiaData.
- 39 core spell definitions.
- 8 Soul War canonical boss profiles grouped.
- 9 boss profiles blocked by current RubinOT reconciliation guards:
  - Magma Bubble
  - 8 Soul War profiles
- RubinOT v13.9 and client v4.064 stored.
- 5 v13.9 change candidates stored.
- Boss Build Preview validated:
  - Magma Bubble final build blocked.
  - Goshnar's Hatred final build blocked.
  - Chivalrous Challenge excluded from boss support and surfaced as restricted.
  - Divine Dazzle surfaced as restricted for RP boss context.

Official indexed RubinOT sources do not currently expose the exact reworked Magma Bubble/Soul War room mechanics, so no old/global guide was promoted to current RubinOT truth.

## GitHub product layer prepared

Implemented:
- supabase/functions/huntnexus-api/index.ts
- api/huntnexus-client.ts

API actions:
- health
- search_hunts
- search_bosses
- recommend
- boss_build

Service-role remains server-side only.

Prepared Lovable UI patch:
- web/lovable-patch/src/routes/index.tsx
- web/LOVABLE_MVP_PROMPT.md

The current Lovable page is still the old Brain Status placeholder because Lovable agent editing requires credits and the workspace remains out of agent credits.

## Pending DB application after cooldown

- 0043_api_lookup_functions.sql
- 0044_rubinot_payload_warnings.sql

Then run:
- tests/sql/phase16_17_smoke.sql

## Current deployment blocker

The Edge Function and new UI code are versioned in the canonical GitHub repository but are not yet deployed into the Lovable project because the only available Lovable code-edit path is the AI agent, whose credits remain unavailable.

Do not publish the Lovable project before the user explicitly asks.
