// FE-26. Rejection/identity matrix for honest, owned build choices.
// Uses randomized guest IDs and real item keys; does NOT generate fake community
// sessions or claim a player-tested RubinOT set.
import assert from "node:assert/strict";

const endpoint=process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const cases=[
  {vocation:"EK",wrongVocation:"ED",hunt:"cobra-bastion",
    main:{weapon:"soulshredder",head:"falcon-coif",body:"falcon-plate"},
    alternative:{weapon:"gnome-sword",head:"cobra-hood",body:"lion-plate"}},
  {vocation:"RP",wrongVocation:"MS",hunt:"iksupan-last-stand",
    main:{weapon:"soulbleeder",head:"alicorn-headguard",body:"gnome-armor",offhand:"quiver",ammunition:"diamond-arrow"},
    alternative:{weapon:"eldritch-bow",head:"falcon-coif",body:"soulshell",offhand:"eldritch-quiver",ammunition:"crystalline-arrow"}},
  {vocation:"ED",wrongVocation:"EK",hunt:"nimmersatts-breeding-ground",
    main:{weapon:"soulhexer",head:"gnome-helmet",body:"soulshroud"},
    alternative:{weapon:"amber-rod",head:"falcon-circlet",body:"frostmind-raiment"}},
  {vocation:"MS",wrongVocation:"EM",hunt:"podzilla",
    main:{weapon:"soultainter",head:"gnome-helmet",body:"soulmantle"},
    alternative:{weapon:"amber-wand",head:"eldritch-cowl",body:"dawnfire-sherwani"}},
  {vocation:"EM",wrongVocation:"RP",hunt:"grounds-of-undeath",
    main:{weapon:"soulkamas",head:"dark-vision-bandana",body:"soulgarb"},
    alternative:{weapon:"nunchaku-of-destruction",head:"demon-mengu",body:"naga-tanko"}},
];

