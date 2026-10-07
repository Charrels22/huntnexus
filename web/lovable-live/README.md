# Lovable live implementation mirror

Canonical mirror of the HuntNexus Lovable implementation produced at Lovable commit:

`380f51a7ef60a19266f6056d8bb2df941a5c37d5`

The Lovable project itself is still unpublished.

Mirrored here:
- `src/routes/index.tsx`
- `src/routes/api/huntnexus.ts`
- `src/routes/__root.tsx`

Canonical patch includes one pending display correction not yet applied in Lovable because agent credits ran out:
- incoming damage uses `weight`; display as `Math.round(weight * 100)%`.

The active Lovable app currently uses the TanStack server route `/api/huntnexus` with the server-only Supabase service-role client. The earlier Supabase Edge Function prototype is not the active Lovable path.
