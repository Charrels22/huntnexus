# Checkpoint — 2026-10-07 — Infraestrutura independente

## Infraestrutura

### Supabase
Projeto próprio: HuntNexus
- região: São Paulo
- status: ACTIVE_HEALTHY
- schema/migrations aplicados até 0095
- ChatGPT possui conexão direta via Supabase connector

### Cloudflare
Worker: huntnexus
- TanStack Start
- nodejs_compat
- observability enabled
- runtime secrets confirmados:
  - SUPABASE_URL
  - SUPABASE_SERVICE_ROLE_KEY
- ChatGPT possui conexão direta via Cloudflare connector
- GitHub é a fonte canônica.
- Cloudflare Builds está conectado ao repositório `Charrels22/huntnexus`, branch `main`.
- produção usa `web/app` como root, executa `npm run build` e depois `npx wrangler deploy`.
- `auto_build_enabled=true`; push em `main` dispara build/deploy pelo Cloudflare somente quando `web/app/**` é alterado.
- o GitHub Actions `HuntNexus Web CI` é uma validação separada de build/typecheck e não é o mecanismo de deploy.

Lovable deixou de ser dependência de runtime/produção.

## Catálogo factual atual

- criaturas: 2.193
- creature details: 2.193/2.193
- creature detail errors: 0
- abilities: 2.193
- loot rows: 18.675
- hunts: 459
- hunt details: 459/459
- hunt detail errors: 0
- hunt-creature links: 3.745
- links canonical resolved: 3.745/3.745
- unresolved hunt-creature links: 0
- itens: 6.470
- combat/equipment detail subset atual: 1.600
- item detail errors: 0
- item effects: 1.658
- items with effects: 695
- item effect parse issues: 0
- bosses: 548
- Soul War group: 8
- spells: 39

Observação:
O catálogo TibiaData atual classifica 1.600 itens no filtro de combate utilizado; o snapshot antigo tinha 1.610. Apesar disso, o conjunto normalizado de efeitos permanece idêntico: 1.658 efeitos / 695 itens / 0 parse issues.

## Community current public sample

- list sessions: 100
- detail sessions: 100/100
- detail errors: 0
- player rows: 201
- creature rows: 414
- resolved hunt sessions: 68
- unresolved hunt sessions: 32
- incoming damage sessions parsed: 100/100
- incoming damage rows: 390
- incoming damage source rows: 289
- unresolved incoming damage sources: 0
- unresolved session creature label: Nomad only (ambiguous canonical variants)
- player combat profile parser: 100/100 sessions completed; 0 errors
- normalized combat stat rows: 2.193 across 102 configured player snapshots
- normalized equipment rows: 918 across 102 configured player snapshots
- equipment canonical resolution: 917/918; only `Enchanted Ring of Souls` remains raw-only
- normalized combat-stat provenance rows: 6.852
- numeric provenance rows with source labels: 6.164
- imbuement provenance matches: 492 rows across 75 player snapshots

Current public sample differs from the prior Lovable snapshot because HuntAnalyser's newest public pages changed. This is expected for a live Tier C source.

## Canonical compatibility fixes

Applied:
- 0055 restores original apostrophe-removal slug semantics.
- 0056 restores community normalization compatibility and safe aliases.
- creature slug mismatches: 0
- hunt slug mismatches: 0
- Goshnar's Hatred key restored to goshnars-hatred.
- Soul War guard works again.
- 0063 resolves source slug `demongoblin` to canonical `demon-goblin` / Demon (Goblin) through `entity_aliases`; raw hunt-source rows remain unchanged.
- 0064 records Tier A RubinOT combat-profile facts for VIP, Loyalty, Guild Ascension and Weapon Proficiency.
- 0065 defines `character_combat_profile_contract_v1`, preferring effective client-displayed stats to avoid double-counting RubinOT bonuses.
- 0066 adds character-profiled EK recommendations while preserving legacy `preview_v7`; EK weapon families are explicitly Sword/Axe/Club.
- 0067 normalizes HuntAnalyser member combat stats and equipped items without storing player names in clear text.
- 0068 preserves semantically distinct stats such as `Magic Shield Capacity` vs `Magic Shield Capacity %`.
- 0069 normalizes per-stat provenance (for example, `+25% from Vampirism`) and derives Tier C observed imbuement usage.
- 0070 exposes that community usage in `imbuement_candidates_v2` as context only; it does not alter factual priority.
- 0071 chains incoming-damage, player-profile and provenance parsing after HuntAnalyser detail ingestion, with each post-processing stage isolated from raw/detail ingestion failures.
- 0072 makes provenance parsing snapshot-idempotent, including legitimate zero-row results.

## Product smoke in Supabase

Confirmed:
- huntnexus_api_health() = ok
- recommendation stage = preview_v7
- EK700 XP returns Cobra Bastion
- loadout candidate matrix = `loadout_candidate_matrix_v5`
- set preview = `loadout_set_preview_v3`
- EK hand comparison = `ek_hand_options_v2`
- imbuement compatibility = `loadout_imbuement_compatibility_v1`
- imbuement candidate context = `imbuement_candidates_v2`, including Tier C community-observed usage with `affects_priority=false`
- Cobra Bastion / EK observed sample currently has 7 eligible configured profiles; 3 directly show Vampirism ×2, Void ×2, Strike ×1, Chop ×1 and Snake Skin ×1
- Ice Rapier is excluded from sustained-hunt weapon choices by explicit catalog evidence
- one-hand EK example: Grand Sanguine Blade + Shield of Corruption
- two-hand EK example: Grand Sanguine Battleaxe
- hand configuration remains unresolved when neither factual vector Pareto-dominates the other
- score and confidence remain separate
- Magma Bubble final build blocked by v13.8 guard
- Goshnar's Hatred final build blocked by Soul War v13.7 guard

