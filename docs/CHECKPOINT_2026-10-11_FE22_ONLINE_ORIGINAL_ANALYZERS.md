# HuntNexus FE-22 — Original online Hunt / Party Analyzer excerpts

Date: 2026-10-11 (America/Sao_Paulo).
Continuation from FE-21: `docs/CHECKPOINT_2026-10-11_FE21_REAL_SOURCE_PARSER_PROFICIENCY.md`.

## What this improves over FE-21

Previously there were five **reconstructions using numerical data** from community tracker records; they were not the original client copy/paste. FE-22 finds real player-published copy/pastes on public community pages. It stores *only short original excerpts* for regression and links each original full post; no complete third-party publication has been mirrored or merged into the HuntNexus community tables.

Sources (public Tibia ecosystem, Tier C **not RubinOT verified**):
- EK: https://www.reddit.com/r/TibiaMMO/comments/1o3l7bc/ (public hunt sample, session 00:36h)
- RP: https://www.reddit.com/r/TibiaMMO/comments/1e59z3t/ (public hunt sample, 01:00 h, explicitly reported XP/h = 0)
- ED: https://www.reddit.com/r/TibiaMMO/comments/1bct1k8/ (public ED sample, 00:40h, explicitly reported Loot = 0)
- MS: https://www.reddit.com/r/TibiaMMO/comments/u5whop/ (public MS sample, 00:41h)
- EM: https://www.hunt-analyser.com/hunt_sessions/32789 (public Azzilon Castle Party Hunt Analyzer **with an EM participating**, not a solo EM session; player-level values must not be assigned to EM).

## Files / changes

- `tests/fixtures/fe22-online-original-analyzer-excerpts.json`: 5 minimal, attributable verbatim field excerpts (not full copies), expected numeric fields and ethical limitations; no private names or private gameplay.
- `tests/fe22-online-original-analyzer-excerpts.mjs`: source-fragment parser checks for format recognition, exact reported numeric values, explicit observed zero vs unknown null, Party leader-loot mode and no private/community publication side effects.
- `.github/workflows/huntnexus-web-ci.yml`: original public source excerpt checks are part of mandatory Web CI alongside FE-21 reconstructions and synthetic parser tests.
- `web/app/src/lib/session-parser.ts`: explicit Party Hunt markers (`Loot Type` and session context, or player sections) are checked **before** the generic `XP Gain` classification, because party transcripts may contain XP fields; prevents routing party data into the solo Hunt editor.
- `tests/session-parser-contract.mjs`: regression for Party Hunt with two participants plus XP, separate from sourced original excerpts.
- `web/app/tests/fe22-live-original-party-description.mjs`: browser fetch of published Azzilon Castle page and direct parsing of its full original description **in memory only**; asserts four participants, aggregate party metrics, and no false attribution of XP to EM. Neither player names nor copied description are saved or printed by the test.
- `.github/workflows/huntnexus-frontend-browser-qa.yml`: runs the real public description browser regression; this step has an external website availability dependency distinct from app CI.
- `web/app/tests/frontend-live-browser-smoke.mjs`: uses two attributed original short excerpts in deployed private Session Analyzer UI; verifies RP zero value, unknown killed-monsters count, and EM Party tab editing. No real player profile is logged in, and no session is saved.

## Validated facts vs remaining proof

- Search verifies that the 5 public source posts contain authentic player-published Analyzer text, but these are **not confirmed RubinOT client exports**.
- Excerpt-based CI validates copied numeric fields and formatting; full original text for four individual vocations is **linked but not duplicated**.
- Only the EM source is a complete public Party Hunt Analyzer rendered as a description on the linked page; it is not proof of an individual EM Hunt Analyzer.
- No authorization to reuse copyrighted third-party full reports is inferred solely from them being public. Tests keep only minimal excerpts. Full text from the one party source is parsed transiently by the browser test.
- The **primary missing release gates** are still authentic RubinOT-origin player analyzers for each class, client-side icon identity confirmation, manual real game regression, and real cross-device email Magic Link. These cannot be replaced with Tibia official samples.
- Public external pilot has not been opened or invitations sent.

## CI evidence

- Initial original-public-excerpts Web CI: https://github.com/Charrels22/huntnexus/actions/runs/38192579344 — SUCCESS.
- Parser with Party-priority regression Web CI: https://github.com/Charrels22/huntnexus/actions/runs/38192694707 — SUCCESS.
- Private Session public smoke after parser priority: https://github.com/Charrels22/huntnexus/actions/runs/38192683459 — SUCCESS.
- Latest browser source/live tests: see GitHub Actions `HuntNexus Frontend Browser QA`. **Do not mark these as passed until the final run conclusion is verified**, because they include a live third-party website dependency and the existing guest-recovery QA occasionally races app deployment.

## Next actions

1. Verify final FE-22 browser/CI run logs, fix real failures, and update this checkpoint with exact URLs.
2. For full raw Hunt Analyzer coverage of EK/RP/ED/MS, exercise published originals in memory in a browser where possible without mirroring third-party posts.
3. Find authentic RubinOT client examples or request consented anonymized exports when no public original exists.


## FE-22 implementation and CI addendum

- Public-source excerpt parser + new Party-over-Hunt classifier and synthetic overlap case **PASS** in `HuntNexus Web CI` [#38192694707](https://github.com/Charrels22/huntnexus/actions/runs/38192694707).
- Latest Web CI build and parser regression **PASS** [#38193012732](https://github.com/Charrels22/huntnexus/actions/runs/38193012732).
- After fixing the fixture path and adding an explicit hydration wait, the published **Frontend Browser QA PASS** [#38193154789](https://github.com/Charrels22/huntnexus/actions/runs/38193154789), including RP short original-source excerpt shown in Session Analyzer and EM Party header entry. No session was saved.
- Full public Party Hunt Analyzer on [Azzilon Castle x4](https://www.hunt-analyser.com/hunt_sessions/32789) is parsed in-memory by a public-site browser test, with four participants; EM is one participant. The second full input source is [ED Solo Summer Court](https://www.hunt-analyser.com/hunt_sessions/40884), with 1,242 killed monsters and 0 XP/h as published by the author. Its public webpage summary displays a separately calculated XP/h; the parser must not overwrite the author's original field.
- Public third-party description fetching is now its **own** workflow `.github/workflows/huntnexus-original-source-qa.yml`; an outage of the external site must not prevent CI for the HuntNexus app. Early failures were from an incorrectly escaped solo section regex (corrected to anchor on real session date), not from numeric parsing. The final independent public-source run must be checked separately and never inferred green from Web CI.
- Each original public-source excerpt is small and attributed; third-party full texts and player names are neither stored in Git nor the database.
