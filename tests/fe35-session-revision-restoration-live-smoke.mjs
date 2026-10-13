// FE-35 public HTTP smoke: ephemeral synthetic guest session only.
// Does not create a revision, alter a player session, or read game exports.
import assert from "node:assert/strict";
const endpoint=process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const owner=crypto.randomUUID();
const other=crypto.randomUUID();
let session_id=null;
async function call(body){
 const response=await fetch(endpoint,{method:"POST",
  headers:{"content-type":"application/json"},
  body:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
 return {http:response.status,...await response.json().catch(()=>({}))};
}
const checks=[];
try {
 const saved=await call({action:"session_import_save",client_id:owner,
  blocks:{hunt:"Session: 00:43h\nXP Gain: 8,600\nXP/h: 12,000",party:"",input:"",misc:""},
  metadata:{character:"FE35 ephemeral fixture",vocation:"MS",level:"100",
   server:"RubinOT",location:"FE35 synthetic",hunt_key:"",setupMode:"none",
   observation:"SYNTHETIC QA",tags:["synthetic"],type:"normal",
   favorite:false,publishHighscores:false,rareDrops:""}});
 assert.equal(saved.http,200,JSON.stringify(saved).slice(0,300));
 session_id=saved.data?.session_id;assert.ok(session_id);
 const denied=await call({action:"player_session_revision_list",client_id:other,session_id});
 assert.equal(denied.http,404);assert.equal(denied.error,"session_not_found");
 checks.push("other_guest_revision_list_denied");
 const list=await call({action:"player_session_revision_list",client_id:owner,session_id});
 assert.equal(list.http,200);
 assert.equal(list.data?.session_id,session_id);
 assert.deepEqual(list.data?.revisions,[]);
 assert.equal(list.data?.raw_blocks,undefined);
 checks.push("owner_empty_revision_list_sanitized");
 const unknown=crypto.randomUUID();
 const previewDenied=await call({action:"player_session_restore_preview",client_id:owner,
  session_id,revision_id:unknown});
 assert.equal(previewDenied.http,404);
 assert.equal(previewDenied.error,"revision_not_found");
 checks.push("unknown_revision_preview_denied");
 const foreignPreview=await call({action:"player_session_restore_preview",client_id:other,
  session_id,revision_id:unknown});
 assert.equal(foreignPreview.http,404);
 checks.push("foreign_revision_preview_denied");
 const restoreDenied=await call({action:"player_session_restore_apply",client_id:owner,
  session_id,revision_id:unknown,expected_fingerprint:"0".repeat(32),
  confirm:true,accept_regressions:true});
 assert.equal(restoreDenied.http,404);
 assert.equal(restoreDenied.error,"revision_not_found");
 checks.push("unrecorded_revision_apply_denied");
 const foreignApply=await call({action:"player_session_restore_apply",client_id:other,
  session_id,revision_id:unknown,expected_fingerprint:"0".repeat(32),
  confirm:true,accept_regressions:true});
 assert.equal(foreignApply.http,404);
 checks.push("foreign_revision_apply_denied");
 const actual=await call({action:"player_session_detail",client_id:owner,session_id});
 assert.equal(actual.http,200);
 assert.equal(actual.data?.hunt_analyse?.duration_seconds,2580);
 assert.equal(actual.data?.loadout_snapshot?.source,"not_recorded");
 checks.push("invalid_attempts_preserved_snapshot_and_metrics");
}finally{
 if(session_id){
  const removed=await call({action:"player_session_delete",client_id:owner,session_id});
  assert.equal(removed.http,200);
  assert.equal(removed.data?.deleted,true);
 }
}
console.log(JSON.stringify({status:"ok",stage:"fe35_private_revision_restore_live_http",
 ephemeral_sessions_created_deleted:1,real_player_exports_used:false,
 authenticated_users_used:false,checks},null,2));
