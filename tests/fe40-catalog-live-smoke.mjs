// Public API read-only. No player sessions, writes or invented game metrics.
import assert from "node:assert/strict";
const endpoint = process.env.HUNTNEXUS_ENDPOINT ?? "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const results = [];
async function search(query, limit = 50) {
  const start = Date.now();
  const response = await fetch(endpoint, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ action: "search_hunts", query, limit }),
    signal: AbortSignal.timeout(50000),
  });
  assert.equal(response.status, 200);
  const { data } = await response.json();
  assert.ok(Array.isArray(data));
  assert.ok(data.length <= limit);
  for (const hunt of data) {
    assert.equal(typeof hunt.hunt_key, "string");
    assert.equal(typeof hunt.name, "string");
    assert.equal(hunt.planner_eligible, true);
    assert.equal(hunt.fixed_spawn, true);
    assert.ok(Number.isInteger(hunt.observed_sessions) && hunt.observed_sessions >= 0);
    assert.equal(hunt.median_xp_per_hour, undefined);
  }
  results.push({ query, count: data.length, elapsed_ms: Date.now() - start });
  return data;
}
const initial = await search("");
assert.ok(initial.length > 0);
const unobserved = initial.find((hunt) => hunt.observed_sessions === 0);
assert.ok(unobserved, "Catalog search must include an eligible hunt without observations");
const exact = await search(unobserved.hunt_key);
assert.ok(exact.some((hunt) => hunt.hunt_key === unobserved.hunt_key));
const detailResponse = await fetch(endpoint, {
  method: "POST", headers: { "content-type": "application/json" },
  body: JSON.stringify({ action: "hunt_detail", hunt_key: unobserved.hunt_key, vocation: "EK", level: 700, set_objective: "balanced" }),
  signal: AbortSignal.timeout(50000),
});
assert.equal(detailResponse.status, 200);
const detail = (await detailResponse.json()).data;
assert.ok(detail.factual?.hunt, "An unobserved catalog hunt remains navigable");
assert.equal(detail.evidence?.hunt_key, unobserved.hunt_key);
assert.equal(detail.evidence?.source?.tier, "B");
assert.equal((await search("zzzz-fe40-no-result")).length, 0);
await search("São"); // Accent is sent unchanged; the backend need not remove diacritics.
await search(initial[0].city ?? initial[0].name, 1);
console.log(JSON.stringify({ status: "PASS", mode: "published API read-only", unobserved_hunt: unobserved.hunt_key, factual_source_tier: detail.evidence.source.tier, results }, null, 2));
