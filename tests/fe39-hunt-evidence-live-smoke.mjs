// FE-39: read-only production API contract for two catalog hunts.
// The public HTTP handler uses the pre-existing factual/observed endpoints
// and a scoped, service-only source provenance RPC. No private writes.
import assert from "node:assert/strict";

const endpoint=process.env.HUNTNEXUS_ENDPOINT ??
 "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const results=[];
for (const [hunt_key,minimumCreatures] of [
  ["cobra-bastion",11],["forest-of-life",3],
]) {
  const response=await fetch(endpoint,{
    method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify({
      action:"hunt_detail",hunt_key,vocation:"EK",
      level:700,set_objective:"balanced",
    }),
    signal:AbortSignal.timeout(50000),
  });
  assert.equal(response.status,200,hunt_key+": HTTP 200");
  const body=await response.json();
  const data=body.data;
  assert.ok(data?.factual?.hunt,hunt_key+": factual hunt available");
  const e=data?.evidence;
  assert.equal(e?.hunt_key,hunt_key,"source must belong to requested hunt only");
  assert.equal(e.methodology?.stage,"hunt_evidence_context_fe39_v1");
  assert.equal(e.methodology?.scoped_to_one_hunt,true);
  assert.equal(e.methodology?.collection_timestamp_not_live_verified,true);
  assert.equal(e.source?.name,"ByteWizards TibiaData");
  assert.equal(e.source?.layer,"tibia_factual");
  assert.equal(e.source?.tier,"B");
  assert.ok(e.source.source_last_updated);
  assert.equal(e.source.snapshot_recorded,true);
  assert.equal(e.source.snapshot_id,undefined,"internal snapshot ID must not leak");
  assert.ok(e.coverage?.creature_count>=minimumCreatures);
  assert.equal(e.coverage.creatures_with_elements,e.coverage.creature_count);
  assert.equal(e.coverage.creatures_with_detail,e.coverage.creature_count);
  assert.equal(e.coverage.creatures_with_abilities,e.coverage.creature_count);
  assert.equal(e.coverage.creatures_with_loot,e.coverage.creature_count);
  assert.equal(e.source_core_complete,true);
  assert.equal(e.methodology.observed_sessions_do_not_determine_source_completeness,true);
  assert.ok(data?.observed!==undefined,"observational layer must remain separate");
  results.push({hunt_key,creatures:e.coverage.creature_count,
    provenance_present:true,source_core_complete:true});
}
console.log(JSON.stringify({
  status:"ok",stage:"fe39_hunt_evidence_public_http",
  real_private_sessions_modified:false,
  source_provenance_verified:true,non_confidential_read_only:true,results,
},null,2));
