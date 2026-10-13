// SYNTHETIC fixtures: validates UI context, accessibility and unavailable source; no private writes.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
const site = process.env.HUNTNEXUS_BASE_URL ?? "http://127.0.0.1:4174";
const output = resolve("fe41-navigation-qa");
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
try {
  for (const width of [1440, 390]) {
    for (const vocation of ["EK", "RP", "ED", "MS", "EM"]) {
      const page = await browser.newPage({ viewport: { width, height: 900 } });
      const calls = [], errors = [];
      page.on("pageerror", (error) => errors.push(String(error)));
      let failDetail = false;
      await page.route("**/api/huntnexus", async (route) => {
        const req = route.request().postDataJSON();
        calls.push(req);
        if (req.action === "player_profile_get") {
          await new Promise((done) => setTimeout(done, 350));
          return route.fulfill({ json: { data: { profile: { vocation: "EK", level: 900, defaults: { party_size: 1, hunt_objective: "xp", set_objective: "offense" } } } } });
        }
        if (req.action === "search_hunts") return route.fulfill({ json: { data: [{ hunt_key: "synthetic-fe41", name: "SYNTHETIC FE-41", observed_sessions: 0, planner_eligible: true }] } });
        if (req.action === "hunt_detail") {
          if (failDetail) return route.fulfill({ status: 503, json: { error: "SYNTHETIC network failure" } });
          return route.fulfill({ json: { data: { factual: { hunt: { name: "SYNTHETIC FE-41" }, monsters: [], elements: [] }, observed: { performance: { session_count: 0 } }, evidence: null, media: {}, defensive: { elements: [] } } } });
        }
        return route.fulfill({ json: { data: {} } });
      });
      await page.goto(`${site}/hunts/synthetic-fe41?vocation=${vocation}&level=450&setObjective=sustain&huntObjective=profit&party=4&catalogQuery=S%C3%A3o`, { waitUntil: "networkidle" });
      await page.getByRole("tab", { name: "Overview", exact: true }).waitFor();
      await page.getByTestId("hunt-source-core-status").getByText("Evidência factual indisponível").waitFor();
      const overview = page.getByRole("tab", { name: "Overview", exact: true });
      await overview.focus(); await overview.press("ArrowRight");
      assert.equal(await page.getByRole("tab", { name: "Creatures", exact: true }).getAttribute("aria-selected"), "true");
      await page.getByRole("tab", { name: "Creatures", exact: true }).press("End");
      assert.equal(await page.getByRole("tab", { name: "Community", exact: true }).getAttribute("aria-selected"), "true");
      await page.getByRole("tab", { name: "Community", exact: true }).press("Home");
      assert.equal(await overview.getAttribute("aria-selected"), "true");
      assert.equal(calls.filter((req) => req.action === "hunt_detail").length, 1, "Overview/Creatures/Community use existing data only");
      if (vocation === "MS") await page.screenshot({ path: resolve(output, `${width}-source-unavailable-keyboard.png`), fullPage: true });
      await page.getByRole("link", { name: "Abrir Hunt Planner", exact: true }).click();
      await page.waitForTimeout(500); // delayed Profile has resolved; explicit URL filters must still win.
      assert.equal(await page.getByLabel("Vocação").inputValue(), vocation);
      assert.equal(await page.getByLabel("Level", { exact: true }).inputValue(), "450");
      assert.equal(await page.getByLabel("Objetivo do set").inputValue(), "sustain");
      assert.equal(await page.getByLabel("Objetivo da hunt").inputValue(), "profit");
      assert.equal(await page.getByLabel("Party").inputValue(), "4");
      if (vocation === "MS") await page.screenshot({ path: resolve(output, `${width}-planner-context.png`), fullPage: true });
      await page.goBack();
      await page.getByRole("link", { name: "Voltar ao catálogo", exact: true }).click();
      await page.waitForURL(/q=S%C3%A3o/);
      assert.equal(await page.getByRole("searchbox").inputValue(), "São");
      await page.getByRole("link", { name: "Ver detalhes de SYNTHETIC FE-41" }).click();
      await page.getByRole("tab", { name: "Overview", exact: true }).waitFor();
      failDetail = true;
      await page.reload();
      await page.getByRole("alert").waitFor();
      failDetail = false;
      await page.getByRole("button", { name: "Tentar novamente", exact: true }).click();
      await page.getByRole("tab", { name: "Overview", exact: true }).waitFor();
      assert.deepEqual(errors, []);
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth), false);
      console.log(JSON.stringify({ status: "PASS", width, vocation, fixture: "SYNTHETIC", context: true, accessible_tabs: true, source_unavailable: true, retry: true }));
      await page.close();
    }
  }
} finally { await browser.close(); }
