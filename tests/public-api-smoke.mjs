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
  one_hand_active_perk_orders: [1, 3, 10, 12, 15],
  two_hand_active_perk_orders: [1, 2, 10, 12, 15],
});

assert(
  profiledRecommendation?.data?.methodology?.stage ===
    "recommendation_preview_contextual_v3",
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
    ?.one_handed?.methodology?.stage === "weapon_proficiency_impact_preview_v1" &&
  profiledRecommendation?.data?.results?.[0]?.actual_weapon_proficiency
    ?.two_handed?.methodology?.stage === "weapon_proficiency_impact_preview_v1",
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
