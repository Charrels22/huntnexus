import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const account = readFileSync(resolve(root, "web/app/src/routes/account.tsx"), "utf8");
const api = readFileSync(resolve(root, "web/app/src/routes/api/huntnexus.ts"), "utf8");
const apiClient = readFileSync(resolve(root, "web/app/src/lib/api/huntnexus.ts"), "utf8");
const migration = readFileSync(resolve(root, "db/migrations/0164_topic05_auth_session_gate.sql"), "utf8");
const verification = readFileSync(resolve(root, "docs/evidence/2026-10-14-topic05-post-migration-verification.sql"), "utf8");
const rollbackVerification = readFileSync(resolve(root, "docs/evidence/2026-10-28-topic05-post-rollback-verification.sql"), "utf8");
const artifactManifest = JSON.parse(readFileSync(resolve(root, "docs/evidence/2026-10-28-topic05-artifact-manifest.json"), "utf8"));

for (const required of [
  "signInWithPassword",
  "signUp",
  "resetPasswordForEmail",
  "updateUser({ password",
  "current_password: currentPassword",
  "reauthenticate()",
  "nonce: reauthenticationCode.trim()",
  "mfa.enroll",
  "mfa.challengeAndVerify",
  'scope: "local"',
  'scope: "others"',
]) assert.match(account, new RegExp(required.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
assert.match(account, /signOut\("global"\)/);
assert.match(account, /authGate !== "ready"/);

assert.doesNotMatch(account, /signInWithOtp|sendMagicLink|shouldCreateUser/);
assert.match(account, /verifiedFactors\.length < 2/);
assert.match(account, /authGate === "ready"/);
const removalFlow = account.slice(account.indexOf("async function confirmFactorRemoval"), account.indexOf("function restorePreviousGuest"));
assert.ok(removalFlow.indexOf("mfa.challengeAndVerify") < removalFlow.indexOf("mfa.unenroll"), "MFA removal must reverify a preserved factor first");
assert.match(removalFlow, /factor\.id !== factorToRemove\.id/);
assert.match(removalFlow, /refreshSession\(\)/);

assert.match(api, /auth\.getUser\(accessToken\)/);
assert.match(api, /getAuthenticatorAssuranceLevel\(accessToken\)/);
assert.match(api, /huntnexus_auth_session_gate/);
assert.match(api, /auth\.state !== "ready"/);
assert.match(api, /request\.headers\.get\("authorization"\)/);
assert.match(api, /conflicting_auth_tokens/);
assert.match(apiClient, /headers\.authorization = `Bearer \$\{accessToken\}`/);
assert.match(apiClient, /key !== "access_token"/);

assert.match(migration, /from auth\.sessions/);
assert.match(migration, /from auth\.mfa_factors/);
assert.match(migration, /set search_path\s*=\s*''/i);
assert.match(migration, /pg_catalog\.jsonb_build_object/);
assert.match(migration, /pg_catalog\.count/);
assert.match(migration, /pg_catalog\.now/);
assert.match(migration, /grant execute[\s\S]*to service_role/i);
assert.match(migration, /revoke all[\s\S]*from public,anon,authenticated/i);
assert.doesNotMatch(migration, /\b(insert|update|delete)\s+(into|from)?\s*auth\./i);

for (const required of [
  "security_definer",
  "stable",
  "empty_search_path",
  "public_execute",
  "anon_execute",
  "authenticated_execute",
  "service_role_execute",
  "null_input_result",
  "sessions_has_not_after",
  "factors_has_status",
  "factors_has_type",
]) assert.match(verification, new RegExp(`\\b${required}\\b`));
assert.equal((verification.match(/\bverification_pass\b/g) || []).length, 4);
for (const required of [
  "function_absent",
  "auth_user_rows",
  "auth_session_rows",
  "auth_factor_rows",
  "verification_pass",
]) assert.match(rollbackVerification, new RegExp(`\\b${required}\\b`));

assert.equal(artifactManifest.algorithm, "sha256");
assert.equal(artifactManifest.artifacts.length, 4);
for (const artifact of artifactManifest.artifacts) {
  const content = readFileSync(resolve(root, artifact.path));
  const actual = createHash("sha256").update(content).digest("hex");
  assert.equal(actual, artifact.sha256, `${artifact.path} does not match the production-gate manifest`);
}

console.log("PASS topic 5 contract: password + TOTP UI, scoped sign-out, AAL2 and live-session API gate");
