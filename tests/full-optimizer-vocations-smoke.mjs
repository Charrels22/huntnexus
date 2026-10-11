const endpoint = process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const cases = [
  { vocation: "EK", hunt_key: "cobra-bastion" },
  { vocation: "RP", hunt_key: "iksupan-last-stand" },
  { vocation: "ED", hunt_key: "nimmersatts-breeding-ground" },
  { vocation: "MS", hunt_key: "podzilla" },
  { vocation: "EM", hunt_key: "grounds-of-undeath" },
];

const results = [];
for (const current of cases) {
  const began = performance.now();
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      action: "hunt_detail_setup",
      hunt_key: current.hunt_key,
      vocation: current.vocation,
      level: 700,
      set_objective: "balanced",
      proficiency_selections: {},
      character_profile: {},
    }),
    signal: AbortSignal.timeout(55000),
  });
  const elapsed_seconds = Number(((performance.now() - began) / 1000).toFixed(2));
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${current.vocation}/${current.hunt_key}: HTTP ${response.status} after ${elapsed_seconds}s; ${JSON.stringify(payload)}`);
  }
  const data = payload.data;
  if (data?.methodology?.stage !== "optimizer_set_selection_universal_v1") {
    throw new Error(`${current.vocation}: missing real universal optimizer stage`);
  }
  if (data?.execution?.enumeration_set_limit !== 100 ||
      data?.execution?.returned_set_limit !== 20 ||
      data?.execution?.exhaustive_all_possible_combinations !== false) {
    throw new Error(`${current.vocation}: missing transparent bounded enumeration contract`);
  }
  if (!Array.isArray(data?.selected_sets) || !data.selected_sets.length) {
    throw new Error(`${current.vocation}: no concrete set options returned`);
  }
  if (Number(data?.summary?.returned) !== data.selected_sets.length) {
    throw new Error(`${current.vocation}: selected set count mismatch`);
  }
  if (Number(data?.source_summary?.valid_sets_considered) < data.selected_sets.length ||
      Number(data?.source_summary?.valid_sets_considered) > 100) {
    throw new Error(`${current.vocation}: invalid 100-candidate enumeration contract`);
  }
  if (data.selected_sets.some((set) =>
    set?.validation?.status !== "valid" ||
    !set?.set_vector?.comparison_key ||
    !set?.selection?.weapon
  )) {
    throw new Error(`${current.vocation}: invalid or unverified concrete set returned`);
  }
  const result = {
    vocation: current.vocation,
    hunt_key: current.hunt_key,
    elapsed_seconds,
    configured_set_limit: 100,
    valid_sets: data.source_summary.valid_sets_considered,
    frontier_sets: data.summary.frontier_sets_considered,
    returned_sets: data.selected_sets.length,
    truncated: data.summary.truncated,
    visual_qa_complete: false,
    human_playtest_complete: false,
  };
  results.push(result);
  console.log(JSON.stringify({ step: "vocation_complete", ...result }));
}
console.log(JSON.stringify({
  status: "ok",
  stage: "full_optimizer_five_vocations_public_smoke",
  count: results.length,
  results,
}, null, 2));
