// FE-32 local preview only. All session records are synthetic browser fixtures,
// API writes are blocked, and no real player's private data is read.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const site=process.env.HUNTNEXUS_BASE_URL ?? "http://127.0.0.1:4173";
const target=site.includes("workers.dev") ? "published" : "preview";
const folder=resolve("fe32-session-qa",target);
await mkdir(folder,{recursive:true});
const browser=await chromium.launch({headless:true});
const results=[];
const sessionId="f8359b45-16cf-4bfa-b9ba-f57c9b7da692";
try{
  const ctx=await browser.newContext({viewport:{width:1360,height:900}});
  const page=await ctx.newPage();
  const runtimeErrors=[];
  const imageTraffic=[];
  let interceptedSyntheticSave=null;
  page.on("pageerror",e=>runtimeErrors.push(e.message));
  page.on("response",response=>{
    if(response.url().toLowerCase().includes(".gif")) {
      imageTraffic.push({status:response.status(),url:response.url().slice(0,220)});
    }
  });
  page.on("requestfailed",request=>{
    if(request.url().toLowerCase().includes(".gif")) {
      imageTraffic.push({error:request.failure()?.errorText ?? "unknown",url:request.url().slice(0,220)});
    }
  });
  await page.route("**/api/huntnexus", async route=>{
    let request={};
    try{request=route.request().postDataJSON()}catch{}
    const action=request.action;
    let data={};
    if(action==="player_profile_get")data={exists:true,profile:{vocation:"MS",level:700}};
    else if(action==="player_inventory_get")data={
      main_set:{weapon:{selection_key:"weapon",item_key:"soultainter",item_name:"Soultainter",storage_kind:"main"}},
      backpack:[{selection_key:"weapon",item_key:"amber-wand",item_name:"Amber Wand",storage_kind:"backpack"}],
      summary:{main_slots:1,backpack_items:1},
    };
    else if(action==="player_hunt_build_choice_get")data={
      exists:request.hunt_key==="the-void",
      choice:{option_type:"owned_variant",selection:{weapon:"amber-wand"}},
    };
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
    else if(action==="session_import_save"){
      interceptedSyntheticSave=request;
      return route.fulfill({status:405,contentType:"application/json",body:JSON.stringify({error:"synthetic_write_disabled"})});
    }
    await route.fulfill({status:200,contentType:"application/json",body:JSON.stringify({data})});
  });
  let nav=await page.goto(site+"/session",{waitUntil:"domcontentloaded",timeout:30000});
  assert.ok(nav?.ok());
  await page.getByRole("heading",{name:"Cadastrar uma hunt"}).waitFor();
  // TanStack hydration restores local draft; do not paste before React owns input.
  await page.waitForTimeout(1100);
  await page.locator("textarea").first().fill("Session: 02:03h\nXP Gain: 16,526,550\nXP/h: 8,031,558\nDamage: 3,510,000");
  await page.getByText("2h 03m",{exact:true}).waitFor({timeout:15000});
  await page.getByText(/Bloco não enviado. Elementos e fontes de dano recebido/).waitFor();
  await page.getByText(/Bloco não enviado. Combat Stats permanecerá sem dados/).waitFor();
  await page.getByText("Setup usado na sessão").waitFor();
  const location=page.getByPlaceholder("Selecione no catálogo ou digite o nome da hunt");
  await location.focus();
  await page.getByRole("button",{name:/The Void \(Zao\)/}).waitFor({timeout:15000});
  await page.getByRole("button",{name:/The Void \(Zao\)/}).click();
  const setup=page.getByTestId("session-setup-mode");
  await setup.waitFor({timeout:15000});
  await page.getByText("Build da hunt disponível").waitFor({timeout:15000});
  await setup.selectOption("hunt");
  await page.getByTestId("session-setup-items").getByTitle("Amber Wand").waitFor();
  await setup.selectOption("main");
  await page.getByTestId("session-setup-items").getByTitle("Soultainter").waitFor();
  await setup.selectOption("none");
  await page.getByText(/Você escolheu não registrar setup/).waitFor();
  assert.equal(await page.getByTestId("session-setup-items").count(),0);
  await setup.selectOption("auto");
  await page.getByTestId("session-setup-items").getByTitle("Amber Wand").waitFor();
  await page.screenshot({path:resolve(folder,"fe33-session-hunt-build-selected.png"),fullPage:true});
  await setup.selectOption("main");
  await page.getByTestId("session-setup-items").getByTitle("Soultainter").waitFor();
  await page.screenshot({path:resolve(folder,"fe33-session-main-selected.png"),fullPage:true});
  // Confirm metadata, without writing to any real user/session backend.
  await page.getByRole("button",{name:"Salvar hunt",exact:true}).click();
  await page.getByText("synthetic_write_disabled").waitFor({timeout:15000});
  assert.equal(interceptedSyntheticSave?.metadata?.setupMode,"main");
  assert.equal(interceptedSyntheticSave?.metadata?.hunt_key,"the-void");
  await page.screenshot({path:resolve(folder,"fe32-session-import-preview.png"),fullPage:true});
  results.push({case:"session_import_preview",result:"PASS",duration:"02:03h",missing_damage_and_misc_explicit:true,hunt_catalog_on_focus:true});
  nav=await page.goto(site+"/sessions",{waitUntil:"domcontentloaded",timeout:30000});
  assert.ok(nav?.ok());
  await page.getByText("Duração: 2h 03m").waitFor({timeout:15000});
  await page.getByRole("button",{name:"Misc",exact:true}).click();
  await page.getByText("blue crystal shard",{exact:true}).waitFor();
  await page.getByText("02:03h",{exact:true}).waitFor();
  await page.waitForTimeout(4500); // Allow live external GIFs to load or fail.
  const imageNames=await page.locator('img[src*="Especial:Redirect/file/"]').evaluateAll(imgs=>
    imgs.map(img=>({name:img.alt,src:img.getAttribute("src"),complete:img.complete,loaded:img.naturalWidth>0})));
  assert.ok(imageNames.some(x=>x.name==="blue crystal shard"&&x.src?.includes("Blue_Crystal_Shard.gif")),
    "Loot must use source-backed Blue_Crystal_Shard.gif title");
  assert.equal(imageNames.filter(x=>x.loaded).length,3,
    "The three TibiaWiki test item GIFs must actually decode in a browser; a valid filename alone is insufficient. Traffic=" +
    JSON.stringify(imageTraffic.slice(-15)));
  await page.screenshot({path:resolve(folder,"fe32-session-misc-loot.png"),fullPage:true});
  assert.deepEqual(runtimeErrors,[],"Browser must not raise runtime exceptions");
  results.push({case:"saved_session_read_with_synthetic_fixture",result:"PASS",
    raw_misc_duration_visible:true,canonical_sprite_filenames_verified:true,
    observed_image_loads:imageNames.filter(x=>x.loaded).length,
    image_files:imageNames.map(x=>({name:x.name,loaded:x.loaded})),
    image_traffic:imageTraffic.slice(-15)});
  console.log(JSON.stringify({status:"ok",stage:"fe32_session_browser_preview",
    real_player_session_used:false,real_gameplay_proven:false,real_api_writes:false,
    results},null,2));
}finally{await browser.close();}
