const endpoint = process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const dummy = "invalid-test-token-this-is-not-a-real-session";
const cases = [
  { action: "account_status", access_token: dummy },
  { action: "account_unbind", access_token: dummy },
  { action: "account_resolve", access_token: dummy,
    local_client_id: "928942a5-aa1b-4ae8-a56f-815ef4829491" },
];

for (const input of cases) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(input),
    signal: AbortSignal.timeout(15000),
  });
  const body = await response.json().catch(() => ({}));
  if (response.status !== 401 || body?.error !== "invalid_auth_token") {
    throw new Error(`${input.action} must reject invalid auth: HTTP ${response.status}; ${JSON.stringify(body)}`);
  }
}
console.log(JSON.stringify({
  status: "ok",
  stage: "account_negative_auth_public_smoke",
  unauthenticated_account_access_denied: true,
  canonical_merge_with_valid_magic_link_tested: false,
  real_cross_device_auth_tested: false,
}, null, 2));
