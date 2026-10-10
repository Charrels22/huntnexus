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

  const personalizedPlanner = await post({
    action: "final_optimizer",
    client_id: clientId,
    vocation: "MS",
    level: 655,
    hunt_objective: "balanced",
    set_objective: "offense",
    party_size: 1,
    hunt_limit: 1,
    hand_per_source: 2,
    per_body_slot: 1,
    set_limit: 30,
    frontier_limit: 30,
    selection_limit: 8,
    unlocked_requirement_keys: [],
    proficiency_selections: {
      "soultainter": [1, 3],
      "amber-wand": [1],
    },
    character_profile: {
      weapon_family: "wand",
      effective_magic_level: 110,
    },
  });

  assert(
    personalizedPlanner?.data?.methodology?.stage === "optimizer_final_personalized_api_v1",
    "personalized planner stage regression",
  );
  assert(
    personalizedPlanner?.data?.methodology?.ownership_affects_hunt_rank === false,
    "inventory affected hunt rank",
  );
  assert(
    personalizedPlanner?.data?.results?.[0]?.owned_builds?.methodology?.stage === "player_owned_build_options_v2",
    "planner owned build enrichment regression",
  );
  assert(
    personalizedPlanner?.data?.results?.[0]?.owned_builds?.options?.[0]?.option_type === "main",
    "planner Main option regression",
  );

  const ownedOptions = await post({
    action: "player_owned_build_options",
    client_id: clientId,
    hunt_key: "podzilla",
    vocation: "MS",
    level: 655,
    proficiency_selections: {
      "soultainter": [1, 3],
      "amber-wand": [1],
    },
    character_profile: {
      effective_magic_level: 110,
    },
    option_limit: 3,
  });

  assert(ownedOptions?.data?.methodology?.stage === "player_owned_build_options_v2", "owned build stage regression");
  assert(ownedOptions?.data?.methodology?.main_set_is_option_1 === true, "Main must be option 1");
  assert(ownedOptions?.data?.methodology?.external_items_used_in_owned_options === false, "external item leaked into owned options");
  assert(ownedOptions?.data?.options?.[0]?.option_type === "main", "option 1 type regression");
  assert(ownedOptions?.data?.options?.[0]?.selection?.weapon === "soultainter", "option 1 weapon regression");
  const explainedVariant = (ownedOptions?.data?.options ?? []).find((option) =>
    option.option_type === "owned_variant" &&
    (option.replacement_details ?? []).some((detail) => detail.to_item_key === "amber-wand")
  );
  assert(explainedVariant, "explained Amber Wand variant missing");
  const amberDetail = explainedVariant.replacement_details.find((detail) => detail.to_item_key === "amber-wand");
  assert(amberDetail?.to_context?.item?.item_key === "amber-wand", "Amber Wand explanation item regression");
  assert(
    amberDetail?.to_context?.effect_profile?.groups?.protection?.ice === 6,
    "Amber Wand factual protection explanation regression",
  );
  assert(
    !(ownedOptions?.data?.options ?? []).some((option) =>
      option.option_type === "owned_variant" &&
      Object.values(option.selection ?? {}).some((itemKey) =>
        !["soultainter","amber-wand","spellbook-of-ancient-arcana"].includes(itemKey)
      )
    ),
    "non-owned item leaked into owned build option",
  );

  const ownedVariant = (ownedOptions?.data?.options ?? []).find((option) => option.option_type === "owned_variant");
  if (ownedVariant) {
    const choiceSave = await post({
      action: "player_hunt_build_choice_save",
      client_id: clientId,
      hunt_key: "podzilla",
      vocation: "MS",
      level: 655,
      selection: ownedVariant.selection,
      option_type: "owned_variant",
      replacements: ownedVariant.replacements ?? [],
    });

    assert(choiceSave?.data?.saved === true, "hunt build choice save regression");
    assert(choiceSave?.data?.main_set_mutated === false, "hunt choice mutated Main Set");

    const choiceGet = await post({
      action: "player_hunt_build_choice_get",
      client_id: clientId,
      hunt_key: "podzilla",
      vocation: "MS",
    });

    assert(choiceGet?.data?.exists === true, "hunt build choice get regression");
    assert(
      JSON.stringify(choiceGet?.data?.choice?.selection) === JSON.stringify(ownedVariant.selection),
      "hunt build choice selection regression",
    );

    const inventoryAfterChoice = await post({
      action: "player_inventory_get",
      client_id: clientId,
    });
    assert(
      inventoryAfterChoice?.data?.main_set?.weapon?.item_key === "soultainter",
      "selecting hunt option changed Main Set",
    );

    const choiceDelete = await post({
      action: "player_hunt_build_choice_delete",
      client_id: clientId,
      hunt_key: "podzilla",
      vocation: "MS",
    });
    assert(choiceDelete?.data?.main_set_mutated === false, "hunt choice delete mutated Main Set");
  }

  console.log(JSON.stringify({
    status: "ok",
    stage: "player_inventory_public_smoke",
    main_item: inventory.data.main_set.weapon.item_key,
    backpack_items: inventory.data.summary.backpack_items,
    backpack_frontier_candidates: review.data.summary.backpack_frontier_candidates,
    external_frontier_candidates: review.data.summary.external_frontier_candidates,
    automatic_main_replacement: review.data.methodology.automatic_main_replacement,
    owned_build_options: ownedOptions.data.summary.returned_options,
    discarded_bp_variants: ownedOptions.data.summary.discarded_as_main_dominated,
    hunt_build_choice_tested: Boolean(ownedVariant),
    personalized_planner_stage: personalizedPlanner.data.methodology.stage,
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
