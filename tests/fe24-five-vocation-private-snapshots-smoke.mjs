// FE-24: five-vocation public HTTP regression, isolated private fixtures.
// Uses real item/hunt catalog keys but GENERATED SYNTHETIC analyzer measurements.
// Absolutely no fake community observations, human testers or RubinOT claim.
import assert from "node:assert/strict";

const endpoint = process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const cases = [
  { vocation:"EK",family:"sword",hunt:"cobra-bastion",main:"soulshredder",bp:"gnome-sword" },
  { vocation:"RP",family:"bow",hunt:"iksupan-last-stand",main:"soulbleeder",bp:"eldritch-bow" },
  { vocation:"ED",family:"rod",hunt:"nimmersatts-breeding-ground",main:"soulhexer",bp:"amber-rod" },
  { vocation:"MS",family:"wand",hunt:"podzilla",main:"soultainter",bp:"amber-wand" },
  { vocation:"EM",family:"fist",hunt:"grounds-of-undeath",main:"soulkamas",bp:"nunchaku-of-destruction" },
];
const results=[];

async function post(payload) {
  const response=await fetch(endpoint,{
    method:"POST",
    headers:{"content-type":"application/json"},
    body:JSON.stringify(payload),
    signal:AbortSignal.timeout(35000),
  });
  const result=await response.json().catch(()=>({}));
  assert.ok(response.ok,
    `HTTP ${response.status} / ${payload.action} / ${payload.vocation??"-"}: ${JSON.stringify(result).slice(0,1200)}`);
  return result.data;
}
async function ownedProfileCatalog(c) {
  const data=await post({
    action:"player_profile_proficiency_catalog",
    vocation:c.vocation,level:700,weapon_family:c.family,
  });
  const first=(data?.trees??[]).find(x=>x.item_key===c.main&&x.eligible===true);
  const second=(data?.trees??[]).find(x=>x.item_key===c.bp&&x.eligible===true);
  assert.ok(first && second,`${c.vocation}: both weapon fixtures must be eligible in the LIVE catalog`);
  const firstPerk=first.perks?.find(x=>Number.isInteger(x.perk_order));
  assert.ok(firstPerk,`${c.vocation}: Main must have an indexed proficiency perk`);
  return firstPerk.perk_order;
}

function synthesizedAnalyzer(c,variant) {
  const xp=variant==="BP"?11500000:9500000;
  const balance=variant==="BP"?370000:240000;
  return [
    "Session: 01:00h",
    `XP Gain: ${xp.toLocaleString("en-US")}`,
    `XP/h: ${xp.toLocaleString("en-US")}`,
    "Loot: 800,000",
    `Supplies: ${(800000-balance).toLocaleString("en-US")}`,
    `Balance: ${balance.toLocaleString("en-US")}`,
    "Damage: 4,500,000",
    "Healing: 700,000",
  ].join("\n");
}

