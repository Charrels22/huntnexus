# HuntNexus FE-18 / PERF-01–05 — Universal optimizer runtime closure

Date: 2026-10-11 (America/Sao_Paulo).

## Scope and invariants

The universal Pareto set algorithm was **not replaced** with an opaque score. Main stays the personal baseline; owned Backpack and external candidates remain separated; Weapon Proficiency selection is bound to each item's exact `item_key`. Neither simulated DPS nor simulated XP/Profit was added.

## Production database migrations (applied)

- **0148 — optimizer_hunt_element_membership_fast_path**: for item vector construction, reads distinct incoming-damage elements from the same raw joined evidence with no unnecessary median/sum/share aggregation. Compared five vocation/hunt element sets (EK/Cobra Bastion, RP/Iksupan Last Stand, ED/Nimmersatt, MS/Podzilla, EM/Grounds of Undeath); all five exact.
- **0149 — optimizer_pareto_dominance_jsonb_lookup**: each dimension uses direct JSONB lookup into the compared vector after verifying equal dimension keysets. No dimensional score or ranking changed; Sword, Axe and Helmet frontier JSON hashes unchanged.
- **0150 — optimizer_item_effect_aggregate_once**: aggregate item effects once per evaluated item across skill, utility and protection dimensions. Four pre/post item-vector JSON hashes exactly match.
- **0151 — optimizer_proficiency_unique_weapon_evaluation**: identical Weapon Proficiency effects now evaluated once per unique weapon across set candidates. Pre/post full profiled concrete-sets JSON hashes match (`cdb7e39439294a25506bb7540cf6320b`), as does full selected set JSON (`11c6770ab8b8c8c0c450c2a08f541ff0`). No selection or item-key inheritance changes.
- **0152 — optimizer_selection_isolated_timeout**: documented Supabase function-level `SET statement_timeout TO '25s'` applies **only** to explicit `huntnexus_optimizer_set_selection_universal` calls. Does not increase the default PostgREST API timeout globally; source: https://supabase.com/docs/guides/database/postgres/timeouts#function-level

## Measured evidence (EK700 / Cobra Bastion)

| Call | Baseline | After PERF-01 | After PERF-02 | After PERF-03/04 |
|---|---:|---:|---:|---:|
| Hand packages | 9.07 s | 5.58 s | 4.22 s | 4.00 s |
| Universal 100-set selection | 18.43 s | 11.20 s | 10.49 s | 9.72–10.02 s |

These are individual measured runs, not statistical benchmarks or latency SLOs.

## Live Cloudflare public HTTP validation

- **PASS:** https://github.com/Charrels22/huntnexus/actions/runs/38141904110 — `tests/full-optimizer-smoke.mjs`.
- Production `hunt_detail_setup` returned HTTP 200 at **10.83 seconds**, with `valid_sets_considered=100`, `frontier_sets_considered=64`, and `selected_sets=20`. Every returned concrete set passed the validity and comparison-key assertions.
- **This is exhaustive over the 100 configured candidate sets, not proof that every possible set in the game's full combinatorial space was enumerated.** When the upstream enumeration reports truncated, the UI/methodology must say so explicitly.
- Cross-vocation test `tests/full-optimizer-vocations-smoke.mjs` and workflow `huntnexus-five-vocation-full-optimizer.yml` independently exercise EK/RP/ED/MS/EM with one sourced hunt per vocation. Record run result before marking the full matrix green.

## Still pending

- Bring average production latency down further; current long-lived RPC consumes database resources. Do not open external community pilot without rate limiting/abuse mitigation and concurrency controls for this expensive public action.
- Ensure UI clearly labels the 100-set candidate cap, truncation and user-visible latency.
- Frontend visual QA, real analyzers/hunts from EK/RP/ED/MS/EM players, magic link delivery/cross-device auth and external community validation remain separate gates.


## Five-class production run (pass)

GitHub Actions https://github.com/Charrels22/huntnexus/actions/runs/38142018318 — success using the deployed Cloudflare API, sequential per-class setup:

| Vocation | Hunt | HTTP time | Valid concrete candidates | Pareto sets | Returned |
|---|---|---:|---:|---:|---:|
| EK | cobra-bastion | 11.21s | 100 | 64 | 20 |
| RP | iksupan-last-stand | 7.60s | 100 | 32 | 20 |
| ED | nimmersatts-breeding-ground | 7.76s | 100 | 100 | 20 |
| MS | podzilla | 7.41s | 100 | 16 | 16 |
| EM | grounds-of-undeath | 6.80s | 100 | 48 | 20 |

All returned concrete selections passed checks for valid structure, real weapon slot and comparable dimensions. The returned result count is capped at 20 and the generated candidate universe at 100. Repeated calls/concurrent workloads may vary in runtime.

## Scope transparency update
- `hunt_detail_setup` now exposes `data.execution.enumeration_set_limit=100`, `frontier_limit=100`, `returned_set_limit=20`, `exhaustive_all_possible_combinations=false` and a source methodology tag.
- Hunt Detail Setup explicitly states how many sets were examined, how many stayed undominated, how many were returned and that the result is NOT exhaustive across every game item.
- Users can expand all sets returned by the API rather than seeing only the first eight with no explanation.
- `tests/full-optimizer-vocations-smoke.mjs` includes assertions for API candidate-cap metadata; latest verification should be re-checked after Worker deployment.


## Post-change verification — scope-aware UI/API and database advisors
- Scope-aware `hunt_detail_setup` API now returns `execution.enumeration_set_limit=100`, `execution.returned_set_limit=20`, and `execution.exhaustive_all_possible_combinations=false`. The frontend shows the cap, comparison scope, co-winners and returned count and lets users expand all returned sets.
- Five-vocation HTTP regression **38142232270** — SUCCESS with this new scope assertion: https://github.com/Charrels22/huntnexus/actions/runs/38142232270
  - EK 10.85 s, RP 8.26 s, ED 7.97 s, MS 7.68 s, EM 7.37 s; 100 valid sets examined per test.
  - This verifies the deployed API action and normalized result, not browser-rendered visuals.
- Web CI **38142215553** — SUCCESS on the updated Hunt Detail UI: https://github.com/Charrels22/huntnexus/actions/runs/38142215553
- Player inventory smoke **38142215548**, Player Session smoke **38142188658**, Profile smoke **38142188602**, and Cross Vocation factual smoke **38142188576** — SUCCESS on their relevant commits.
- Production database function config independently verified: only `huntnexus_optimizer_set_selection_universal` has `statement_timeout=25s`; the underlying item vector/proficiency functions retain original configuration.
- Re-ran `huntnexus_product_readiness_audit()`: **9/9 backend contract checks ready**, 454 eligible hunts with core complete, 34 proficiency trees, 24 Powerful Imbuements; this audit explicitly excludes public performance tests, frontend visual QA and real class playtests.

### Advisor review
- Security linter: 24 `rls_enabled_no_policy` INFORMATION notices on service-role/data-source tables; these lack direct client access by design and remain denied to ordinary clients. Must periodically verify intentional privileges rather than adding permissive policies.
- Security linter: one `extension_in_public` WARNING for existing `pg_net`; remediation requires reviewing dependencies before moving the extension. Ref: https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public
- Performance linter: 75 informational foreign-key indexing suggestions and 6 potentially unused indexes. Review hot-path evidence first; do not indiscriminately create/drop indexes. Ref: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- These are remaining infrastructure hardening tasks, not a reason to retroactively mark the proven five-class optimizer RPC as failed.

### Handoff
**Optimizer blocker:** resolved for the tested 100-set configuration across EK, RP, ED, MS and EM via real deployed HTTP, with average latency still a product-performance concern. Before opening a broad external pilot, add distributed rate limits/concurrency protection to the advanced endpoint; verify browser visuals, official-vs-canonical provenance, account cross-device Magic Link, and real-game session cases for each vocation.
