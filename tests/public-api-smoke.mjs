const endpoint =
  process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function post(body) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });

  const payload = await response.json();
  assert(response.ok, `HTTP ${response.status}: ${JSON.stringify(payload)}`);
  return payload;
}

const health = await post({ action: "health" });
assert(health?.data?.status === "ok", "health status must be ok");
assert(
  health?.data?.recommendation_stage === "preview_v7",
  `expected preview_v7, got ${health?.data?.recommendation_stage}`,
);

const recommendation = await post({
  action: "recommend",
  vocation: "EK",
  level: 700,
  objective: "xp",
  party_size: 1,
  limit: 1,
  defensive_items_per_slot: 3,
});

const first = recommendation?.data?.results?.[0];
assert(first, "EK700 XP must return at least one hunt");
assert(first?.ranking?.ranking_score != null, "ranking_score missing");
assert(first?.ranking?.confidence_score != null, "confidence_score missing");
assert(
  first?.loadout_candidate_matrix?.methodology?.stage ===
    "loadout_candidate_matrix_v5",
  "loadout matrix stage regression",
);
assert(
  first?.loadout_set_preview?.methodology?.stage === "loadout_set_preview_v3",
  "loadout set stage regression",
);
assert(
  first?.loadout_set_preview?.hand_analysis?.methodology?.stage ===
    "ek_hand_options_v2",
  "EK hand model regression",
);
assert(
  first?.loadout_set_preview?.imbuement_preview?.methodology?.stage ===
    "loadout_imbuement_compatibility_v1",
  "imbuement compatibility regression",
);
assert(
  first?.loadout_set_preview?.hand_options?.one_handed?.main_hand?.item_key !==
    "ice-rapier",
  "Ice Rapier must not be selected for sustained hunts",
);

const magma = await post({
  action: "boss_build",
  boss_key: "magma-bubble",
  vocation: "EK",
  level: 700,
});
assert(
  magma?.data?.readiness?.final_build_blocked === true,
  "Magma Bubble guard must stay active",
);
assert(
  magma?.data?.final_build_available === false,
  "Magma Bubble final build must remain unavailable",
);

console.log(
  JSON.stringify(
    {
      status: "ok",
      recommendation_stage: health.data.recommendation_stage,
      top_hunt: first.ranking.hunt_name,
      ranking_score: first.ranking.ranking_score,
      confidence_score: first.ranking.confidence_score,
      one_hand:
        first.loadout_set_preview?.hand_options?.one_handed?.main_hand?.name,
      two_hand:
        first.loadout_set_preview?.hand_options?.two_handed?.item?.name,
      magma_blocked: magma.data.readiness.final_build_blocked,
    },
    null,
    2,
  ),
);
