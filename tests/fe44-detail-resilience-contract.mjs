import assert from "node:assert/strict";
import { loadHuntDetail } from "../web/app/src/lib/hunt-detail-loader.ts";
import { callHuntNexusApi } from "../web/app/src/lib/api/huntnexus.ts";

const names = [];
const pending = [];
const parallel = loadHuntDetail((name) => new Promise(resolve => pending.push(() => resolve({ name }))), "synthetic", "EK");
assert.equal(pending.length, 7, "All reads start before any finishes, without per-card fanout");
pending.forEach(resolve => resolve());
await parallel;
const result = await loadHuntDetail(async (name, params) => {
  names.push(name);
  assert.equal(params.p_hunt_key, "synthetic");
  if (name.includes("factual")) return { hunt: { name: "SYNTHETIC" } };
  throw new Error("SYNTHETIC unavailable");
}, "synthetic", "EM");
assert.equal(names.length, 7);
assert.equal(new Set(names).size, 7);
assert.ok(names.every(name => !/optimizer|planner|player/.test(name)));
assert.equal(result.factual.hunt.name, "SYNTHETIC");
for (const [key, available] of Object.entries(result.availability)) {
  assert.equal(available, key === "factual");
  if (key !== "factual") assert.equal(result[key], null);
}
for (const missing of [null, undefined, { error: "missing" }]) {
  await assert.rejects(loadHuntDetail(async () => missing, "synthetic", "EK"), /Required factual/);
}
await assert.rejects(loadHuntDetail(async () => { throw Error("offline"); }, "synthetic", "RP"), /Required factual/);
const good = await loadHuntDetail(async () => ({ sample: { session_count: 0 } }), "synthetic", "MS");
assert.ok(Object.values(good.availability).every(Boolean));
assert.equal(good.observed.sample.session_count, 0);

const original = globalThis.fetch;
let fetches = 0;
try {
  globalThis.fetch = async (_url, init) => {
    fetches++;
    assert.equal(JSON.parse(init.body).action, "search_hunts");
    return new Promise((_resolve, reject) => {
      if (init.signal.aborted) reject(init.signal.reason);
      else init.signal.addEventListener("abort", () => reject(init.signal.reason), { once: true });
    });
  };
  const keepAlive = setInterval(() => {}, 50);
  try { await assert.rejects(callHuntNexusApi({ action: "search_hunts" }, { timeoutMs: 15 }), { name: "TimeoutError" }); }
  finally { clearInterval(keepAlive); }
  const controller = new AbortController(); controller.abort();
  await assert.rejects(callHuntNexusApi({ action: "search_hunts" }, { signal: controller.signal }), { name: "AbortError" });
  assert.equal(fetches, 2, "No automatic retries");
} finally { globalThis.fetch = original; }
console.log("PASS FE-44: seven bounded reads, factual required, auxiliary degradation, timeout/cancellation without retry");
