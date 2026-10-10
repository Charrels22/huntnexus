const endpoint =
  process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function post(body) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${JSON.stringify(payload)}`);
  }
  return payload;
}

const lookup = await post({
  action: "character_lookup",
  name: "Rangel Vendetta",
});

assert(lookup?.source === "rubinot_official", "character lookup source regression");
assert(["found", "not_found"].includes(lookup?.lookup_status), `RubinOT lookup unavailable: ${JSON.stringify(lookup)}`);

if (lookup.lookup_status === "found") {
  assert(lookup?.data?.character_name, "character name missing");
  assert(Number(lookup?.data?.level) > 0, "character level missing");
  assert(["EK","RP","ED","MS","EM"].includes(lookup?.data?.vocation), "normalized vocation missing");
}

console.log(JSON.stringify({
  status: "ok",
  stage: "rubinot_character_lookup",
  lookup_status: lookup.lookup_status,
  character: lookup?.data?.character_name ?? null,
  level: lookup?.data?.level ?? null,
  vocation: lookup?.data?.vocation ?? null,
  world: lookup?.data?.world_name ?? null,
}, null, 2));
