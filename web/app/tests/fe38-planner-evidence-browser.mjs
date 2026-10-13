import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const site=process.env.HUNTNEXUS_BASE_URL ?? "https://huntnexus.charr3ls22.workers.dev";
const target=site.includes("workers.dev")?"published":"preview";
const directory=resolve("fe38-planner-qa",target);
await mkdir(directory,{recursive:true});
const browser=await chromium.launch({headless:true,args:["--no-sandbox"]});
const page=await browser.newPage({viewport:{width:1380,height:900}});
const pageErrors=[];
page.on("pageerror",e=>pageErrors.push(String(e)));
const syntheticHunt={
  hunt_key:"synthetic-source-backed-hunt",
  hunt_name:"Synthetic source fixture",
  session_count:1,
  confidence_score:0.92, // internal ranking heuristic, NOT a 92% statistical certainty.
  median_xp_per_hour:1520000,
  median_balance_per_hour:850000,
};
let queries=[];
await page.route("**/api/huntnexus",async route=>{
  let request={};
  try{request=route.request().postDataJSON()??{}}catch{}
  const action=request.action;
  if(action==="player_profile_get"){
    return route.fulfill({status:200,contentType:"application/json",
      body:JSON.stringify({data:{exists:false,profile:null}})});
  }
  if(action==="planner_personalized"){
    queries.push({
      vocation:request.vocation,level:request.level,
      objective:request.objective,party_size:request.party_size,
    });
    const empty=request.vocation==="ED";
    const evidence={
      source_layer:"community_observations",
      observed_session_count:1,
      limited_sample:true,
      confidence_index_is_statistical_probability:false,
      ranking_is_experimental:true,
      private_sessions_do_not_change_rank:true,
    };
    const data={
      query:{vocation:request.vocation,level:request.level,
        objective:request.objective,party_size:request.party_size},
      results:empty?[]:[{
        hunt:syntheticHunt, hunt_rank_order:1,
        evidence, owned_builds:null, saved_owned_choice:{exists:false,choice:null},
        personal_performance:{summary:{sessions:0}},
      }],
      summary:{ranked_hunts:empty?0:1,observed_sessions_in_displayed_hunts:empty?0:1,
        hunts_with_limited_sample:empty?0:1},
      methodology:{experimental_observational_ranking:true,
        confidence_index_is_not_a_statistical_probability:true,
        no_results_does_not_mean_no_hunts_exist:true},
    };
    return route.fulfill({status:200,contentType:"application/json",body:JSON.stringify({data})});
  }
  // Prevent any external writes or unrelated private reads in this browser fixture.
  return route.fulfill({status:200,contentType:"application/json",
    body:JSON.stringify({data:{}})});
});
try{
  const navigation=await page.goto(site+"/planner",{waitUntil:"domcontentloaded",timeout:30000});
  assert.ok(navigation?.ok(),site+" must serve the planner");
  await page.getByRole("heading",{name:"Monte o contexto do seu personagem"}).waitFor({timeout:18000});
  // Avoid submitting before React hydration owns controls.
  await page.waitForTimeout(1000);
  await page.getByRole("button",{name:"Encontrar hunts"}).click();
  await page.getByTestId("planner-observed-results").waitFor({timeout:20000});
  await page.getByRole("heading",{name:"Hunts com desempenho observado"}).waitFor();
  await page.getByTestId("planner-observational-disclosure").getByText(/não é uma probabilidade estatística/).waitFor();
  await page.getByTestId("planner-evidence-status").getByText("Amostra limitada — comparar com cautela").waitFor();
  await page.getByText("Sessões",{exact:true}).waitFor();
  assert.equal(await page.getByText("Conf.",{exact:true}).count(),0,
    "Raw confidence heuristic must not be displayed as a percentage.");
  assert.equal(queries.at(-1)?.vocation,"EK");
  await page.screenshot({path:resolve(directory,"planner-observed-one-session.png"),fullPage:true});

  await page.getByLabel("Vocação").selectOption("ED");
  assert.equal(await page.getByTestId("planner-observed-results").count(),0,
    "Changing filters must invalidate previous ranking and its hunt links.");
  await page.getByRole("button",{name:"Encontrar hunts"}).click();
  await page.getByTestId("planner-no-observed-evidence").waitFor({timeout:20000});
  await page.getByText("Sem sessões observadas para esses filtros").waitFor();
  await page.getByText(/Nenhum XP\/h ou profit foi estimado/).waitFor();
  assert.equal(queries.at(-1)?.vocation,"ED");
  assert.equal(await page.getByRole("link",{name:"Ver hunt e setup"}).count(),0);
  await page.screenshot({path:resolve(directory,"planner-no-observed-evidence.png"),fullPage:true});
  assert.deepEqual(pageErrors,[],"Browser should not throw script errors.");
  console.log(JSON.stringify({status:"ok",stage:"fe38_planner_evidence_browser",
    target,source_kind:"synthetic_fixture",one_session_warning_visible:true,
    false_confidence_percent_removed:true,filter_change_clears_results:true,
    zero_observations_show_empty_state:true,page_errors:pageErrors.length},null,2));
}finally{await browser.close();}
