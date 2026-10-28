import assert from "node:assert/strict";
import { callHuntNexusApi } from "../web/app/src/lib/api/huntnexus.ts";

const originalFetch = globalThis.fetch;
const token = "header.payload.synthetic-signature-with-enough-length";
let captured;

globalThis.fetch = async (input, init) => {
  captured = { input, init };
  return Response.json({ data: { ok: true } });
};

try {
  const result = await callHuntNexusApi({ action: "account_status", access_token: token });
  assert.deepEqual(result, { data: { ok: true } });
  assert.equal(captured.input, "/api/huntnexus");
  assert.equal(captured.init.headers.authorization, `Bearer ${token}`);
  assert.equal(captured.init.headers["content-type"], "application/json");
  assert.deepEqual(JSON.parse(captured.init.body), { action: "account_status" });
} finally {
  globalThis.fetch = originalFetch;
}

console.log("PASS topic 5 auth transport: bearer header used and token omitted from JSON body");
