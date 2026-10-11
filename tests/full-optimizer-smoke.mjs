const endpoint = process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";

const began = performance.now();
const response = await fetch(endpoint, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({
    action: "hunt_detail_setup",
    hunt_key: "cobra-bastion",
    vocation: "EK",
    level: 700,
    set_objective: "balanced",
    proficiency_selections: {},
    character_profile: {},
  }),
  signal: AbortSignal.timeout(50000),
});
const elapsedSeconds = Number(((performance.now() - began) / 1000).toFixed(2));
const payload = await response.json().catch(() => ({}));
if (!response.ok) {
  throw new Error(`Full optimizer HTTP ${response.status} after ${elapsedSeconds}s: ${JSON.stringify(payload)}`);
}
const data = payload.data;
const fail = (reason) => { throw new Error(reason); };
if (data?.methodology?.stage !== "optimizer_set_selection_universal_v1") {
  fail("Unexpected universal set selection stage");
}
if (data?.query?.hunt_key !== "cobra-bastion" || data?.query?.vocation !== "EK") {
  fail("Wrong hunt/vocation in optimizer response");
}
if (!Array.isArray(data?.selected_sets) || data.selected_sets.length === 0) {
  fail("Missing calculated concrete set selections");
}
if (Number(data?.summary?.returned) !== data.selected_sets.length) {
  fail("Returned count differs from actual concrete sets");
}
if (!(Number(data?.summary?.frontier_sets_considered) >= data.selected_sets.length)) {
  fail("Frontier was not evaluated over the reported candidates");
}
if (!(Number(data?.source_summary?.valid_sets_considered) >= 100)) {
  fail("Concrete enumeration silently lost the 100-set input contract");
}
if (data.selected_sets.some((set) => set?.validation?.status !== "valid" ||
  !set?.set_vector?.comparison_key || !set?.selection?.weapon)) {
  fail("Invalid or source-less concrete sets included");
}
console.log(JSON.stringify({
  status: "ok",
  stage: "full_optimizer_public_smoke",
  source: "deployed_cloudflare_worker",
  vocation: "EK",
  hunt_key: "cobra-bastion",
  elapsed_seconds: elapsedSeconds,
  candidate_set_limit: 100,
  valid_sets_considered: data.source_summary.valid_sets_considered,
  frontier_sets_considered: data.summary.frontier_sets_considered,
  selected_sets: data.selected_sets.length,
  real_player_playtest: false,
}, null, 2));