## Public Cloudflare end-to-end smoke

Endpoint:
- `https://huntnexus.charr3ls22.workers.dev/api/huntnexus`

Confirmed through real public HTTP requests:
- `health`: HTTP 200, HuntNexus, v13.9 / v4.064, preview_v7
- `recommend`: EK 700 / XP / Solo -> Cobra Bastion, score 0.794, confidence 0.920, HTTP 200
- legacy request without character profile remains on `recommendation_preview_v7`
- profiled EK API request uses `recommendation_preview_contextual_v1`, based on `recommendation_preview_profiled_v2`; Sword 120 constrains both one-hand and two-hand candidates to Sword
- `profile_contract`: EK -> Sword/Axe/Club
- frontend exposes optional EK weapon family, effective weapon skill, Magic Level and shielding; family options come from the API contract
- recommendation stage atual: `preview_v7`
- loadout set preview: `loadout_set_preview_v3`, sem score combinado artificial
- EK hand tradeoff: `ek_hand_options_v2`, com Pareto dominance only
- imbuement compatibility: `loadout_imbuement_compatibility_v1`, sem prioridade artificial entre Strike/leech/skill/proteção
- `search_bosses`: Magma Bubble -> `magma-bubble`, guard state exposed correctly, HTTP 200
- `boss_build`: Magma Bubble -> `final_build_blocked=true`, `final_build_available=false`, RubinOT v13.8 guard, HTTP 200

Frontend root also resolves publicly from the same Worker.

API contract cleanup:
- `api/huntnexus-client.ts` now matches the Worker vocations exactly: EK/RP/ED/MS.
- `api/README.md` documents Cloudflare as the production API path.
- old Supabase Edge Function and Lovable-oriented directories are legacy references only.

## Regression coverage

- `tests/sql/phase20_22_regression.sql` passes with hard assertions.
- database regression result: `status=ok`, recommendation `preview_v7`, 3.745 hunt-creature links, 0 unresolved.
- `tests/public-api-smoke.mjs` validates the production Worker without secrets.
- GitHub Actions workflow `HuntNexus Public Smoke` runs daily, manually and when smoke coverage changes.
- first public smoke workflow run completed successfully.
- Cloudflare deploy trigger remains restricted to `web/app/**`; migration/test/doc commits do not redeploy production.

## Character-aware optimizer foundation

Tier A RubinOT facts now preserved:
- VIP protected imbuement behavior in protection zones.
- VIP additional critical chance.
- Loyalty skill tiers and vocation mapping.
- Guild Ascension combat bonus categories: leech, critical, skill, race damage, elemental damage and elemental defense.
- Weapon Proficiency bonus visibility in Offense Stats.

`character_combat_profile_contract_v2`:
- prefers effective client-displayed values;
- EK precise hand comparison uses Sword/Axe/Club + effective weapon skill;
- optional effective shielding, critical, life/mana leech and elemental/race modifiers are modeled in the contract;
- internal profiled layer is `recommendation_preview_profiled_v2`; public profiled API path is `recommendation_preview_contextual_v1`;
- effective weapon skill is treated as client-displayed context and is no longer incremented again by candidate item skill bonuses; candidate bonuses remain separate dimensions;
- Weapon Proficiency exact combat formula remains unreconciled;
- Guild Ascension seasonal numeric perk values are intentionally not inferred.

Observed community profile layer:
- HuntAnalyser Member Details tabs map deterministically to existing hashed `session_players` rows (201/201 members matched in the current sample);
- combat stats, equipped items and per-stat provenance are preserved separately from Tier A RubinOT facts;
- observed equipment family can identify Sword/Axe/Club/etc. when the public profile has equipment configured;
- community imbuement usage is explicitly Tier C and never changes optimizer priority by itself.

## Security

Supabase advisor:
- function search-path warning fixed in 0057
- new player-profile tables are server-only: RLS enabled, no permissive policies, and privileges revoked from public/anon/authenticated
- advisor reports 4 informational `rls_enabled_no_policy` findings for those server-only tables; this is intentional deny-by-default behavior
- remaining warning: pg_net installed in public schema
  - accepted temporarily because pg_net is used only by service-role/internal ingestion
  - do not relocate extension until ingestion has a replacement path and a migration test

## Deployment validation

- frontend commit `292932473f0fad7e6fd253a0411af7818893ae1e` introduziu o primeiro set preview e foi publicado com sucesso.
- frontend commit `a6a974d429f39f9a73da50516f2806821c62b939` adicionou comparação factual de mãos, exclusões de hunt sustentada e compatibilidade de imbuements; Cloudflare build/deploy e GitHub CI passaram.
- commit `7ac17de116639a37286212e5de249003b433d7eb` corrigiu o CI que referenciava um `package-lock.json` inexistente.
- GitHub CI do HEAD ficou verde.
- primeiro deploy Cloudflare desse HEAD falhou apenas no upload de assets com erro transitório `10013`.
- retry manual do mesmo commit, sem mudança de código, concluiu com sucesso.
- trigger Cloudflare restringido de `*` para `web/app/**`, evitando rebuild/deploy por mudanças apenas em docs, migrations ou CI.
- smoke público final após o retry:
  - health HTTP 200 / `preview_v7`
  - recommend HTTP 200 / Cobra Bastion / 0.794 / 0.920
  - boss_build HTTP 200 / Magma Bubble bloqueado / final build indisponível

