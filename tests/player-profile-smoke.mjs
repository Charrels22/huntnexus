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

assert(catalog?.data?.methodology?.stage === "player_profile_proficiency_catalog_v1", "catalog stage regression");
assert(Number(catalog?.data?.summary?.eligible_tree_count) >= 4, "MS 655 wand tree coverage regression");
assert(
  catalog?.data?.trees?.some((tree) => tree.item_key === "amber-wand" && tree.eligible === true),
  "Amber Wand tree regression",
);

console.log(JSON.stringify({
  status: "ok",
  stage: "player_profile_public_smoke",
  vocation: loaded.data.profile.vocation,
  level: loaded.data.profile.level,
  eligible_wand_trees: catalog.data.summary.eligible_tree_count,
  amber_selection: loaded.data.profile.proficiency_selections["amber-wand"],
}, null, 2));
