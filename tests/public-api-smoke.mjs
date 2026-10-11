// FE-02 private session import smoke checkpoint.
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


// Creature Explorer must be reachable through the public Worker, not only via SQL.
const creatureSearch = await post({ action: "search_creatures", query: "cobra", limit: 10 });
assert(
  creatureSearch?.data?.methodology?.stage === "creature_search_v1",
  "creature search API stage regression",
);
const firstCreature = creatureSearch?.data?.creatures?.find((row) => row.creature_key === "cobra-assassin")
  ?? creatureSearch?.data?.creatures?.[0];
assert(firstCreature?.creature_key, "creature search should return a canonical creature key");

const creatureDetail = await post({ action: "creature_detail", creature_key: firstCreature.creature_key });
assert(
  creatureDetail?.data?.methodology?.stage === "creature_detail_v1",
  "creature detail API stage regression",
);
assert(
  creatureDetail?.data?.creature?.creature_key === firstCreature.creature_key,
  "creature detail must match the selected creature",
);
for (const field of ["vulnerabilities", "abilities", "loot"]) {
  assert(Array.isArray(creatureDetail?.data?.[field]), `creature detail ${field} must be an array`);
}

const importClientId = crypto.randomUUID();
let importedSessionId = null;
try {
  const imported = await post({
    action: "session_import_save",
    client_id: importClientId,
    blocks: {
      hunt: [
        "Session: 01:30h",
        "Session data: From 2026-10-10, 10:00:00 to 2026-10-10, 11:30:00",
        "XP Gain: 12,000,000",
        "XP/h: 8,000,000",
        "Loot: 1,500,000",
        "Supplies: 500,000",
        "Balance: 1,000,000",
        "Damage: 6,000,000",
        "Healing: 1,200,000",
        "Killed Monsters:",
        "100x cobra assassin",
        "50x cobra scout",
        "Looted Items:",
      ].join("\n"),
      party: [
        "Session: 01:30h",
        "Session data: From 2026-10-10, 10:00:00 to 2026-10-10, 11:30:00",
        "Loot Type: Leader",
        "Loot: 1,500,000",
        "Supplies: 500,000",
        "Balance: 1,000,000",
        "Damage: 6,000,000",
        "Healing: 1,200,000",
        "Smoke One (Leader)",
        "Loot: 1,000,000",
        "Supplies: 250,000",
        "Balance: 750,000",
        "Damage: 3,500,000",
        "Healing: 700,000",
        "Smoke Two",
        "Loot: 500,000",
        "Supplies: 250,000",
        "Balance: 250,000",
        "Damage: 2,500,000",
        "Healing: 500,000",
      ].join("\n"),
      input: [
        "Damage Types:",
        "physical: 120,000 (60%)",
        "fire: 80,000 (40%)",
        "Damage Sources:",
        "cobra assassin: 150,000 (75%)",
        "cobra scout: 50,000 (25%)",
      ].join("\n"),
      misc: [
        "Mana Leech: 8%",
        "Critical Hit: 10%",
      ].join("\n"),
    },
    metadata: {
      character: "Smoke Tester",
      server: "RubinOT",
      vocation: "EK",
      level: "700",
      location: "Cobra Bastion",
      observation: "public smoke regression",
      tags: ["smoke"],
      type: "normal",
      favorite: false,
      publishHighscores: false,
      rareDrops: "",
    },
  });

  importedSessionId = imported?.data?.session_id;
  assert(importedSessionId, "session import must return session_id");
  assert(imported?.data?.status === "parsed", "session import must be parsed");
  assert(imported?.data?.community_evidence_written === false, "private import must not write community evidence");
  assert(imported?.parsed?.methodology?.stage === "session_parser_v2", "session parser stage regression");
  assert(imported?.parsed?.hunt_analyse?.duration_seconds === 5400, "session duration parse regression");
  assert(imported?.parsed?.hunt_analyse?.xp_gain === 12000000, "XP Gain parse regression");
  assert(imported?.parsed?.hunt_analyse?.total_kills === 150, "killed monsters parse regression");
  assert(imported?.parsed?.party_hunt?.players?.length === 2, "party player parse regression");
  assert(imported?.parsed?.damage?.incoming_by_element?.length === 2, "input element parse regression");
  assert(imported?.parsed?.damage?.incoming_by_source?.length === 2, "input source parse regression");

  const personalList = await post({
    action: "player_session_list",
    client_id: importClientId,
    limit: 10,
  });
  assert(personalList?.data?.summary?.returned === 1, "private session list regression");
  assert(personalList?.data?.sessions?.[0]?.hunt_name === "Cobra Bastion", "private session hunt name regression");

  const personalDetail = await post({
    action: "player_session_detail",
    client_id: importClientId,
    session_id: importedSessionId,
  });
  assert(personalDetail?.data?.hunt_analyse?.xp_per_hour === 8000000, "private detail XP/h regression");
  assert(personalDetail?.data?.party_hunt?.players?.length === 2, "private detail party regression");
  assert(personalDetail?.data?.parser?.community_evidence_written === false, "private detail community isolation regression");
} finally {
  if (importedSessionId) {
    const deleted = await post({
      action: "player_session_delete",
      client_id: importClientId,
      session_id: importedSessionId,
    });
    assert(deleted?.data?.deleted === true, "private smoke session cleanup regression");
  }
}

