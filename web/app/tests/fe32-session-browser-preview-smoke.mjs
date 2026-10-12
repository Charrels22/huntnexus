// FE-32 local preview only. All session records are synthetic browser fixtures,
// API writes are blocked, and no real player's private data is read.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const site=process.env.HUNTNEXUS_BASE_URL ?? "http://127.0.0.1:4173";
const folder=resolve("fe32-session-qa");
await mkdir(folder,{recursive:true});
const browser=await chromium.launch({headless:true});
const results=[];
const sessionId="f8359b45-16cf-4bfa-b9ba-f57c9b7da692";
try{
  const ctx=await browser.newContext({viewport:{width:1360,height:900}});
  const page=await ctx.newPage();
  const runtimeErrors=[];
  page.on("pageerror",e=>runtimeErrors.push(e.message));
  await page.route("**/api/huntnexus", async route=>{
    let request={};
    try{request=route.request().postDataJSON()}catch{}
    const action=request.action;
    let data={};
    if(action==="player_profile_get")data={exists:false,profile:null};
    else if(action==="player_inventory_get")data={main_set:{},backpack:[],summary:{main_slots:0,backpack_items:0}};
    else if(action==="search_hunts")data=[{hunt_key:"the-void",name:"The Void (Zao)",city:"Zao",vocation:"All",observed_sessions:0}];
    else if(action==="player_session_list")data={sessions:[{session_id:sessionId,hunt_name:"The Void (Zao)",vocation:"MS",status:"parsed",duration_seconds:7380,xp_per_hour:8031558}]};
    else if(action==="player_session_detail")data={
      session:{session_id:sessionId,hunt_name_raw:"The Void (Zao)",vocation:"MS",hunt_key:null},
      hunt_analyse:{duration_seconds:7380,xp_per_hour:8031558,balance_value:727000,total_kills:944,total_damage:3510000,total_healing:1300000},
      misc:{looted_items:[{item_name:"blue crystal shard",amount:35},{item_name:"blue gem",amount:3},{item_name:"collar of green plasma",amount:2}],
        combat_stats:[{stat_key:"session",stat_name_raw:"Session",numeric_value:null,raw_value:"02:03h",unit:"raw"},{stat_key:"critical_hit",stat_name_raw:"Critical Hit",numeric_value:393,raw_value:"393",unit:"raw"}],
        creatures:[]},
      damage:{total_damage:3510000,incoming_total_damage:null,incoming_by_element:[],incoming_by_source:[],charm_damage_available:false},
      party_hunt:{players:[],party_size:1},
      availability:{hunt_analyse:true,misc:true,damage:true,party_hunt:false},
      validation:{warnings:[]},parser:{version:"session_parser_v2",raw_blocks_preserved:true,community_evidence_written:false},
      loadout_snapshot:{},
    };
    else if(action==="session_import_save")return route.fulfill({status:405,contentType:"application/json",body:JSON.stringify({error:"synthetic_write_disabled"})});
    await route.fulfill({status:200,contentType:"application/json",body:JSON.stringify({data})});
  });
  let nav=await page.goto(site+"/session",{waitUntil:"domcontentloaded",timeout:30000});
  assert.ok(nav?.ok());
  await page.getByRole("heading",{name:"Cadastrar uma hunt"}).waitFor();
  await page.locator("textarea").first().fill("Session: 02:03h\nXP Gain: 16,526,550\nXP/h: 8,031,558\nDamage: 3,510,000");
  await page.getByText("2h 03m",{exact:true}).waitFor({timeout:15000});
  await page.getByText(/Bloco não enviado. Elementos e fontes de dano recebido/).waitFor();
  await page.getByText(/Bloco não enviado. Combat Stats permanecerá sem dados/).waitFor();
  await page.getByText("Setup usado na sessão").waitFor();
  const location=page.getByPlaceholder("Selecione no catálogo ou digite o nome da hunt");
  await location.focus();
  await page.getByRole("button",{name:/The Void \(Zao\)/}).waitFor({timeout:15000});
  await page.screenshot({path:resolve(folder,"fe32-session-import-preview.png"),fullPage:true});
  results.push({case:"session_import_preview",result:"PASS",duration:"02:03h",missing_damage_and_misc_explicit:true,hunt_catalog_on_focus:true});
  nav=await page.goto(site+"/sessions",{waitUntil:"domcontentloaded",timeout:30000});
  assert.ok(nav?.ok());
  await page.getByText("Duração: 2h 03m").waitFor({timeout:15000});
  await page.getByRole("button",{name:"Misc",exact:true}).click();
  await page.getByText("blue crystal shard",{exact:true}).waitFor();
  await page.getByText("02:03h",{exact:true}).waitFor();
  const imageNames=await page.locator('img[src*="Especial:Redirect/file/"]').evaluateAll(imgs=>
    imgs.map(img=>({name:img.alt,src:img.getAttribute("src"),complete:img.complete,loaded:img.naturalWidth>0})));
  assert.ok(imageNames.some(x=>x.name==="blue crystal shard"&&x.src?.includes("Blue_Crystal_Shard.gif")),
    "Loot must use source-backed Blue_Crystal_Shard.gif title");
  await page.screenshot({path:resolve(folder,"fe32-session-misc-loot.png"),fullPage:true});
  assert.deepEqual(runtimeErrors,[],"Browser must not raise runtime exceptions");
  results.push({case:"saved_session_read_with_synthetic_fixture",result:"PASS",
    raw_misc_duration_visible:true,canonical_sprite_filenames_verified:true,
    observed_image_loads:imageNames.filter(x=>x.loaded).length,
    image_files:imageNames.map(x=>({name:x.name,loaded:x.loaded}))});
  console.log(JSON.stringify({status:"ok",stage:"fe32_session_browser_preview",
    real_player_session_used:false,real_gameplay_proven:false,real_api_writes:false,
    results},null,2));
}finally{await browser.close();}
