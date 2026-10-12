// FE-25: actual deployed API regressions of multi-slot Main/BP and snapshot
// immutability. Item keys are from the live catalog, but the private characters,
// numerical analyzer inputs, and sessions are SYNTHETIC; not gameplay evidence.
import assert from "node:assert/strict";
const endpoint = process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";

const cases = [
  { vocation:"EK",family:"sword",hunt:"cobra-bastion",
    main:{weapon:"soulshredder",head:"falcon-coif",body:"falcon-plate"},
    alternative:{weapon:"gnome-sword",head:"cobra-hood",body:"lion-plate"} },
  { vocation:"RP",family:"bow",hunt:"iksupan-last-stand",
    main:{weapon:"soulbleeder",head:"alicorn-headguard",body:"gnome-armor",offhand:"quiver",ammunition:"diamond-arrow"},
    alternative:{weapon:"eldritch-bow",head:"falcon-coif",body:"soulshell",offhand:"eldritch-quiver",ammunition:"crystalline-arrow"} },
  { vocation:"ED",family:"rod",hunt:"nimmersatts-breeding-ground",
    main:{weapon:"soulhexer",head:"gnome-helmet",body:"soulshroud"},
    alternative:{weapon:"amber-rod",head:"falcon-circlet",body:"frostmind-raiment"} },
  { vocation:"MS",family:"wand",hunt:"podzilla",
    main:{weapon:"soultainter",head:"gnome-helmet",body:"soulmantle"},
    alternative:{weapon:"amber-wand",head:"eldritch-cowl",body:"dawnfire-sherwani"} },
  { vocation:"EM",family:"fist",hunt:"grounds-of-undeath",
    main:{weapon:"soulkamas",head:"dark-vision-bandana",body:"soulgarb"},
    alternative:{weapon:"nunchaku-of-destruction",head:"demon-mengu",body:"naga-tanko"} },
];
async function post(body){
  const response=await fetch(endpoint,{
    method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify(body),signal:AbortSignal.timeout(35000),
  });
  const value=await response.json().catch(()=>({}));
  assert.ok(response.ok,
    "HTTP "+response.status+" action="+body.action+": "+JSON.stringify(value).slice(0,1000));
  return value.data;
}
const sessionInput=(which)=>[
  "Session: 01:00h", "XP Gain: "+(which===1?"10,500,000":"9,200,000"),
  "XP/h: "+(which===1?"10,500,000":"9,200,000"),
  "Loot: 880,000","Supplies: 340,000","Balance: 540,000",
  "Damage: 4,900,000","Healing: 690,000",
].join("\n");

