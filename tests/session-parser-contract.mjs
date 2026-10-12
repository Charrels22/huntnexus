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

const invalidMinutes = parseSessionImport({ hunt: "Session: 01:90h\nXP Gain: 120,000" });
assert.equal(invalidMinutes.hunt_analyse.duration_seconds, null, "90 minutes is invalid");
assert.ok(invalidMinutes.validation.warnings.includes("invalid_duration_format"),
  "invalid duration must produce visible warning");
const trailingDuration = parseSessionImport({ hunt: "Session: 01:30h error\nXP Gain: 120,000" });
assert.equal(trailingDuration.hunt_analyse.duration_seconds, null,
  "duration with trailing arbitrary text must not be accepted");
const validHourMinutes = parseSessionImport({ hunt: "Session: 1h 30m\nXP Gain: 120,000" });
assert.equal(validHourMinutes.hunt_analyse.duration_seconds, 5400,
  "explicit hours/minutes remains supported");
const overflowMinutes = parseSessionImport({ hunt: "Session: 1h 75m\nXP Gain: 120,000" });
assert.equal(overflowMinutes.hunt_analyse.duration_seconds, null,
  "overlong minutes field must not roll into hours");

const partyWithXp = [
  "Session data: From 2026-10-11, 20:00:00 to 2026-10-11, 21:00:00",
  "Session: 01:00h",
  "Loot Type: Leader",
  "XP Gain: 123,456",
  "Private Fixture One (Leader)",
  "Loot: 200,000",
  "Supplies: 50,000",
  "Balance: 150,000",
  "Private Fixture Two",
  "Loot: 100,000",
  "Supplies: 20,000",
].join("\n");
assert.equal(detectAnalyzerType(partyWithXp), "party",
  "Explicit Party Hunt markers must override a generic XP Gain key");
const parsedPartyWithXp = parseSessionImport({party:partyWithXp});
assert.equal(parsedPartyWithXp.party_hunt.party_size, 2);
assert.equal(parsedPartyWithXp.party_hunt.totals.duration_seconds, 3600);
assert.equal(parsedPartyWithXp.party_hunt.players.length, 2);

// FE-23 real-world failure mode: Party totals cannot become a character's
// observed personal balance or damage simply because no Hunt block was pasted.
const partyOnlyBlock = [
  "Session data: From 2026-10-11, 20:00:00 to 2026-10-11, 21:00:00",
  "Session: 01:00h",
  "Loot Type: Leader",
  "Loot: 4,500,000",
  "Supplies: 2,200,000",
  "Balance: 2,300,000",
  "Damage: 9,000,000",
  "Healing: 3,200,000",
  "Fixture Tank (Leader)",
  "Loot: 2,500,000",
  "Supplies: 1,500,000",
  "Balance: 1,000,000",
  "Damage: 6,000,000",
  "Fixture Healer",
  "Loot: 2,000,000",
  "Supplies: 700,000",
  "Balance: 1,300,000",
  "Damage: 3,000,000",
].join("\n");
const isolatedParty = parseSessionImport({party: partyOnlyBlock});
assert.equal(isolatedParty.party_hunt.party_size, 2);
assert.equal(isolatedParty.party_hunt.totals.loot_value, 4500000);
assert.equal(isolatedParty.party_hunt.totals.supplies_value, 2200000);
assert.equal(isolatedParty.party_hunt.totals.balance_value, 2300000);
assert.equal(isolatedParty.party_hunt.totals.total_damage, 9000000);
assert.equal(isolatedParty.party_hunt.totals.total_healing, 3200000);
assert.equal(isolatedParty.party_hunt.totals.duration_seconds, 3600);
assert.equal(isolatedParty.hunt_analyse.duration_seconds, 3600,
  "session duration may be shared, but financial/combat totals must not be");
