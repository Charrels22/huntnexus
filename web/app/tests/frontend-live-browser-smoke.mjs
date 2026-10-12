import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const baseUrl = process.env.HUNTNEXUS_BASE_URL ??
  "https://huntnexus.charr3ls22.workers.dev";
const output = resolve("frontend-qa");
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
const results = [];

async function audit(route, expected, filename, width = 1440, height = 900) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
  const runtimeErrors = [];
  page.on("pageerror", (error) => runtimeErrors.push(error.message));
  const goto = await page.goto(baseUrl + route, { waitUntil: "domcontentloaded", timeout: 30000 });
  if (!goto?.ok()) throw new Error(`${route}: HTTP ${goto?.status()}`);
  await page.getByRole("heading", { name: expected }).first().waitFor({ timeout: 25000 });
  await page.waitForTimeout(1000);
  const filenamePath = resolve(output, filename);
  await page.screenshot({ path: filenamePath, fullPage: true, animations: "disabled" });
  const bounds = await page.evaluate(() => ({
    width: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  if (bounds.scrollWidth > bounds.width + 8) {
    throw new Error(`${route}: horizontal overflow ${bounds.scrollWidth}px at viewport ${bounds.width}px`);
  }
  if (runtimeErrors.length) {
    throw new Error(`${route}: unhandled browser JS errors: ${runtimeErrors.slice(0,3).join("; ")}`);
  }
  results.push({ route, viewport: width, title: await page.title(), screenshot: filename, overflow: false, script_errors: 0 });
  return page;
}

try {
  const account = await audit("/account", /Sincronize seu personagem entre dispositivos/i, "account-desktop.png");
  await account.getByRole("button", { name: "Enviar link" }).waitFor();
  await account.close();

  const profile = await audit("/profile", /Cadastre seu personagem uma vez/i, "profile-empty-desktop.png");
  await profile.close();

  const session = await audit("/session", /Cadastrar uma hunt/i, "session-analyzer-desktop.png");
  await session.close();

  const planner = await audit("/planner", /Monte o contexto do seu personagem/i, "planner-desktop.png");
  await planner.close();

  const hunt = await audit("/hunts/cobra-bastion", /Cobra Bastion/i, "hunt-detail-desktop.png");
  let unrequestedOptimizer = 0;
  hunt.on("request", (request) => {
    if (request.url().includes("/api/huntnexus") &&
        request.postData()?.includes('"action":"hunt_detail_setup"')) unrequestedOptimizer++;
  });
  await hunt.getByRole("button", { name: "Setup", exact: true }).click();
  await hunt.getByRole("heading", { name: "Setup da hunt" }).waitFor();
  await hunt.getByRole("button", { name: /Calcular frontier universal/i }).waitFor();
  await hunt.waitForTimeout(1000);
  if (unrequestedOptimizer !== 0) {
    throw new Error("Setup must not trigger heavy optimizer without an explicit click");
  }
  await hunt.screenshot({ path: resolve(output, "hunt-setup-before-calculation.png"), fullPage: true });
  results.push({ route: "/hunts/cobra-bastion#setup", lazy_optimizer_respected: true, screenshot: "hunt-setup-before-calculation.png" });
  await hunt.getByRole("button", { name: "Community", exact: true }).click();
  await hunt.getByText("Amostra de sessões com EK").first().waitFor({ timeout: 15000 });
  await hunt.getByText("São sessões verificáveis que incluíram a vocação").first().waitFor();
  await hunt.screenshot({ path: resolve(output, "hunt-community-vocation.png"), fullPage: true });
  results.push({ route: "/hunts/cobra-bastion#community", tier_c_vocation_sample_visible: true, screenshot: "hunt-community-vocation.png" });
  await hunt.close();

  // Guest identity recovery UI regression. This verifies the browser control;
  // it does not impersonate a real authenticated user or claim Magic Link QA.
  const oldGuestId = "90a00000-0000-4000-8000-000000000072";
  const restore = await browser.newPage({ viewport: { width: 1160, height: 830 } });
  await restore.goto(baseUrl + "/account", { waitUntil: "domcontentloaded", timeout: 30000 });
  await restore.evaluate((guestId) => {
    window.localStorage.setItem("huntnexus.unmerged-guest-client-id.v1", guestId);
  }, oldGuestId);
  await restore.reload({ waitUntil: "domcontentloaded" });
  await restore.getByRole("button", { name: "Retomar perfil convidado anterior" }).waitFor({ timeout: 12000 });
  await restore.screenshot({ path: resolve(output, "account-guest-recovery.png"), fullPage: true });
  await Promise.all([
    restore.waitForNavigation({ waitUntil: "domcontentloaded", timeout: 15000 }),
    restore.getByRole("button", { name: "Retomar perfil convidado anterior" }).click(),
  ]);
  const recoveredIdentity = await restore.evaluate(() => ({
    current: window.localStorage.getItem("huntnexus.client-id.v1"),
    pending: window.localStorage.getItem("huntnexus.unmerged-guest-client-id.v1"),
  }));
  if (recoveredIdentity.current !== oldGuestId || recoveredIdentity.pending !== null) {
    throw new Error("Explicit guest recovery did not restore previous client ID and remove pending marker");
  }
  results.push({
    route: "/account#guest-recovery",
    restored_previous_guest_identity: true,
    screenshot: "account-guest-recovery.png",
    real_magic_link_tested: false,
  });
  await restore.close();

  // Source-backed Weapon Proficiency catalog per vocation. Mock ONLY the
  // private profile read to select the vocation; catalog and sprites are live.
  // This does not create accounts, inventory or synthetic community sessions.
  const vocationFamilies = [
    ["EK", "sword"], ["RP", "bow"], ["ED", "rod"], ["MS", "wand"], ["EM", "fist"],
  ];
  for (const [vocation, family] of vocationFamilies) {
    const profilePage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    const errors = [];
    profilePage.on("pageerror", (error) => errors.push(error.message));
    await profilePage.route("**/api/huntnexus", async (route) => {
      const request = route.request();
      const body = request.postDataJSON();
      if (body?.action === "player_profile_get") {
        await route.fulfill({
          status: 200, contentType: "application/json",
          body: JSON.stringify({ data: { exists: true, profile: {
            character_name: "Local UI QA",
            world_name: "RubinOT",
            vocation, level: 700,
            manual_stats: { weapon_family: family },
            proficiency_selections: {},
            defaults: { hunt_objective: "balanced", set_objective: "balanced", party_size: 1 },
          } } }),
        });
        return;
      }
      if (body?.action === "player_inventory_get") {
        await route.fulfill({
          status: 200, contentType: "application/json",
          body: JSON.stringify({ data: {
            main_set: {}, backpack: [],
            summary: { main_slots: 0, backpack_items: 0 },
          } }),
        });
        return;
      }
      await route.continue();
    });
    const catalogPromise = profilePage.waitForResponse((response) =>
      response.url().includes("/api/huntnexus") &&
      response.request().postData()?.includes('"action":"player_profile_proficiency_catalog"') &&
      response.request().postData()?.includes('"vocation":"' + vocation + '"'),
      { timeout: 30000 },
    );
    await profilePage.goto(baseUrl + "/profile", { waitUntil: "domcontentloaded", timeout: 30000 });
    const catalog = await (await catalogPromise).json();
    if (!(Number(catalog?.data?.summary?.eligible_tree_count) > 0)) {
      throw new Error(vocation + ": live proficiency catalog returned no eligible trees");
    }
    const firstTree = (catalog?.data?.trees ?? []).find((tree) => tree.eligible && tree.topology_status === "source_backed_level_position" && tree.perk_count > 0)
      ?? (catalog?.data?.trees ?? []).find((tree) => tree.eligible && tree.perk_count > 0);
    if (!firstTree) throw new Error(vocation + ": no eligible source-backed proficiency tree");
    const treeButton = profilePage.locator("article > button").filter({ hasText: firstTree.item_name }).first();
    await treeButton.click();
    await profilePage.locator("article button[title]").first().waitFor({ timeout: 12000 });
    await profilePage.waitForTimeout(2800);
    const iconCoverage = await profilePage.locator('img[src*="Proficiency"]').evaluateAll((images) =>
      images.map((image) => ({
        filename: decodeURIComponent((image.getAttribute("src") ?? "").split("/").pop() ?? ""),
        loaded: image.complete && image.naturalWidth > 0,
      })),
    );
    const filename = "weapon-proficiency-" + vocation.toLowerCase() + ".png";
    await profilePage.screenshot({ path: resolve(output, filename), fullPage: true });
    if (errors.length) throw new Error(vocation + ": browser runtime error: " + errors.slice(0, 2).join("; "));
    results.push({
      route: "/profile#weapon-proficiency-" + vocation.toLowerCase(),
      vocation, family, eligible_trees: catalog.data.summary.eligible_tree_count,
      selected_tree: firstTree.item_key, icon_mappings_examined: iconCoverage.length,
      loaded_icons: iconCoverage.filter((x) => x.loaded).length,
      failed_external_icons: iconCoverage.filter((x) => !x.loaded).map((x) => x.filename),
      screenshot: filename, actual_human_profile_used: false,
    });
    await profilePage.close();
  }

  // No network scrape or private session write: only public, short authentic
  // excerpts pinned with provenance are pasted into the published Analyzer UI.
  const publicExcerpts = JSON.parse(readFileSync(
    resolve("../../tests/fixtures/fe22-online-original-analyzer-excerpts.json"), "utf8"
  )).vocations;
  const rpPublic = publicExcerpts.find(x => x.vocation === "RP");
  const emPublic = publicExcerpts.find(x => x.vocation === "EM");
  const excerptPage = await browser.newPage({viewport:{width:1440,height:900}});
  const excerptErrors = [];
  excerptPage.on("pageerror", e => excerptErrors.push(e.message));
  await excerptPage.goto(baseUrl + "/session", {waitUntil:"domcontentloaded",timeout:30000});
  await excerptPage.getByRole("heading",{name:/Cadastrar uma hunt/i}).first().waitFor({timeout:14000});
  // Wait for TanStack hydration and guest draft restoration before input.
  await excerptPage.waitForTimeout(1100);
  const sourceInput = excerptPage.locator("textarea").first();
  await sourceInput.fill(rpPublic.excerpt);
  await excerptPage.getByText(/métricas reconhecidas/).first().waitFor({timeout:15000});
  const recognizedLabel = await excerptPage.getByText(/métricas reconhecidas/).first().innerText();
  if (!recognizedLabel.includes("5 métricas reconhecidas")) {
    throw new Error("Public RP paste was not parsed as 5 observed metrics: " + recognizedLabel);
  }
  const xpPreview = excerptPage.getByText("XP/h", {exact:true}).first().locator("..");
  if (!(await xpPreview.innerText()).includes("0")) {
    throw new Error("Published RP XP/h: 0 was not preserved as explicitly observed zero");
  }
  await excerptPage.getByText("Kills", {exact:true}).first().locator("..")
    .getByText("Não informado").waitFor();
  await excerptPage.screenshot({path:resolve(output,"source-rp-original-excerpt-preview.png"),fullPage:true});
  results.push({
    route:"/session#rp-public-excerpt", source_vocation:"RP",
    observed_zero_kept:true, unknown_kills_not_zero:true,
    screenshot:"source-rp-original-excerpt-preview.png", real_gameplay_upload:false,
  });

  await excerptPage.getByRole("button",{name:"Party Hunt",exact:true}).click();
  await excerptPage.locator("textarea").first().fill(emPublic.excerpt);
  if (!(await excerptPage.locator("textarea").first().inputValue()).includes("Loot Type: Leader")) {
    throw new Error("Public EM Party header was not stored in the Party Hunt editor");
  }
  await excerptPage.getByText("2/4 blocos preenchidos").first().waitFor({timeout:14000});
  await excerptPage.screenshot({path:resolve(output,"source-em-public-party-header-preview.png"),fullPage:true});
  if (excerptErrors.length) throw new Error("Source excerpt browser JS errors: " + excerptErrors.slice(0,3).join("; "));
  results.push({
    route:"/session#em-public-party-header", source_vocation:"EM",
    tested_as_party_aggregate:true, source_excerpt_not_full_party_export:true,
    screenshot:"source-em-public-party-header-preview.png", real_gameplay_upload:false,
  });
  await excerptPage.close();

  const mobileAccount = await audit("/account", /Sincronize seu personagem entre dispositivos/i, "account-mobile.png", 390, 844);
  await mobileAccount.close();
  const mobileHunt = await audit("/hunts/cobra-bastion", /Cobra Bastion/i, "hunt-detail-mobile.png", 390, 844);
  await mobileHunt.close();

  console.log(JSON.stringify({ status: "ok", stage: "frontend_browser_visual_regression", real_player_playtest: false, results }, null, 2));
} finally {
  await browser.close();
}
