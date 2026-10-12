// FE-33 live API regression with synthetic, private, immediately deleted sessions.
// Does not use legitimate player data or accounts; no community writes.
import assert from "node:assert/strict";

const endpoint=process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const client_id=crypto.randomUUID();
const otherClient=crypto.randomUUID();
const sessions=[];
async function call(body) {
  const response=await fetch(endpoint,{
    method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify({client_id,...body}),signal:AbortSignal.timeout(30000),
  });
  const payload=await response.json().catch(()=>({}));
  return {http:response.status,...payload};
}
const metadata={
  vocation:"MS",level:"700",character:"FE33 synthetic isolated fixture",
  location:"FE33 synthetic (no real hunt)",hunt_key:"",
  observation:"FE33 SYNTHETIC QA ONLY",type:"normal",favorite:false,
  publishHighscores:false,rareDrops:"",tags:["synthetic","fe33"],
};
const blocks={hunt:"Session: 00:30h\nXP Gain: 30,000\nXP/h: 60,000\nDamage: 50,000"};
const result=[];
try {
  for(const [mode,expected] of [
    ["main","session_setup_main_unavailable"],
    ["hunt","session_setup_hunt_required"],
  ]){
    const rsp=await call({action:"session_import_save",blocks,metadata:{...metadata,setupMode:mode}});
    assert.equal(rsp.http,409,`${mode}: expected HTTP 409, got ${rsp.http}: ${JSON.stringify(rsp).slice(0,500)}`);
    assert.equal(rsp.error,expected,`${mode}: unavailable owned loadout must fail before DB insert`);
    result.push({mode,rejected:true,http:409,error:rsp.error});
  }
  const none=await call({action:"session_import_save",blocks,metadata:{...metadata,setupMode:"none"}});
  assert.equal(none.http,200,JSON.stringify(none).slice(0,550));
  assert.ok(none.data?.session_id,"Mode none must create a private session");
  sessions.push(none.data.session_id);
  const detail=await call({action:"player_session_detail",session_id:none.data.session_id});
  assert.equal(detail.http,200);
  assert.equal(detail.data?.loadout_snapshot?.source,"not_recorded");
  assert.equal(detail.data?.loadout_snapshot?.setup_mode,"none");
  assert.deepEqual(detail.data?.loadout_snapshot?.items,[]);
  assert.equal(detail.data?.hunt_analyse?.duration_seconds,1800);
  const other=await fetch(endpoint,{
    method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify({action:"player_session_detail",client_id:otherClient,session_id:none.data.session_id}),
    signal:AbortSignal.timeout(30000),
  });
  assert.ok(other.ok);
  const otherData=await other.json();
  assert.ok(!otherData.data?.session && !otherData.data?.loadout_snapshot,
    "Guest private session must remain isolated across client scopes");
  result.push({mode:"none",saved:true,explicit_source:"not_recorded",
    immutable_snapshot_recorded:true,unrelated_guest_cannot_read:true});
  const automatic=await call({action:"session_import_save",blocks,metadata});
  assert.equal(automatic.http,200);
  assert.ok(automatic.data?.session_id);
  sessions.push(automatic.data.session_id);
  const autoDetail=await call({action:"player_session_detail",session_id:automatic.data.session_id});
  assert.equal(autoDetail.data?.loadout_snapshot?.source,"not_available");
  assert.equal(autoDetail.data?.loadout_snapshot?.setup_mode,"auto");
  result.push({mode:"auto",legacy_fallback_preserved:true});
}finally{
  const failures=[];
  for(const session_id of sessions){
    try {
      const removed=await call({action:"player_session_delete",session_id});
      if(removed.http!==200 || removed.data?.deleted!==true)failures.push(session_id+": deletion failed");
    }catch(e){failures.push(session_id+": "+String(e));}
  }
  assert.deepEqual(failures,[],"All synthetic private sessions must be deleted");
}
console.log(JSON.stringify({status:"ok",stage:"fe33_explicit_setup_modes_live_api",
  real_gameplay_sessions_used:false,auth_accounts_used:false,
  synthetic_sessions_created_and_deleted:sessions.length,
  attempted_invalid_mode_saved:false,results:result},null,2));
