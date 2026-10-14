// Topic 5 browser QA uses only synthetic credentials and intercepted Auth calls.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const baseUrl = process.env.HUNTNEXUS_BASE_URL || "http://127.0.0.1:4173";
const screenshotDir = resolve("topic05-browser-qa");
await mkdir(screenshotDir, { recursive: true });
const browser = await chromium.launch({ headless: true });

try {
  const desktop = await browser.newContext({ viewport: { width: 1365, height: 900 } });
  const page = await desktop.newPage();
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await page.route("**/api/huntnexus", (route) => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({ data: { sessions: [] } }),
  }));
  await page.route("**/auth/v1/token?grant_type=password", async (route) => {
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 650));
    await route.fulfill({ status: 400, contentType: "application/json", body: JSON.stringify({ message: "SYNTHETIC invalid credentials" }) });
  });
  const response = await page.goto(baseUrl + "/account", { waitUntil: "domcontentloaded", timeout: 30000 });
  assert.ok(response?.ok());
  await page.getByRole("button", { name: "Entrar", exact: true }).waitFor();
  await page.screenshot({ path: resolve(screenshotDir, "topic05-desktop-empty.png"), fullPage: true });
  await page.getByPlaceholder("seu@email.com").fill("synthetic@example.invalid");
  await page.getByText(/minúscula, maiúscula, número e símbolo/).waitFor();
  await page.getByPlaceholder(/Senha \(12\+ caracteres\)/).fill("synthetic-passphrase1!");
  assert.equal(await page.getByRole("button", { name: "Entrar", exact: true }).isDisabled(), true, "Missing uppercase must keep sign-in disabled");
  await page.getByPlaceholder(/Senha \(12\+ caracteres\)/).fill("SYNTHETIC-passphrase1!");
  await page.getByRole("button", { name: "Entrar", exact: true }).click();
  await page.screenshot({ path: resolve(screenshotDir, "topic05-desktop-loading.png"), fullPage: true });
  await page.getByText(/SYNTHETIC invalid credentials/).waitFor();
  await page.screenshot({ path: resolve(screenshotDir, "topic05-desktop-error.png"), fullPage: true });
  assert.deepEqual(pageErrors, []);
  await desktop.close();

  const mobile = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
  const mobilePage = await mobile.newPage();
  await mobilePage.route("**/api/huntnexus", (route) => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({ data: { sessions: [] } }),
  }));
  await mobilePage.goto(baseUrl + "/account", { waitUntil: "domcontentloaded", timeout: 30000 });
  await mobilePage.getByRole("button", { name: "Entrar", exact: true }).waitFor();
  await mobilePage.waitForTimeout(800);
  const geometry = await mobilePage.evaluate(() => {
    const header = document.querySelector("header")?.getBoundingClientRect();
    const hero = document.querySelector("main section")?.getBoundingClientRect();
    return { headerBottom: header?.bottom ?? -1, heroTop: hero?.top ?? -1 };
  });
  assert.ok(geometry.heroTop >= geometry.headerBottom, "Mobile header must not cover the account hero at viewport top");
  await mobilePage.getByRole("button", { name: "Esqueci a senha" }).click();
  await mobilePage.getByRole("button", { name: "Enviar recuperação" }).waitFor();
  const overflow = await mobilePage.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
  assert.equal(overflow, false, "Mobile auth page must not overflow horizontally");
  await mobilePage.screenshot({ path: resolve(screenshotDir, "topic05-mobile-recovery.png"), fullPage: false });
  await mobile.close();

  console.log(JSON.stringify({
    status: "ok",
    stage: "topic05_auth_preview",
    fixture: "SYNTHETIC",
    desktop_states: ["empty", "loading", "error"],
    mobile_states: ["recovery"],
    real_auth_attempted: false,
    real_email_sent: false,
  }, null, 2));
} finally {
  await browser.close();
}
