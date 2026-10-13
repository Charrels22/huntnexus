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
  let interceptedSyntheticReparse=null;
  let interceptedSyntheticRestore=null;
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
    else if(action==="player_session_integrity_review")data={
      session_id:sessionId,
      stage:"fe37_session_integrity_readonly",
      blocks:[
        {key:"hunt",status:"recognized",supplied:true,observed_fields:7,note:"Métricas principais registradas"},
        {key:"input",status:"partial",supplied:true,observed_fields:2,note:"Há dados observados, mas o bloco é parcial ou requer revisão"},
        {key:"misc",status:"recognized",supplied:true,observed_fields:2,note:"Combat Stats registrados"},
        {key:"party",status:"missing",supplied:false,observed_fields:0,note:"Party Hunt não foi fornecido"},
      ],
      storage_consistency:{status:"consistent",checked_sections:6,mismatched_sections:[]},
      parser_version:"session_parser_v2",
      current_parser_drift:{status:"same",differing_sections:[],not_a_persistence_error:true},
      original_blocks_preserved:true,contains_raw_analyzer_text:false,
      requires_real_export_acceptance:true,
    };
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
    else if(action==="player_session_reparse_preview")data={
      session_id:sessionId,
      previous_parser_version:"session_parser_v1",
      proposed_parser_version:"session_parser_v2",
      snapshot_source:"not_available",
      raw_blocks_preserved:true,loadout_snapshot_preserved:true,
      expected_fingerprint:"1".repeat(32),
      review:{
        changed:true,safe_to_apply:true,no_raw_text_exposed:true,
        changes:[{key:"hunt_analyse.duration_seconds",label:"Duração (segundos)",
          before:null,after:7380,regression:false}],
        unchanged_metric_count:25,warnings_before:[],warnings_after:[],
        regression_reasons:[],
      },
    };
    else if(action==="player_session_reparse_apply"){
      interceptedSyntheticReparse=request;
      data={
        updated:true,session_id:sessionId,
        new_parser_version:"session_parser_v2",
        raw_blocks_preserved:true,loadout_snapshot_preserved:true,
        original_raw_blocks_preserved:true,
        original_loadout_snapshot_preserved:true,
      };
    }
    else if(action==="player_session_revision_list")data={
      session_id:sessionId,
      revisions:[{revision_id:"bb8a1b54-b286-4c52-a562-85ef906d948a",
        revised_at:"2026-10-12T19:30:00Z",
        previous_parser_version:"session_parser_v1",
        next_parser_version:"session_parser_v2"}],
    };
    else if(action==="player_session_restore_preview")data={
      session_id:sessionId,
      revision_id:"bb8a1b54-b286-4c52-a562-85ef906d948a",
      current_parser_version:"session_parser_v2",
      target_parser_version:"session_parser_v1",
      snapshot_source:"main_default",
      expected_fingerprint:"2".repeat(32),
      raw_blocks_preserved:true,
      loadout_snapshot_preserved:true,
      data_loss_warning:true,
      review:{
        changed:true,
        changes:[{key:"hunt_analyse.duration_seconds",
          label:"Duração (segundos)",before:7380,after:null,regression:true}],
        warnings_before:[],warnings_after:[],
        regression_reasons:["Perda de dado antes conhecido em Duração (segundos)"],
        no_raw_text_exposed:true,
      },
    };
    else if(action==="player_session_restore_apply"){
      interceptedSyntheticRestore=request;
      data={restored:true,session_id:sessionId,parser_version:"session_parser_v1",
        raw_blocks_preserved:true,loadout_snapshot_preserved:true,
        undo_revision_id:"5b8b6ff4-c22c-4265-b38c-29d5f09dfc88"};
    }
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
  // FE-36: verify observed Input totals aren't silently treated as Misc.
  await page.getByRole("button",{name:"Input Analyzer",exact:true}).click();
  await page.locator("textarea").first().fill(
    "Received Damage Total: 12,000\nMax-DPS: 345");
  await page.getByText(/Total ou Max-DPS reconhecido/).waitFor({timeout:12000});
  await page.getByTestId("session-input-recognized-preview").getByText(/Total recebido:/).waitFor();
  await page.locator("textarea").first().fill(
    "Total: 12,000\nMax-DPS: 345\nDamage Types:\nFire: 7,000 (58.3%)" +
    "\nPhysical: 5,000 (41.7%)\nDamage Sources:\nsynthetic spectre: 12,000 (100%)");
  await page.getByText("2 elementos e 1 fontes reconhecidos.").waitFor({timeout:12000});
  await page.getByTestId("session-input-recognized-preview").getByText("synthetic spectre").waitFor();

  await page.getByRole("button",{name:"Miscellaneous",exact:true}).click();
  await page.locator("textarea").first().fill(
    "Session: 00:30h\nCritical Hit: 393\nMana Gain: 1,234\nLife Gain: 2,345");
  await page.getByTestId("session-misc-recognized-preview").getByText("Critical Hit").waitFor();
  await page.getByTestId("session-misc-recognized-preview").getByText("Mana Gain").waitFor();
  await page.screenshot({path:resolve(folder,"fe36-input-misc-observed-before-save.png"),fullPage:true});
  // Restore missing-block fixture to keep earlier FE-32/33 assertions isolated.
  await page.locator("textarea").first().fill("");
  await page.getByRole("button",{name:"Input Analyzer",exact:true}).click();
  await page.locator("textarea").first().fill("");
  await page.getByRole("button",{name:"Hunt Analyzer",exact:true}).click();
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
  results.push({case:"session_import_preview",result:"PASS",duration:"02:03h",missing_damage_and_misc_explicit:true,hunt_catalog_on_focus:true,
    fe36_optional_input_breakdown_and_combat_stats_previewed:true});
  nav=await page.goto(site+"/sessions",{waitUntil:"domcontentloaded",timeout:30000});
  assert.ok(nav?.ok());
  await page.getByText("Duração: 2h 03m").waitFor({timeout:15000});
  await page.getByTestId("session-integrity-report").waitFor({timeout:15000});
  await page.getByTestId("session-integrity-input").getByText("Parcial",{exact:true}).waitFor();
  await page.getByTestId("session-integrity-misc").getByText("Reconhecido").waitFor();
  await page.getByTestId("session-integrity-party").getByText("Não enviado").waitFor();
  await page.getByTestId("session-integrity-storage-status").getByText(/coerentes/).waitFor();
  await page.getByTestId("session-integrity-parser-drift").getByText(/sem diferenças observadas/).waitFor();
  await page.screenshot({path:resolve(folder,"fe37-session-integrity-private-report.png"),fullPage:true});
  await page.getByTestId("session-reparse-compare").click();
  await page.getByTestId("session-reparse-diff").waitFor({timeout:15000});
  await page.getByText("Duração (segundos)",{exact:true}).waitFor();
  const apply=page.getByTestId("session-reparse-apply");
  assert.equal(await apply.isDisabled(),true,"Apply must require explicit confirmation checkbox");
  await page.getByTestId("session-reparse-confirm").check();
  assert.equal(await apply.isEnabled(),true);
  page.once("dialog",dialog=>dialog.accept());
  await apply.click();
  await page.getByText(/Sessão reinterpretada. Texto original, setup histórico/).waitFor({timeout:15000});
  assert.equal(interceptedSyntheticReparse?.action,"player_session_reparse_apply");
  assert.equal(interceptedSyntheticReparse?.session_id,sessionId);
  assert.equal(interceptedSyntheticReparse?.expected_fingerprint,"1".repeat(32));
  assert.equal(interceptedSyntheticReparse?.confirm,true);
  await page.screenshot({path:resolve(folder,"fe34-session-reparse-applied-synthetic.png"),fullPage:true});
  // FE-35: historical version only for this synthetic session; no real writes.
  await page.getByTestId("session-restore-list").click();
  await page.getByTestId("session-restore-revisions").waitFor({timeout:15000});
  await page.getByTestId("session-restore-preview-0").click();
  await page.getByTestId("session-restore-diff").waitFor({timeout:15000});
  const restoreApply=page.getByTestId("session-restore-apply");
  assert.equal(await restoreApply.isDisabled(),true);
  await page.getByTestId("session-restore-confirm").check();
  assert.equal(await restoreApply.isDisabled(),true,
    "A potentially regressive restore must require separate loss acknowledgement");
  await page.getByTestId("session-restore-accept-loss").check();
  assert.equal(await restoreApply.isEnabled(),true);
  await page.screenshot({path:resolve(folder,"fe35-revision-diff-before-restore.png"),fullPage:true});
  page.once("dialog",dialog=>dialog.accept());
  await restoreApply.click();
  await page.getByText(/Interpretação anterior restaurada/).waitFor({timeout:15000});
  assert.equal(interceptedSyntheticRestore?.action,"player_session_restore_apply");
  assert.equal(interceptedSyntheticRestore?.session_id,sessionId);
  assert.equal(interceptedSyntheticRestore?.confirm,true);
  assert.equal(interceptedSyntheticRestore?.accept_regressions,true);
  assert.equal(interceptedSyntheticRestore?.expected_fingerprint,"2".repeat(32));
  await page.screenshot({path:resolve(folder,"fe35-restore-confirmed-synthetic.png"),fullPage:true});
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
    fe34_reparse_preview_confirmed_without_real_write:true,
    fe35_restore_preview_double_confirmed_without_real_write:true,
    fe37_owner_scoped_import_integrity_rendered_without_raw_blocks:true,
    observed_image_loads:imageNames.filter(x=>x.loaded).length,
    image_files:imageNames.map(x=>({name:x.name,loaded:x.loaded})),
    image_traffic:imageTraffic.slice(-15)});
  console.log(JSON.stringify({status:"ok",stage:"fe32_session_browser_preview",
    real_player_session_used:false,real_gameplay_proven:false,real_api_writes:false,
    results},null,2));
}finally{await browser.close();}
