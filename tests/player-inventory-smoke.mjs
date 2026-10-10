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
let inventoryIds = [];

try {
  const main = await post({
    action: "player_inventory_put",
    client_id: clientId,
    storage_kind: "main",
    item_key: "soultainter",
    quantity: 1,
  });
  assert(main?.data?.saved === true, "main set save regression");
  assert(main?.data?.selection_key === "weapon", "main weapon slot regression");

  const bpWand = await post({
    action: "player_inventory_put",
    client_id: clientId,
    storage_kind: "backpack",
    item_key: "amber-wand",
    quantity: 1,
  });
  assert(bpWand?.data?.saved === true, "backpack wand save regression");

  const bpBook = await post({
    action: "player_inventory_put",
    client_id: clientId,
    storage_kind: "backpack",
    item_key: "spellbook-of-ancient-arcana",
    quantity: 1,
  });
  assert(bpBook?.data?.saved === true, "backpack spellbook save regression");

  const inventory = await post({
    action: "player_inventory_get",
    client_id: clientId,
  });

  assert(inventory?.data?.main_set?.weapon?.item_key === "soultainter", "main set get regression");
  assert(inventory?.data?.summary?.main_slots === 1, "main slot count regression");
  assert(inventory?.data?.summary?.backpack_items === 2, "backpack count regression");
  assert(inventory?.data?.methodology?.main_set_is_baseline === true, "main baseline contract regression");
  assert(inventory?.data?.methodology?.automatic_main_replacement === false, "automatic replacement regression");

  inventoryIds = [
    ...Object.values(inventory?.data?.main_set ?? {}).map((item) => item.inventory_id),
    ...(inventory?.data?.backpack ?? []).map((item) => item.inventory_id),
  ].filter(Boolean);

  const search = await post({
    action: "player_inventory_search",
    vocation: "MS",
    level: 655,
    query: "Soultainter",
    selection_key: "weapon",
    limit: 10,
  });
  assert(search?.data?.items?.some((item) => item.item_key === "soultainter" && item.eligible === true), "inventory search regression");

  const review = await post({
    action: "player_inventory_hunt_review",
    client_id: clientId,
    hunt_key: "podzilla",
    vocation: "MS",
    level: 655,
    proficiency_selections: {
      "soultainter": [1, 3],
      "amber-wand": [1],
    },
    frontier_limit: 12,
  });

  assert(review?.data?.methodology?.stage === "player_inventory_hunt_review_v1", "hunt review stage regression");
  assert(review?.data?.methodology?.main_set_is_baseline === true, "hunt review baseline regression");
  assert(review?.data?.methodology?.automatic_main_replacement === false, "hunt review replacement regression");
  assert(
    review?.data?.frontier_candidates?.some((item) => item.item_key === "amber-wand" && item.ownership === "backpack"),
    "owned frontier classification regression",
  );
  assert(
    review?.data?.frontier_candidates?.some((item) => item.ownership === "external"),
    "external frontier classification regression",
  );

  console.log(JSON.stringify({
    status: "ok",
    stage: "player_inventory_public_smoke",
    main_item: inventory.data.main_set.weapon.item_key,
    backpack_items: inventory.data.summary.backpack_items,
    backpack_frontier_candidates: review.data.summary.backpack_frontier_candidates,
    external_frontier_candidates: review.data.summary.external_frontier_candidates,
    automatic_main_replacement: review.data.methodology.automatic_main_replacement,
  }, null, 2));
} finally {
  for (const inventoryId of inventoryIds) {
    await post({
      action: "player_inventory_remove",
      client_id: clientId,
      inventory_id: inventoryId,
    });
  }
}
