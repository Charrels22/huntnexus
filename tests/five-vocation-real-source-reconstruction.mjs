import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { parseSessionImport, detectAnalyzerType } from "../web/app/src/lib/session-parser.ts";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/reconstructed-source-sessions-2026-10-11.json", import.meta.url), "utf8"));
assert.equal(fixture.human_player_analyzer_text_obtained, false,
  "This fixture must NEVER be described as original player-provided Analyzer text");
assert.equal(fixture.reconstruction_intended_only_for_parser_regression, true);
assert.deepEqual(fixture.cases.map((x) => x.vocation).sort(), ["ED","EK","EM","MS","RP"]);
const integerFields = [
  ["XP Gain", "xp_gain"],
  ["XP/h", "xp_per_hour"],
  ["Loot", "loot_value"],
  ["Supplies", "supplies_value"],
  ["Balance", "balance_value"],
  ["Damage", "total_damage"],
  ["Healing", "total_healing"],
];
const results = [];
for (const row of fixture.cases) {
  assert.match(row.source_url, /^https:\/\/www\.hunt-analyser\.com\/hunt_sessions\/\d+$/,
    "Every fixture must link to the public Tier C source used to extract metrics");
  assert.equal(row.duration_seconds % 60, 0, "Reconstructed time must remain minute-exact");
  const duration = Math.floor(row.duration_seconds / 3600).toString().padStart(2, "0") +
    ":" + Math.floor((row.duration_seconds % 3600) / 60).toString().padStart(2, "0") + "h";
  // This text is built FROM REAL PUBLIC METRICS. It is NOT the raw input text
  // actually produced by a player, and never becomes community evidence.
  const reconstructedLines = ["Session: " + duration];
  for (const [label, key] of integerFields) {
    if (row[key] != null) reconstructedLines.push(label + ": " + row[key].toLocaleString("en-US"));
  }
  const reconstructed = reconstructedLines.join("\n");
  assert.equal(detectAnalyzerType(reconstructed), "hunt", row.vocation + ": auto-detection");
  const parsed = parseSessionImport({ hunt: reconstructed });
  assert.equal(parsed.methodology.stage, "session_parser_v2");
  assert.equal(parsed.methodology.community_evidence_written, false);
  assert.equal(parsed.hunt_analyse.duration_seconds, row.duration_seconds);
  assert.equal(parsed.hunt_analyse.party_size, 1);
  assert.equal(parsed.hunt_analyse.total_kills, null,
    row.vocation + ": absent Killed Monsters must NOT become 0");
  for (const [, key] of integerFields) {
    assert.equal(parsed.hunt_analyse[key], row[key], row.vocation + ": " + key + " source reconstruction");
  }
  assert.equal(parsed.validation.warnings.length, 0, row.vocation + ": warnings");
  assert.equal(parsed.validation.recognized_metric_count, 6,
    row.vocation + ": expected duration + XP gain + XP/h + Balance + Damage + Healing");
  const derivedHourly = Math.round(row.xp_gain * 3600 / row.duration_seconds);
  assert.equal(derivedHourly, row.xp_per_hour, row.vocation + ": source rate consistency");
  results.push({
    vocation: row.vocation,
    hunt_key: row.hunt_key,
    source_url: row.source_url,
    source_rate_verified: true,
    numeric_fields_roundtripped: 6,
    human_raw_analyzer_verified: false,
  });
}
console.log(JSON.stringify({
  status: "ok",
  stage: "five_vocation_public_source_numeric_reconstruction_v1",
  source_tier: "C",
  real_public_source_records: fixture.cases.length,
  real_hunt_analyzer_texts: 0,
  original_source_format_claimed: false,
  private_session_data_written: false,
  human_playtest_complete: false,
  results,
}, null, 2));