## Remaining work

- manual visual/browser interaction QA of the character-profile controls and Tier C imbuement section
- expand Weapon Proficiency normalization beyond Grand Sanguine to actual optimizer-selected weapons; current Sword top-5 audit exposed Gnome Sword, Naga Sword, Soulshredder and Eldritch Claymore as uncovered candidates
- extend profiled recommendation logic beyond EK after vocation-specific evidence/formulas are reconciled
- continue recommendation/final-set optimizer with character-aware data
- keep cross-type imbuement priorities explicit; Tier C observed usage remains contextual only
- current RubinOT boss mechanic reconciliation
- optional performance indexing based on real query usage
- terms/privacy decision before expanding HuntAnalyser beyond the current 100-session public sample


## 2026-10-08 continuation validation

- migration history and repository aligned through 0081
- SQL regression suite: status=ok
- Web CI for Tier C imbuement UI: success
- Cloudflare build/deploy commit `d9bec8bb3cdee851592c7413acf85349a34aa59d`: success
- Public Smoke with `imbuement_candidates_v2`: success
- character-profile public smoke remains backward compatible with legacy `preview_v7`

- HuntAnalyser detail post-processing smoke: no pending details, all derived parsers returned zero work and zero post-processing errors
- provenance snapshot mismatch count: 0


## Weapon Proficiency research decision

- No single generic Weapon Proficiency damage multiplier was found in RubinOT official material.
- RubinOT confirms Weapon Proficiency bonuses are surfaced in Offense Stats.
- Tibia official material defines Weapon Proficiency as per-weapon progression trees with weapon-specific perks.
- TibiaWiki exposes those perk trees per item, including optimizer-relevant Sanguine/Grand Sanguine weapons.
- Therefore the optimizer must model proficiency as per-weapon perks, not as one global damage formula.
- Next bounded step: normalize proficiency trees only for weapons currently entering EK hand comparisons (Sanguine/Grand Sanguine first), validate them, then stop for checkpoint.


## Grand Sanguine Weapon Proficiency normalization

- migration 0073 adds normalized Weapon Proficiency trees/perks for six EK Grand Sanguine weapons:
  - Grand Sanguine Blade
  - Grand Sanguine Razor
  - Grand Sanguine Hatchet
  - Grand Sanguine Battleaxe
  - Grand Sanguine Cudgel
  - Grand Sanguine Bludgeon
- 6 trees / 90 perks normalized, 15 perks per weapon.
- source: TibiaWiki BR, Tier B.
- source declares 7 proficiency levels, but rendered text flattens the tree topology; therefore all `level_number` values intentionally remain NULL.
- `perk_order` preserves source order and normalized fields preserve effect, numeric value, unit, scope, optional spell target and source stat.
- one-hand and two-hand differences are preserved instead of collapsed into one generic proficiency modifier.
- no proficiency perk affects the optimizer yet; 0073 is factual normalization only.
- SQL regression now asserts 6 trees, 90 perks and zero invented level assignments.


## Weapon Proficiency preview

- migration 0074 adds `weapon_proficiency_preview_v1` and `ek_weapon_proficiency_comparison_v1`.
- supported EK families: Sword, Axe and Club through their Grand Sanguine one-hand/two-hand pairs.
- no perk is inferred from level or proficiency points.
- active effects are calculated only from explicitly supplied `perk_order` values.
- preview groups active effects by scope/effect family and preserves spell-specific effects.
- optimizer/ranking/hand choice remain unchanged: `optimizer_effect_applied=false`, `ranking_changed=false`, `hand_choice_changed=false`.
- validated Sword example:
  - Blade selection [1,4,12,15] -> +1 Sword, +3% global life leech, +1 attack, +3% critical chance.
  - Razor selection [1,3,12,15] -> +1 Sword, +5% Fierce Berserk life leech, +1 attack, +3% critical chance.
- legacy EK700 XP recommendation remains `preview_v7` with Cobra Bastion on top.


## Public Weapon Proficiency preview wiring

- public API action `proficiency_preview` is active for EK Sword/Axe/Club.
- API accepts separate explicit perk-order arrays for one-hand and two-hand Grand Sanguine weapons.
- frontend EK profile now accepts optional perk-order lists for both hand configurations.
- leaving perk-order fields empty keeps `reference_only` mode.
- result cards show a Weapon Proficiency preview section with:
  - one-hand vs two-hand weapon names;
  - reference perk counts or active perk counts;
  - active effects grouped by scope/effect family;
  - explicit badges that proficiency does not alter ranking and no level is inferred.
- recommendation payload/ranking remains unchanged; since migration 0080 the profiled public request returns proficiency + contextual hand comparison in the same RPC path, reusing the already-computed hand analysis.
- public API smoke validated:
  - reference mode HTTP 200;
  - explicit Sword [1,4,12,15] vs [1,3,12,15] HTTP 200;
  - 4 active perks on each side;
  - `optimizer_effect_applied=false`.
- frontend commit `1df728af2ba2f9714c19d3a27b1678b20c3308a7`: GitHub Web CI success and Cloudflare build/deploy success.
- Public Smoke commit `53a65fdda47cfbef121516f92c283e6b266a4be7`: success.


## Weapon Proficiency impact preview

- migration 0075 adds `weapon_proficiency_impact_preview_v1` and `ek_weapon_proficiency_impact_comparison_v1`.
- migration 0076 prevents double-counting proficiency skill bonuses already present in RubinOT client-displayed effective skill values.
- impact preview resolves only directly supported terms:
  - flat skill bonus;
  - flat attack bonus;
  - global critical chance / critical extra damage;
  - global life/mana leech;
  - source-stat percentage terms such as 5% of effective weapon skill for auto-attacks and 10% for spells.
