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
    throw new Error(`HTTP ${response.status} action=${body.action} vocation=${body.vocation ?? "n/a"} hunt=${body.hunt_key ?? "n/a"}: ${JSON.stringify(payload)}`);
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

  const huntKey = planner.data.results[0].hunt.hunt_key;
  const detail = await post({
    action: "hunt_detail",
    hunt_key: huntKey,
    vocation: current.vocation,
    level: 700,
    set_objective: "balanced",
    proficiency_selections: {},
    character_profile: {},
  });
  const factual = detail?.data?.factual;
  assert(factual?.hunt?.name, `${current.vocation} Hunt Detail missing factual hunt name`);
  assert(Array.isArray(factual?.monsters) && factual.monsters.length > 0,
    `${current.vocation} Hunt Detail missing source-backed creature catalog`);
  assert(Array.isArray(factual?.elements),
    `${current.vocation} Hunt Detail factual elements shape regression`);
  assert(detail?.data?.observed && typeof detail.data.observed === "object",
    `${current.vocation} Hunt Detail observed contract regression`);
  assert(detail?.data?.methodology?.stage === "hunt_detail_lazy_heavy_v1",
    `${current.vocation} Hunt Detail must load factual data without full optimizer`);
  assert(detail?.data?.set_selection === undefined && detail?.data?.spells === undefined,
    `${current.vocation} heavy contracts must remain lazy`);
  assert(detail?.data?.imbuements && typeof detail.data.imbuements === "object",
    `${current.vocation} Hunt Detail imbuements contract regression`);

  const spellDetail = await post({
    action: "hunt_detail_spells",
    hunt_key: huntKey,
    vocation: current.vocation,
    level: 700,
  });
  assert(spellDetail?.data?.methodology?.stage === "hunt_detail_spells_resilient_v1",
    `${current.vocation} Spells resilient contract regression`);
  assert(["available","unavailable"].includes(spellDetail?.data?.availability?.vocation_composition),
    `${current.vocation} must report composition availability`);
  assert(spellDetail?.data?.spells?.methodology?.stage ===
    "spell_candidates_with_unlocks_universal_v1",
    `${current.vocation} on-demand spell catalog regression`);

  results.push({
    vocation: current.vocation,
    family: current.family,
    hunt_key: huntKey,
    factual_creatures: factual.monsters.length,
    imbuement_contract: true,
    spell_contract: true,
    composition_available: spellDetail.data.availability.vocation_composition === "available",
    universal_setup_deferred: true,
    proficiency_trees: proficiency.data.summary.eligible_tree_count,
  });
}

console.log(JSON.stringify({
  status: "ok",
  stage: "cross_vocation_public_smoke",
  level: 700,
  human_playtest_complete: false,
  factual_hunt_detail_checked: true,
  heavy_set_optimizer_runtime_verified: false,
  frontend_visual_validation_complete: false,
  results,
}, null, 2));