async function post(body){
  const response=await fetch(endpoint,{
    method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify(body),signal:AbortSignal.timeout(30000),
  });
  const result=await response.json().catch(()=>({}));
  assert.ok(response.ok,`HTTP ${response.status} / ${body.action}: ${JSON.stringify(result).slice(0,500)}`);
  return result.data;
}
async function testOne(c){
  const id=crypto.randomUUID();
  const foreign=crypto.randomUUID();
  const savedIds=[];
  const errors=[];
  let choiceAttempted=false;
  let stage="init",fatal=null;
  let response=null;
  try {
    stage="owned inventory";
    for(const [slot,item_key] of [...Object.entries(c.main),...Object.entries(c.alternative)]){
      const r=await post({action:"player_inventory_put",client_id:id,
        storage_kind:c.main[slot]===item_key?"main":"backpack",item_key,quantity:1});
      assert.equal(r?.saved,true,`${c.vocation}: inventory put ${slot}:${item_key}`);
      if(r.inventory_id)savedIds.push(r.inventory_id);
      assert.equal(r.selection_key,slot);
    }
    const main=await post({action:"player_inventory_get",client_id:id});
    assert.equal(main?.summary?.main_slots,Object.keys(c.main).length);
    assert.equal(main?.summary?.backpack_items,Object.keys(c.alternative).length);
    const foreignInventory=await post({action:"player_inventory_get",client_id:foreign});
    assert.equal(foreignInventory?.summary?.main_slots,0);

    const save=async ({option_type="owned_variant",selection=c.alternative,
       level=700,vocation=c.vocation,client_id=id}={})=>{
      choiceAttempted=true;
      return post({
        action:"player_hunt_build_choice_save",client_id,
        hunt_key:c.hunt,vocation,level,selection,option_type,
        replacements:[],
      });
    };
    const get=async (vocation=c.vocation,client_id=id)=>post({
      action:"player_hunt_build_choice_get",client_id,
      hunt_key:c.hunt,vocation,
    });
    const assertRejected=async (params,error,status=null)=>{
      const r=await save(params);
      assert.notEqual(r?.saved,true,`${c.vocation}: falsely accepted ${error}`);
      assert.equal(r?.error,error,`${c.vocation}: expected rejection ${error}`);
      if(status!==null)assert.equal(r?.validation?.status,status,
        `${c.vocation}: compatibility status mismatch`);
      return r;
    };
    stage="Main identity";
    await assertRejected({option_type:"main",selection:c.alternative},
      "main_choice_must_match_main_set");
    await assertRejected({option_type:"main",selection:{weapon:c.main.weapon}},
      "main_choice_must_match_main_set");
    assert.equal((await get())?.exists,false,
      "spoofed/partial Main must not become a saved choice");

    const actualMain=await save({option_type:"main",selection:c.main});
    assert.equal(actualMain?.saved,true,`${c.vocation}: actual Main rejected`);
    assert.equal(actualMain?.main_set_mutated,false);
    let persisted=await get();
    assert.equal(persisted?.choice?.option_type,"main");
    assert.deepEqual(persisted?.choice?.selection,c.main);

    stage="reject overwrites";
    await assertRejected({option_type:"main",selection:c.alternative},
      "main_choice_must_match_main_set");
    await assertRejected({option_type:"owned_variant",selection:c.alternative,level:1},
      "invalid_loadout","blocked");
    // Zod rejects invalid option_type *before* calling SQL (HTTP 400).
    // Keep this as a strict transport-schema assertion, not a SQL result.
    const invalidTypeResponse=await fetch(endpoint,{
      method:"POST",headers:{"content-type":"application/json"},
      body:JSON.stringify({
        action:"player_hunt_build_choice_save",client_id:id,
        hunt_key:c.hunt,vocation:c.vocation,level:700,
        selection:c.alternative,option_type:"invalid",replacements:[],
      }),signal:AbortSignal.timeout(30000),
    });
    const invalidTypeJson=await invalidTypeResponse.json();
    assert.equal(invalidTypeResponse.status,400,
      "invalid option type should fail request schema");
    assert.equal(invalidTypeJson?.error,"invalid_input");
    assert.match(invalidTypeJson?.detail??"",/option_type/);
    await assertRejected({selection:{...c.alternative,head:c.alternative.weapon}},
      "selection_contains_non_owned_item");
    await assertRejected({selection:{...c.alternative,weapon:"unowned-fe26-item"}},
      "selection_contains_non_owned_item");
    persisted=await get();
    assert.equal(persisted?.choice?.option_type,"main");
    assert.deepEqual(persisted?.choice?.selection,c.main);
    const wrongVocation=await assertRejected({
      vocation:c.wrongVocation,selection:c.alternative},"invalid_loadout","blocked");
    assert.ok(wrongVocation.validation?.slot_evaluations?.some(x=>x.status==="blocked"),
      "wrong vocation must expose a blocked item");
    assert.equal((await get(c.wrongVocation))?.exists,false);

    stage="isolation and variant";
    await assertRejected({client_id:foreign,selection:c.alternative},
      "selection_contains_non_owned_item");
    assert.equal((await get(c.vocation,foreign))?.exists,false);
    const variant=await save({option_type:"owned_variant",selection:c.alternative});
    assert.equal(variant?.saved,true);
    assert.equal(variant?.main_set_mutated,false);
    persisted=await get();
    assert.equal(persisted?.choice?.option_type,"owned_variant");
    assert.deepEqual(persisted?.choice?.selection,c.alternative);
    await assertRejected({option_type:"main",selection:c.alternative},
      "main_choice_must_match_main_set");
    persisted=await get();
    assert.equal(persisted?.choice?.option_type,"owned_variant");
    assert.deepEqual(persisted?.choice?.selection,c.alternative,
      "failed Main spoof should preserve existing saved variant");
    const unchanged=await post({action:"player_inventory_get",client_id:id});
    for(const [slot,key] of Object.entries(c.main)){
      assert.equal(unchanged?.main_set?.[slot]?.item_key,key);
    }
    response={
      vocation:c.vocation,
      main_slots:Object.keys(c.main).length,
      owned_bp_slots:Object.keys(c.alternative).length,
      rejected_cases:10,
      actual_main_accepted:true,
      exact_main_label_enforced:true,
      blocked_other_vocation:c.wrongVocation,
      underleveled_selection_rejected:true,
      rejected_writes_preserve_previous_choice:true,
      nonowned_cross_client_rejected:true,
      main_untouched:true,
    };
  }catch(e){fatal=e;}
  finally {
    if(choiceAttempted){
      try{
        const d=await post({action:"player_hunt_build_choice_delete",
          client_id:id,hunt_key:c.hunt,vocation:c.vocation});
        assert.equal(d.main_set_mutated,false);
      }catch(e){errors.push("choice:"+String(e));}
    }
    for(const inventory_id of savedIds){
      try{
        const d=await post({action:"player_inventory_remove",client_id:id,inventory_id});
        assert.equal(d?.deleted,true);
      }catch(e){errors.push("inventory:"+String(e));}
    }
    try{
      const [inventory,choice]=await Promise.all([
        post({action:"player_inventory_get",client_id:id}),
        post({action:"player_hunt_build_choice_get",client_id:id,
          hunt_key:c.hunt,vocation:c.vocation}),
      ]);
      assert.equal(inventory?.summary?.main_slots,0);
      assert.equal(inventory?.summary?.backpack_items,0);
      assert.equal(choice?.exists,false);
    }catch(e){errors.push("verification:"+String(e));}
  }
  if(fatal||errors.length){
    throw new Error(`${c.vocation} stage=${stage}: ${String(fatal??"passed")} / cleanup=${errors.join(";").slice(0,1000)}`);
  }
  return response;
}

const results=[];
for(const c of cases){
  const row=await testOne(c);
  results.push(row);
  console.log(`[FE-26] ${c.vocation} main identity/10 rejected choices/isolation/cleanup OK`);
}
assert.equal(results.length,5);
console.log(JSON.stringify({
  status:"ok",stage:"fe26_five_vocation_choice_guards_v1",
  live_api:true,temporary_clients:5,
  actual_rubinot_players:0,raw_gameplay_analysers:0,
  sessions_saved:0,community_published:0,
  residual_test_inventory_expected:0,
  main_spoof_rejection_applied:true,
  results,
},null,2));
