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
