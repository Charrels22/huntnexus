// SYNTHETIC builds: reflects already validated RPC selections, never invents ownership or writes.
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
const site = process.env.HUNTNEXUS_BASE_URL ?? "http://127.0.0.1:4175";
const output = resolve("fe43-build-qa");
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
try {
  for (const vocation of ["EK", "RP", "ED", "MS", "EM"]) {
    const page = await browser.newPage({ viewport: { width: 390, height: 900 } });
    const calls = [], errors = [];
    page.on("pageerror", (e) => errors.push(String(e)));
    const main = { weapon: "synthetic-main", body: "synthetic-body", ...(vocation === "RP" ? { ammunition: "synthetic-arrow" } : { offhand: "synthetic-offhand" }) };
    const variant = { ...main, body: "synthetic-backpack" };
    const review = { baseline: { main_set: Object.entries(main).map(([selection_key, item_key]) => ({ selection_key, item_key, item_name: `SYNTHETIC ${item_key}` })) }, owned_alternatives: [{ selection_key: "body", item_key: "synthetic-backpack", item_name: "SYNTHETIC BP item" }], frontier_candidates: [{ selection_key: "body", item_key: "synthetic-external", item_name: "SYNTHETIC External item", ownership: "external" }] };
    await page.route("**/api/huntnexus", async (route) => {
      const req = route.request().postDataJSON(); calls.push(req);
      if (req.action === "hunt_detail") return route.fulfill({ json: { data: { factual: { hunt: { name: "SYNTHETIC FE-43" }, monsters: [], elements: [] }, media: {}, observed: {}, imbuements: {
        defensive_priority: [{ imbuement_key: "synthetic-missing", name: "SYNTHETIC missing potency", element: "earth", powerful_value: null, unit: "percent", total_damage_share: .339324, protectable_damage_share: .681796, priority_basis: "observed_incoming_damage" }],
        community_observed_usage: [{ imbuement_key: "synthetic-usage", name: "SYNTHETIC usage", observed_profiles: 0, eligible_profiles: 3 }],
      } } } });
      if (req.action === "player_profile_get") return route.fulfill({ json: { data: { profile: { vocation, level: 450 } } } });
      if (req.action === "player_inventory_hunt_review") return route.fulfill({ json: { data: review } });
      if (req.action === "player_owned_build_options") return route.fulfill({ json: { data: { options: [
        { option_order: 1, option_type: "main", selection: main, replacements: [] },
        { option_order: 2, option_type: "owned_variant", selection: variant, exact_comparable: false, replacements: [{ selection_key: "body", item_key: "synthetic-backpack", item_name: "SYNTHETIC BP item" }] },
      ] } } });
      if (req.action.endsWith("_set") || req.action.endsWith("_put")) throw new Error("Unexpected private write");
      return route.fulfill({ json: { data: {} } });
    });
    await page.goto(`${site}/hunts/synthetic-fe43?vocation=${vocation}&level=450`, { waitUntil: "networkidle" });
    await page.getByRole("tab", { name: "Imbuements", exact: true }).click();
    const panel = page.getByRole("tabpanel");
    assert.match(await panel.innerText(), /earth · Não informado/);
    assert.match(await panel.innerText(), /33,9%/);
    assert.match(await panel.innerText(), /68,2%/);
    assert.match(await panel.innerText(), /0\/3 perfis/);
    assert.match(await panel.innerText(), /Fonte específica do efeito não informada/);
    assert.equal((await panel.innerText()).includes("earth · 0%"), false);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(100);
    await page.screenshot({ path: resolve(output, `${vocation}-imbuements.png`), fullPage: true });
    await page.getByRole("tab", { name: "Setup", exact: true }).click();
    const compare = page.getByRole("button", { name: "Comparar 2ª opção", exact: true });
    await compare.waitFor(); await compare.focus(); await compare.press("Space");
    assert.equal(await compare.getAttribute("aria-pressed"), "true");
    assert.match(await panel.innerText(), /O que muda nesta opção/);
    assert.match(await panel.innerText(), /não é totalmente comparável ao Main/);
    assert.match(await panel.innerText(), /SYNTHETIC External item/);
    assert.equal(calls.filter((req) => req.action === "hunt_detail_setup").length, 0, "Heavy optimizer remains explicit");
    assert.equal(calls.filter((req) => req.action === "player_owned_build_options").at(-1).vocation, vocation);
    if (vocation === "RP") assert.match(await panel.innerText(), /ammo/i);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(100);
    await page.screenshot({ path: resolve(output, `${vocation}-main-backpack.png`), fullPage: true });
    assert.deepEqual(errors, []);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    console.log(JSON.stringify({ status: "PASS", vocation, fixture: "SYNTHETIC", no_writes: true, reflects_rpc_selection_only: true, constraints_backend_not_homologated_by_fixture: true }));
    await page.close();
  }
} finally { await browser.close(); }