- source-stat percentage terms are exposed as explanatory terms, not final hit damage or DPS.
- with displayed Sword skill 120:
  - 5% skill term = 6;
  - 10% skill term = 12.
- displayed effective skill remains 120 even when a +1 proficiency skill perk is active; the +1 is shown separately and is not re-applied.
- missing source inputs remain explicit (for example Magic Level-dependent healing terms).
- public `proficiency_preview` now returns both the tree/reference preview and a separate `impact` object.
- frontend shows direct bonuses and derived terms while explicitly stating that they do not change score, ranking or hand choice.
- SQL regression: status=ok.
- Web CI commit `5dcd5e4f3b68b612d488c20c89df6ac720e63abf`: success.
- Cloudflare deploy for the same commit: success.
- Public Smoke commit `ad67b1fd85f360af24651e4dfc1ff962197871b0`: success.


## Contextual EK hand comparison and performance path

- migration 0077 fixes profiled-skill semantics:
  - `character_combat_profile_contract_v2`;
  - `ek_hand_options_profiled_v2`;
  - `loadout_set_preview_profiled_v2`;
  - `recommendation_preview_profiled_v2`.
- client-displayed effective weapon skill is no longer recalculated with candidate item bonuses.
- example Sword 120:
  - displayed skill remains 120 for one-hand and two-hand;
  - candidate item/set skill bonuses remain separate: +7 one-hand vs +4 two-hand.
- migration 0078 adds `ek_hand_context_comparison_v1`:
  - compares attack proxy, candidate-item skill bonus, weighted protection and imbue capacity;
  - adds explicitly selected Weapon Proficiency effects as separate dimensions;
  - no weighted score;
  - no mixed-scope summation;
  - Pareto only;
  - no optimizer/ranking mutation.
- migration 0079 adds a batch contextual function for compatibility/testing.
- a 5-hunt batch that recomputed hand analysis per hunt hit statement timeout; this path is not used by the frontend.
- migration 0080 fixes that architecture:
  - `huntnexus_ek_hand_context_from_precomputed` reuses the hand analysis already produced by the recommendation;
  - `recommendation_preview_contextual_v1` calculates proficiency once and attaches contextual comparison to all returned hunts;
  - public frontend now uses a single `recommend` request instead of recommend + proficiency + batch calls.
- optimized 5-result validation succeeds in one call.
- Cobra Bastion / Sword 120 / explicit proficiency fixture:
  - 9 comparable dimensions;
  - 1 one-hand advantage;
  - 1 two-hand advantage;
  - 7 ties;
  - no base or contextual Pareto dominance.
- top-5 Sword audit:
  - Cobra Bastion: full Grand Sanguine proficiency coverage on both hand options;
  - Warzone 3: Gnome Sword vs Grand Sanguine Razor, partial proficiency coverage;
  - Murky Caverns: Naga Sword vs Soulshredder, no Grand Sanguine proficiency coverage;
  - Haunted Tomb: Grand Sanguine Blade vs Eldritch Claymore, partial coverage;
  - Exotic Cave: Grand Sanguine Blade vs Eldritch Claymore, partial coverage.
- migration 0081 guards semantics:
  - contextual Pareto dominance is only exposed when both actual weapon candidates match normalized proficiency trees and both perk selections are explicit;
  - base Pareto dominance remains separately visible.
- Warzone 3 validation after 0081:
  - base dominance = two-handed;
  - contextual dominance = null;
  - status = `proficiency_weapon_mismatch`.
- frontend explicitly distinguishes:
  - contextual dominance;
  - base-only dominance;
  - proficiency applied to the current pair;
  - proficiency not yet covering the current pair.
- Web CI commit `be4dddf4c79afbce1beae1a1bf5f8a47453d08a0`: success.
- Cloudflare deployment of the same single-request frontend: success.
- Public Smoke commit `714da139b080fbd1348d5475e47a0951ae968cc7`: success.
- focused synthetic SQL smoke: `tests/sql/phase23_contextual_hand_smoke.sql` -> status=ok.
- the large legacy SQL regression remains versioned but can hit connector statement/runtime limits as coverage grows; new contextual semantics are protected by the focused synthetic smoke plus public API smoke.


## Proficiency coverage expansion and item binding

- migration 0082 normalizes additional Sword proficiency trees that appear in real EK optimizer results:
  - Gnome Sword: 2 perks;
  - Naga Sword: 7 perks;
  - Eldritch Claymore: 8 perks;
  - Soulshredder: 16 perks.
- all four sources declare 7 proficiency levels, but normalized `level_number` remains NULL because the accessible source is flattened; no branch/level placement is invented.
- migration 0083 resolves explicit Magic Level-derived proficiency terms without converting them into final hit damage or DPS.
- Naga Sword validation with ML 20:
  - 75% of Magic Level auto-attack term = 15;
  - 50% of Magic Level spell term = 10;
  - `optimizer_effect_applied=false`.
- migration 0084 exposes normalized proficiency coverage for each actual one-hand/two-hand candidate pair.
- migration 0085 fixes selection semantics:
  - perk-order inputs are bound to the weapon tree they were entered for;
  - perk orders never transfer from Grand Sanguine Blade to Gnome/Naga/etc.;
  - non-bound actual candidates may expose their normalized tree as reference only.
