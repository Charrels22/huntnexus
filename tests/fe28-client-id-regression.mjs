// FE-28: browser storage client_id is an authorization-scope capability.
// Reject any legacy/malformed 36-char value that fails strict UUID syntax.
import assert from "node:assert/strict";
import { getOrCreateClientId, getStoredClientId, setClientId }
  from "../web/app/src/lib/client-id.ts";

const storage=new Map();
const events=[];
const generated=[
  "d7f0755e-a53c-4bbf-8c2d-dc34f25885ad",
  "7178ea3b-ae35-4e87-b960-29dbd684e43d",
  "bc29aa88-f5a3-43a9-b3a4-6efafbb41c12",
];
globalThis.CustomEvent=class {
  constructor(type,init) {this.type=type;this.detail=init?.detail;}
};
globalThis.window={
  localStorage:{
    getItem:key=>storage.get(key)??null,
    setItem:(key,value)=>storage.set(key,String(value)),
  },
  crypto:{randomUUID:()=>{const next=generated.shift();assert.ok(next);return next;}},
  dispatchEvent:event=>events.push(event),
};
const storageKey="huntnexus.client-id.v1";

assert.equal(getStoredClientId(),null);
const poisoned="------------------------------------";
assert.equal(poisoned.length,36);
storage.set(storageKey,poisoned);
assert.equal(getStoredClientId(),null,
  "36 hyphens are not a valid UUID and must never be a private scope");
const first=getOrCreateClientId();
assert.equal(first,"d7f0755e-a53c-4bbf-8c2d-dc34f25885ad");
assert.equal(getStoredClientId(),first);
assert.equal(getOrCreateClientId(),first,"Preserve valid stable client scope");
assert.equal(setClientId(poisoned),false);
assert.equal(getStoredClientId(),first,"Invalid overwrite must be rejected");
assert.equal(setClientId("bbbbbbbb-bbbb-3bbb-abbb-bbbbbbbbbbbb"),true,
  "Existing v3 UUID-shaped client IDs must remain compatible");
assert.equal(setClientId("some-prefix-1234-abcde-very-bad-id"),false);
assert.equal(setClientId("7178ea3b-ae35-4e87-b960-29dbd684e43d"),true);
assert.equal(events.length,2);
assert.equal(events[0].detail.previous,first);
assert.equal(events[1].detail.current,"7178ea3b-ae35-4e87-b960-29dbd684e43d");
assert.equal(setClientId("7178ea3b-ae35-4e87-b960-29dbd684e43d"),true);
assert.equal(events.length,2,"Idempotent client ID updates must not emit duplicate events");
storage.set(storageKey,"ffffffffffffffffffffffffffffffffffff");
assert.equal(getOrCreateClientId(),"bc29aa88-f5a3-43a9-b3a4-6efafbb41c12",
  "Malformed but hex-only scope must be replaced with secure UUID");
console.log(JSON.stringify({
  status:"ok",
  stage:"fe28_strict_guest_client_identity_v1",
  invalid_36_char_scopes_rejected:true,
  valid_legacy_uuid_versions_retained:true,
  same_id_write_idempotent:true,
  identity_change_events_checked:true,
  valid_stored_id_reused:true,
  actual_authenticated_user_tested:false,
},null,2));
