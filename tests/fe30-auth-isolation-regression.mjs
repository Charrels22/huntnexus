// FE-30: synthetic browser storage regression; no tokens, Auth users or email.
import assert from "node:assert/strict";
import { getStoredClientId } from "../web/app/src/lib/client-id.ts";
import {
  markBoundClientId, isolateClientAfterAuthLoss,
} from "../web/app/src/lib/account-session-guard.ts";

const canonical = "a139c884-ae74-4d8a-95e4-2c36b9284500";
const newGuest = "b115b559-46fa-4f47-a914-178522128218";
const legacyGuest = "ced10894-9f6e-4525-a645-777774183780";
const nextGuest = "97e08d04-0ccb-4562-9587-50ad31c2d0a9";
const local = new Map();
const session = new Map();
const events = [];
const uuids = [newGuest, nextGuest];
globalThis.CustomEvent = class {
  constructor(type, options) { this.type=type; this.detail=options?.detail; }
};
function storage(map) {
  return {
    getItem: key => map.get(key) ?? null,
    setItem: (key,value) => map.set(key,String(value)),
    removeItem: key => map.delete(key),
  };
}
globalThis.window = {
  localStorage: storage(local),
  sessionStorage: storage(session),
  crypto: { randomUUID: () => {
    const next=uuids.shift();
    assert.ok(next, "Unexpected second rotation of same browser identity");
    return next;
  } },
  dispatchEvent: event => events.push(event),
};
const scopeKey = "huntnexus.client-id.v1";
const boundKey = "huntnexus.bound-client-id.v1";
const draftKey = "huntnexus.session-import.draft.v1";
const openKey = "huntnexus.open-player-session";

local.set(scopeKey,legacyGuest);
local.set(draftKey,"guest draft");
session.set(openKey,"guest open session");
assert.equal(markBoundClientId(canonical),false,"A different canonical UUID must not mark a guest");
assert.equal(local.has(boundKey),false);
assert.equal(isolateClientAfterAuthLoss(),false,"Unbound guest must not be wiped");
assert.equal(getStoredClientId(),legacyGuest);
assert.equal(local.get(draftKey),"guest draft");
assert.equal(session.get(openKey),"guest open session");
assert.equal(events.length,0);

local.set(scopeKey,canonical);
assert.equal(markBoundClientId(canonical),true);
assert.equal(local.get(boundKey),canonical);
assert.equal(isolateClientAfterAuthLoss(),true,"Cold startup without Auth must isolate prior bound scope");
assert.equal(getStoredClientId(),newGuest);
assert.equal(local.has(boundKey),false);
assert.equal(local.has(draftKey),false,"Bound Analyzer draft must be scrubbed");
assert.equal(session.has(openKey),false,"Opened private session must be scrubbed");
assert.equal(events.length,1);
assert.equal(events[0].detail.previous,canonical);
assert.equal(events[0].detail.current,newGuest);
assert.equal(isolateClientAfterAuthLoss(),false,"Second subscriber must not rotate again");
assert.equal(getStoredClientId(),newGuest);
assert.equal(events.length,1);

local.set(draftKey,"another guest draft");
session.set(openKey,"another guest session");
assert.equal(isolateClientAfterAuthLoss(),false);
assert.equal(local.get(draftKey),"another guest draft");
assert.equal(session.get(openKey),"another guest session");

assert.equal(isolateClientAfterAuthLoss(true),true,
  "Legacy authenticated session with no scope marker still requires isolation");
assert.equal(getStoredClientId(),nextGuest);
assert.equal(local.has(draftKey),false);
assert.equal(session.has(openKey),false);
assert.equal(events.length,2);
assert.equal(isolateClientAfterAuthLoss(),false);
assert.equal(events.length,2);

delete globalThis.window;
assert.equal(markBoundClientId(canonical),false,"SSR must not access browser storage");
assert.equal(isolateClientAfterAuthLoss(),false,"SSR guard must remain inert");

console.log(JSON.stringify({
  status: "ok", stage: "fe30_global_auth_scope_isolation_regression",
  guest_preserved_without_auth_binding: true,
  marker_requires_matching_canonical: true,
  cold_start_bound_scope_rotated: true,
  old_private_draft_scrubbed: true,
  duplicate_auth_events_idempotent: true,
  legacy_unmarked_session_isolated: true,
  real_supabase_auth_tested: false, real_two_device_tested: false,
},null,2));
