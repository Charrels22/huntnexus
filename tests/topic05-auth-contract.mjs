import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const account = readFileSync(resolve(root, "web/app/src/routes/account.tsx"), "utf8");
const api = readFileSync(resolve(root, "web/app/src/routes/api/huntnexus.ts"), "utf8");
const migration = readFileSync(resolve(root, "db/migrations/0164_topic05_auth_session_gate.sql"), "utf8");

for (const required of [
  "signInWithPassword",
  "signUp",
  "resetPasswordForEmail",
  "updateUser({ password",
  "mfa.enroll",
  "mfa.challengeAndVerify",
  'scope: "local"',
  'scope: "others"',
]) assert.match(account, new RegExp(required.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
assert.match(account, /signOut\("global"\)/);

assert.doesNotMatch(account, /signInWithOtp|sendMagicLink|shouldCreateUser/);
assert.match(account, /verifiedFactors\.length < 2/);
assert.match(account, /authGate === "ready"/);

assert.match(api, /auth\.getUser\(accessToken\)/);
assert.match(api, /getAuthenticatorAssuranceLevel\(accessToken\)/);
assert.match(api, /huntnexus_auth_session_gate/);
assert.match(api, /auth\.state !== "ready"/);

assert.match(migration, /from auth\.sessions/);
assert.match(migration, /from auth\.mfa_factors/);
assert.match(migration, /grant execute[\s\S]*to service_role/i);
assert.match(migration, /revoke all[\s\S]*from public,anon,authenticated/i);
assert.doesNotMatch(migration, /\b(insert|update|delete)\s+(into|from)?\s*auth\./i);

console.log("PASS topic 5 contract: password + TOTP UI, scoped sign-out, AAL2 and live-session API gate");
