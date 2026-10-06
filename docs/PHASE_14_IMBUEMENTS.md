# Phase 14 — Imbuement candidates

Tier B factual source: TibiaWiki BR Imbuements.

Powerful values currently modeled:
- Cloud Fabric: 15% Energy protection
- Demon Presence: 15% Holy protection
- Dragon Hide: 15% Fire protection
- Quara Scale: 15% Ice protection
- Snake Skin: 15% Earth protection
- Lich Shroud: 10% Death protection
- Vampirism: 25% life leech, 100% chance
- Void: 8% mana leech, 100% chance
- Strike: +50% critical damage, 10% chance
- Epiphany / Precision / Slash / Chop / Bash / Blockade: +4 relevant skill at Powerful

HuntNexus does **not** merge these into one arbitrary score.

For a hunt/vocation:
- elemental protections are prioritized by observed incoming-damage share;
- skill boosts are filtered by vocation;
- Strike/Vampirism/Void are returned as separate core candidates;
- final assignment to actual item slots is deferred to the build optimizer.
