# HuntNexus API

The HuntNexus Brain remains private. Public clients must never receive the Supabase service-role key.

## Production endpoint

The production API is served by the Cloudflare Worker from:

`web/app/src/routes/api/huntnexus.ts`

Public endpoint:

`POST https://huntnexus.charr3ls22.workers.dev/api/huntnexus`

The Worker reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` only in the server runtime and calls the internal Supabase RPCs.

Supported actions:

- `health`
- `search_hunts`
- `search_bosses`
- `recommend`
- `boss_build`

### Recommendation

```json
{
  "action": "recommend",
  "vocation": "EK",
  "level": 700,
  "objective": "xp",
  "party_size": 1,
  "limit": 5,
  "defensive_items_per_slot": 3
}
```

Calls the internal service-role-only RPC:

`huntnexus_recommendation_preview(...)`

### Boss build

```json
{
  "action": "boss_build",
  "boss_key": "magma-bubble",
  "vocation": "EK",
  "level": 700
}
```

Calls:

`huntnexus_boss_build_preview(...)`

A boss with an active RubinOT reconciliation guard returns a preview with `final_build_available=false`.

## Browser client

`api/huntnexus-client.ts` provides the typed client for the public HuntNexus API contract.

Supported public vocations currently match the Worker contract exactly:

`EK | RP | ED | MS`

## Legacy code

`supabase/functions/huntnexus-api/` and the old Lovable-oriented web directories are retained only as historical migration references. They are not part of the production deploy path.

Current production ownership is:

```text
GitHub Charrels22/huntnexus
  -> web/app
  -> Cloudflare Worker huntnexus
  -> Supabase HuntNexus
```

Lovable is not a production dependency.