- contextual recommendation stage is now `recommendation_preview_contextual_v3`.
- Sword EK700 XP top-5 validation:
  - Cobra Bastion: Grand Sanguine Blade / Grand Sanguine Razor -> both trees available and both explicit selections applied;
  - Warzone 3: Gnome Sword / Grand Sanguine Razor -> both trees available, only Razor selection applied;
  - Murky Caverns: Naga Sword / Soulshredder -> both trees available, both reference-only;
  - Haunted Tomb: Grand Sanguine Blade / Eldritch Claymore -> both trees available, only Blade selection applied;
  - Exotic Cave: Grand Sanguine Blade / Eldritch Claymore -> same partial binding behavior.
- contextual Pareto dominance remains NULL unless both actual weapons have explicit correctly-bound proficiency selections.
- focused regression `tests/sql/phase24_actual_candidate_proficiency.sql`: status=ok.
- public Worker validation for contextual v3: HTTP 200; top Cobra pair returns per-item proficiency impact on both sides with correct bindings.

- Public Smoke for contextual v3 item-binding contract: success on commit `5f085d5957d80dcb94e198ce389bddc3820892de`.


## Item-key Weapon Proficiency selections

- migration 0086 adds `huntnexus_recommendation_preview_contextual_items`.
- contextual recommendation stage is now `recommendation_preview_contextual_v4` for the public profiled path.
- new request contract: `proficiency_selections = { item_key: [perk_order, ...] }`.
- perk orders are resolved only from the exact actual candidate `item_key`.
- legacy one-hand/two-hand arrays remain API-compatible fallback only for the original Grand Sanguine family pair.
- verified no cross-tree leakage:
  - Gnome Sword [1,2] does not activate Grand Sanguine Blade;
  - Naga Sword [4,7] resolves only Naga Sword;
  - Soulshredder [1,2,11,13] resolves only Soulshredder.
- frontend no longer asks for generic one-hand/two-hand perk orders before recommendations.
- after the first recommendation, each actual candidate weapon with a normalized proficiency tree receives its own perk-order input.
- repeated weapons across hunt cards share the same item-key selection state.
- `Atualizar contexto dos perks` reruns the contextual preview using the item-key selection map; ranking still ignores proficiency effects.
- UI exposes active perk count, item key, selection source and resolved impact terms per actual weapon.
- Magic Level-derived terms are visible when applicable.
- focused regression `tests/sql/phase25_item_key_proficiency.sql`: status=ok.
- Web CI commit `e71d2480e5b04ffa525a06ab96bd5b7daecaa38b`: success.
- Cloudflare API deploy commit `f964167d374f261f201cb1f635a0ebf9ce901be6`: success.
- Cloudflare UI deploy commit `e71d2480e5b04ffa525a06ab96bd5b7daecaa38b`: success.
- Public Smoke commit `198aab0df7f59cd49d3c58c81e2eda22f796398c`: success.
- security advisor after 0086:
  - 6 informational `rls_enabled_no_policy` findings correspond to intentionally server-only deny-by-default tables;
  - existing `pg_net` public-schema warning remains unchanged.


## Visual Weapon Proficiency selection

- migration 0087 upgrades `huntnexus_weapon_proficiency_pair_for_items` to `weapon_proficiency_pair_for_items_v2`.
- actual candidate proficiency payload now includes both:
  - resolved impact for selected perks;
  - full normalized proficiency tree reference for each actual one-hand/two-hand weapon.
- full tree reference contains every normalized perk with:
  - `perk_order`;
  - normalized effect family/value/unit/scope;
  - optional spell/source stat;
  - original normalized description;
  - active state for the current item-key selection.
- frontend replaces manual perk-order text entry with a collapsible checkbox list built from the actual weapon tree.
- checkbox state remains keyed by exact `item_key`, so a repeated weapon across multiple hunts shares one selection.
- checkbox interaction only updates the local item-key selection map; the user explicitly runs `Atualizar contexto dos perks` to refresh derived context.
- UI shows active count and resolved impact terms after refresh.
- no proficiency effect changes score, ranking or automatic hand selection.
- focused regression `tests/sql/phase26_actual_weapon_tree_reference.sql`: status=ok.
- top Cobra Grand Sanguine pair validation returns 15 normalized perks on each side and preserves selected active counts.
- Public Smoke commit `177e2c64c011e30d17858fbe5ab7fbacf6a5abcc`: success.
- Cloudflare UI build/deploy commit `81e938be49314b2b091024b2f1dcd49b7882bf18`: success.
- GitHub Web CI commit `81e938be49314b2b091024b2f1dcd49b7882bf18`: completed successfully.
  - checkout/install: success;
  - build and typecheck: success;
  - all post/complete steps: success.


## Architecture pivot — category-first implementation

- from migration 0088 onward, HuntNexus development is category-first instead of EK-first.
- EK remains the principal regression case, not the center of the domain model.
- first universal category: weapons.
- `vw_weapon_catalog_universal` normalizes all currently cataloged weapon-like items into one server-only contract.
- current universal weapon inventory: 855 items.
- normalized weapon classes:
  - `melee`;
  - `distance`;
  - `caster`.
- normalized weapon families:
  - sword;
  - axe;
  - club;
  - fist;
  - bow;
  - crossbow;
  - throwing;
  - wand;
  - rod.
- the universal contract normalizes:
  - weapon family/class;
  - primary skill key;
  - hands and whether hand count came from source or category default;
  - raw and normalized vocation applicability;
  - level requirement;
  - attack/defense/range;
  - imbue slots;
  - damage type and elemental attack components;
  - normalized item effects;
  - Weapon Proficiency coverage.
