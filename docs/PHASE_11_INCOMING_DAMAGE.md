# Phase 11 — Observed incoming damage

HuntAnalyser public detail pages can contain an **Input Damage Summary** for members with a linked detailed hunt session.

Important semantic rule:
- this is not automatically party-wide;
- the block belongs to a specific member tab;
- HuntNexus pairs tabs and panels by ordinal and links the result to the hashed player identity.

Captured per linked member:
- total input damage;
- max DPS;
- damage by element;
- element share;
- damage by monster;
- monster share.

No new HuntAnalyser request is needed for ingestion: Phase 11 parses the raw public detail snapshots already stored by HuntNexus.

This evidence will support defensive equipment/build recommendations later.

A hunt defensive profile is still observational Tier C evidence and must not be presented as guaranteed incoming damage.
