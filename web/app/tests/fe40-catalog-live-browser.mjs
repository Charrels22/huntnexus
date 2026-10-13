// Compiled local frontend + real published public API, read-only.
// Shell private-session requests are deliberately stubbed empty, never forwarded.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
const site = process.env.HUNTNEXUS_BASE_URL ?? "http://127.0.0.1:4173";
const endpoint = process.env.HUNTNEXUS_ENDPOINT ?? "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const output = resolve("fe40-catalog-qa");
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
try {
  for (const width of [1440, 390]) {
    const page = await browser.newPage({ viewport: { width, height: 900 } });
    const errors = [];
    page.on("pageerror", (error) => errors.push(String(error)));
    await page.route("**/api/huntnexus", async (route) => {
      const req = route.request().postDataJSON();
      if (!["search_hunts", "hunt_detail"].includes(req.action)) return route.fulfill({ json: { data: {} } });
      // Rebuild an allowlisted body; do not forward any browser auth or client IDs.
      const body = req.action === "search_hunts" ? { action: req.action, query: req.query, limit: req.limit }
        : { action: req.action, hunt_key: req.hunt_key, vocation: req.vocation, level: req.level, set_objective: req.set_objective };
      const response = await fetch(endpoint, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body), signal: AbortSignal.timeout(50000) });
      return route.fulfill({ status: response.status, contentType: "application/json", body: await response.text() });
    });
    await page.goto(site + "/hunts?q=forest-of-life", { waitUntil: "domcontentloaded" });
    await page.getByRole("heading", { name: "Forest of Life", exact: true }).waitFor({ timeout: 60000 });
    await page.getByText("Sem sessões de desempenho observadas. A hunt continua disponível no catálogo.").waitFor();
    await page.screenshot({ path: resolve(output, `${width}-real-api-catalog.png`), fullPage: true });
    await page.getByRole("link", { name: "Ver detalhes de Forest of Life" }).click();
    await page.getByTestId("hunt-evidence-source-name").getByText("ByteWizards TibiaData").waitFor({ timeout: 60000 });
    await page.getByTestId("hunt-community-evidence-separation").getByText(/Sem sessões de desempenho observadas/).waitFor();
    await page.screenshot({ path: resolve(output, `${width}-real-api-detail.png`), fullPage: true });
    assert.deepEqual(errors, []);
    console.log(JSON.stringify({ status: "PASS", width, mode: "local frontend + real published read-only API", hunt: "forest-of-life", private_requests: "stubbed empty", deployment_verified: false }));
    await page.close();
  }
} finally { await browser.close(); }