- important architecture correction: Rods/Wands do not rely on `weapon_type` in source data, so they are explicitly normalized as caster weapons rather than being silently excluded.
- highest-level regression representatives validated in one contract:
  - Knight: Moonsilver Claymore;
  - Paladin: Moonsilver Bow;
  - Druid: Moonsilver Sceptre;
  - Sorcerer: Moonsilver Channeler.
- server-only security preserved: no anon/authenticated SELECT grant.
- security advisor after the universal layer introduced no new finding.
- focused regression `tests/sql/phase27_universal_weapon_catalog.sql`: status=ok, 855 weapons, 3 classes, 9 families.
- migration commit: `ba8d20a4a529d98063d0f65c8858c71fb10107d0`.
- regression commit: `a985d554646d8e8da867076a0a3783c17aad139e`.

### Category-first order

1. weapons — universal catalog and candidate logic;
2. armor/equipment slots;
3. imbues;
4. protections/effects;
5. slot/restriction compatibility;
6. combat/spell mechanics;
7. vocation composition;
8. final optimizer.

The existing EK implementation remains as a regression fixture while generic category layers replace EK-specific assumptions incrementally.


## Universal weapon eligibility

- migration 0089 adds `huntnexus_weapon_candidates_universal`.
- the function is category-first and vocation-agnostic in structure; vocation is used only as an eligibility input.
- supported vocation aliases normalize through the existing canonical helper:
  - EK / Knight;
  - RP / Paladin;
  - ED / Druid;
  - MS / Sorcerer;
  - EM / Monk.
- optional filters:
  - weapon class;
  - weapon family;
  - result limit.
- every matching weapon is classified factually as:
  - `eligible`;
  - `incomplete`;
  - `blocked`;
  - invalid input is returned explicitly for unsupported vocation values.
- known blocking reasons:
  - `level_requirement`;
  - `vocation_restriction`.
- completeness flags include:
  - missing level requirement;
  - unknown vocation restriction;
  - unknown hand count.
- conservative rule: unknown vocation/level data is never silently assumed eligible.
- known blocking facts take precedence over incompleteness.
- the function does not apply:
  - combat score;
  - hunt weighting;
  - vocation-specific optimizer logic;
  - final weapon ranking.
- level 700 regression snapshot:
  - EK Sword eligible: 87;
  - RP Distance eligible: 80;
  - ED Rod eligible: 45;
  - MS Wand eligible: 51;
  - EM Fist eligible: 34.
- factual regression examples:
  - Grand Sanguine Blade is eligible for EK 700;
  - Moonsilver Claymore is blocked for EK 700 by level requirement;
  - Grand Sanguine Blade is blocked for RP 1000 by vocation restriction.
- focused regression `tests/sql/phase28_universal_weapon_candidates.sql`: status=ok.
- migration commit: `7a3380b19f76ff671b74d38409eb69455a26e7d1`.
- regression commit: `077cf3a76663e0b29a902fb6ea652e6cedd53395`.
- security advisor after 0089: no new finding; existing server-only RLS INFO findings and the known `pg_net` warning remain unchanged.


## Universal weapon attribute comparison

- migration 0090 adds:
  - `huntnexus_weapon_attribute_vector(item_key)`;
  - `huntnexus_compare_weapons_universal(item_keys)`.
- the attribute vector is category-first and factual only.
- normalized dimensions remain separated by:
  - scope;
  - metric;
  - unit.
- core weapon dimensions include:
  - base attack;
  - defense;
  - defense modifier;
  - range;
  - imbue slots.
- elemental/physical attack components remain separate metrics.
- normalized `item_effects` become independent comparison dimensions such as:
  - melee/distance skill;
  - generic and elemental Magic Level;
  - attack modifier;
  - hit modifier;
  - critical;
  - leech;
  - elemental protection;
  - other cataloged effects.
- Weapon Proficiency coverage remains metadata and is not converted into an inferred combat score.
- missing dimensions remain NULL/missing; zero is never imputed.
- no cross-metric sum is applied.
- no "higher is better" direction is inferred.
- no winner, ranking or Pareto dominance is selected by this layer.
- comparisons support up to 10 item keys and explicitly report whether all items share:
  - weapon class;
  - weapon family.
- cross-class regression with Grand Sanguine Blade, Moonsilver Bow, Moonsilver Sceptre and Moonsilver Channeler produced 18 independent dimensions.
- factual regression examples:
  - Moonsilver Bow: attack modifier +10, hit modifier +7, Distance +5;
  - Moonsilver Sceptre: Magic Level +6, Healing Magic Level +2;
  - Moonsilver Channeler: Magic Level +6, Death Magic Level +1.
- focused regression `tests/sql/phase29_universal_weapon_attribute_comparison.sql`: status=ok.
- migration commit: `07162f126b037d01e463470358fbbff3b2d460e6`.
- regression commit: `4104a8e85c1204ca5088c760ea8add5e3459aed6`.
- security advisor after 0090: no new findings; existing server-only RLS INFO findings and the known `pg_net` warning remain unchanged.


## Universal weapon usage dependencies

- migration 0091 adds:
  - server-only `weapon_usage_rules`;
  - server-only `vw_quiver_catalog_universal`;
  - `huntnexus_weapon_usage_context(item_key,vocation,level)`.
- current usage rules cover all 9 normalized weapon families.
- bows/crossbows:
  - require a quiver in the shield/off-hand slot;
  - bow ammunition family = arrow;
  - crossbow ammunition family = bolt;
  - ammunition catalog is explicitly marked `missing`, so no ammo candidate is inferred yet.
