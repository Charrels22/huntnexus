// FE-22: attributed, short fragments copied from public, player-published
// Hunt/Party analyzers. Not complete user exports and not RubinOT signoff.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { detectAnalyzerType, parseSessionImport } from "../web/app/src/lib/session-parser.ts";

const fixture = JSON.parse(readFileSync(
  new URL("./fixtures/fe22-online-original-analyzer-excerpts.json", import.meta.url), "utf8"
));
assert.equal(fixture.complete_raw_analyzers, 0);
assert.equal(fixture.contains_private_sessions, false);
assert.equal(fixture.provenance_tier, "C");
assert.equal(fixture.vocations.length, 5);
assert.deepEqual(fixture.vocations.map(x => x.vocation).sort(), ["ED","EK","EM","MS","RP"]);

const results = [];
for (const sample of fixture.vocations) {
  assert.match(sample.source_url, /^https:\/\/(www\.)?(reddit\.com|hunt-analyser\.com)\//,
    "Fixture source must link to actual public community publication");
  const block = detectAnalyzerType(sample.excerpt);
  assert.equal(block, sample.block, sample.vocation + " real excerpt type classification");
  const parsed = parseSessionImport({ [block]: sample.excerpt });
  assert.equal(parsed.methodology.raw_blocks_preserved, true);
  assert.equal(parsed.methodology.community_evidence_written, false);
  assert.equal(parsed.methodology.unknown_values_invented, false);
  for (const [field, expected] of Object.entries(sample.expected)) {
    assert.equal(parsed.hunt_analyse[field], expected,
      sample.vocation + " source excerpt must not rewrite " + field);
  }
  assert.equal(parsed.hunt_analyse.total_kills, null,
    sample.vocation + " missing Killed Monsters section must remain unknown");
  assert.equal(parsed.hunt_analyse.total_damage, null,
    sample.vocation + " missing Damage must remain unknown");
  assert.equal(parsed.validation.warnings.some(w => w.startsWith("invalid_numeric_format:")), false,
    sample.vocation + " valid original numeric syntax");
  if (sample.vocation === "RP") {
    assert.equal(parsed.hunt_analyse.raw_xp_per_hour, 0,
      "Explicit player-published 0 must not be replaced with inferred XP/h");
    assert.equal(parsed.hunt_analyse.xp_per_hour, 0,
      "Player-published 0 is an observed value, not a missing metric");
  }
  if (sample.vocation === "ED") {
    assert.equal(parsed.hunt_analyse.loot_value, 0,
      "Explicitly observed zero Loot must remain 0");
  }
  if (sample.vocation === "EM") {
    assert.equal(parsed.party_hunt.totals.loot_type_raw, "Leader",
      "Party leader loot mode must remain explicit");
    assert.equal(parsed.party_hunt.totals.loot_value, 4471286);
    assert.equal(parsed.party_hunt.players.length, 0,
      "Short party header excerpt does not contain player-level metrics");
    assert.equal(parsed.availability.party_hunt, false,
      "An excerpt of a party header is not a full party-participant analyzer");
    assert.equal(parsed.hunt_analyse.xp_gain, null,
      "Unreported XP on the party excerpt must not be fabricated as 0");
  }
  results.push({
    vocation: sample.vocation, block,
    source_url: sample.source_url,
    fields_verified: Object.keys(sample.expected),
    full_raw_analyzer_available: false,
    original_player_report_excerpt: true,
    run_server: "not_verified_RubinOT",
  });
}
console.log(JSON.stringify({
  status: "ok",
  stage: "five_vocation_online_original_excerpts_v1",
  cases: results.length,
  full_raw_tibian_analyzers_stored: 0,
  human_rubinot_qa_completed: false,
  results,
}, null, 2));
