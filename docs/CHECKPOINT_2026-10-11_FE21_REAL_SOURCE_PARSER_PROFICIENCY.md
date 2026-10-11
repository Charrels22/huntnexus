# HuntNexus FE-21 — Five vocation session source reconstruction, parser integrity and proficiency sprites

**Date:** 2026-10-11 (America/Sao_Paulo). Continues FE-20.

## What is verified

### Tier C sessions and original input availability

A read-only production Supabase audit found:
- `public.community_sessions` contains 100 published/sourced tracker sessions; all 100 have `raw_payload` but this JSON stores tracker details (`page`, `stage`, `party_label`, `detail_snapshot_id`, `detail_ingested`), **not a raw Hunt Analyzer transcript**. None of the 100 payloads or source descriptions matched Analyzer section markers.
- The original `Session Analyzer` text for EK, RP, ED, MS and EM has **not** been obtained. Do **not** claim player-provided raw-parser validation.
- Five source-linked numeric fixtures were extracted from specific public `community_sessions` rows, **without copying private player names**. All have explicit `vocation`, `hunt_key`, source URL, duration, XP, XP/h, Balance, Damage and Healing. Missing Loot/Supplies remain `null`.
- Fixture: `tests/fixtures/reconstructed-source-sessions-2026-10-11.json`. Reconstructed input text used exclusively for a source-numeric parser regression, clearly marked **NOT original Analyzer content**.
- `tests/five-vocation-real-source-reconstruction.mjs` verifies metric preservation (including missing-as-null), exact observed XP/h arithmetic, parser private methodology and 5 real-source references. CI `38169397330`: **SUCCESS**: https://github.com/Charrels22/huntnexus/actions/runs/38169397330

Sources pinned for reproducibility (Tier C):
- EK / Cobra Bastion: https://www.hunt-analyser.com/hunt_sessions/58543
- RP / Iksupan Last Stand: https://www.hunt-analyser.com/hunt_sessions/58667
- ED / Nimmersatt's Breeding Ground: https://www.hunt-analyser.com/hunt_sessions/58511
- MS / Podzilla: https://www.hunt-analyser.com/hunt_sessions/58564
- EM / Grounds of Undeath: https://www.hunt-analyser.com/hunt_sessions/58264

These URLs were present in the production database; website retrievability through an external search fetch was not independently established this run.

### Parser integrity

- `web/app/src/lib/session-parser.ts`: duration parser now anchors the input, refuses minutes >= 60 and returns `null` rather than rolling minutes into invented hours. Adds the readable `invalid_duration_format` warning. Supports canonical `HH:MMh` and explicit `1h 30m`.
- `tests/session-parser-contract.mjs` covers invalid `01:90h`, arbitrary trailing text and out-of-range minute fields. Web CI `38169563708`: **SUCCESS**: https://github.com/Charrels22/huntnexus/actions/runs/38169563708
- Production Player Session smoke on parser change `38169547434`: **SUCCESS**.

### Weapon Proficiency live browser and mappings

- Browser Playwright workflow `web/app/tests/frontend-live-browser-smoke.mjs` now uses real public `player_profile_proficiency_catalog` responses and mocks only the **private profile read** with a non-saved local QA configuration, without writing personal data.
- Five actual eligible item trees opened on deployed UI, with successful icon images:
  - EK Eldritch Claymore **7/7** load
  - RP Bow of Destruction **6/6**
  - ED Eldritch Rod **8/8**
  - MS Eldritch Wand **10/10**
  - EM Nunchaku of Destruction **6/6**
  - **37/37 visible mapped icons loaded; zero image loading failures in these five sampled trees**. Captured 15 screenshots and no browser JS exceptions/overflow; run `38169701010` **SUCCESS**: https://github.com/Charrels22/huntnexus/actions/runs/38169701010
- Mapping extracted from `profile.tsx` to the versioned pure helper `web/app/src/lib/proficiency-icons.ts` for testing and audit.
- Source-catalog icon map audit covers **all eight weapon families**, 32 eligible source-backed+fallback trees at level 700 and **373 perk occurrences**; workflow `38169995711` **SUCCESS**, initial map **350/373 (93.8%)**:
  https://github.com/Charrels22/huntnexus/actions/runs/38169995711
