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
