# Phase 17 — Product API lookups

The Edge Function can use service-role-only RPC helpers for:
- hunt search;
- boss search;
- health/status.

Boss search includes readiness/guard state so the UI can immediately show whether a final RubinOT build is blocked.

Health exposes current catalogue counts and latest RubinOT client/server versions without exposing internal credentials.

RubinOT warning RPCs expose unresolved spell and boss-system changes to the UI instead of silently using stale behavior.
