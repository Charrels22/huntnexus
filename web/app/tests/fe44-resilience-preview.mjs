// SYNTHETIC partial API response. No real accounts or production writes.
import assert from "node:assert/strict";
import { chromium } from "playwright";
const site = process.env.HUNTNEXUS_BASE_URL ?? "http://127.0.0.1:4176";
const browser = await chromium.launch({ headless: true });
try {
  for (const width of [1440, 390]) {
    const page = await browser.newPage({ viewport: { width, height: 900 } });
    const errors = [], calls = [];
    page.on("pageerror", error => errors.push(String(error)));
    await page.route("**/api/huntnexus", route => {
      const request = route.request().postDataJSON(); calls.push(request.action);
      return route.fulfill({ json: { data: request.action === "hunt_detail" ? {
        factual: { hunt: { name: "SYNTHETIC FE-44" }, monsters: [], elements: [] },
        observed: null, vocation_observed: null, defensive: null, imbuements: null, media: null, evidence: null,
        availability: { factual: true, observed: false, vocation_observed: false, defensive: false, imbuements: false, media: false, evidence: false },
      } : {} } });
    });
    await page.goto(`${site}/hunts/synthetic-fe44`, { waitUntil: "networkidle" });
    await page.getByRole("status").filter({ hasText: "O conteúdo factual foi preservado" }).waitFor();
    await page.getByText("Sessões comunitárias não informadas", { exact: true }).waitFor();
    await page.getByRole("tab", { name: "Community", exact: true }).click();
    assert.equal(await page.getByText("Amostra insuficiente", { exact: true }).count(), 0);
    assert.equal(await page.getByText(/Existem 0 sessões/).count(), 0);
    await page.getByRole("tab", { name: "Damage", exact: true }).click();
    await page.getByText("Dados de dano recebido indisponíveis. Tente novamente mais tarde.", { exact: true }).waitFor();
    await page.getByRole("tab", { name: "Imbuements", exact: true }).click();
    await page.getByText("Dados de imbuements indisponíveis. Tente novamente mais tarde.", { exact: true }).waitFor();
    assert.equal(calls.filter(action => action === "hunt_detail").length, 1);
    assert.equal(calls.some(action => /optimizer|save|upsert|delete/.test(action)), false);
    assert.deepEqual(errors, []);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    console.log(JSON.stringify({ status: "PASS", width, fixture: "SYNTHETIC", partial_failure: true, absent_not_zero: true }));
    await page.close();
  }
} finally { await browser.close(); }
