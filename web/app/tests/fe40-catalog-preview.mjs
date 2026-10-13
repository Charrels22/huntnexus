// SYNTHETIC UI fixtures only. Separate live backend contract: tests/fe40-catalog-live-smoke.mjs.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const site = process.env.HUNTNEXUS_BASE_URL ?? "http://127.0.0.1:4173";
const output = resolve("fe40-catalog-qa");
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
const fixture = { hunt_key: "synthetic-são-hunt", name: "SYNTHETIC São Hunt", city: "SYNTHETIC City", observed_sessions: 0, planner_eligible: true, level_knights: null, level_paladins: "350", level_mages: "300" };
const summary = [];
try {
  for (const viewport of [{ width: 1440, height: 1000 }, { width: 390, height: 844 }]) {
    const page = await browser.newPage({ viewport });
    const errors = [], calls = [];
    page.on("pageerror", (error) => errors.push(String(error)));
    await page.route("**/api/huntnexus", async (route) => {
      const req = route.request().postDataJSON() ?? {};
      calls.push(req);
      if (req.action === "search_hunts") {
        if (req.query === "old") await new Promise((done) => setTimeout(done, 1300));
        if (req.query === "error") return route.fulfill({ status: 503, json: { error: "SYNTHETIC unavailable" } });
        const data = req.query === "empty" ? [] : req.query === "old" ? [{ ...fixture, hunt_key: "synthetic-old", name: "SYNTHETIC OLD" }] : req.query === "limit" ? Array.from({ length: 50 }, (_, index) => ({ ...fixture, hunt_key: `synthetic-${index}`, name: `SYNTHETIC ${index}` })) : [fixture];
        return route.fulfill({ status: 200, json: { data } });
      }
      if (req.action === "hunt_detail") return route.fulfill({ status: 200, json: { data: {
        factual: { hunt: { key: fixture.hunt_key, name: fixture.name, city: fixture.city }, monsters: [], elements: [] },
        observed: { performance: { session_count: 0 } }, vocation_observed: { sample: { sourced_session_count: 0 } },
        evidence: null, media: {}, defensive: { elements: [] }, imbuements: {},
      } } });
      return route.fulfill({ status: 200, json: { data: {} } });
    });
    await page.goto(site + "/", { waitUntil: "networkidle" });
    await page.getByRole("link", { name: "Explorar catálogo factual", exact: true }).click();
    const input = page.getByRole("searchbox", { name: "Buscar por hunt, cidade ou slug" });
    await page.getByRole("heading", { name: fixture.name }).waitFor();
    assert.match(await page.locator("main").innerText(), /Sem sessões de desempenho observadas/);
    assert.match(await page.locator("main").innerText(), /Não informado/);
    assert.equal(calls.filter((req) => req.action === "search_hunts").length, 1, "No per-hunt requests");
    await page.screenshot({ path: resolve(output, `${viewport.width}-results.png`), fullPage: true });
    const before = calls.length;
    await input.fill("a"); await input.fill("ab"); await input.fill("São");
    await page.getByRole("status").getByText("Buscando hunts...").waitFor();
    await page.screenshot({ path: resolve(output, `${viewport.width}-loading.png`), fullPage: true });
    await page.waitForFunction(() => !document.querySelector('[aria-label="Resultados do catálogo"]')?.getAttribute("aria-busy")?.includes("true"));
    assert.equal(calls.slice(before).filter((req) => req.action === "search_hunts").length, 1, "Rapid typing is debounced");
    assert.equal(calls.at(-1).query, "São");
    await input.fill("empty");
    await page.getByText("Nenhuma hunt encontrada. Tente outro nome, cidade ou slug.").waitFor();
    await page.screenshot({ path: resolve(output, `${viewport.width}-empty.png`), fullPage: true });
    await input.fill("error");
    await page.getByRole("alert").waitFor();
    await page.screenshot({ path: resolve(output, `${viewport.width}-error.png`), fullPage: true });
    const failures = calls.filter((req) => req.query === "error").length;
    const retried = page.waitForRequest((req) => req.url().endsWith("/api/huntnexus") && req.postDataJSON()?.query === "error");
    await page.getByRole("button", { name: "Tentar novamente" }).click();
    await retried;
    await page.getByRole("alert").waitFor();
    assert.equal(calls.filter((req) => req.query === "error").length, failures + 1);
    await input.fill("old");
    await page.waitForRequest((req) => req.url().endsWith("/api/huntnexus") && req.postDataJSON()?.query === "old");
    await input.fill("new");
    await page.getByRole("heading", { name: fixture.name }).waitFor();
    await page.waitForTimeout(1500);
    assert.equal(await page.getByRole("heading", { name: "SYNTHETIC OLD" }).count(), 0, "Stale response discarded");
    await input.fill("limit");
    await page.getByRole("status").getByText(/limite atingido/).waitFor();
    await input.fill("São"); await input.press("Enter");
    await page.waitForURL(/q=S%C3%A3o/);
    await page.getByRole("heading", { name: fixture.name }).waitFor();
    await input.focus(); await input.press("Tab");
    assert.equal(await page.getByRole("button", { name: "Buscar", exact: true }).evaluate((element) => element === document.activeElement), true);
    await page.getByRole("link", { name: `Ver detalhes de ${fixture.name}` }).click();
    assert.ok(decodeURIComponent(new URL(page.url()).pathname).endsWith("/hunts/" + fixture.hunt_key));
    await page.getByRole("link", { name: "Voltar ao catálogo", exact: true }).waitFor();
    await page.getByTestId("hunt-source-core-status").getByText("Evidência factual indisponível").waitFor();
    await page.getByRole("link", { name: "Abrir Hunt Planner", exact: true }).click();
    await page.getByRole("heading", { name: "Monte o contexto do seu personagem" }).waitFor();
    await page.getByRole("link", { name: /Explorar catálogo factual, inclusive/ }).click();
    await page.getByRole("heading", { name: fixture.name }).waitFor();
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth), false, "No horizontal overflow");
    if (viewport.width < 500) {
      await page.getByRole("button", { name: "Abrir navegação", exact: true }).click();
      await page.getByRole("link", { name: "Catálogo de hunts", exact: true }).click();
    } else {
      await page.getByRole("textbox", { name: "Buscar hunts no catálogo" }).fill("São");
      await page.getByRole("textbox", { name: "Buscar hunts no catálogo" }).press("Enter");
      await page.waitForURL(/q=S%C3%A3o/);
      assert.equal(await input.inputValue(), "São");
    }
    assert.deepEqual(errors, []);
    summary.push({ viewport, status: "PASS", fixture: "SYNTHETIC", debounce: true, stale_response: true, zero_observations_navigable: true, keyboard: true, empty_error_loading: true });
    await page.close();
  }
  await writeFile(resolve(output, "summary.json"), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify(summary, null, 2));
} finally { await browser.close(); }
