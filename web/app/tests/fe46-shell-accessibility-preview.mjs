// SYNTHETIC public shell fixtures; no private writes or real authentication.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
const site = process.env.HUNTNEXUS_BASE_URL ?? "http://127.0.0.1:4177";
const output = resolve("fe46-shell-qa"); await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
try {
  for (const width of [1440, 390]) {
    const page = await browser.newPage({ viewport: { width, height: width < 1024 ? 600 : 900 } });
    const errors = []; page.on("pageerror", error => errors.push(String(error)));
    await page.route("**/api/huntnexus", route => route.fulfill({ json: { data: [] } }));
    await page.goto(`${site}/hunts`, { waitUntil: "networkidle" });
    await page.keyboard.press("Tab");
    const skip = page.getByRole("link", { name: "Pular para o conteúdo" });
    await skip.waitFor(); assert.ok(await skip.evaluate(element => document.activeElement === element));
    await skip.press("Enter");
    assert.equal(await page.evaluate(() => document.activeElement.id), "main-content");
    const menu = page.getByRole("button", { name: "Abrir navegação", exact: true });
    if (width < 1024) {
      assert.equal(await page.locator("#primary-navigation").getAttribute("inert"), "");
      assert.equal(await page.getByRole("navigation", { name: "Navegação principal" }).count(), 0);
      await menu.click();
      const nav = page.getByRole("navigation", { name: "Navegação principal" });
      await nav.waitFor();
      await page.waitForFunction(() => document.getElementById("primary-navigation").getBoundingClientRect().left >= 0);
      assert.equal(await page.getByRole("button", { name: "Fechar menu de navegação" }).getAttribute("aria-expanded"), "true");
      assert.ok(await nav.getByRole("link", { name: "Dashboard", exact: true }).evaluate(element => document.activeElement === element));
      await page.screenshot({ path: resolve(output, `${width}-navigation-open.png`), fullPage: true });
      await nav.getByRole("link", { name: "Conta", exact: true }).scrollIntoViewIfNeeded();
      assert.ok(await nav.getByRole("link", { name: "Conta", exact: true }).evaluate(element => {
        const rect = element.getBoundingClientRect(); return rect.top >= 64 && rect.bottom <= innerHeight;
      }), "Short viewport can scroll to last navigation item");
      await page.keyboard.press("Escape");
      assert.ok(await menu.evaluate(element => document.activeElement === element));
      await menu.click(); await page.getByRole("button", { name: "Fechar navegação", exact: true }).click({ position: { x: 330, y: 100 } });
      assert.equal(await menu.getAttribute("aria-expanded"), "false");
      await menu.click(); await page.getByRole("navigation", { name: "Navegação principal" }).getByRole("link", { name: "Hunt Planner", exact: true }).click();
      await page.waitForURL(/\/planner/); assert.equal(await menu.getAttribute("aria-expanded"), "false");
      await page.setViewportSize({ width: 1440, height: 900 });
      await page.getByRole("navigation", { name: "Navegação principal" }).waitFor();
    } else {
      assert.equal(await page.getByRole("navigation", { name: "Navegação principal" }).getByRole("link", { name: "Catálogo de hunts", exact: true }).getAttribute("aria-current"), "page");
    }
    await page.screenshot({ path: resolve(output, `${width}-shell.png`), fullPage: true });
    assert.deepEqual(errors, []);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    console.log(JSON.stringify({ status: "PASS", width, fixture: "SYNTHETIC", skip_link: true, keyboard_mobile_menu: true }));
    await page.close();
  }
} finally { await browser.close(); }
