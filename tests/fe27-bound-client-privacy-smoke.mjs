// FE-27: temporary, pre-bound synthetic account canary, no real Auth user.
// GitHub Action MUST receive HUNTNEXUS_BOUND_CANARY_ID while SQL fixture is
// present. This does not and cannot exercise a REAL valid Magic Link session.
import assert from "node:assert/strict";

const endpoint=process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const client_id=process.env.HUNTNEXUS_BOUND_CANARY_ID;
assert.match(client_id??"",/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
  "Provide a SQL-created, BOUND ephemeral canary client ID via environment");
const fakeToken="fe27-invalid-never-issued-jwt-"+"X".repeat(50);
const missingSession="490e2453-28c0-4283-8ba1-1cd4240adc4e";
const fakeItemId="aaacbe5f-d0c4-4ed3-9c41-4902b7ecb7a2";
const profile={
  character_name:"unauthorized-update-should-not-apply",
  world_name:"RubinOT",vocation:"RP",level:777,
  manual_stats:{weapon_family:"bow"},proficiency_selections:{},
  defaults:{hunt_objective:"balanced",set_objective:"balanced",party_size:1},
};
const metadata={
  character:"unauthorized-test",server:"RubinOT",vocation:"EK",level:"700",
  location:"Unauthorized test fixture",hunt_key:"cobra-bastion",
  observation:"FE27 unauthorized write MUST fail",
  tags:[],type:"normal",favorite:false,publishHighscores:false,rareDrops:"",
};
const base=[
  {action:"player_profile_get"},
  {action:"player_profile_delete"},
  {action:"player_profile_save",profile},
  {action:"player_inventory_get"},
  {action:"player_inventory_put",storage_kind:"backpack",item_key:"gnome-sword",quantity:1},
  {action:"player_inventory_remove",inventory_id:fakeItemId},
  {action:"player_inventory_hunt_review",hunt_key:"cobra-bastion",vocation:"EK",level:700},
  {action:"player_hunt_build_choice_get",hunt_key:"cobra-bastion",vocation:"EK"},
  {action:"player_hunt_build_choice_save",hunt_key:"cobra-bastion",vocation:"EK",level:700,
    selection:{weapon:"soulshredder"},option_type:"main",replacements:[]},
  {action:"player_hunt_build_choice_delete",hunt_key:"cobra-bastion",vocation:"EK"},
  {action:"player_owned_build_options",hunt_key:"cobra-bastion",vocation:"EK",level:700},
  {action:"session_import_save",blocks:{hunt:"Session: 01:00h\\nXP Gain: 100",party:"",input:"",misc:""},metadata},
  {action:"player_session_build_performance",hunt_key:"cobra-bastion",vocation:"EK"},
  {action:"player_session_list",limit:5},
  {action:"player_session_detail",session_id:missingSession},
  {action:"player_session_delete",session_id:missingSession},
  {action:"planner_personalized",vocation:"EK",level:700,objective:"balanced",party_size:1,
    limit:1,character_profile:{},proficiency_selections:{}},
  // Test final_optimizer authorization guard without performing any optimizer:
  // a BOUND canary MUST return 401 before the expensive path.
  {action:"final_optimizer",vocation:"EK",level:700,hunt_limit:1,
    selection_limit:1,frontier_limit:1,character_profile:{},proficiency_selections:{}},
];
async function request(payload,headerToken=null){
  const headers={"content-type":"application/json"};
  if(headerToken)headers.authorization="Bearer "+headerToken;
  const res=await fetch(endpoint,{method:"POST",headers,
    body:JSON.stringify(payload),signal:AbortSignal.timeout(35000)});
  const data=await res.json().catch(()=>({}));
  return {status:res.status,error:data.error??null,body:data};
}
const result=[];
for(const action of base){
  for(const [mode,extra,header] of [
    ["no-token",{},null],
    ["forged-token-body",{access_token:fakeToken},null],
    ["forged-token-header",{},fakeToken],
  ]){
    const output=await request({...action,client_id,...extra},header);
    const expected=mode==="forged-token-body"?"invalid_auth_token":"authentication_required_for_bound_client";
    assert.equal(output.status,401,
      action.action+" "+mode+" must not expose bound private scope; got "+output.status+" "+output.error);
    assert.equal(output.error,expected,
      action.action+" "+mode+" wrong denial");
    result.push({action:action.action,mode,http_status:output.status,reason:output.error});
  }
}
assert.equal(result.length,base.length*3);
const guest=await request({action:"player_profile_get",client_id:fakeItemId});
assert.equal(guest.status,200,"Unbound guest reads should not be blocked globally");
assert.equal(guest.body?.data?.exists,false,
  "Foreign synthetic guest should have no profile");
const health=await request({action:"health"});
assert.equal(health.status,200,"Public health must still respond");
console.log(JSON.stringify({
  status:"ok",stage:"fe27_bound_client_http_negative_matrix_v1",
  protected_private_actions:base.length,negative_checks:result.length,
  bearer_without_body_not_accepted:true,forged_body_token_denied:true,
  public_health_unchanged:true,anonymous_unbound_read_unchanged:true,
  real_email_magic_link_validated:false,valid_supabase_jwt_used:false,
  canary_data_mutation_permitted:false,
  checked_actions:base.map(x=>x.action),
},null,2));
