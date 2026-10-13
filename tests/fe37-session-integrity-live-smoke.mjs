// FE-37 live private integrity read-only test. Random synthetic guest scope,
// explicit cleanup; no player files, no account binding, no community writes.
import assert from "node:assert/strict";

const endpoint=process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const owner=crypto.randomUUID(),foreign=crypto.randomUUID();
const sessions=[],checks=[];
const hunt="Session: 00:30h\nXP Gain: 120,000\nDamage: 800,000";
async function call(body){
  const response=await fetch(endpoint,{
    method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify({client_id:owner,...body}),signal:AbortSignal.timeout(30000),
  });
  return {http:response.status,...await response.json().catch(()=>({}))};
}
async function create(input,misc){
  const result=await call({
    action:"session_import_save",blocks:{hunt,input,misc,party:""},
    metadata:{
      character:"FE37 SYNTHETIC QA",server:"RubinOT",vocation:"MS",
      level:"100",location:"FE37 synthetic temporary session",
      hunt_key:"",setupMode:"none",observation:"SYNTHETIC; NOT GAMEPLAY",
      tags:["synthetic","fe37"],type:"normal",favorite:false,
      publishHighscores:false,rareDrops:"",
    },
  });
  assert.equal(result.http,200,JSON.stringify(result).slice(0,500));
  const id=result.data?.session_id;assert.ok(id);
  sessions.push(id);return id;
}
try {
  const full=await create(
    "Total: 12,000\nMax-DPS: 345\nDamage Types:\nFire: 7,000 (58.3%)\nPhysical: 5,000 (41.7%)\nDamage Sources:\nsynthetic spectre: 12,000 (100%)",
    "Session: 00:30h\nCritical Hit: 393\nMana Gain: 1,234",
  );
  const fullReport=await call({action:"player_session_integrity_review",session_id:full});
  assert.equal(fullReport.http,200,JSON.stringify(fullReport).slice(0,650));
  const report=fullReport.data;
  assert.equal(report.session_id,full);
  assert.deepEqual(report.blocks.map(x=>x.status),
    ["recognized","recognized","recognized","missing"]);
  assert.equal(report.storage_consistency.status,"consistent");
  assert.equal(report.storage_consistency.checked_sections,6);
  assert.equal(report.current_parser_drift.status,"same");
  assert.equal(report.contains_raw_analyzer_text,false);
  assert.equal(report.original_blocks_preserved,true);
  assert.ok(!JSON.stringify(report).includes("synthetic spectre"));
  assert.ok(!JSON.stringify(report).includes("Critical Hit"));
  assert.ok(!JSON.stringify(report).includes("XP Gain: 120,000"));
  checks.push({case:"complete_original_block_vs_stored_detail_consistent",result:"PASS"});

  const foreignReport=await call({action:"player_session_integrity_review",
    client_id:foreign,session_id:full});
  assert.equal(foreignReport.http,404);
  assert.equal(foreignReport.error,"session_not_found");
  checks.push({case:"unrelated_guest_no_private_integrity_access",result:"PASS"});

  const partial=await create("Received Damage Total: 12,000\nMax-DPS: 345","");
  const partialReport=await call({
    action:"player_session_integrity_review",session_id:partial,
  });
  assert.equal(partialReport.http,200);
  assert.deepEqual(partialReport.data.blocks.map(x=>x.status),
    ["recognized","partial","missing","missing"]);
  assert.equal(partialReport.data.storage_consistency.status,"consistent");
  checks.push({case:"totals_only_input_partial_without_invention",result:"PASS"});

  const malformed=await create(
    "Damage Types:\nUnknown Element: 300","Miscellaneous\nCombat Stats");
  const malformedReport=await call({
    action:"player_session_integrity_review",session_id:malformed,
  });
  assert.equal(malformedReport.http,200);
  assert.deepEqual(malformedReport.data.blocks.map(x=>x.status),
    ["recognized","unrecognized","unrecognized","missing"]);
  assert.equal(malformedReport.data.storage_consistency.status,"consistent");
  checks.push({case:"supplied_but_unrecognized_blocks_flagged",result:"PASS"});
}finally{
  const cleanupErrors=[];
  for(const session_id of sessions){
    try{
      const result=await call({action:"player_session_delete",session_id});
      if(result.http!==200||result.data?.deleted!==true)
        cleanupErrors.push("delete_failure:"+session_id);
    }catch(e){cleanupErrors.push(String(e))}
  }
  assert.deepEqual(cleanupErrors,[],"All synthetic session fixtures must be deleted");
}
console.log(JSON.stringify({
  status:"ok",stage:"fe37_private_session_integrity_live",
  results:checks,synthetic_sessions_created_and_deleted:sessions.length,
  real_player_exports_used:false,real_gameplay_proven:false,
  readonly_integrity_reports:true,
},null,2));
