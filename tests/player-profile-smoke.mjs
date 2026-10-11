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

const clientId = crypto.randomUUID();

try {
const saved = await post({
  action: "player_profile_save",
  client_id: clientId,
  profile: {
    character_name: "Profile Smoke",
    world_name: "Elysian",
    vocation: "MS",
    level: "655",
    online: null,
    former_names: [],
    official_lookup_at: null,
    official_lookup_status: null,
    manual_stats: {
      weapon_family: "wand",
      magic_level: 110,
      effective_magic_level: 112,
    },
    proficiency_selections: {
      "amber-wand": [1, 3, 9],
    },
    defaults: {
      hunt_objective: "balanced",
      set_objective: "offense",
      party_size: 1,
    },
  },
});

assert(saved?.data?.saved === true, "profile save regression");

const loaded = await post({
  action: "player_profile_get",
  client_id: clientId,
});

assert(loaded?.data?.exists === true, "profile get regression");
assert(loaded?.data?.profile?.vocation === "MS", "profile vocation regression");
assert(loaded?.data?.profile?.level === 655, "profile level regression");
assert(
  JSON.stringify(loaded?.data?.profile?.proficiency_selections?.["amber-wand"]) === JSON.stringify([1, 3, 9]),
  "profile proficiency persistence regression",
);

const catalog = await post({
  action: "player_profile_proficiency_catalog",
  vocation: "MS",
  level: 655,
  weapon_family: "wand",
});

assert(catalog?.data?.methodology?.stage === "player_profile_proficiency_catalog_v2", "catalog stage regression");
assert(Number(catalog?.data?.summary?.source_backed_topology_count) >= 4, "source-backed topology coverage regression");
assert(Number(catalog?.data?.summary?.eligible_tree_count) >= 4, "MS 655 wand tree coverage regression");
assert(
  catalog?.data?.trees?.some((tree) => tree.item_key === "amber-wand" && tree.eligible === true),
  "Amber Wand tree regression",
);

const soulTree = catalog?.data?.trees?.find((tree) => tree.item_key === "soultainter");
assert(soulTree?.topology_status === "source_backed_level_position", "Soultainter topology status regression");
assert(soulTree?.topology_source?.profile_name === "Soul 1H Wand", "Soultainter topology source regression");
assert(
  soulTree?.perks?.some((perk) => perk.perk_order === 14 && perk.level_number === 7 && perk.position_in_level === 1),
  "Soultainter final level topology regression",
);

const eldritchTree = catalog?.data?.trees?.find((tree) => tree.item_key === "eldritch-wand");
assert(eldritchTree?.levels_declared === 5, "Eldritch Wand level count regression");

const conflictingTree = catalog.data.trees.find((tree) =>
  tree.topology_status === "source_backed_level_position" &&
  tree.eligible === true &&
  Array.isArray(tree.perks) &&
  tree.perks.some((perk) =>
    perk.level_number != null &&
    tree.perks.some((other) => other.perk_order !== perk.perk_order && other.level_number === perk.level_number)
  )
);
assert(conflictingTree, "no eligible source-backed proficiency tree with multiple choices");
const conflictingPerks = conflictingTree.perks.filter(
  (perk) => perk.level_number != null &&
    conflictingTree.perks.filter((p) => p.level_number === perk.level_number).length > 1
).slice(0, 2);
assert(conflictingPerks.length === 2 && conflictingPerks[0].level_number === conflictingPerks[1].level_number,
  "unable to select two perks from the same known level");
const rejected = await post({
  action: "player_profile_save",
  client_id: clientId,
  profile: {
    character_name: "Profile Smoke",
    world_name: "Elysian",
    vocation: "MS",
    level: "655",
    proficiency_selections: {
      [conflictingTree.item_key]: conflictingPerks.map((perk) => perk.perk_order),
    },
  },
});
assert(rejected?.data?.saved === false, "same-level perks must be rejected");
assert(rejected?.data?.error === "invalid_proficiency_selections", "expected actionable validation error");
assert(rejected?.data?.validation?.issues?.some(
  (issue) => issue.item_key === conflictingTree.item_key &&
    issue.level_number === conflictingPerks[0].level_number
), "validation should identify the conflicting weapon and level");
const afterRejected = await post({ action: "player_profile_get", client_id: clientId });
assert(
  JSON.stringify(afterRejected?.data?.profile?.proficiency_selections?.["amber-wand"]) === JSON.stringify([1, 3, 9]),
  "rejected perks must not mutate previously saved profile",
);

console.log(JSON.stringify({
  status: "ok",
  stage: "player_profile_public_smoke",
  vocation: loaded.data.profile.vocation,
  level: loaded.data.profile.level,
  eligible_wand_trees: catalog.data.summary.eligible_tree_count,
  amber_selection: loaded.data.profile.proficiency_selections["amber-wand"],
}, null, 2));
} finally {
  const deleted = await post({
    action: "player_profile_delete",
    client_id: clientId,
  });
  assert(deleted?.data?.deleted === true, "profile smoke cleanup regression");
}
