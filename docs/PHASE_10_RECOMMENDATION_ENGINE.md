# Phase 10 — Experimental observed-hunt ranking

This phase begins the recommendation engine, but deliberately labels the output as an **experimental evidence ranking**.

Inputs:
- vocation;
- level;
- objective: XP / profit / balanced;
- exact party size.

Ranking data:
- median Raw XP/h;
- median Balance/h;
- canonical recommended level where available;
- observed player levels for the requested vocation;
- current kill-weighted elemental profile.

Important correction:
- raw HuntAnalyser `Balance` is a session total, so profit comparison must normalize it to `Balance/h`.
- Phase 9.3 adds that normalization before ranking.

Confidence is independent from performance score:
- session sample size contributes to confidence;
- structural data completeness contributes to confidence;
- a high performance score with one session remains low-confidence.

This is not the final HuntNexus recommendation engine. Final ranking still needs:
- larger/authorized community evidence;
- RubinOT exact overrides;
- current player equipment/build;
- imbuements;
- charms/prey and other modifiers;
- boss-room mechanics and spells;
- incoming-damage protection evidence.
