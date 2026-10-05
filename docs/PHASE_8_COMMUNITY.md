# Phase 8 — Community observations smoke test

First candidate: HuntAnalyser public hunt sessions.

## Why it is useful

The public list currently exposes:
- hunt/session title;
- duration;
- party size;
- XP Gain;
- Balance;
- XP/h;
- Raw XP/h;
- vocation + level for each party member;
- public description/comments;
- stable public session IDs.

The public catalogue contains thousands of sessions and explicitly presents a Public Hunts surface.

## Safety / access rules

Initial ingestion is intentionally capped at **5 public list pages / 100 sessions per execution**.

HuntNexus will:
- use only pages available without login;
- never access private sessions;
- never bypass access controls;
- preserve raw source snapshots and source IDs;
- keep the source status as `review`;
- keep `terms_review_status=pending` until terms/permission for larger-scale collection is reviewed.

## Name resolution

Community session titles are not assumed to equal canonical hunting-place names.

They are stored first as:
- `hunt_name_raw`;
- `hunt_resolution_status='unresolved'`.

A separate alias/reconciliation step will map titles such as “cobra bastion”, “Energy Library”, custom labels and spelling variants to canonical HuntNexus hunts.

## Timestamps

Public HTML timestamps are retained as `session_started_at_raw` during the smoke phase. The system does not assign a timezone until the source timezone behavior is verified.

## Detail pages

Individual public session pages appear to expose additional Hunt Analyser structure. Detail-page parsing for kills, damage, healing, prey/charms/build context is a separate step after the list parser is validated.
