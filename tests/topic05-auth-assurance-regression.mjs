import assert from "node:assert/strict";
import { evaluateAuthGate, jwtSessionId, minimumPasswordLength, passwordMeetsPolicy } from "../web/app/src/lib/auth-security.ts";

assert.equal(evaluateAuthGate({ currentLevel: "aal1", nextLevel: "aal2", verifiedFactorCount: 0, activeSession: true }), "mfa_enrollment_required");
assert.equal(evaluateAuthGate({ currentLevel: "aal1", nextLevel: "aal2", verifiedFactorCount: 1, activeSession: true }), "mfa_challenge_required");
assert.equal(evaluateAuthGate({ currentLevel: "aal2", nextLevel: "aal2", verifiedFactorCount: 1, activeSession: true }), "ready");
assert.equal(evaluateAuthGate({ currentLevel: "aal2", nextLevel: "aal2", verifiedFactorCount: 2, activeSession: false }), "invalid_session");

assert.equal(minimumPasswordLength, 12);
assert.equal(passwordMeetsPolicy("short"), false);
assert.equal(passwordMeetsPolicy("twelve-chars"), true);

const sessionId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
const token = `${encode({ alg: "none" })}.${encode({ sub: "SYNTHETIC", session_id: sessionId })}.signature`;
assert.equal(jwtSessionId(token), sessionId);
assert.equal(jwtSessionId(`${encode({})}.${encode({ session_id: "not-a-uuid" })}.signature`), null);
assert.equal(jwtSessionId("broken"), null);

console.log("PASS topic 5 auth assurance: AAL2 gate, active session, 12-character client policy, JWT session_id");
