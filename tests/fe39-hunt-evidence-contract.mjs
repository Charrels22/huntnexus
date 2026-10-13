import assert from "node:assert/strict";
import { describeHuntEvidence } from "../web/app/src/lib/hunt-evidence.ts";
const source={
  name:"ByteWizards TibiaData",tier:"B",layer:"tibia_factual",
  url:"https://tibiadata.bytewizards.de",snapshot_recorded:true,
  source_last_updated:"2026-04-09T02:36:10.816582+00:00",
};
const coverage={
  creature_count:11,creatures_with_elements:11,creatures_with_detail:11,
  creatures_with_abilities:11,creatures_with_loot:11,elements_complete:true,
  creature_detail_complete:true,abilities_complete:true,loot_complete:true,
};
const evidence={source,coverage,source_core_complete:true,methodology:{stage:"hunt_evidence_context_fe39_v1"}};
const full=describeHuntEvidence(evidence,{performance:{session_count:9}},
  {sample:{sourced_session_count:7}});
assert.equal(full.status,"complete");
assert.equal(full.sourceName,"ByteWizards TibiaData");
assert.equal(full.sourceTier,"B");
assert.equal(full.sourceLayer,"tibia_factual");
assert.equal(full.lastUpdated,"09/04/2026");
assert.equal(full.snapshotRecorded,true);
assert.equal(full.observedSessions,9);
assert.equal(full.vocationSourcedSessions,7);
assert.ok(full.coverage.every(x=>x.complete && x.observed===11 && x.total===11));
const noObservations=describeHuntEvidence(evidence,{performance:{session_count:0}},null);
assert.equal(noObservations.status,"complete");
assert.equal(noObservations.observedSessions,0);
assert.equal(noObservations.vocationSourcedSessions,null);
assert.match(noObservations.observationalWarning,/Sem sessões/);
const sparse=describeHuntEvidence({...evidence,
  source:{name:"Unknown",url:"javascript:alert(1)",source_last_updated:"not-a-date"},
  source_core_complete:false,
  coverage:{...coverage,creatures_with_abilities:7,abilities_complete:false},
},{performance:{session_count:1}},null);
assert.equal(sparse.status,"incomplete");
assert.equal(sparse.sourceUrl,null);
assert.equal(sparse.lastUpdated,null);
assert.equal(sparse.coverage.find(x=>x.key==="abilities").observed,7);
assert.equal(sparse.coverage.find(x=>x.key==="abilities").complete,false);
assert.match(sparse.observationalWarning,/Amostra geral limitada/);
const absent=describeHuntEvidence(null,{performance:{session_count:null}},null);
assert.equal(absent.status,"unavailable");
assert.equal(absent.snapshotRecorded,false);
assert.equal(absent.coverage[0].observed,null);
assert.equal(absent.coverage[0].total,null);
assert.equal(absent.sourceUrl,null);
assert.equal(absent.observedSessions,null);
assert.equal(absent.vocationSourcedSessions,null);
assert.ok(!JSON.stringify(full).includes("snapshot_id"));
assert.ok(!JSON.stringify(full).includes("raw_player"));
console.log(JSON.stringify({
 status:"ok",stage:"fe39_evidence_presentation",
 core_full_and_incomplete_separated:true,
 absent_not_zero:true,untrusted_link_rejected:true,
 observed_sample_independent_of_factual_core:true,
 date_not_freshness_claim:true,private_data_accessed:false
},null,2));
