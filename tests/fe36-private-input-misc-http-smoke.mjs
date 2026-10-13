// FE-36 end-to-end persistence with PRIVATE SYNTHETIC analyzers, not RubinOT
// player exports. All sessions are removed; no community evidence is written.
import assert from "node:assert/strict";
const endpoint=process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const client_id=crypto.randomUUID();
const sessions=[];
const findings=[];
async function api(body){
  const res=await fetch(endpoint,{
    method:"POST",
    headers:{"content-type":"application/json"},
    body:JSON.stringify({client_id,...body}),
    signal:AbortSignal.timeout(30000),
  });
  return {http:res.status,...await res.json().catch(()=>({}))};
}
const hunt="Session: 00:30h\nXP Gain: 120,000\nDamage: 800,000";
const metadata={
  character:"FE36 SYNTHETIC parser fixture",server:"RubinOT",
  vocation:"MS",level:"100",location:"FE36 isolated test",
  hunt_key:"",setupMode:"none",
  observation:"SYNTHETIC QA; NOT gameplay",
  tags:["synthetic","fe36"],type:"normal",
  favorite:false,publishHighscores:false,rareDrops:"",
};
async function createAndLoad(blocks){
  const saved=await api({action:"session_import_save",blocks,metadata});
  assert.equal(saved.http,200,JSON.stringify(saved).slice(0,450));
  const session_id=saved.data?.session_id;
  assert.ok(session_id,"Temporary private session must be saved");
  sessions.push(session_id);
  const detail=await api({action:"player_session_detail",session_id});
  assert.equal(detail.http,200,JSON.stringify(detail).slice(0,450));
  assert.ok(detail.data,"Private saved session must be readable by owner");
  return detail.data;
}
try{
  const full=await createAndLoad({
    hunt,
    input:[
      "Total: 12,000","Max-DPS: 345","Damage Types:",
      "Fire: 7,000 (58.3%)","Physical: 5,000 (41.7%)",
      "Damage Sources:","synthetic spectre: 11,000 (91.7%)",
      "synthetic creature: 1,000 (8.3%)",
    ].join("\n"),
    misc:"Session: 00:30h\nCritical Hit: 393\nMana Gain: 1,234\nLife Gain: 2,345",
    party:"",
  });
  assert.equal(full.hunt_analyse.total_damage,800000);
  assert.equal(full.damage.incoming_total_damage,12000);
  assert.equal(full.damage.incoming_max_dps,345);
  assert.deepEqual(full.damage.incoming_by_element.map(v=>v.element),["fire","physical"]);
  assert.equal(full.damage.incoming_by_source.length,2);
  assert.equal(full.damage.incoming_by_source[0].source_name_raw,"synthetic spectre");
  assert.equal(full.misc.combat_stats.find(v=>v.stat_key==="critical_hit").numeric_value,393);
  assert.equal(full.misc.combat_stats.find(v=>v.stat_key==="mana_gain").numeric_value,1234);
  assert.equal(full.misc.combat_stats.find(v=>v.stat_key==="life_gain").numeric_value,2345);
  assert.equal(full.misc.combat_stats.find(v=>v.stat_key==="session").raw_value,"00:30h");
  assert.equal(full.loadout_snapshot.source,"not_recorded");
  findings.push({case:"complete_input_misc_saved_and_read",result:"PASS",elements:2,sources:2,combat_stats:4});

  const totalsOnly=await createAndLoad({
    hunt,input:"Received Damage Total: 12,000\nMax-DPS: 345",misc:"",party:"",
  });
  assert.equal(totalsOnly.damage.incoming_total_damage,12000);
  assert.equal(totalsOnly.damage.incoming_max_dps,345);
  assert.equal(totalsOnly.damage.incoming_by_element.length,0);
  assert.equal(totalsOnly.damage.incoming_by_source.length,0);
  assert.equal(totalsOnly.misc.combat_stats.length,0);
  assert.ok(totalsOnly.validation.warnings.includes("input_breakdown_not_observed"),
    "Optional hidden types/sources must remain unobserved, not invented");
  findings.push({case:"partial_input_totals_only_not_fabricated",result:"PASS",invented_elements:0});
}finally{
  const failures=[];
  for(const session_id of sessions){
    try{
      const removed=await api({action:"player_session_delete",session_id});
      if(removed.http!==200 || removed.data?.deleted!==true)
        failures.push(session_id);
    }catch(e){failures.push(session_id+":"+String(e))}
  }
  assert.deepEqual(failures,[],"Every synthetic private session must be removed");
}
console.log(JSON.stringify({status:"ok",stage:"fe36_private_damage_misc_roundtrip",
  sessions_created_deleted:sessions.length,original_player_data_used:false,
  gameplay_acceptance_tested:false,community_sessions_written:false,
  findings},null,2));
