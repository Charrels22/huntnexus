// FE-31: read-only live API catalog checks. No account, inventory mutation,
// player logs, Magic Link, token, or synthetic community session is created.
import assert from "node:assert/strict";

const origin=process.env.HUNTNEXUS_BASE_URL ??
  "https://huntnexus.charr3ls22.workers.dev";
const endpoint=new URL("/api/huntnexus",origin);
const tests=[
  {vocation:"EK",family:"sword"},
  {vocation:"RP",family:"bow"},
  {vocation:"ED",family:"rod"},
  {vocation:"MS",family:"wand"},
  {vocation:"EM",family:"fist"},
];
const rounds=Number(process.env.HUNTNEXUS_PROFICIENCY_ROUNDS || 2);
assert.ok(Number.isInteger(rounds) && rounds>=1 && rounds<=3,"rounds must be 1–3");
const results=[];
for(let round=1;round<=rounds;round++){
  for(const test of tests){
    const start=performance.now();
    let response;
    try{
      response=await fetch(endpoint,{
        method:"POST",
        headers:{"content-type":"application/json"},
        body:JSON.stringify({
          action:"player_profile_proficiency_catalog",
          vocation:test.vocation,
          weapon_family:test.family,
          level:700,
        }),
        signal:AbortSignal.timeout(25000),
      });
    }catch(error){
      throw new Error("FE-31 catalog network error "+test.vocation+"/"+test.family+
        " round="+round+": "+String(error));
    }
    const latency_ms=Math.round(performance.now()-start);
    const raw=await response.json().catch(()=>null);
    assert.equal(response.status,200,
      test.vocation+" catalog returned HTTP "+response.status+" round="+round);
    assert.ok(Array.isArray(raw?.data?.trees),
      test.vocation+" catalog has no trees array round="+round);
    const eligible=raw.data.trees.filter(x=>x.eligible);
    assert.ok(eligible.length>0,test.vocation+" live catalog has zero eligible trees");
    assert.ok(Number(raw.data.summary?.eligible_tree_count)>0,
      test.vocation+" summary has zero eligible trees");
    const sourceBacked=eligible.filter(x=>x.topology_status==="source_backed_level_position");
    results.push({
      vocation:test.vocation,weapon_family:test.family,round,
      latency_ms,http_status:response.status,
      eligible_trees:eligible.length,
      source_backed_eligible:sourceBacked.length,
      eligible_without_verified_topology:eligible.length-sourceBacked.length,
      inspected_catalog:"PUBLIC_READ_ONLY",
    });
    console.log(JSON.stringify(results.at(-1)));
  }
}
const latencies=results.map(x=>x.latency_ms).sort((a,b)=>a-b);
console.log(JSON.stringify({
  status:"ok",
  stage:"fe31_source_backed_live_proficiency_catalog",
  samples:results.length,
  per_vocation_rounds:rounds,
  median_latency_ms:latencies[Math.floor((latencies.length-1)/2)],
  max_latency_ms:latencies.at(-1),
  all_catalogs_nonempty:true,
  real_player_profile_used:false,
  real_gameplay_sessions_imported:false,
  logged_in_auth_tested:false,
  results,
},null,2));
