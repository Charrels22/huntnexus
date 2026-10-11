// Regression: Session Analyzer must never turn missing fields into observed zeroes.
// All input is SYNTHETIC and isolated from the community evidence pipeline.
import assert from "node:assert/strict";
import { detectAnalyzerType, parseSessionImport } from "../web/app/src/lib/session-parser.ts";

const hunt = [
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
  "3x a cobra crest",
].join("\n");

assert.equal(detectAnalyzerType(hunt), "hunt");
const complete = parseSessionImport({ hunt });
assert.equal(complete.methodology.stage, "session_parser_v2");
assert.equal(complete.methodology.community_evidence_written, false);
assert.equal(complete.hunt_analyse.duration_seconds, 5400);
assert.equal(complete.hunt_analyse.xp_gain, 12000000);
assert.equal(complete.hunt_analyse.total_kills, 150);
assert.equal(complete.misc.looted_items[0]?.amount, 3);
assert.equal(complete.hunt_analyse.raw_xp_per_hour, null);
assert.equal(complete.damage.incoming_total_damage, null);
assert.equal(complete.damage.charm_damage_status, "not_observed");

const omittedKills = parseSessionImport({ hunt: "Session: 01:30h\nXP Gain: 12,000,000" });
assert.equal(omittedKills.hunt_analyse.total_kills, null, "missing kill section is unknown, not zero");
assert.equal(omittedKills.hunt_analyse.balance_value, null, "missing balance is unknown");
assert.equal(omittedKills.hunt_analyse.raw_xp_gain, null, "missing raw XP must stay unknown");

const emptyKills = parseSessionImport({ hunt: "Session: 00:30h\nXP Gain: 10,000\nKilled Monsters:\nLooted Items:" });
assert.equal(emptyKills.hunt_analyse.total_kills, 0, "explicitly empty kills may be zero");

const party = [
  "Session: 01:30h",
  "Session data: From 2026-10-10, 10:00:00 to 2026-10-10, 11:30:00",
  "Loot Type: Leader",
  "Smoke One (Leader)",
  "Loot: 1,000,000",
  "Damage: 3,500,000",
  "Healing: 700,000",
  "Smoke Two",
  "Loot: 500,000",
  "Damage: 2,500,000",
].join("\n");
const partyImport = parseSessionImport({ hunt, party });
assert.equal(partyImport.party_hunt.players.length, 2);
assert.equal(partyImport.party_hunt.players[1]?.healing, null, "unreported player healing is unknown");
assert.equal(partyImport.party_hunt.totals.total_healing, null, "unreported party healing total is unknown");
assert.equal(partyImport.availability.party_hunt, true);

const input = parseSessionImport({
  hunt,
  input: "Total: 200,000\nMax-DPS: 3,250\nDamage Types:\nphysical: 120,000 (60%)\nfire: 80,000 (40%)",
});
assert.equal(input.damage.incoming_total_damage, 200000);
assert.equal(input.damage.incoming_max_dps, 3250);
assert.equal(input.damage.incoming_by_element.length, 2);
assert.equal(input.damage.incoming_by_element[0]?.share_percent, 60);

const explicitCharm = parseSessionImport({ hunt, misc: "Charm Damage: 250,000\nCharm Damage/h: 500,000" });
assert.equal(explicitCharm.damage.charm_damage_total, 250000);
assert.equal(explicitCharm.damage.charm_damage_per_hour, 500000);
assert.equal(explicitCharm.damage.charm_damage_status, "observed");

const garbage = parseSessionImport({ hunt: "arbitrary unrecognized text" });
assert.equal(garbage.validation.recognized_metric_count, 0);
assert.equal(garbage.availability.hunt_analyse, false);
assert.ok(garbage.validation.warnings.includes("no_primary_metrics_recognized"));


const groupedFormats = parseSessionImport({
  hunt: "Session: 00:30h\nXP Gain: 1.234.567\nLoot: 2,500,000\nSupplies: -30 000",
});
assert.equal(groupedFormats.hunt_analyse.xp_gain, 1234567, "dot thousands formatting");
assert.equal(groupedFormats.hunt_analyse.loot_value, 2500000, "comma thousands formatting");
assert.equal(groupedFormats.hunt_analyse.supplies_value, -30000, "signed spaced thousands formatting");

const ambiguousNumbers = parseSessionImport({
  hunt: "Session: 00:30h\nXP Gain: 1.2kk\nLoot: 2.5M\nSupplies: 1,00\nDamage: 9e12",
});
assert.equal(ambiguousNumbers.hunt_analyse.xp_gain, null, "malformed XP must not become 12");
assert.equal(ambiguousNumbers.hunt_analyse.loot_value, null, "abbreviated Loot must not become 25");
assert.equal(ambiguousNumbers.hunt_analyse.supplies_value, null, "ambiguous grouping must not become 100");
assert.equal(ambiguousNumbers.hunt_analyse.total_damage, null, "scientific notation is unsupported, must not become 912");
assert.ok(ambiguousNumbers.validation.recognized_metric_count > 0, "valid duration remains observed");

console.log(JSON.stringify({
  status: "ok",
  stage: "session_parser_contract_v3",
  fixture: "SYNTHETIC",
  checks: ["canonical", "unknown_vs_zero", "party_partial", "input", "charm_provenance", "garbage"],
}));