const profileContract = await post({
  action: "profile_contract",
  vocation: "EK",
});
assert(
  profileContract?.data?.stage === "character_combat_profile_contract_v2",
  "character profile contract stage regression",
);
const ekFamilies =
  profileContract?.data?.vocation_specific?.weapon_family?.values ?? [];
assert(
  JSON.stringify(ekFamilies) === JSON.stringify(["sword", "axe", "club"]),
  `unexpected EK weapon families: ${JSON.stringify(ekFamilies)}`,
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
  first?.imbuement_candidates?.methodology?.stage ===
    "imbuement_candidates_v2",
  "imbuement candidate stage regression",
);
assert(
  first?.imbuement_candidates?.methodology
    ?.community_observed_usage_affects_priority === false,
  "community imbuement evidence must not affect priority",
);
assert(
  Array.isArray(first?.imbuement_candidates?.community_observed_usage),
  "community_observed_usage must be an array",
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

const profiledRecommendation = await post({
  action: "recommend",
  vocation: "EK",
  level: 700,
  objective: "xp",
  party_size: 1,
  limit: 1,
  defensive_items_per_slot: 3,
  character_profile: {
    weapon_family: "sword",
    effective_weapon_skill: 120,
    effective_magic_level: 12,
    effective_shielding: 110,
  },
  one_hand_active_perk_orders: [],
  two_hand_active_perk_orders: [],
  proficiency_selections: {
    "grand-sanguine-blade": [1, 3, 10, 12, 15],
    "grand-sanguine-razor": [1, 2, 10, 12, 15],
  },
});

assert(
  profiledRecommendation?.data?.methodology?.stage ===
    "recommendation_preview_contextual_v4",
  "contextual recommendation stage regression",
);
assert(
  profiledRecommendation?.data?.methodology?.base_stage ===
    "recommendation_preview_profiled_v2",
  "contextual recommendation base stage regression",
);
assert(
  profiledRecommendation?.data?.methodology?.character_profile_applied === true,
  "character profile must be applied",
);

const profiledSet =
  profiledRecommendation?.data?.results?.[0]?.loadout_set_preview;
assert(profiledSet, "profiled loadout set missing");
assert(
  profiledSet?.methodology?.stage === "loadout_set_preview_profiled_v2",
  "profiled loadout stage regression",
);
assert(
  profiledSet?.hand_analysis?.methodology?.stage ===
    "ek_hand_options_profiled_v2",
  "profiled EK hand model regression",
);
assert(
  profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
    ?.one_handed?.methodology?.stage === "weapon_proficiency_impact_preview_v2" &&
  profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
    ?.two_handed?.methodology?.stage === "weapon_proficiency_impact_preview_v2",
  "contextual recommendation actual weapon proficiency payload regression",
);
assert(
  profiledRecommendation?.data?.results?.[0]?.hand_context_comparison?.methodology?.stage ===
    "ek_hand_context_comparison_v1",
  "embedded hand context stage regression",
);
assert(
  profiledRecommendation?.data?.results?.[0]?.hand_context_comparison?.methodology
    ?.optimizer_effect_applied === false,
  "embedded hand context must not alter optimizer",
);
assert(
  profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
    ?.selection_binding?.one_handed_applied_to_actual_item === true,
  "top result one-hand proficiency binding regression",
);
assert(
  profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
    ?.selection_binding?.two_handed_applied_to_actual_item === true,
  "top result two-hand proficiency binding regression",
);
assert(
  profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
    ?.selection_binding?.one_handed_selection_source === "item_key" &&
  profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
    ?.selection_binding?.two_handed_selection_source === "item_key",
  "top result proficiency selection source must be item_key",
);
assert(
  profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
    ?.methodology?.stage === "weapon_proficiency_pair_for_items_v2",
  "actual weapon proficiency pair stage regression",
);
assert(
  Array.isArray(
    profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
      ?.one_handed_reference?.perks,
  ) &&
  profiledRecommendation.data.results[0].actual_weapon_proficiency
    .one_handed_reference.perks.length > 0,
  "one-hand full proficiency tree missing",
);
assert(
  Array.isArray(
    profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
      ?.two_handed_reference?.perks,
  ) &&
  profiledRecommendation.data.results[0].actual_weapon_proficiency
    .two_handed_reference.perks.length > 0,
  "two-hand full proficiency tree missing",
);

const oneHandType =
  profiledSet?.hand_options?.one_handed?.main_hand?.weapon_type?.toLowerCase();
const twoHandType =
  profiledSet?.hand_options?.two_handed?.item?.weapon_type?.toLowerCase();
assert(oneHandType === "sword", `expected sword one-hand, got ${oneHandType}`);
assert(twoHandType === "sword", `expected sword two-hand, got ${twoHandType}`);
assert(
  profiledSet?.hand_analysis?.one_handed?.offense_options?.[0]
    ?.displayed_effective_weapon_skill === 120,
  "expected one-hand displayed skill 120",
);
assert(
  profiledSet?.hand_analysis?.two_handed?.offense_options?.[0]
    ?.displayed_effective_weapon_skill === 120,
  "expected two-hand displayed skill 120",
);
assert(
  profiledSet?.hand_analysis?.one_handed?.offense_options?.[0]
    ?.matching_weapon_skill_bonus === 7,
  "expected one-hand candidate skill bonus 7",
);
assert(
  profiledSet?.hand_analysis?.two_handed?.offense_options?.[0]
    ?.weapon_skill_bonus === 4,
  "expected two-hand candidate skill bonus 4",
);

const proficiencyReference = await post({
  action: "proficiency_preview",
  weapon_family: "sword",
  one_hand_active_perk_orders: [],
  two_hand_active_perk_orders: [],
});
assert(
  proficiencyReference?.data?.methodology?.stage ===
    "ek_weapon_proficiency_comparison_v1",
  "proficiency preview stage regression",
);
assert(
  proficiencyReference?.data?.one_handed?.selection?.mode === "reference_only",
  "proficiency reference mode regression",
);
assert(
  proficiencyReference?.data?.methodology?.optimizer_effect_applied === false,
  "proficiency preview must not affect optimizer",
);

const proficiencyActive = await post({
  action: "proficiency_preview",
  weapon_family: "sword",
  one_hand_active_perk_orders: [1, 4, 12, 15],
  two_hand_active_perk_orders: [1, 3, 12, 15],
  effective_weapon_skill: 120,
});
assert(
  proficiencyActive?.data?.one_handed?.selection?.active_perk_count === 4,
  "one-hand active proficiency count regression",
);
assert(
  proficiencyActive?.data?.two_handed?.selection?.active_perk_count === 4,
  "two-hand active proficiency count regression",
);
assert(
  proficiencyActive?.data?.impact?.methodology?.stage ===
    "ek_weapon_proficiency_impact_comparison_v1",
  "proficiency impact stage regression",
);
assert(
  proficiencyActive?.data?.impact?.methodology?.optimizer_effect_applied === false,
  "proficiency impact must not affect optimizer",
);
assert(
  proficiencyActive?.data?.impact?.one_handed?.impact_vector
    ?.displayed_effective_weapon_skill === 120,
  "displayed effective skill regression",
);
assert(
  proficiencyActive?.data?.impact?.one_handed?.impact_vector
    ?.flat_skill_bonus_applied_to_displayed_skill === false,
  "proficiency skill bonus must not be double counted",
);

const handContextBatch = await post({
  action: "hand_context_batch",
  hunt_keys: ["cobra-bastion"],
  level: 700,
  character_profile: {
    weapon_family: "sword",
    effective_weapon_skill: 120,
    effective_magic_level: 12,
    effective_shielding: 110,
  },
  one_hand_active_perk_orders: [1, 3, 10, 12, 15],
  two_hand_active_perk_orders: [1, 2, 10, 12, 15],
});
assert(
  handContextBatch?.data?.methodology?.stage === "ek_hand_context_batch_v1",
  "hand context batch stage regression",
);
const cobraContext = handContextBatch?.data?.items?.["cobra-bastion"];
assert(cobraContext, "cobra-bastion hand context missing");
assert(
  cobraContext?.methodology?.stage === "ek_hand_context_comparison_v1",
  "hand context comparison stage regression",
);
assert(
  cobraContext?.methodology?.optimizer_effect_applied === false,
  "hand context must not alter optimizer",
);
assert(
  cobraContext?.one_handed?.base_vector?.displayed_effective_weapon_skill === 120 &&
  cobraContext?.two_handed?.base_vector?.displayed_effective_weapon_skill === 120,
  "hand context displayed skill double-count regression",
);
assert(
  cobraContext?.one_handed?.base_vector?.candidate_item_skill_bonus === 7 &&
  cobraContext?.two_handed?.base_vector?.candidate_item_skill_bonus === 4,
  "hand context candidate item skill bonus regression",
);
assert(
  cobraContext?.comparison?.dimension_summary?.comparable_dimensions >= 4,
  "hand context expected comparable dimensions",
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
      private_session_import: "ok",
      top_hunt: first.ranking.hunt_name,
      ranking_score: first.ranking.ranking_score,
      confidence_score: first.ranking.confidence_score,
      one_hand:
        first.loadout_set_preview?.hand_options?.one_handed?.main_hand?.name,
      two_hand:
        first.loadout_set_preview?.hand_options?.two_handed?.item?.name,
      contextual_stage: profiledRecommendation.data.methodology.stage,
      profiled_one_hand:
        profiledSet?.hand_options?.one_handed?.main_hand?.name,
      profiled_two_hand:
        profiledSet?.hand_options?.two_handed?.item?.name,
      proficiency_stage: proficiencyReference.data.methodology.stage,
      proficiency_one_active:
        proficiencyActive.data.one_handed.selection.active_perk_count,
      proficiency_two_active:
        proficiencyActive.data.two_handed.selection.active_perk_count,
      magma_blocked: magma.data.readiness.final_build_blocked,
    },
    null,
    2,
  ),
);
