import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
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

  const mobileAccount = await audit("/account", /Sincronize seu personagem entre dispositivos/i, "account-mobile.png", 390, 844);
  await mobileAccount.close();
  const mobileHunt = await audit("/hunts/cobra-bastion", /Cobra Bastion/i, "hunt-detail-mobile.png", 390, 844);
  await mobileHunt.close();

  console.log(JSON.stringify({ status: "ok", stage: "frontend_browser_visual_regression", real_player_playtest: false, results }, null, 2));
} finally {
  await browser.close();
}