async function runCase(c){
  const client_id=crypto.randomUUID();
  const foreign_client=crypto.randomUUID();
  const inventoryIds=[];
  const sessionIds=[];
  const errors=[];
  let profileStarted=false;
  let choiceStarted=false;
  let currentStep="start";
  let result=null;
  let fatal=null;
  try {
    currentStep="profile";
    profileStarted=true;
    const profile=await post({action:"player_profile_save",client_id,
      profile:{
        character_name:"FE25 QA "+c.vocation,world_name:"RubinOT",
        vocation:c.vocation,level:700,
        manual_stats:{weapon_family:c.family},
        proficiency_selections:{},
        defaults:{hunt_objective:"balanced",set_objective:"balanced",party_size:1},
      },
    });
    assert.equal(profile?.saved,true,
      c.vocation+" profile must save: "+JSON.stringify(profile).slice(0,550));
    const createdProfile=await post({action:"player_profile_get",client_id});
    assert.equal(createdProfile?.profile?.vocation,c.vocation);

    currentStep="equip";
    for(const [slot,item_key] of Object.entries(c.main)){
      const equip=await post({action:"player_inventory_put",client_id,
        storage_kind:"main",item_key,quantity:1});
      if(equip?.inventory_id) inventoryIds.push(equip.inventory_id);
      assert.equal(equip?.saved,true,c.vocation+": Main "+slot+" "+item_key);
      assert.equal(equip?.selection_key,slot,c.vocation+": Main slot mismatch");
    }
    for(const [slot,item_key] of Object.entries(c.alternative)){
      const stored=await post({action:"player_inventory_put",client_id,
        storage_kind:"backpack",item_key,quantity:1});
      if(stored?.inventory_id)inventoryIds.push(stored.inventory_id);
      assert.equal(stored?.saved,true,c.vocation+": BP "+slot+" "+item_key);
      assert.equal(stored?.selection_key,slot,c.vocation+": BP slot mismatch");
    }
    const initial=await post({action:"player_inventory_get",client_id});
    assert.equal(initial?.summary?.main_slots,Object.keys(c.main).length);
    assert.equal(initial?.summary?.backpack_items,Object.keys(c.alternative).length);
    for(const [slot,key] of Object.entries(c.main)){
      assert.equal(initial.main_set?.[slot]?.item_key,key,
        c.vocation+": Main slot "+slot+" unexpectedly changed");
    }
    const unrelated=await post({action:"player_inventory_get",client_id:foreign_client});
    assert.equal(unrelated?.summary?.main_slots,0);
    assert.equal(unrelated?.summary?.backpack_items,0);

    currentStep="selection";
    // Negative controls. The same RP bow must NOT be accepted if its quiver,
    // arrow family or vocation-compatible body is wrong. Rejected options must
    // not overwrite Main or create a Hunt choice. Validity is controlled by the
    // real SQL loadout rules, never bypassed for testing.
    if(c.vocation==="RP"){
      const invalidRP=[
        {reason:"required_quiver_missing",expected:"incomplete",
          selection:{...c.alternative,offhand:undefined}},
        {reason:"required_ammunition_missing",expected:"incomplete",
          selection:{...c.alternative,ammunition:undefined}},
        {reason:"ammunition_family_mismatch",expected:"blocked",
          selection:{...c.alternative,ammunition:"spectral-bolt"}},
        {reason:"wrong_vocation_body",expected:"blocked",
          selection:{...c.alternative,body:"soulmantle"}},
      ];
      for(const invalid of invalidRP){
        const rejected=await post({action:"player_hunt_build_choice_save",client_id,
          hunt_key:c.hunt,vocation:c.vocation,level:700,
          option_type:"owned_variant",selection:invalid.selection,
          replacements:[],
        });
        assert.equal(rejected?.saved,false,
          "RP must reject "+invalid.reason+": "+JSON.stringify(rejected).slice(0,500));
        assert.equal(rejected?.error,"invalid_loadout");
        assert.equal(rejected?.validation?.status,invalid.expected);
        if(invalid.reason!=="wrong_vocation_body"){
          assert.ok((rejected?.validation?.combination_issues??[])
            .some(x=>x.issue===invalid.reason),
            "RP should explain blocked dependency: "+invalid.reason);
        }
        const previous=await post({action:"player_hunt_build_choice_get",client_id,
          hunt_key:c.hunt,vocation:c.vocation});
        assert.equal(previous?.exists,false,
          "RP invalid loadout must not create or alter saved choice");
      }
      const untouched=await post({action:"player_inventory_get",client_id});
      assert.equal(untouched?.main_set?.weapon?.item_key,c.main.weapon);
    }
    choiceStarted=true;
    const choice=await post({action:"player_hunt_build_choice_save",client_id,
      hunt_key:c.hunt,vocation:c.vocation,level:700,
      option_type:"owned_variant",selection:c.alternative,
      replacements:Object.entries(c.alternative).map(([slot,item_key])=>({
        selection_key:slot,item_key,item_name:item_key
      })),
    });
    assert.equal(choice?.saved,true,
      c.vocation+": multi-slot option not accepted "+JSON.stringify(choice).slice(0,950));
    assert.equal(choice?.main_set_mutated,false);
    const saved=await post({action:"player_hunt_build_choice_get",client_id,
      hunt_key:c.hunt,vocation:c.vocation});
    assert.equal(saved?.exists,true);
    for(const [slot,key] of Object.entries(c.alternative)){
      assert.equal(saved?.choice?.selection?.[slot],key,c.vocation+": BP choice "+slot);
    }

    currentStep="first snapshot";
    const sharedMetadata={
      character:"FE25 QA "+c.vocation,server:"RubinOT",
      vocation:c.vocation,level:"700",
      location:"Synthetic multi-slot audit",hunt_key:c.hunt,
      observation:"SYNTHETIC FE25 QA - NOT GAMEPLAY",
      tags:["fe25","synthetic","private"],type:"normal",favorite:false,
      publishHighscores:false,rareDrops:"",
    };
    const importA=await post({action:"session_import_save",client_id,
      blocks:{hunt:sessionInput(1)},metadata:sharedMetadata});
    if(importA?.session_id)sessionIds.push(importA.session_id);
    assert.equal(importA?.status,"parsed");
    assert.equal(importA?.community_evidence_written,false);
    const first=await post({action:"player_session_detail",client_id,
      session_id:importA.session_id});
    assert.equal(first?.parser?.loadout_snapshot_immutable,true);
    assert.equal(first?.loadout_snapshot?.source,"saved_hunt_choice");
    for(const [slot,key] of Object.entries(c.alternative)){
      assert.equal(first?.loadout_snapshot?.selection?.[slot],key,
        c.vocation+": initial BP snapshot lost "+slot);
    }
    const immutableSnapshot=JSON.stringify(first.loadout_snapshot);

    currentStep="negative isolation";
    const foreign=await post({action:"player_session_detail",client_id:foreign_client,
      session_id:importA.session_id});
    assert.ok(!foreign?.session&&!foreign?.loadout_snapshot,
      c.vocation+": unauthorized client read private snapshot");

    currentStep="switch Main/BP";
    for(const [slot,item_key] of Object.entries(c.alternative)){
      const previous=initial.backpack.find(x=>x.item_key===item_key);
      assert.ok(previous,c.vocation+": BP item not found for "+slot);
      const deleted=await post({action:"player_inventory_remove",client_id,
        inventory_id:previous.inventory_id});
      assert.equal(deleted?.deleted,true,c.vocation+": remove BP "+slot);
      const pos=inventoryIds.indexOf(previous.inventory_id);
      if(pos>=0)inventoryIds.splice(pos,1);
    }
    const erase=await post({action:"player_hunt_build_choice_delete",client_id,
      hunt_key:c.hunt,vocation:c.vocation});
    assert.equal(erase?.main_set_mutated,false);
    choiceStarted=false;
    const after=await post({action:"player_inventory_get",client_id});
    assert.equal(after.summary.backpack_items,0);
    assert.equal(after.summary.main_slots,Object.keys(c.main).length);
    for(const [slot,key] of Object.entries(c.main)){
      assert.equal(after.main_set?.[slot]?.item_key,key);
    }
    const readAgain=await post({action:"player_session_detail",client_id,
      session_id:importA.session_id});
    assert.equal(JSON.stringify(readAgain.loadout_snapshot),immutableSnapshot,
      c.vocation+": BP removal modified previously stored session!");

    currentStep="second snapshot";
    const importB=await post({action:"session_import_save",client_id,
      blocks:{hunt:sessionInput(2)},metadata:{...sharedMetadata,
        observation:"SYNTHETIC FE25 QA - unchanged Main baseline"}});
    if(importB?.session_id)sessionIds.push(importB.session_id);
    assert.equal(importB?.status,"parsed");
    assert.equal(importB?.community_evidence_written,false);
    const second=await post({action:"player_session_detail",client_id,
      session_id:importB.session_id});
    assert.equal(second?.parser?.loadout_snapshot_immutable,true);
    for(const [slot,key] of Object.entries(c.main)){
      assert.equal(second?.loadout_snapshot?.selection?.[slot],key,
        c.vocation+": second Main snapshot "+slot);
    }
    const older=await post({action:"player_session_detail",client_id,
      session_id:importA.session_id});
    assert.equal(JSON.stringify(older.loadout_snapshot),immutableSnapshot,
      c.vocation+": newer Main session mutated the older BP snapshot");

    currentStep="performance and privacy";
    const performance=await post({action:"player_session_build_performance",client_id,
      hunt_key:c.hunt,vocation:c.vocation});
    assert.equal(performance?.summary?.sessions,2);
    assert.equal(performance?.summary?.distinct_builds,2);
    assert.equal(performance?.methodology?.causal_effect_inferred,false);
    const weapons=new Set((performance.builds??[]).map(x=>x.selection?.weapon));
    assert.ok(weapons.has(c.main.weapon)&&weapons.has(c.alternative.weapon));
    const list=await post({action:"player_session_list",client_id,limit:10});
    assert.equal(list?.summary?.returned,2);
    const foreignList=await post({action:"player_session_list",client_id:foreign_client,limit:5});
    assert.equal(foreignList?.summary?.returned,0);

    result={
      vocation:c.vocation,hunt_key:c.hunt,
      main_slots:Object.keys(c.main).length,
      bp_alternative_slots:Object.keys(c.alternative).length,
      rp_quiver_ammunition_verified:c.vocation==="RP",
      rp_invalid_dependency_cases_rejected:c.vocation==="RP"?4:null,
      first_snapshot:"owned_bp_multislot",
      second_snapshot:"main_multislot",
      distinct_historical_builds:2,
      first_snapshot_unchanged_after_all_BP_removed:true,
      private_guest_uuid_isolation:true,community_published:false,
      raw_analyzers_synthetic:true,
    };
  }catch(error){fatal=error;}
  finally{
    for(const session_id of sessionIds){
      try {
        const d=await post({action:"player_session_delete",client_id,session_id});
        assert.equal(d?.deleted,true);
      }catch(e){errors.push("session:"+String(e));}
    }
    if(choiceStarted){
      try{await post({action:"player_hunt_build_choice_delete",client_id,
        hunt_key:c.hunt,vocation:c.vocation});}
      catch(e){errors.push("choice:"+String(e));}
    }
    for(const inventory_id of inventoryIds){
      try{
        const d=await post({action:"player_inventory_remove",client_id,inventory_id});
        assert.equal(d?.deleted,true);
      }catch(e){errors.push("inventory:"+String(e));}
    }
    if(profileStarted){
      try{
        const d=await post({action:"player_profile_delete",client_id});
        assert.equal(d?.deleted,true);
      }catch(e){errors.push("profile:"+String(e));}
    }
    try{
      const [profile,inv,sessions]=await Promise.all([
        post({action:"player_profile_get",client_id}),
        post({action:"player_inventory_get",client_id}),
        post({action:"player_session_list",client_id,limit:5}),
      ]);
      if(profile?.exists!==false || inv?.summary?.main_slots!==0 ||
         inv?.summary?.backpack_items!==0 || sessions?.summary?.returned!==0){
        errors.push("nonempty fixture after cleanup");
      }
    }catch(e){errors.push("verify:"+String(e));}
  }
  if(fatal||errors.length){
    throw new Error(c.vocation+" step="+currentStep+" "+
      (fatal?String(fatal):"passed primary assertions")+
      " cleanup="+JSON.stringify(errors).slice(0,850));
  }
  return result;
}
const results=[];
for(const c of cases){
  const r=await runCase(c);
  results.push(r);
  console.log("[FE25] "+c.vocation+" Main/BP multi-slot immutable snapshots / isolation / cleanup PASS");
}
assert.equal(results.length,5);
console.log(JSON.stringify({
  status:"ok",stage:"fe25_five_vocation_multislot_private_snapshots_v1",
  live_deployed_API:true,
  synthetic_profiles:5,synthetic_private_sessions:10,
  catalog_keys_verified_sql_before_run:true,
  private_fixture_residue_expected:0,
  community_sessions_written:0,
  real_playtests_performed:0,results,
},null,2));
