// FE-22 live source QA: extract the original Party Hunt Analyzer description
// from the public source page in a disposable browser. NEVER persist names or
// raw third-party text. No player permissions or account credentials used.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { detectAnalyzerType, parseSessionImport } from "../src/lib/session-parser.ts";

const url = "https://www.hunt-analyser.com/hunt_sessions/32789";
const browser = await chromium.launch({headless:true});
try {
  const page = await browser.newPage({ viewport:{width:1360,height:900}});
  const response = await page.goto(url,{waitUntil:"domcontentloaded",timeout:45000});
  assert.ok(response?.ok(), "Public third-party source page unavailable: " + response?.status());
  await page.getByText("Description",{exact:true}).first().waitFor({timeout:12000});
  const raw = await page.locator("body").innerText();
  const match = raw.match(/(?:^|\n)Description\s*\n([\s\S]*?)\n\s*(?:Party Members|Payment Distribution)\b/i);
  assert.ok(match?.[1],"Original party description section not extractable");
  const publishedDescription = match[1].trim();
  assert.ok(publishedDescription.includes("Session data: From 2025-07-14"),
    "Description does not preserve the original Tibia Party analyzer time range");
  assert.equal(detectAnalyzerType(publishedDescription),"party",
    "Original live Party Hunt Analyzer must be recognized as party, not hunt/misc");
  const parsed = parseSessionImport({party:publishedDescription});
  assert.equal(parsed.hunt_analyse.duration_seconds,5760);
  assert.equal(parsed.party_hunt.totals.loot_type_raw,"Leader");
  assert.equal(parsed.party_hunt.totals.loot_value,4471286);
  assert.equal(parsed.party_hunt.totals.supplies_value,2262694);
  assert.equal(parsed.party_hunt.totals.balance_value,2208592);
  assert.equal(parsed.party_hunt.players.length,4,
    "Parser must recover all four members from the full original party input");
  assert.equal(parsed.party_hunt.party_size,4);
  assert.equal(parsed.availability.party_hunt,true);
  const sortedDamages = parsed.party_hunt.players
    .map(player=>player.damage).sort((a,b)=>a-b);
  assert.deepEqual(sortedDamages,[6571966,7047641,8089371,8535923]);
  assert.equal(parsed.party_hunt.players.filter(p=>p.leader===true).length,1);
  assert.ok(parsed.party_hunt.players.some(p=>p.balance<0));
  assert.equal(parsed.hunt_analyse.xp_gain,null,
    "Party text did not include per-character XP; null is required");
  assert.equal(parsed.methodology.community_evidence_written,false);
  assert.equal(parsed.validation.warnings.includes("party_block_present_but_no_players_recognized"),false);
  console.log(JSON.stringify({
    status:"ok",
    stage:"fe22_live_original_public_party_analyzer",
    source_url:url,
    text_origin:"live third-party published complete party description",
    stored_raw_text:false,
    player_names_logged:false,
    player_count:parsed.party_hunt.players.length,
    parsed_duration_seconds:parsed.hunt_analyse.duration_seconds,
    parsed_balance_value:parsed.party_hunt.totals.balance_value,
    per_vocation_individual_performance_claimed:false,
    human_rubinot_homologated:false,
  },null,2));
} finally {
  await browser.close();
}
