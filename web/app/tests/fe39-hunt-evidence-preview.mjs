import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const site=process.env.HUNTNEXUS_BASE_URL??"https://huntnexus.charr3ls22.workers.dev";
const target=site.includes("workers.dev")?"published":"preview";
const output=resolve("fe39-hunt-evidence-qa",target);
await mkdir(output,{recursive:true});
const browser=await chromium.launch({headless:true,args:["--no-sandbox"]});
const page=await browser.newPage({viewport:{width:1300,height:900}});
let missing=false;
const captured=[];
page.on("pageerror",e=>captured.push(String(e)));
await page.route("**/api/huntnexus",async route=>{
  let req={};
  try {req=route.request().postDataJSON()??{};}catch{}
  const proof=missing?null:{
    hunt_key:"cobra-bastion",
    catalog:{fixed_spawn:true,planner_eligible:true,catalog_role:"fixed_hunt"},
    source:{name:"Synthetic source provider",tier:"B",layer:"tibia_factual",
      url:"https://example.org/",snapshot_recorded:true,
      source_last_updated:"2026-08-31T03:03:49.642372Z"},
    coverage:{creature_count:4,creatures_with_elements:4,creatures_with_detail:4,
      creatures_with_abilities:3,creatures_with_loot:4,
      elements_complete:true,creature_detail_complete:true,
      abilities_complete:false,loot_complete:true},
    source_core_complete:false,
    methodology:{stage:"hunt_evidence_context_fe39_v1"},
  };
  if(req.action==="hunt_detail"){
    const data={
      factual:{hunt:{key:"cobra-bastion",name:"Cobra Bastion",city:"Ankrahmun",
        location:"Northern desert",level_knights:"350",level_paladins:"300",level_mages:"300"},
        monsters:[],elements:[]},
      observed:{performance:{session_count:0}},
      vocation_observed:{sample:{sourced_session_count:0}},
      evidence:proof,media:{},defensive:{elements:[]},imbuements:{},
    };
    return route.fulfill({status:200,contentType:"application/json",body:JSON.stringify({data})});
  }
  return route.fulfill({status:200,contentType:"application/json",body:JSON.stringify({data:{}})});
});
try{
  let r=await page.goto(site+"/hunts/cobra-bastion",{waitUntil:"domcontentloaded",timeout:30000});
  assert.ok(r?.ok(),"Hunt detail entrypoint");
  await page.getByTestId("hunt-factual-evidence").waitFor({timeout:20000});
  await page.getByTestId("hunt-evidence-source-name").getByText("Synthetic source provider").waitFor();
  await page.getByTestId("hunt-source-core-status").getByText("Cobertura factual parcial").waitFor();
  await page.getByTestId("hunt-coverage-abilities").getByText("3/4").waitFor();
  await page.getByTestId("hunt-coverage-elements").getByText("4/4").waitFor();
  const separation=await page.getByTestId("hunt-community-evidence-separation").innerText();
  assert.match(separation,/0/,"Zero observed samples must be shown explicitly");
  assert.match(separation,/Sem sessões de desempenho observadas/);
  await page.screenshot({path:resolve(output,"partial-source-no-sessions.png"),fullPage:true});
  missing=true;
  await page.reload({waitUntil:"domcontentloaded",timeout:30000});
  await page.getByTestId("hunt-source-core-status").getByText("Evidência factual indisponível").waitFor({timeout:20000});
  await page.getByTestId("hunt-coverage-abilities").getByText("Não informado").waitFor();
  assert.equal(await page.getByTestId("hunt-evidence-source-name").innerText(),"Fonte não identificada");
  await page.screenshot({path:resolve(output,"missing-source-not-inferred.png"),fullPage:true});
  assert.deepEqual(captured,[]);
  console.log(JSON.stringify({status:"ok",stage:"fe39_hunt_evidence_visual",
    target,source_fixture_only:true,no_player_data_used:true,
    incomplete_dimensions_labeled:true,zero_samples_not_fabricated:true,
    absent_provenance_not_inferred:true},null,2));
}finally{await browser.close();}
