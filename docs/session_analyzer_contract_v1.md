# HuntNexus Session Analyzer Contract v1

## Product meaning

`/session` is the hunt intake/import flow.

It is not the result viewer.

A player pastes one or more Tibia analyzer blocks and optionally adds metadata. HuntNexus parses recognized fields, preserves all raw text, saves the private hunt, then opens the saved session in `/sessions`.

## Supported input blocks

- Hunt Analyzer
- Party Hunt
- Input Analyzer / Damage Input
- Miscellaneous

Paste auto-detection is enabled when recognizable signatures exist.

## Current parser v1

Recognized Hunt Analyzer fields:
- Session duration
- Session data raw range
- XP Gain
- XP/h
- Raw XP/h when present
- Loot
- Supplies
- Balance
- Damage
- Healing
- Killed Monsters rows

Recognized Party Hunt fields:
- Session duration
- Loot
- Supplies
- Balance
- Damage
- Healing
- Player blocks
- Player loot/supplies/balance/damage/healing
- Leader marker

Recognized Input Analyzer fields:
- damage elements
- element damage
- share percentage when present
- damage sources
- source damage
- source share percentage when present

Recognized Misc fields:
- generic `name: value` stats
- numeric/percentage values when safely parseable

## Data integrity rules

- Unknown values are never invented.
- Raw analyzer blocks are preserved.
- Parse warnings are explicit.
- Charm damage stays unavailable until a supported source is normalized.
- Private player sessions do not automatically enter community evidence.
- Publishing/highscore intent is stored but does not currently mutate community evidence.

## Persistence

Private/browser-scoped table:
- `player_hunt_sessions`

RPCs:
- `huntnexus_player_session_save()`
- `huntnexus_player_session_list()`
- `huntnexus_player_session_detail()`
- `huntnexus_player_session_delete()`

Browser scope currently uses a locally generated UUID. Account-backed identity can replace this later without changing the parser contract.

## Route responsibilities

### /session

- analyzer paste/import
- type auto-detection
- parser preview
- optional metadata
- draft save
- final private save

### /sessions

- private hunt history
- open saved session
- Hunt Analyse
- Misc
- Damage
- Party Hunt
- delete private hunt

## Community boundary

`community_sessions` remains evidence for observed hunt statistics.

`player_hunt_sessions` remains private/product history.

A future explicit publish/review pipeline may promote suitable player submissions into community evidence. This must not happen implicitly.