for (const key of ["loot_value","supplies_value","balance_value","total_damage","total_healing"]) {
  assert.equal(isolatedParty.hunt_analyse[key], null,
    "Team aggregate cannot be attributed to individual: " + key);
}
assert.equal(isolatedParty.damage.total_damage, null);
assert.equal(isolatedParty.availability.hunt_analyse, false);
assert.equal(isolatedParty.availability.party_hunt, true);
assert.ok(isolatedParty.validation.warnings.includes("hunt_analyzer_missing"));

const separateInputs = parseSessionImport({hunt,party:partyOnlyBlock});
assert.equal(separateInputs.hunt_analyse.loot_value,1500000);
assert.equal(separateInputs.hunt_analyse.balance_value,1000000);
assert.equal(separateInputs.hunt_analyse.total_damage,6000000);
assert.equal(separateInputs.party_hunt.totals.loot_value,4500000);
assert.equal(separateInputs.party_hunt.totals.balance_value,2300000);
assert.equal(separateInputs.party_hunt.totals.total_damage,9000000);

// FE-23: numeric transcription from a PUBLIC third-party *Input Damage
// Summary*, NOT the original client clipboard format. Source:
// https://www.hunt-analyser.com/hunt_sessions/2007
// The Tibia client lists Total, Max-DPS, Damage Types and up to five sources.
// Preserve those reported values without inventing the player's raw input.
const sourceLinkedInputSummary = [
  "Received Damage Total: 1,164,196",
  "Max-DPS: 2,276",
  "Damage Types:",
  "Fire: 344,853 (29.6%)",
  "Physical: 323,887 (27.8%)",
  "Life Drain: 278,477 (23.9%)",
  "Holy: 114,403 (9.8%)",
  "Energy: 102,576 (8.8%)",
  "Damage Sources:",
  "gazer spectre: 846,907 (72.7%)",
  "thanatursus: 316,431 (27.2%)",
  "(other): 858 (0.1%)",
].join("\n");
assert.equal(detectAnalyzerType(sourceLinkedInputSummary), "input");
const inputFromPublishedSummary = parseSessionImport({input:sourceLinkedInputSummary});
assert.equal(inputFromPublishedSummary.damage.incoming_total_damage,1164196);
assert.equal(inputFromPublishedSummary.damage.incoming_max_dps,2276);
assert.equal(inputFromPublishedSummary.damage.incoming_by_element.length,5);
assert.equal(inputFromPublishedSummary.damage.incoming_by_source.length,3);
assert.equal(inputFromPublishedSummary.damage.incoming_by_element[0].element,"fire");
assert.equal(inputFromPublishedSummary.damage.incoming_by_element[0].damage,344853);
assert.equal(inputFromPublishedSummary.damage.incoming_by_element[0].share_percent,29.6);
assert.equal(inputFromPublishedSummary.damage.incoming_by_source[0].source_name_raw,"gazer spectre");
assert.equal(inputFromPublishedSummary.damage.incoming_by_source[0].damage,846907);
assert.equal(inputFromPublishedSummary.damage.incoming_by_source[2].damage,858);
assert.equal(inputFromPublishedSummary.hunt_analyse.total_damage,null,
  "incoming damage must NEVER be mistaken for the player's outgoing damage");
assert.equal(inputFromPublishedSummary.availability.hunt_analyse,false);
assert.equal(inputFromPublishedSummary.availability.damage,true);
assert.equal(inputFromPublishedSummary.methodology.community_evidence_written,false);
assert.equal(inputFromPublishedSummary.damage.incoming_by_element.reduce((s,row)=>s+row.damage,0),1164196);
assert.equal(inputFromPublishedSummary.damage.incoming_by_source.reduce((s,row)=>s+row.damage,0),1164196);

console.log(JSON.stringify({
  status: "ok",
  stage: "session_parser_contract_v3",
  fixture: "SYNTHETIC",
  checks: ["canonical", "unknown_vs_zero", "party_partial", "input", "charm_provenance", "garbage"],
}));