- usable quiver catalog contains 8 items; the category-page pseudo-item `quivers` is excluded.
- quiver effects are preserved, including:
  - Alicorn Quiver ML/perfect-shot effects;
  - Eldritch Quiver perfect-shot effect;
  - Naga/Candy-Coated elemental protections.
- Tier-B quiver rule source: TibiaWiki BR `Aljavas`.
- throwing weapons are modeled one-handed with optional shield/off-hand and no quiver requirement.
- rods/wands are modeled one-handed with optional shield or spellbook.
- melee one-hand allows optional shield/off-hand; melee two-hand blocks standard off-hand.
- compatibility is kept separate from combat score/ranking.
- unresolved catalog facts remain unresolved:
  - ammunition candidates are not present in the current item catalog;
  - Assassin Star still has unknown vocation restriction in catalog data and remains `incomplete`.
- focused regression `tests/sql/phase30_weapon_usage_dependencies.sql`: status=ok.
- regression summary:
  - 8 usable quivers;
  - 9 rule families;
  - ammunition_catalog_ready=false.
- migration commit: `6f28e882c1f81566e4078692488dea477f36e134`.
- regression commit: `94651a8e9ed7bafc470e58228776f7d8447a0bad`.
- security advisor after 0091:
  - 7 informational `rls_enabled_no_policy` findings; the new one is `weapon_usage_rules`, intentionally server-only deny-by-default;
  - existing `pg_net` public-schema warning remains unchanged.


## Ammunition catalog + Weapon Proficiency family audit

- migration 0092 adds:
  - server-only `ammunition_catalog`;
  - `huntnexus_ammunition_candidates(family,level)`;
  - server-only `weapon_proficiency_family_rules`;
  - server-only `vw_weapon_proficiency_family_audit`;
  - `huntnexus_weapon_usage_context` upgraded to stage `weapon_usage_context_v2`.
- ammunition catalog source: TibiaWiki BR `Munição` (Tier B).
- current ammunition inventory:
  - 19 arrows;
  - 8 bolts;
  - 27 total.
- ammo facts preserve source attack, level requirement and physical/elemental components separately.
- no final damage formula is inferred from source attack.
- Diamond Arrow is explicitly marked as area ammunition from the Tier-B source.
- Burst Arrow attack pattern remains `unspecified`; no area behavior is inferred.
- Bow usage context now returns real arrow candidates.
- Crossbow usage context now returns real bolt candidates.
- level filtering is active:
  - at level 100: 14/19 arrows eligible, 5 blocked;
  - at level 100: 6/8 bolts eligible, 2 blocked.
- Weapon Proficiency family audit source: TibiaWiki BR `Weapon Proficiency` (Tier B).
- Tier-B system-listed families:
  - sword;
  - axe;
  - club;
  - fist;
  - bow;
  - crossbow;
  - wand;
  - rod.
- Throwing is marked `not_listed`, not inferred as supported or unsupported.
- normalized tree coverage currently in HuntNexus:
  - sword: 6;
  - axe: 2;
  - club: 2;
  - bow/crossbow/fist/wand/rod: 0;
  - total normalized trees: 10.
- focused regression `tests/sql/phase31_ammunition_and_proficiency_family_audit.sql`: status=ok.
- migration commit: `6402373e83ceb932e8ddf2a6e4b42cae7fb27675`.
- regression commit: `c870c631c7e2401ab9943fffbd06650840dd1235`.
- security advisor after 0092:
  - 9 informational `rls_enabled_no_policy` findings; new server-only tables `ammunition_catalog` and `weapon_proficiency_family_rules` are intentionally deny-by-default;
  - existing `pg_net` public-schema warning remains unchanged.


## Distance Weapon Proficiency normalization

- migration 0093 adds the first normalized Bow/Crossbow Weapon Proficiency trees.
- normalized Distance trees in this block:
  - Grand Sanguine Bow;
  - Grand Sanguine Crossbow;
  - Soulbleeder;
  - Soulpiercer;
  - Eldritch Bow;
  - Gilded Eldritch Bow;
  - Bow of Destruction;
  - Crossbow of Destruction.
- 8 trees / 92 perks added.
- source: current TibiaWiki BR item pages, Tier B.
- each source declares seven proficiency levels, but rendered page topology flattens the perk placement.
- therefore:
  - `levels_declared=7`;
  - `topology_status='flattened_source_order'`;
  - all `level_number=NULL`;
  - `perk_order` is source order only.
- no branch/unlock level is inferred.
- the existing generic `huntnexus_weapon_proficiency_preview` works unchanged for Bow/Crossbow.
- examples validated:
  - Grand Sanguine Bow explicit selection returns Distance skill, Divine Caldera leech, Distance-derived spell damage, attack and crit effects;
  - Soulpiercer explicit selection preserves life-on-hit, Distance skill, attack and crit as independent effects.
- current normalized family coverage:
  - sword: 6;
  - axe: 2;
  - club: 2;
  - bow: 5;
  - crossbow: 3;
  - fist: 0;
  - wand: 0;
  - rod: 0.
- total normalized Weapon Proficiency trees: 18.
- focused regression `tests/sql/phase32_distance_weapon_proficiency_trees.sql`: status=ok.
- migration commit: `2d47ad79df9fbbe39a10b89970aea6f87894697a`.
- regression commit: `d4ed0765a704ff2e61e70c29a9f6eca12d636508`.
- security advisor after 0093: no new finding count; existing intentional server-only INFO findings and known `pg_net` warning remain unchanged.


## Caster Weapon Proficiency normalization

