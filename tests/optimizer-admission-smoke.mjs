const endpoint = process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";

const body = {
  action: "hunt_detail_setup",
  hunt_key: "cobra-bastion",
  vocation: "EK",
  level: 700,
  set_objective: "balanced",
  proficiency_selections: {},
  character_profile: {},
};

const post = () => fetch(endpoint, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify(body),
  signal: AbortSignal.timeout(50000),
});

const first = post();
// Admission should have finished long before the optimizer result is ready.
await new Promise((resolve) => setTimeout(resolve, 1200));
const second = await post();
const denied = await second.json().catch(() => ({}));

if (second.status !== 429 || denied.error !== "optimizer_admission_denied") {
  throw new Error(`Concurrent same-origin setup must return 429, got ${second.status}: ${JSON.stringify(denied)}`);
}
if (denied.reason !== "subject_busy") {
  throw new Error(`Unexpected concurrency reason: ${denied.reason}`);
}
if (!(Number(second.headers.get("retry-after")) >= 1)) {
  throw new Error("429 must provide Retry-After header");
}

const health = await fetch(endpoint, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ action: "health" }),
  signal: AbortSignal.timeout(12000),
});
if (!health.ok) {
  throw new Error(`Non-expensive health action blocked during setup: ${health.status}`);
}

const initial = await first;
const result = await initial.json().catch(() => ({}));
if (!initial.ok) {
  throw new Error(`Admitted optimizer did not complete: HTTP ${initial.status}: ${JSON.stringify(result)}`);
}
if (result.data?.execution?.admission_stage !== "distributed_optimizer_admission_v1" ||
    result.data?.execution?.enumeration_set_limit !== 100 ||
    result.data?.methodology?.stage !== "optimizer_set_selection_universal_v1") {
  throw new Error("Admitted optimizer lost method or scope contract");
}
console.log(JSON.stringify({
  status: "ok",
  stage: "optimizer_admission_public_smoke",
  duplicate_request_status: second.status,
  duplicate_request_reason: denied.reason,
  retry_after: second.headers.get("retry-after"),
  health_unaffected: true,
  admitted_optimizer_completed: true,
  lease_cleanup_expected: true,
  privacy: "no caller IP or HMAC hash returned",
}, null, 2));
