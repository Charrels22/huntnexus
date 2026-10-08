# Checkpoint — 2026-10-07 — Infraestrutura independente

## Infraestrutura

### Supabase
Projeto próprio: HuntNexus
- região: São Paulo
- status: ACTIVE_HEALTHY
- schema/migrations aplicados até 0070
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
- profiled EK request uses `recommendation_preview_profiled_v1`; Sword 120 smoke constrains both one-hand and two-hand candidates to Sword
- `profile_contract`: EK -> Sword/Axe/Club
- frontend exposes optional EK weapon family, effective weapon skill and shielding; family options come from the API contract
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

`character_combat_profile_contract_v1`:
- prefers effective client-displayed values;
- EK precise hand comparison uses Sword/Axe/Club + effective weapon skill;
- optional effective shielding, critical, life/mana leech and elemental/race modifiers are modeled in the contract;
- API/frontend wiring is active through `recommendation_preview_profiled_v1`;
- effective weapon skill/shielding are exposed as context, not silently converted into final DPS/mitigation;
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

- automatically invoke player-profile + provenance parsing when new HuntAnalyser detail snapshots are ingested, so the normalized layer cannot become stale
- manual visual/browser interaction QA of the character-profile controls and Tier C imbuement section
- reconcile Weapon Proficiency exact combat contribution before converting effective skill/attack into a final damage estimate
- extend profiled recommendation logic beyond EK after vocation-specific evidence/formulas are reconciled
- continue recommendation/final-set optimizer with character-aware data
- keep cross-type imbuement priorities explicit; Tier C observed usage remains contextual only
- current RubinOT boss mechanic reconciliation
- optional performance indexing based on real query usage
- terms/privacy decision before expanding HuntAnalyser beyond the current 100-session public sample


## 2026-10-08 continuation validation

- migration history and repository aligned through 0070
- SQL regression suite: status=ok
- Web CI for Tier C imbuement UI: success
- Cloudflare build/deploy commit `d9bec8bb3cdee851592c7413acf85349a34aa59d`: success
- Public Smoke with `imbuement_candidates_v2`: success
- character-profile public smoke remains backward compatible with legacy `preview_v7`