- A Playwright URL probe `38170080326` verified **9 of 10** unconfirmed TibiaWiki sprite candidates load with actual 16×16/32×32 images. `Proficiency Type Damage.gif` did **not** load and was not used.
- Added verified spell sprite candidates for Eternal Winter, Heal Friend, Ice Burst, Strong Ice Wave, Terra Wave, Devastating Knockout and Magic Auto Attack. Current map `372/373 (99.7%)` across eight families, workflow `38170208160` **SUCCESS**: https://github.com/Charrels22/huntnexus/actions/runs/38170208160
- Final unverified effect: `base_damage` on Soulshredder's **Executioner's Throw**, source `https://www.tibiawiki.com.br/wiki/soulshredder` (Tier B). Do not assign a generic, potentially incorrect sprite. The extension probe for the spell filename must finish before a map is added.
- Source asset load, filename mapping, and a matched icon in the actual RubinOT client are **three distinct acceptance gates**. All mappings are canonical Tier B until compared in-game.

## Pilot acceptance

`docs/PILOT_ACCEPTANCE_EK_RP_ED_MS_EM_FE21.md` defines steps for five vocation volunteers: validate Profile and Main/BP, original Hunt Analyzer paste, parsed fields, per-hunt build snapshot, privacy and manual review. No external invitation or player's private data was sent or published.

## Next actions
1. Finish Executioner's Throw source-icon filename proof and update mapper only if found.
2. Verify last Web CI and visual regression against deployed version; no automatic inference of GitHub commit SHA from Wrangler timestamps.
3. Obtain consented real raw Hunt Analyzer text from EK/RP/ED/MS/EM and compare parser against actual game (still not available).
4. Manual screenshot and in-game sprite review for all 32 eligible trees (5 sampled screenshots alone are not full visual certification).
5. Real Magic Link login on two devices, with a consenting test account; cross-device SQL fixture is not enough.
6. Closed pilot only with explicit user approval after privacy and authentication gates.


## FE-21 further source-backed sprite closure
- File existence probe `38170282340` **SUCCESS**: https://github.com/Charrels22/huntnexus/actions/runs/38170282340 . The spell icon `Proficiency Spell Executioner's Throw.gif` loaded (32x32); `Proficiency Spell Executioners Throw.gif` without the apostrophe did not.
- Exact source record: `weapon_proficiency_perks.item_key=soulshredder`, `effect_key=base_damage`, `spell_key=executioners-throw`, description `+4% base damage for Executioner's Throw`, reference `https://www.tibiawiki.com.br/wiki/soulshredder` (Tier B).
- `proficiencyIconFiles` now chooses `Proficiency Spell Executioner's Throw.gif` + the verified `Proficiency Augment Damage.gif` **only** for the exact Executioner's Throw spell key, not for generic or unrelated base_damage perks.
- Entire 700-level public proficiency catalog coverage **373/373 mapped (100%)** across 32 eligible trees and eight weapon-family checks. Live public audit `38170417763` **SUCCESS**: https://github.com/Charrels22/huntnexus/actions/runs/38170417763 . This measures nonempty verified-name candidates for all perks, **NOT** actual browser loading of every icon, nor visual equality to the RubinOT client.
- `tests/proficiency-sprite-coverage.mjs` also asserts exact-item perk mapping and that an unrelated spell does not inherit the Soulshredder-specific asset; regression `38170438790` **SUCCESS**.
- Continue the separate browser/headless five-tree visual regression; 37/37 checked before mapping completion. A second browser run is pending verification at checkpoint update.


## Latest frontend/code final gates

- **Web CI (post complete mapper) SUCCESS**: https://github.com/Charrels22/huntnexus/actions/runs/38170417827 — React/Vite build, TypeScript, synthetic duration/parser tests and 5-vocation public-source numeric reconstruction.
- **Live Playwright Frontend Browser QA (post complete mapper) SUCCESS**: https://github.com/Charrels22/huntnexus/actions/runs/38170417750 — profile/perk trees for EK, RP, ED, MS, EM, desktop/mobile and lazy Hunt Detail; all sampled source file images loaded; artifact `huntnexus-live-frontend-qa`, ~5.6 MB, 15 screenshots.
- **Full 8-family Proficiency sprite coverage**: https://github.com/Charrels22/huntnexus/actions/runs/38170438790 — SUCCESS, all 373 eligible perk occurrences mapped with exact-weapon spell rule, no unknown spell inherits Executioner's Throw.
- **Public source candidate image probe**: https://github.com/Charrels22/huntnexus/actions/runs/38170282340 — confirmed apostrophized 32x32 Executioner's Throw icon and explicitly rejected unavailable unpunctuated candidate.
- **Remaining signoff is not automated:** real RubinOT screenshots per class/perk, original raw Hunt Analyzer texts from consenting EK/RP/ED/MS/EM players, and actual Magic Link recovery on two devices. Do not publish an open pilot or claim product is 100% operational solely from the above automated checks.
