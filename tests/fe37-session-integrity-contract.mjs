import assert from "node:assert/strict";
import {parseSessionImport} from "../web/app/src/lib/session-parser.ts";
import {buildSessionIntegrityReport} from "../web/app/src/lib/session-integrity.ts";

const hunt="Session: 00:30h\nXP Gain: 120,000\nDamage: 800,000";
const complete={
  hunt,
  input:"Total: 12,000\nMax-DPS: 345\nDamage Types:\nFire: 7,000 (58.3%)\nPhysical: 5,000 (41.7%)\nDamage Sources:\nsynthetic spectre: 12,000 (100%)",
  misc:"Session: 00:30h\nCritical Hit: 393\nMana Gain: 1,234",
  party:"",
};
const parsed=parseSessionImport(complete);
const detail=Object.fromEntries([
  "hunt_analyse","misc","damage","party_hunt","availability","validation"
].map(k=>[k,parsed[k]]));
const mk=(rawBlocks,storedParsedData=parsed,sessionDetail=detail,parserVersion="session_parser_v2")=>
  buildSessionIntegrityReport({rawBlocks,storedParsedData,sessionDetail,parserVersion});
const completeAudit=mk(complete);
assert.deepEqual(completeAudit.blocks.map(x=>x.status),["recognized","recognized","recognized","missing"]);
assert.equal(completeAudit.storage_consistency.status,"consistent");
assert.equal(completeAudit.storage_consistency.checked_sections,6);
assert.equal(completeAudit.current_parser_drift.status,"same");
assert.equal(completeAudit.original_blocks_preserved,true);
assert.equal(completeAudit.contains_raw_analyzer_text,false);
assert.equal(completeAudit.requires_real_export_acceptance,true);
assert.ok(!JSON.stringify(completeAudit).includes("synthetic spectre"),
  "Private raw source names must never leave server");
assert.ok(!JSON.stringify(completeAudit).includes("Critical Hit"),
  "Individual stat names must not be returned");

const partialBlocks={hunt,input:"Received Damage Total: 12,000\\nMax-DPS: 345"};
const partialStored=parseSessionImport(partialBlocks);
const sectionKeys=["hunt_analyse","misc","damage","party_hunt","availability","validation"];
const storedDetail=(v)=>Object.fromEntries(sectionKeys.map(k=>[k,v[k]]));
const partialInput=mk(partialBlocks,partialStored,storedDetail(partialStored));
assert.deepEqual(partialInput.blocks.map(x=>x.status),["recognized","partial","missing","missing"]);
const unreadableBlocks={hunt,input:"Damage Types:\\nUnknown Element: 300",
  misc:"Miscellaneous\\nCombat Stats"};
const unreadableStored=parseSessionImport(unreadableBlocks);
const unreadable=mk(unreadableBlocks,unreadableStored,storedDetail(unreadableStored));
assert.equal(unreadable.blocks[1].status,"unrecognized");
assert.equal(unreadable.blocks[2].status,"unrecognized");
assert.equal(unreadable.current_parser_drift.status,"same");
assert.equal(unreadable.storage_consistency.status,"consistent",
  "A correctly stored but unrecognized block must not look like data corruption");
const tampered={
  ...detail,
  damage:{...detail.damage,incoming_total_damage:22000},
};
const mismatch=mk(complete,parsed,tampered);
assert.equal(mismatch.storage_consistency.status,"mismatch");
assert.deepEqual(mismatch.storage_consistency.mismatched_sections,["damage"]);
assert.equal(mismatch.current_parser_drift.status,"same");
const old={
  ...parsed,
  damage:{...parsed.damage,incoming_by_source:[]},
};
const oldDetail={...detail,damage:old.damage};
const drift=mk(complete,old,oldDetail);
assert.equal(drift.storage_consistency.status,"consistent");
assert.equal(drift.current_parser_drift.status,"different");
assert.ok(drift.current_parser_drift.differing_sections.includes("damage"));
assert.equal(drift.current_parser_drift.not_a_persistence_error,true);
const invalidHunt=mk({
  hunt:"garbled non-numeric hunt text",input:"",misc:"",party:"",
},parsed,detail);
assert.equal(invalidHunt.blocks[0].status,"recognized",
  "Block completeness reports what was STORED, not a newly inferred reparse");
assert.equal(invalidHunt.current_parser_drift.status,"different");

console.log(JSON.stringify({
  status:"ok",stage:"fe37_private_session_integrity_contract",
  cases:["all_blocks","partial_input","unrecognized_input_misc","storage_mismatch",
    "parser_drift_is_not_storage_failure","raw_versus_stored_provenance"],
  real_user_data_used:false,raw_session_contents_returned:false,
},null,2));
