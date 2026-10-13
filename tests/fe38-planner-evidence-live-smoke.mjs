// FE-38: read-only verified Planner source/sample semantics for all vocations.
// No player identity, no profile, no synthetic gameplay writes.
import assert from "node:assert/strict";

const endpoint=process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const summary=[];
for(const vocation of ["EK","RP","ED","MS","EM"]){
  const response=await fetch(endpoint,{
    method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify({
      action:"planner_personalized",vocation,level:700,
      objective:"balanced",party_size:1,limit:3,
    }),
    signal:AbortSignal.timeout(35000),
  });
  assert.equal(response.status,200,vocation+": Planner must return HTTP 200");
  const body=await response.json();
  const data=body.data;
  assert.equal(data.query.vocation,vocation);
  assert.equal(data.methodology.experimental_observational_ranking,true);
  assert.equal(data.methodology.performance_values_are_observed_not_guaranteed,true);
  assert.equal(data.methodology.confidence_index_is_not_a_statistical_probability,true);
  assert.equal(data.methodology.no_results_does_not_mean_no_hunts_exist,true);
  assert.equal(data.methodology.hunt_ranking_reordered_by_inventory,false);
  assert.ok(Array.isArray(data.results));
  const counted=data.results.reduce((sum,row)=>sum+row.evidence.observed_session_count,0);
  assert.equal(data.summary.observed_sessions_in_displayed_hunts,counted);
  assert.equal(data.summary.ranked_hunts,data.results.length);
  assert.equal(data.summary.hunts_with_limited_sample,
    data.results.filter(row=>row.evidence.limited_sample).length);
  for(const [i,row] of data.results.entries()){
    assert.equal(row.hunt_rank_order,i+1);
    assert.equal(row.evidence.source_layer,"community_observations");
    assert.equal(row.evidence.observed_session_count,row.hunt.session_count);
    assert.ok(row.evidence.observed_session_count>0,
      "No fabricated median performance when evidence count is zero");
    assert.equal(row.evidence.limited_sample,row.evidence.observed_session_count<3);
    assert.equal(row.evidence.confidence_index_is_statistical_probability,false);
    assert.equal(row.evidence.ranking_is_experimental,true);
    assert.equal(row.evidence.private_sessions_do_not_change_rank,true);
  }
  summary.push({vocation,results:data.results.length,
    min_sample:data.results.length?Math.min(...data.results.map(x=>x.evidence.observed_session_count)):null,
    limited_sample_count:data.summary.hunts_with_limited_sample});
}
console.log(JSON.stringify({
  status:"ok",stage:"fe38_planner_observational_api_live",
  vocations_checked:5,synthetic_player_sessions_created:0,
  raw_gameplay_exports_used:false,ranking_modified:false,checks:summary,
},null,2));
