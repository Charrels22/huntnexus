import assert from "node:assert/strict";
import { parseSessionImport } from "../web/app/src/lib/session-parser.ts";
import { canonicalSpriteFileName } from "../web/app/src/lib/canonical-sprite-url.ts";

for (const [duration, seconds] of [["02:03h",7380],["02:03",7380],["2:03:05",7385],["2h 03m",7380]]) {
  const output = parseSessionImport({hunt:"Session: "+duration+"\nXP Gain: 16,526,550"});
  assert.equal(output.hunt_analyse.duration_seconds, seconds);
}
const range=parseSessionImport({hunt:"Session data: From 2026-10-12, 10:11:00 to 2026-10-12, 12:14:00\nXP Gain: 16,526,550"});
assert.equal(range.hunt_analyse.duration_seconds,7380);
const invalid=parseSessionImport({hunt:"Session: 02:90h\nXP Gain: 10,000"});
assert.equal(invalid.hunt_analyse.duration_seconds,null);
assert.ok(invalid.validation.warnings.includes("invalid_duration_format"));
const noInput=parseSessionImport({hunt:"Session: 02:03h\nXP Gain: 16,526,550"});
assert.equal(noInput.damage.incoming_total_damage,null);
assert.equal(noInput.misc.combat_stats.length,0);
const loot=[
  ["blue crystal shard","Blue_Crystal_Shard.gif"],
  ["blue crystal splinter","Blue_Crystal_Splinter.gif"],
  ["blue gem","Blue_Gem.gif"],
  ["collar of green plasma","Collar_of_Green_Plasma.gif"],
  ["collar of orange plasma","Collar_of_Orange_Plasma.gif"],
  ["collar of red plasma","Collar_of_Red_Plasma.gif"],
];
for(const [input,expected] of loot) assert.equal(canonicalSpriteFileName(input),expected);
console.log(JSON.stringify({status:"ok",stage:"fe32-session-import",durations:4,loot_assets:6,real_player_data_used:false}));
