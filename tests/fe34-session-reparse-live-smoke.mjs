// FE-34 public Worker API, private randomized guest scope and synthetic data.
// Reparse changes and cross-client reads are explicitly tested without any
// real player session, private analyzer export, or community publication.
import assert from "node:assert/strict";
const endpoint=process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const client_id=crypto.randomUUID();
const other_client=crypto.randomUUID();
let session_id=null;
const status=[];
async function call(body) {
  const response=await fetch(endpoint,{
    method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify(body),signal:AbortSignal.timeout(35000),
  });
  return {status:response.status,...await response.json().catch(()=>({}))};
}
try {
  const saved=await call({
    action:"session_import_save",client_id,
    blocks:{
      hunt:"Session: 00:43h\nXP Gain: 8,600\nXP/h: 12,000\nDamage: 2,700",
      party:"",input:"",misc:"",
    },
    metadata:{
      character:"FE34 Synthetic QA",server:"RubinOT",
      vocation:"MS",level:"100",location:"FE34 synthetic fixture",
      hunt_key:"",setupMode:"none",
      observation:"FE34 synthetic private only",
      tags:["synthetic","fe34"],type:"normal",favorite:false,
      publishHighscores:false,rareDrops:"",
    },
  });
  assert.equal(saved.status,200,JSON.stringify(saved).slice(0,800));
  session_id=saved.data?.session_id;
  assert.ok(session_id,"Synthetic private session must return an ID");

  const denied=await call({
    action:"player_session_reparse_preview",client_id:other_client,session_id,
  });
  assert.equal(denied.status,404);
  assert.equal(denied.error,"session_not_found");
  status.push({case:"cross_guest_private_preview_denied",passed:true});

  const preview=await call({
    action:"player_session_reparse_preview",client_id,session_id,
  });
  assert.equal(preview.status,200,JSON.stringify(preview).slice(0,800));
  assert.equal(preview.data.review.no_raw_text_exposed,true);
  assert.equal(preview.data.review.changed,false);
  assert.equal(preview.data.review.safe_to_apply,false);
  assert.equal(preview.data.raw_blocks,undefined);
  assert.equal(preview.data.loadout_snapshot,undefined);
  assert.ok(/^[0-9a-f]{32}$/.test(preview.data.expected_fingerprint));
  status.push({case:"unchanged_parser_read_only_preview",passed:true});

  const invalidOwner=await call({
    action:"player_session_reparse_apply",client_id:other_client,session_id,
    expected_fingerprint:preview.data.expected_fingerprint,confirm:true,
  });
  assert.equal(invalidOwner.status,404);
  status.push({case:"cross_guest_apply_denied",passed:true});

  const noChange=await call({
    action:"player_session_reparse_apply",client_id,session_id,
    expected_fingerprint:preview.data.expected_fingerprint,confirm:true,
  });
  assert.equal(noChange.status,409);
  assert.equal(noChange.error,"reparse_no_changes");
  status.push({case:"no_diff_apply_denied",passed:true});

  const stale=await call({
    action:"player_session_reparse_apply",client_id,session_id,
    expected_fingerprint:"0".repeat(32),confirm:true,
  });
  assert.equal(stale.status,409);
  assert.equal(stale.error,"reparse_preview_stale");
  status.push({case:"stale_preview_apply_denied",passed:true});

  const detail=await call({
    action:"player_session_detail",client_id,session_id,
  });
  assert.equal(detail.status,200);
  assert.equal(detail.data.hunt_analyse.duration_seconds,2580);
  assert.equal(detail.data.loadout_snapshot.source,"not_recorded");
  assert.equal(detail.data.loadout_snapshot.setup_mode,"none");
  assert.equal(detail.data.parser.version,"session_parser_v2");
  status.push({case:"rejected_apply_preserves_session_and_setup",passed:true});
}finally{
  if(session_id){
    const cleaned=await call({
      action:"player_session_delete",client_id,session_id,
    });
    assert.equal(cleaned.status,200);
    assert.equal(cleaned.data?.deleted,true,
      "All synthetic session fixtures must be deleted");
  }
}
console.log(JSON.stringify({
  status:"ok",stage:"fe34_reparse_private_http_smoke",
  synthetic_sessions_created_and_deleted:1,
  player_export_used:false,real_auth_used:false,
  raw_blocks_exposed_to_client:false,
  results:status,
},null,2));
