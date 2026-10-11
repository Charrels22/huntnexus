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

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${JSON.stringify(payload)}`);
  }
  return payload;
}

const cases = [
  { vocation: "EK", family: "sword" },
  { vocation: "RP", family: "bow" },
  { vocation: "ED", family: "rod" },
  { vocation: "MS", family: "wand" },
  { vocation: "EM", family: "fist" },
];

const results = [];

for (const current of cases) {
  const planner = await post({
    action: "planner_personalized",
    vocation: current.vocation,
    level: 700,
    objective: "balanced",
    party_size: 1,
    limit: 1,
    proficiency_selections: {},
    character_profile: {},
  });

  assert(
    planner?.data?.methodology?.stage === "planner_personalized_api_v1",
    `${current.vocation} planner stage regression`,
  );
  assert(
    planner?.data?.methodology?.ownership_affects_hunt_rank === false,
    `${current.vocation} ownership ranking regression`,
  );
  assert(
    planner?.data?.results?.[0]?.hunt?.hunt_key,
    `${current.vocation} planner returned no hunt`,
  );

  const proficiency = await post({
    action: "player_profile_proficiency_catalog",
    vocation: current.vocation,
    level: 700,
    weapon_family: current.family,
  });

  assert(
    Number(proficiency?.data?.summary?.eligible_tree_count ?? 0) > 0,
    `${current.vocation}/${current.family} proficiency regression`,
  );

  results.push({
    vocation: current.vocation,
    family: current.family,
    hunt_key: planner.data.results[0].hunt.hunt_key,
    proficiency_trees: proficiency.data.summary.eligible_tree_count,
  });
}

console.log(JSON.stringify({
  status: "ok",
  stage: "cross_vocation_public_smoke",
  level: 700,
  human_playtest_complete: false,
  results,
}, null, 2));