async function testVocation(c) {
  const client_id=crypto.randomUUID();
  const another_client_id=crypto.randomUUID();
  const sessions=[];
  const inventoryIds=[];
  let choiceAttempted=false;
  let profileAttempted=false;
  let primaryError=null;
  let result=null;
  const cleanupErrors=[];
  try {
    const perkOrder=await ownedProfileCatalog(c);
    const saved=await post({
      action:"player_profile_save",client_id,
      profile:{
        character_name:"FE24 Isolated "+c.vocation+" Fixture",world_name:"RubinOT",
        vocation:c.vocation,level:700,
        manual_stats:{
          weapon_family:c.family,
          ...(c.vocation==="ED"||c.vocation==="MS"
            ? {magic_level:110,effective_magic_level:112}
            : {effective_weapon_skill:120}),
        },
        proficiency_selections:{[c.main]:[perkOrder]},
        defaults:{hunt_objective:"balanced",set_objective:"balanced",party_size:1},
      },
    });
    profileAttempted=true;
    assert.equal(saved?.saved,true,`${c.vocation}: save Profile: ${JSON.stringify(saved).slice(0,600)}`);
    const profile=await post({action:"player_profile_get",client_id});
    assert.equal(profile?.exists,true,`${c.vocation}: profile not found`);
    assert.equal(profile.profile.vocation,c.vocation);
    assert.equal(profile.profile.level,700);
    assert.equal(profile.profile.manual_stats.weapon_family,c.family);
    assert.deepEqual(profile.profile.proficiency_selections[c.main],[perkOrder]);
    const profileOther=await post({action:"player_profile_get",client_id:another_client_id});
    assert.equal(profileOther?.exists,false,`${c.vocation}: cross-client Profile leak`);

    const main=await post({action:"player_inventory_put",client_id,
      storage_kind:"main",item_key:c.main,quantity:1});
    assert.equal(main?.saved,true,`${c.vocation}: save Main failed`);
    assert.equal(main?.selection_key,"weapon",`${c.vocation}: wrong Main slot`);
    inventoryIds.push(main.inventory_id);
    // RP two-handed bows require BOTH quiver + arrow dependency according to
    // the live universal loadout validator. Do not bypass the validator.
    if(c.vocation==="RP") {
      for(const dependency of ["quiver","diamond-arrow"]) {
        const equipped=await post({action:"player_inventory_put",client_id,
          storage_kind:"main",item_key:dependency,quantity:1});
        assert.equal(equipped?.saved,true,`RP: missing required ${dependency}`);
        inventoryIds.push(equipped.inventory_id);
      }
    }
    const backpack=await post({action:"player_inventory_put",client_id,
      storage_kind:"backpack",item_key:c.bp,quantity:1});
    assert.equal(backpack?.saved,true,`${c.vocation}: save BP failed`);
    inventoryIds.push(backpack.inventory_id);
    const owned=await post({action:"player_inventory_get",client_id});
    assert.equal(owned.main_set.weapon?.item_key,c.main);
    assert.equal(owned.summary.main_slots,c.vocation==="RP"?3:1);
    if(c.vocation==="RP") {
      assert.equal(owned.main_set.offhand?.item_key,"quiver");
      assert.equal(owned.main_set.ammunition?.item_key,"diamond-arrow");
    }
    assert.equal(owned.summary.backpack_items,1);
    assert.equal(owned.methodology.main_set_is_baseline,true);
    assert.equal(owned.methodology.automatic_main_replacement,false);
    assert.ok(owned.backpack.some(x=>x.item_key===c.bp));
    const otherInventory=await post({action:"player_inventory_get",client_id:another_client_id});
    assert.equal(otherInventory.summary.main_slots,0,`${c.vocation}: leaked Main to unrelated client`);
    assert.equal(otherInventory.summary.backpack_items,0,`${c.vocation}: leaked BP to unrelated client`);

    choiceAttempted=true;
    const choice=await post({action:"player_hunt_build_choice_save",client_id,
      hunt_key:c.hunt,vocation:c.vocation,level:700,
      option_type:"owned_variant",
      selection:{weapon:c.bp,...(c.vocation==="RP"?{offhand:"quiver",ammunition:"diamond-arrow"}:{})},
      replacements:[{selection_key:"weapon",item_key:c.bp,item_name:c.bp}],
    });
    assert.equal(choice?.saved,true,`${c.vocation}: BP choice failed: ${JSON.stringify(choice).slice(0,650)}`);
    assert.equal(choice?.main_set_mutated,false);
    const readChoice=await post({action:"player_hunt_build_choice_get",client_id,
      hunt_key:c.hunt,vocation:c.vocation});
    assert.equal(readChoice?.exists,true);
    assert.equal(readChoice.choice?.selection?.weapon,c.bp);
    const noMainMutation=await post({action:"player_inventory_get",client_id});
    assert.equal(noMainMutation.main_set.weapon?.item_key,c.main,
      `${c.vocation}: saved BP choice mutated Main`);

    // FE-33: explicitly force Main while a BP choice for this hunt exists.
    // The Main snapshot must be selected from server-side owned inventory,
    // without changing the saved per-hunt BP choice.
    const forcedMain=await post({action:"session_import_save",client_id,
      blocks:{hunt:synthesizedAnalyzer(c,"MAIN")},
      metadata:{
        character:"FE33 Main selector "+c.vocation,server:"RubinOT",
        vocation:c.vocation,level:"700",location:"FE33 isolated Main fixture",
        hunt_key:c.hunt,setupMode:"main",
        observation:"SYNTHETIC FE33 explicit Main; not gameplay",
        tags:["fe33","synthetic","private"],type:"normal",
        favorite:false,publishHighscores:false,rareDrops:"",
      },
    });
    if(forcedMain?.session_id)sessions.push(forcedMain.session_id);
    assert.equal(forcedMain?.status,"parsed");
    const forcedSnapshot=await post({action:"player_session_detail",
      client_id,session_id:forcedMain.session_id});
    assert.equal(forcedSnapshot?.loadout_snapshot?.source,"main_default");
    assert.equal(forcedSnapshot?.loadout_snapshot?.setup_mode,"main");
    assert.equal(forcedSnapshot?.loadout_snapshot?.selection?.weapon,c.main,
      c.vocation+": explicitly forced Main must not use saved BP choice");
    const removedForced=await post({action:"player_session_delete",
      client_id,session_id:forcedMain.session_id});
    assert.equal(removedForced?.deleted,true);
    sessions.splice(sessions.indexOf(forcedMain.session_id),1);

    const first=await post({action:"session_import_save",client_id,
      blocks:{hunt:synthesizedAnalyzer(c,"BP")},
      metadata:{
        character:"FE24 Isolated "+c.vocation+" Fixture",
        server:"RubinOT",vocation:c.vocation,level:"700",
        location:"FE24 synthetic session",hunt_key:c.hunt,setupMode:"hunt",
        observation:"SYNTHETIC FE24 snapshot QA; not a real playtest",
        tags:["fe24","synthetic","private"],type:"normal",
        favorite:false,publishHighscores:false,rareDrops:"",
      },
    });
    if(first?.session_id)sessions.push(first.session_id);
    assert.equal(first?.status,"parsed",`${c.vocation}: first session parse`);
    assert.equal(first?.community_evidence_written,false,
      `${c.vocation}: artificial session published to community`);

    const s1=await post({action:"player_session_detail",client_id,session_id:first.session_id});
    assert.equal(s1?.parser?.loadout_snapshot_immutable,true);
    assert.equal(s1?.loadout_snapshot?.source,"saved_hunt_choice",
      `${c.vocation}: first snapshot must pin chosen BP set`);
    assert.equal(s1?.loadout_snapshot?.setup_mode,"hunt");
    assert.equal(s1?.loadout_snapshot?.selection?.weapon,c.bp);
    if(c.vocation==="RP") {
      assert.equal(s1?.loadout_snapshot?.selection?.offhand,"quiver");
      assert.equal(s1?.loadout_snapshot?.selection?.ammunition,"diamond-arrow");
    }
    assert.equal(s1?.hunt_analyse?.xp_gain,11500000);
    assert.equal(s1?.session?.hunt_key,c.hunt);
    const snapshot1=JSON.stringify(s1.loadout_snapshot);

    const otherDetail=await post({action:"player_session_detail",
      client_id:another_client_id,session_id:first.session_id});
    assert.ok(!otherDetail?.session && !otherDetail?.loadout_snapshot,
      `${c.vocation}: private session visible to unrelated client`);

    const removed=await post({action:"player_inventory_remove",client_id,
      inventory_id:backpack.inventory_id});
    assert.equal(removed?.deleted,true,`${c.vocation}: BP removal failed`);
    inventoryIds.splice(inventoryIds.indexOf(backpack.inventory_id),1);

    const delChoice=await post({action:"player_hunt_build_choice_delete",client_id,
      hunt_key:c.hunt,vocation:c.vocation});
    assert.equal(delChoice?.main_set_mutated,false);
    choiceAttempted=false;

    const afterChange=await post({action:"player_inventory_get",client_id});
    assert.equal(afterChange.main_set.weapon?.item_key,c.main);
    assert.equal(afterChange.summary.backpack_items,0);
    const persistedFirst=await post({action:"player_session_detail",client_id,session_id:first.session_id});
    assert.equal(JSON.stringify(persistedFirst.loadout_snapshot),snapshot1,
      `${c.vocation}: historical snapshot was modified after removing BP/choice`);

    const second=await post({action:"session_import_save",client_id,
      blocks:{hunt:synthesizedAnalyzer(c,"MAIN")},
      metadata:{
        character:"FE24 Isolated "+c.vocation+" Fixture",server:"RubinOT",
        vocation:c.vocation,level:"700",location:"FE24 synthetic session",
        hunt_key:c.hunt,observation:"SYNTHETIC Main baseline after BP removal",
        tags:["fe24","synthetic","private"],type:"normal",
        favorite:false,publishHighscores:false,rareDrops:"",
      },
    });
    if(second?.session_id)sessions.push(second.session_id);
    assert.equal(second?.status,"parsed");
    assert.equal(second?.community_evidence_written,false);
    const s2=await post({action:"player_session_detail",client_id,session_id:second.session_id});
    assert.equal(s2?.loadout_snapshot?.selection?.weapon,c.main,
      `${c.vocation}: second snapshot must reflect unchanged Main`);
    assert.equal(s2?.hunt_analyse?.xp_gain,9500000);
    assert.equal(s2?.parser?.loadout_snapshot_immutable,true);
    const stillHistorical=await post({action:"player_session_detail",client_id,session_id:first.session_id});
    assert.equal(JSON.stringify(stillHistorical.loadout_snapshot),snapshot1);

    const list=await post({action:"player_session_list",client_id,limit:20});
    assert.equal(list?.summary?.returned,2,
      `${c.vocation}: expect precisely two isolated private saved sessions`);
    assert.ok(list.sessions.some(x=>x.session_id===first.session_id));
    assert.ok(list.sessions.some(x=>x.session_id===second.session_id));
    const otherList=await post({action:"player_session_list",client_id:another_client_id,limit:5});
    assert.equal(otherList?.summary?.returned,0,
      `${c.vocation}: sessions leaked across anonymous client IDs`);

    const comparison=await post({action:"player_session_build_performance",client_id,
      hunt_key:c.hunt,vocation:c.vocation});
    assert.equal(comparison?.methodology?.stage,"player_session_build_performance_v1");
    assert.equal(comparison?.methodology?.causal_effect_inferred,false);
    assert.equal(comparison?.summary?.sessions,2);
    assert.equal(comparison?.summary?.distinct_builds,2,
      `${c.vocation}: BP and Main session snapshots were grouped as same build`);
    const weapons=new Set((comparison.builds??[]).map(x=>x.selection?.weapon));
    assert.ok(weapons.has(c.main)&&weapons.has(c.bp));
    result={
      vocation:c.vocation,weapon_family:c.family,hunt_key:c.hunt,
      main:c.main,bp:c.bp,proficiency_saved:true,
      inventory_isolated:true,main_untouched_by_choice:true,
      private_sessions:2,distinct_historical_builds:2,
      immutable_old_snapshot_after_BP_removal:true,
      other_client_denied:true,
      actual_gameplay:false,raw_analyzer_origin:"synthetic",
      community_evidence_written:false,
    };
  } catch(error) {
    primaryError=error;
  } finally {
    for(const session_id of sessions){
      try {
        const removed=await post({action:"player_session_delete",client_id,session_id});
        assert.equal(removed?.deleted,true,`${c.vocation}: session cleanup failed`);
      } catch(error) {cleanupErrors.push(`session: ${String(error)}`);}
    }
    if(choiceAttempted) {
      try {await post({action:"player_hunt_build_choice_delete",client_id,
        hunt_key:c.hunt,vocation:c.vocation});}
      catch(error){cleanupErrors.push(`choice: ${String(error)}`);}
    }
    for(const inventory_id of inventoryIds){
      try{
        const removed=await post({action:"player_inventory_remove",client_id,inventory_id});
        assert.equal(removed?.deleted,true);
      }catch(error){cleanupErrors.push(`inventory: ${String(error)}`);}
    }
    if(profileAttempted){
      try {
        const removed=await post({action:"player_profile_delete",client_id});
        assert.equal(removed?.deleted,true,`${c.vocation}: profile cleanup failed`);
      }catch(error){cleanupErrors.push(`profile: ${String(error)}`);}
    }
    const checks=await Promise.allSettled([
      post({action:"player_profile_get",client_id}),
      post({action:"player_inventory_get",client_id}),
      post({action:"player_session_list",client_id,limit:5}),
    ]);
    if(checks.some(x=>x.status==="rejected")) {
      cleanupErrors.push(`${c.vocation}: post-cleanup verification API error`);
    }else{
      const [prof,inv,sess]=checks.map(x=>x.value);
      if(prof?.exists!==false || inv?.summary?.main_slots!==0 ||
         inv?.summary?.backpack_items!==0 || sess?.summary?.returned!==0) {
        cleanupErrors.push(`${c.vocation}: leftover profile/inventory/session fixture`);
      }
    }
  }
  if(primaryError||cleanupErrors.length){
    throw new Error(`${c.vocation}: ${primaryError?String(primaryError):"main assertions passed"}; cleanup=${JSON.stringify(cleanupErrors).slice(0,1600)}`);
  }
  return result;
}
for (const c of cases) {
  const row=await testVocation(c);
  results.push(row);
  console.log(`[FE-24] ${c.vocation}: profile/Main/BP/two historical snapshots/privacy/cleanup passed`);
}
assert.equal(results.length,5);
console.log(JSON.stringify({
  status:"ok",stage:"five_vocation_private_profile_inventory_session_snapshot_v1",
  source:"live_deployed_HuntNexus_API",
  catalog_items_real:true,raw_analyzers_synthetic:true,
  user_player_accounts_used:false,real_rubinot_playtests:0,
  temporary_profiles_created_and_deleted:5,
  temporary_sessions_created_and_deleted:10,
  expected_profile_inventory_session_residue:0,
  all_fixture_clients_randomized:true,
  observations_published_to_community:0,results,
},null,2));
