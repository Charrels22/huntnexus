# Checkpoint — 2026-10-07 — Infraestrutura independente

## Infraestrutura

### Supabase
Projeto próprio: HuntNexus
- região: São Paulo
- status: ACTIVE_HEALTHY
- schema/migrations aplicados até 0057
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
- `auto_build_enabled=true`; push em `main` dispara build/deploy pelo Cloudflare.
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
- links canonical resolved: 3.743
- unresolved: 2 ocorrências de demongoblin
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

Current public sample differs from the prior Lovable snapshot because HuntAnalyser's newest public pages changed. This is expected for a live Tier C source.

## Canonical compatibility fixes

Applied:
- 0055 restores original apostrophe-removal slug semantics.
- 0056 restores community normalization compatibility and safe aliases.
- creature slug mismatches: 0
- hunt slug mismatches: 0
- Goshnar's Hatred key restored to goshnars-hatred.
- Soul War guard works again.

## Product smoke in Supabase

Confirmed:
- huntnexus_api_health() = ok
- recommendation stage = preview_v4
- EK700 XP returns Cobra Bastion
- score and confidence remain separate
- Magma Bubble final build blocked by v13.8 guard
- Goshnar's Hatred final build blocked by Soul War v13.7 guard

## Public Cloudflare end-to-end smoke

Endpoint:
- `https://huntnexus.charr3ls22.workers.dev/api/huntnexus`

Confirmed through real public HTTP requests:
- `health`: HTTP 200, HuntNexus, v13.9 / v4.064, preview_v4
- `recommend`: EK 700 / XP / Solo -> Cobra Bastion, score 0.794, confidence 0.920, HTTP 200
- recommendation stage atual: `preview_v5`
- loadout set preview: `loadout_set_preview_v1`, sem score combinado artificial
- `search_bosses`: Magma Bubble -> `magma-bubble`, guard state exposed correctly, HTTP 200
- `boss_build`: Magma Bubble -> `final_build_blocked=true`, `final_build_available=false`, RubinOT v13.8 guard, HTTP 200

Frontend root also resolves publicly from the same Worker.

API contract cleanup:
- `api/huntnexus-client.ts` now matches the Worker vocations exactly: EK/RP/ED/MS.
- `api/README.md` documents Cloudflare as the production API path.
- old Supabase Edge Function and Lovable-oriented directories are legacy references only.

## Security

Supabase advisor:
- function search-path warning fixed in 0057
- remaining security lint: pg_net installed in public schema
  - accepted temporarily because pg_net is used only by service-role/internal ingestion
  - do not relocate extension until ingestion has a replacement path and a migration test

## Deployment validation

- frontend commit `292932473f0fad7e6fd253a0411af7818893ae1e` foi buildado e publicado com sucesso pelo Cloudflare Builds.
- commit `7ac17de116639a37286212e5de249003b433d7eb` corrigiu o CI que referenciava um `package-lock.json` inexistente.
- GitHub CI do HEAD ficou verde.
- primeiro deploy Cloudflare desse HEAD falhou apenas no upload de assets com erro transitório `10013`.
- retry manual do mesmo commit, sem mudança de código, concluiu com sucesso.
- smoke público final após o retry:
  - health HTTP 200 / `preview_v5`
  - recommend HTTP 200 / Cobra Bastion / 0.794 / 0.920
  - boss_build HTTP 200 / Magma Bubble bloqueado / final build indisponível

## Remaining work

- manual visual/browser interaction QA of form controls
- continue recommendation/final-set optimizer
- current RubinOT boss mechanic reconciliation
- optional performance indexing based on real query usage
- terms/privacy decision before expanding HuntAnalyser beyond 100-session public sample