- migration 0094 adds the first normalized Wand/Rod Weapon Proficiency trees.
- normalized caster trees in this block:
  - Soultainter;
  - Soulhexer;
  - Grand Sanguine Coil;
  - Grand Sanguine Rod;
  - Amber Wand;
  - Amber Rod;
  - Eldritch Wand;
  - Eldritch Rod.
- 8 trees / 100 perks added.
- current Tier-B sources are the individual TibiaWiki BR item pages.
- each source declares seven proficiency levels, but rendered topology is flattened:
  - `levels_declared=7`;
  - `topology_status='flattened_source_order'`;
  - all `level_number=NULL`;
  - `perk_order` remains source order only.
- caster perks now exercise:
  - Magic Level;
  - elemental Magic Level;
  - Healing Magic Level;
  - offensive-rune critical modifiers;
  - spell/rune elemental critical modifiers;
  - spell-specific base damage/critical/leech/healing;
  - life/mana on kill;
  - bestiary damage;
  - Powerful Foe damage.
- `huntnexus_weapon_proficiency_impact_preview` upgraded to stage `weapon_proficiency_impact_preview_v2`.
- impact vector now also exposes:
  - `flat_magic_level_bonus`;
  - `elemental_magic_level_bonuses`;
  - `healing_magic_level_bonus`.
- ML-derived percentage terms remain explanatory only; no final damage/DPS is inferred.
- semantic bug fixed:
  - absent effective skill/ML inputs now remain NULL instead of being coerced to zero;
  - unresolved ML-derived terms correctly surface `effective_magic_level` in `unresolved_inputs`.
- validation examples:
  - Grand Sanguine Coil, ML 20: +1 flat ML, +2 Energy ML, +2 Fire ML, 8% ML spell term -> 1.6 explanatory derived term;
  - Grand Sanguine Rod, ML 20: +1 flat ML, +2 Earth ML, +2 Ice ML, +3 Healing ML, 8% ML spell term -> 1.6 explanatory derived term.
- current normalized family coverage:
  - sword: 6;
  - axe: 2;
  - club: 2;
  - bow: 5;
  - crossbow: 3;
  - wand: 4;
  - rod: 4;
  - fist: 0.
- total normalized Weapon Proficiency trees: 26.
- focused regression `tests/sql/phase33_caster_weapon_proficiency_trees.sql`: status=ok.
- migration commit: `d3aa6877e33577b3fa2c0e5f8bdfdb7fe1aa7ddf`.
- regression commit: `07c97067b901b7de9e4b8be133b84b84c418c82f`.
- security advisor after 0094: no new findings; 9 intentional server-only RLS INFO findings and the known `pg_net` warning remain unchanged.


## Fist proficiency + weapon category readiness

- migration 0095 completes the first Fist proficiency slice and formalizes the weapon-category readiness audit.
- normalized Fist trees in this block:
  - Pair of Monk Fists;
  - Nunchaku of Destruction;
  - Eldritch Crescent Moon Spade;
  - Amber Kusarigama;
  - Soulkamas;
  - Grand Sanguine Claws;
  - Moonsilver Katar.
- Fist contribution: 7 trees / 75 perks.
- current Assassin Star page exposes Weapon Proficiency, so Throwing is no longer marked `not_listed`.
- Assassin Star now contributes 1 normalized Throwing tree / 5 perks.
- current total normalized Weapon Proficiency trees: 34.
- important catalog semantics correction:
  - source rows with no vocation restriction are normalized as unrestricted instead of unknown;
  - missing level requirement is normalized as level 0;
  - pseudo category row `fist-fighting-weapons` is excluded.
- universal real-weapon catalog count is now 854.
- current structural gaps across the 854 weapons:
  - missing hands: 0;
  - missing level: 0;
  - unknown vocation: 0;
  - unparsed explicit vocation: 0.
- `huntnexus_weapon_proficiency_impact_preview_v2` now also exposes `flat_defense_bonus`.
- Fist effects exercised include:
  - Fist-derived auto/spell damage;
  - Magic-Level-derived auto/spell damage;
  - spell-specific leech/base damage/crit;
  - defence;
  - attack;
  - global crit/leech;
  - bestiary/Powerful Foe;
  - Energy pierce;
  - Moonsilver homing-missile proc metadata;
  - Omega damage below 30% HP.
- `huntnexus_weapon_category_audit()` stage `weapon_category_audit_v1` reports:
  - catalog_weapons=854;
  - weapon_classes=3;
  - weapon_families=9;
  - normalized_proficiency_trees=34;
  - core_contract_ready=true;
  - proficiency_exhaustive=false;
  - proficiency_backfill_pending=true;
  - final_combat_formula_ready=false.
- dependencies:
  - 8 quivers: ready;
  - 19 arrows + 8 bolts: ready.
- interpretation:
  - the universal weapon factual/eligibility/compatibility contract is ready to be consumed by vocation composition later;
  - Weapon Proficiency item coverage is intentionally tracked as a separate non-exhaustive backfill;
  - final combat/DPS formulas are intentionally not part of the weapon category layer.
- focused regression `tests/sql/phase34_fist_proficiency_weapon_category_audit.sql`: status=ok.
- migration commit: `fd739b43841087123999aeb6b1df4517dc21dbd6`.
- regression commit: `f240bdbce5600383b727224c90edaadb013bb7ea`.
- security advisor after 0095: no new findings; 9 intentional server-only RLS INFO findings and the known `pg_net` warning remain unchanged.

### Category-first status after 0095

1. weapons — core contract READY; proficiency backfill continues separately;
2. armor/equipment slots — next;
3. imbues;
4. protections/effects;
5. slot/restriction compatibility;
6. combat/spell mechanics;
7. vocation composition;
8. final optimizer.
