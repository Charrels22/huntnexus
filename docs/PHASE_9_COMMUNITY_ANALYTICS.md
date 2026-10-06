# Phase 9 — Community-observation analytics

Phase 9 converts already-ingested Tier C public session observations into analytical evidence.

It does not treat community performance as official game truth.

## Views

### vw_community_session_quality
Structural completeness per session:
- duration;
- party size;
- XP/h;
- Raw XP/h;
- balance;
- player rows;
- creature rows.

### vw_hunt_observed_performance
For canonical-resolved hunts:
- session count;
- solo/duo/party distribution;
- average and median XP/h;
- average and median Raw XP/h;
- average and median balance;
- damage/healing summaries.

### vw_hunt_observed_kill_mix
Uses actual observed kill counts to estimate the monster composition of the hunt.

### vw_hunt_observed_element_profile
Combines observed kill shares with the Tier B monster vulnerability table.

This produces a **kill-weighted elemental profile**, which is more useful than the earlier unweighted species profile.

Important: it is still observational Tier C evidence. It can be biased by:
- route;
- player level;
- vocation;
- party;
- boost/event;
- prey/charm;
- custom modifiers;
- session duration;
- player skill.

## Function

`huntnexus_hunt_observed_profile(hunt_key)`

Returns:
- observed performance;
- observed kill mix;
- kill-weighted elemental profile;
- methodology flags.
