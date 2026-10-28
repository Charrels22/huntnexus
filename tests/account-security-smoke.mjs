// FE-27: all account control operations must reject bogus Auth credentials.
// The tokens below are deliberately fabricated; this does not exercise real
// password delivery, MFA or a legitimate signed-in Supabase Auth session.
const endpoint = process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const tokens = [
  "invalid-test-token-this-is-not-a-real-session",
  "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJub3Qtc2lnbmVkIn0.invalid",
  "fe27-made-up-session-"+"0".repeat(120),
];
const cases = [
  { action: "account_status" },
  { action: "account_unbind" },
  { action: "account_resolve",
    local_client_id: "928942a5-aa1b-4ae8-a56f-815ef4829491" },
];

let denied = 0;
for (const token of tokens) {
  for (const input of cases) {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "content-type": "application/json",
        authorization: "Bearer "+token },
      body: JSON.stringify({...input,access_token:token}),
      signal: AbortSignal.timeout(18000),
    });
    const body = await response.json().catch(() => ({}));
    if (response.status !== 401 || body?.error !== "invalid_auth_token") {
      throw new Error(`${input.action} must reject fake Auth token: HTTP ${response.status}; ${JSON.stringify(body).slice(0,250)}`);
    }
    denied++;
  }
}
console.log(JSON.stringify({
  status: "ok",
  stage: "account_negative_auth_public_smoke_v2",
  fake_auth_attempts_denied: denied,
  account_status_unbind_resolve_protected: true,
  canonical_merge_with_valid_strong_auth_tested: false,
  real_cross_device_auth_tested: false,
}, null, 2));
