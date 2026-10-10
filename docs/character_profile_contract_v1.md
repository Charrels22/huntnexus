# HuntNexus Character Profile Contract v1

## Current decision

The Character Profile is manual-first.

RubinOT exposes a public character search page and a JSON character endpoint, but direct server-side calls from the HuntNexus Cloudflare Worker are currently blocked with HTTP 403 by RubinOT anti-bot protection.

A working external implementation uses browser/TLS impersonation. HuntNexus will not introduce a separate scraping/TLS service only for this lookup at this stage.

Automatic RubinOT lookup remains an optional future enhancement.

## Route

`/profile`

## Stored context

Basic:
- character name
- world
- vocation
- level

Skills:
- sword
- axe
- club
- distance
- fist
- shielding
- magic level

Optimizer-effective values:
- weapon family
- effective weapon skill
- effective magic level
- effective shielding
- effective distance skill
- effective fist skill

Defaults:
- hunt objective
- set objective
- party size

Weapon Proficiency:
- remains item/tree specific
- must not be reduced to one generic numeric field
- storage supports exact selections for future Profile UI

## Persistence

Table:
- `player_character_profiles`

RPCs:
- `huntnexus_player_profile_get(uuid)`
- `huntnexus_player_profile_save(uuid,jsonb)`

The current identity scope is the same browser-scoped UUID used by private player sessions.

## Consumers

### Hunt Planner

On load:
- vocation
- level
- default hunt objective
- default set objective
- default party size

On optimizer execution:
- effective character stats
- weapon family
- saved proficiency selections when present

### Session Analyzer

On load:
- character name
- world/server
- vocation
- level

An existing session draft always takes precedence over Profile defaults.

## Future account migration

Browser-scoped identity can later be replaced by authenticated user/character identity without changing the Profile payload contract.


## Weapon Proficiency UI

Profile now loads item-bound proficiency trees from:

- `huntnexus_player_profile_proficiency_catalog(vocation, level, weapon_family)`

Rules:
- selections are stored by exact `item_key -> [perk_order]`;
- no selection inheritance is assumed;
- no perk dependency/topology is inferred when the source only provides flattened source order;
- only vocation/family/level-compatible trees are presented;
- Planner forwards the exact saved selections to the universal optimizer.

## Effective stat guard

Fields labeled as effective/final values mean the complete final stat, not only the bonus.

Example:
- base Magic Level 110
- +2 equipment bonus
- final/effective Magic Level = 112

If a saved final value is numerically below its corresponding base value, Hunt Planner treats it as inconsistent and falls back to the base value rather than degrading the optimizer context.
