# HuntNexus — FE-23: Party-only data boundaries and incoming-damage source integrity

**Date:** 2026-10-12 (BRT). Continues `docs/CHECKPOINT_2026-10-11_FE22_ONLINE_ORIGINAL_ANALYZERS.md`.

## 1. Reproduced boundary bug and fix

In `web/app/src/lib/session-parser.ts`, the `primary` parser fallback used the Party Hunt block whenever the personal Hunt Analyzer block was omitted. Consequently **Loot/Supplies/Balance/Damage/Healing totals for the entire group were copied into the player's `hunt_analyse` fields**. This would incorrectly label a party result as a participant's individual gain. It also marked `availability.hunt_analyse = true` on a Party-only input based solely on a reported session duration.

FE-23 now ensures:
- A shared session duration may be read from Party Hunt when personal Hunt is missing, without classifying the party report as a personal Hunt report.
- Personal economic and combat metrics are parsed **only** from the explicitly provided Hunt Analyzer block.
- `party_hunt.totals` retains the team aggregates, separately from `party_hunt.players` individual rows.
- A Party-only paste sets `availability.hunt_analyse=false` and leaves personal financial and outgoing damage fields as `null`, never zero or the team's total.
- When *both* Hunt and Party are provided, the Hunt metrics and Party totals remain independently intact.
- The public short EM Azzilon Castle excerpt test and complete live 4-player Party Hunt test now assert these semantics rather than assuming team values were individual.
- This corrects a provenance and attribution bug. No database migrations or private player data changes were required.

## 2. Incoming damage vs outgoing damage

Source context for the independent Tibia Damage Input Analyser: official CipSoft feature description at https://www.tibia.com/news/?id=5867&subtopic=newsarchive and mechanics explanation at https://www.tibiaqa.com/21950/how-does-the-damage-input-analyser-work.

Additional source for a published *Input Damage Summary* numeric sample: https://www.hunt-analyser.com/hunt_sessions/2007; public values (not a recovered original raw clipboard text): **Received Damage Total 1,164,196, Max-DPS 2,276**, five damage elements (Fire, Physical, Life Drain, Holy, Energy) and three listed damage sources.
- FE-23 accepts the explicit `Received Damage Total:` heading as an alternative to `Total:`.
- Explicit `Damage Sources` rows remain in the sources category, even if a row label resembles an elemental damage name.
- It verifies incoming total, DPS, element/source counts, exact source-reported shares and both sums.
- **Input received damage must not populate personal outgoing `hunt_analyse.total_damage`**. The test asserts that it stays `null`.
- The rows in the regression were structured from the public site's summarized values and are *not* described as the original Damage Input copy/paste.

## 3. Visible Session Analyzer preview

`web/app/src/routes/session.tsx` now presents **Totais da Party Hunt** in a separate panel explicitly warning that Loot, Supplies, Balance, Damage and Healing are team aggregates and not player-level gains. Values absent from a Party source remain unknown.

`web/app/tests/frontend-live-browser-smoke.mjs` now checks a source-linked public EM Party excerpt independently from a public RP Hunt excerpt:
- The RP's published `XP/h: 0` is shown as an observed zero.
- A Party-only excerpt produces the distinct Party panel; the individual Balance display stays missing.
- No copied source is submitted or written into any player's private/community session tables.

## 4. Regression and evidence

- `tests/session-parser-contract.mjs`: synthetic Party-only and concurrent Hunt+Party regression cases, with exact team vs individual assertions.
- `tests/fe22-online-original-analyzer-excerpts.mjs`: original community EM partial Party source is correctly asserted under `party_hunt.totals`; individual fields must remain `null`.
- `web/app/tests/fe22-live-original-party-description.mjs`: original public 4-member party source is checked in-memory against the new strict boundaries. The source text or player names are not copied to the repo, logged, or persisted.
- `HuntNexus Web CI` after code+test corrections: https://github.com/Charrels22/huntnexus/actions/runs/38244769056 — **SUCCESS**; after UI changes: https://github.com/Charrels22/huntnexus/actions/runs/38244978206 — **SUCCESS**.
- `HuntNexus Original Public Analyzer Source QA`: https://github.com/Charrels22/huntnexus/actions/runs/38244769062 — **SUCCESS** for original public EM Party/ED Solo.
- Latest Browser QA must be verified separately. An initial test assertion failed because CSS uppercases metric captions; test normalized case rather than altering product behavior. Do not mark a queued/in-progress browser run green.

## 5. Still outstanding before 100% RubinOT launch

- Original RubinOT game-client analyzer dumps provided with player consent and compatible raw Damage Input/Misc/Party clipboard samples. Online Tibia observations are not enough to validate RubinOT-custom mechanics.
- In-game screenshots validating perk images and actual Weapon Proficiency trees (mapped Tier B sprites are not guaranteed RubinOT-equivalent).
- Real Magic Link login and canonical profile recovery across two devices using an authorized test account.
- Closed external pilot per `docs/PILOT_ACCEPTANCE_EK_RP_ED_MS_EM_FE21.md`; no invitations sent.
- Monitor optimizer quota/performance and final deploy SHA/canonical snapshot correctness.


## FE-23 final verification — SUCCESS

- **Web CI after personal/party UI separation and source-linked input checks: SUCCESS** [run 38245223397](https://github.com/Charrels22/huntnexus/actions/runs/38245223397). Includes TypeScript/Vite production build, numeric reconstructed Tier C 5-vocation fixtures, 5 genuine source excerpts, Party-only vs Hunt+Party, and incoming Damage Input source-linked numeric summary.
- **Deployed frontend Chromium desktop/mobile Browser QA: SUCCESS** [run 38245223271](https://github.com/Charrels22/huntnexus/actions/runs/38245223271), confirms the new panel of total Party metrics, group-vs-individual warning, and explicitly missing personal Balance on a Party-only source, alongside Profile/Planner/Account/Weapon Proficiency checks. GitHub Actions artifact `huntnexus-live-frontend-qa` stores the screenshots.
- **Original public four-player Party plus ED solo in-memory source parsing: SUCCESS** [run 38244769062](https://github.com/Charrels22/huntnexus/actions/runs/38244769062), with the new strict `hunt_analyse.loot_value`, `balance_value`, `supplies_value`, `total_damage` null assertions for party-only input.
- **Player Session production HTTP smoke after core parser change: SUCCESS** [run 38244607833](https://github.com/Charrels22/huntnexus/actions/runs/38244607833). Existing single-vocation EK session, and MS inventory coverage, retain their cleanup semantics.
- Initial Web CI attempts failed because an older FE-22 assertion incorrectly expected the EM Party team's Loot in `hunt_analyse.loot_value`. The asserted contract was corrected to check the separate `party_hunt.totals` and personal `null`; final green evidence above supersedes these failures.
- Initial browser assertion failed because CSS `uppercase` transforms metric captions in `innerText`; the test now checks normalized lowercase and whitespace. No product cosmetic change was made for this test failure.

The overall HuntNexus is still **not 100% player-homologated** and the source-backed Damage Input example is a published summary transcript, **not an original game clipboard export**.
