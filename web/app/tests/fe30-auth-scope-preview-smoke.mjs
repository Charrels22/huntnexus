// FE-30 preview-only Browser QA, with no real Supabase Auth or emails.
// The linked UUID is synthetic and all private API calls are intercepted.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const baseUrl=process.env.HUNTNEXUS_BASE_URL || "http://127.0.0.1:4173";
const screenshotDir=resolve("fe30-browser-qa");
await mkdir(screenshotDir,{recursive:true});
const boundUuid="b3bc130e-f1a6-4991-8b87-2e86bb0b1d50";
const guestUuid="af237382-d852-4623-b1d9-3a94d55b9322";
const scopeKey="huntnexus.client-id.v1";
const markerKey="huntnexus.bound-client-id.v1";
const draftKey="huntnexus.session-import.draft.v1";
const openKey="huntnexus.open-player-session";
const browser=await chromium.launch({headless:true});
const results=[];
try {
  const context=await browser.newContext({viewport:{width:1200,height:850}});
  await context.addInitScript(({scopeKey,markerKey,draftKey,openKey,boundUuid})=>{
    try {
      localStorage.setItem(scopeKey,boundUuid);
      localStorage.setItem(markerKey,boundUuid);
      localStorage.setItem(draftKey,"FE30 SYNTHETIC private draft");
      sessionStorage.setItem(openKey,"FE30 SYNTHETIC private session");
    } catch {}
  },{scopeKey,markerKey,draftKey,openKey,boundUuid});
  const page=await context.newPage();
  const errors=[];
  page.on("pageerror",e=>errors.push(e.message));
  await page.route("**/api/huntnexus",route=>route.fulfill({
    status:401,contentType:"application/json",
    body:JSON.stringify({error:"synthetic_private_scope_not_authenticated"}),
  }));
  const response=await page.goto(baseUrl+"/profile",{waitUntil:"domcontentloaded",timeout:30000});
  assert.ok(response?.ok(),"/profile preview should return successful HTML");
  await page.waitForURL(/\/account\/?$/,{timeout:20000});
  await page.getByRole("heading",{name:/Sincronize seu personagem entre dispositivos/i}).waitFor();
  const isolated=await page.evaluate(({scopeKey,markerKey,draftKey,openKey})=>({
    current:localStorage.getItem(scopeKey),
    bound:localStorage.getItem(markerKey),
    draft:localStorage.getItem(draftKey),
    opened:sessionStorage.getItem(openKey),
  }),{scopeKey,markerKey,draftKey,openKey});
  assert.ok(/^[0-9a-f-]{36}$/i.test(isolated.current??"") && isolated.current!==boundUuid,
    "A previously linked scope must rotate to a new guest UUID");
  assert.equal(isolated.bound,null,"Stale linked-account marker must be cleared");
  assert.equal(isolated.draft,null,"Previously authenticated draft must be cleared");
  assert.equal(isolated.opened,null,"Previously authenticated open session must be cleared");
  assert.deepEqual(errors,[],"No uncaught browser exception on cold signed-out scope");
  await page.screenshot({path:resolve(screenshotDir,"fe30-stale-bound-identity-redirect.png"),fullPage:true});
  results.push({case:"stale_bound_scope_without_session",result:"PASS",
    redirected_to_account:true,client_scope_rotated:true,private_drafts_removed:true});
  await context.close();

  const guestContext=await browser.newContext({viewport:{width:1200,height:850}});
  await guestContext.addInitScript(({scopeKey,draftKey,guestUuid})=>{
    try {
      localStorage.setItem(scopeKey,guestUuid);
      localStorage.setItem(draftKey,"FE30 SYNTHETIC guest draft");
    }catch{}
  },{scopeKey,draftKey,guestUuid});
  const guestPage=await guestContext.newPage();
  const guestResponse=await guestPage.goto(baseUrl+"/account",{waitUntil:"domcontentloaded",timeout:30000});
  assert.ok(guestResponse?.ok(),"/account preview should return successful HTML");
  await guestPage.getByRole("heading",{name:/Sincronize seu personagem entre dispositivos/i}).waitFor();
  // Allow Supabase INITIAL_SESSION to settle, then check that pure guests are unchanged.
  await guestPage.waitForTimeout(1700);
  const guestState=await guestPage.evaluate(({scopeKey,draftKey})=>({
    current:localStorage.getItem(scopeKey),draft:localStorage.getItem(draftKey),
  }),{scopeKey,draftKey});
  assert.equal(guestState.current,guestUuid,"Unauthenticated guest UUID must remain stable");
  assert.equal(guestState.draft,"FE30 SYNTHETIC guest draft",
    "Unauthenticated guest draft must be preserved");
  await guestPage.screenshot({path:resolve(screenshotDir,"fe30-guest-state-preserved.png"),fullPage:true});
  results.push({case:"pure_guest_startup",result:"PASS",guest_uuid_preserved:true,guest_draft_preserved:true});
  await guestContext.close();
  console.log(JSON.stringify({
    status:"ok",stage:"fe30_preview_browser_auth_scope",
    real_supabase_auth_tested:false,real_magic_link_sent:false,real_two_device_tested:false,
    results,
  },null,2));
}finally{
  await browser.close();
}
