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
let sessionId = null;

try {
  const imported = await post({
    action: "session_import_save",
    client_id: clientId,
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
      observation: "dedicated import smoke",
      tags: ["smoke"],
      type: "normal",
      favorite: false,
      publishHighscores: false,
      rareDrops: "",
    },
  });

  sessionId = imported?.data?.session_id;
  assert(sessionId, "session_id missing");
  assert(imported?.data?.status === "parsed", "expected parsed status");
  assert(imported?.data?.community_evidence_written === false, "private import leaked to community evidence");

  const parsed = imported?.parsed;
  assert(parsed?.methodology?.stage === "session_parser_v1", "parser stage regression");
  assert(parsed?.hunt_analyse?.duration_seconds === 5400, "duration parse regression");
  assert(parsed?.hunt_analyse?.xp_gain === 12000000, "XP parse regression");
  assert(parsed?.hunt_analyse?.xp_per_hour === 8000000, "XP/h parse regression");
  assert(parsed?.hunt_analyse?.total_kills === 150, "kill parse regression");
  assert(parsed?.party_hunt?.players?.length === 2, "party parse regression");
  assert(parsed?.damage?.incoming_by_element?.length === 2, "element damage parse regression");
  assert(parsed?.damage?.incoming_by_source?.length === 2, "damage source parse regression");
  assert(parsed?.misc?.combat_stats?.length === 2, "misc parse regression");

  const list = await post({
    action: "player_session_list",
    client_id: clientId,
    limit: 10,
  });
  assert(list?.data?.summary?.returned === 1, "private list regression");
  assert(list?.data?.sessions?.[0]?.hunt_name === "Cobra Bastion", "hunt metadata regression");

  const detail = await post({
    action: "player_session_detail",
    client_id: clientId,
    session_id: sessionId,
  });
  assert(detail?.data?.hunt_analyse?.xp_gain === 12000000, "detail hunt analyse regression");
  assert(detail?.data?.party_hunt?.players?.length === 2, "detail party regression");
  assert(detail?.data?.parser?.community_evidence_written === false, "detail privacy regression");

  console.log(JSON.stringify({
    status: "ok",
    stage: "player_session_import_public_smoke",
    parser: parsed.methodology.stage,
    kills: parsed.hunt_analyse.total_kills,
    party_players: parsed.party_hunt.players.length,
    damage_elements: parsed.damage.incoming_by_element.length,
    damage_sources: parsed.damage.incoming_by_source.length,
  }, null, 2));
} finally {
  if (sessionId) {
    const deleted = await post({
      action: "player_session_delete",
      client_id: clientId,
      session_id: sessionId,
    });
    assert(deleted?.data?.deleted === true, "smoke cleanup regression");
  }
}
