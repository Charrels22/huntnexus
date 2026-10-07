# HuntNexus API

The database/Brain remains private. Public clients should not receive the Supabase service-role key.

## Edge Function

`supabase/functions/huntnexus-api/index.ts`

Supported actions:

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
`huntnexus_recommendation_preview(...)`.

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
`huntnexus_boss_build_preview(...)`.

A boss with an active RubinOT reconciliation guard returns a preview, but `final_build_available=false`.

## Browser client

`api/huntnexus-client.ts` provides a small typed wrapper for HuntNexus Web/Lovable.
