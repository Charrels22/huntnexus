import assert from "node:assert/strict";
import { parseSessionImport } from "../web/app/src/lib/session-parser.ts";
import { buildSessionReparseReview } from "../web/app/src/lib/session-reparse-review.ts";

const original={
  hunt:"Session: 02:03h\nXP Gain: 16,526,550\nXP/h: 8,031,558\nDamage: 3,510,000\nLoot: 867,000\nBalance: 727,000",
  input:"",misc:"",party:"",
};
const next=parseSessionImport(original);
const before={
  hunt_analyse:{...next.hunt_analyse,duration_seconds:null},
  misc:next.misc,damage:next.damage,party_hunt:next.party_hunt,
  availability:next.availability,validation:next.validation,
  methodology:{stage:"session_parser_v1"},
  metadata:{rare_drops_raw:"private data never sent to browser"},
};
const review=buildSessionReparseReview(before,next,"session_parser_v1");
assert.ok(review.changed);
assert.ok(review.safe_to_apply);
assert.equal(review.changes.length,1);
assert.equal(review.changes[0].key,"hunt_analyse.duration_seconds");
assert.equal(review.changes[0].before,null);
assert.equal(review.changes[0].after,7380);
assert.equal(review.changes[0].regression,false);
assert.equal(review.no_raw_text_exposed,true);
assert.ok(!JSON.stringify(review).includes("private data never sent to browser"));

const same=buildSessionReparseReview(next,next,"session_parser_v2");
assert.equal(same.changed,false);
assert.equal(same.safe_to_apply,false);
const downgrade={
  ...next,
  hunt_analyse:{...next.hunt_analyse,duration_seconds:null,xp_gain:null},
  misc:{...next.misc,looted_items:[]},
  validation:{...next.validation,warnings:["invalid_duration_format"]},
};
const negative=buildSessionReparseReview(next,downgrade,"session_parser_v2");
assert.equal(negative.safe_to_apply,false);
assert.ok(negative.regression_reasons.some(x=>x.includes("Duração")));
assert.ok(negative.regression_reasons.some(x=>x.includes("XP total")));
assert.ok(negative.regression_reasons.some(x=>x.includes("Novo alerta")));
const noInput=parseSessionImport({hunt:"XP Gain: 1,000"});
const lostInput=buildSessionReparseReview(
  {...next,damage:{...next.damage,incoming_by_element:[{element:"fire"}]}},
  noInput,"session_parser_v1",
);
assert.equal(lostInput.safe_to_apply,false);
assert.ok(lostInput.regression_reasons.some(x=>x.includes("Elementos recebidos")));
console.log(JSON.stringify({
 status:"ok",stage:"fe34_session_reparse_review",
 safe_duration_recovery:true,
 prevents_loss_of_observed_metrics:true,
 prevents_loss_of_source_row_counts:true,
 prevents_new_parser_warning:true,
 no_changes_blocks_apply:true,
 private_text_not_exposed:true,
 existing_user_sessions_accessed:false,
},null,2));
