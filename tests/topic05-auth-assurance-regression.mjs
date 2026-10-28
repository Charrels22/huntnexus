import assert from "node:assert/strict";
import { evaluateAuthGate, extractRequestAccessToken, jwtSessionId, minimumPasswordLength, passwordMeetsPolicy } from "../web/app/src/lib/auth-security.ts";

assert.equal(evaluateAuthGate({ currentLevel: "aal1", nextLevel: "aal2", verifiedFactorCount: 0, activeSession: true }), "mfa_enrollment_required");
assert.equal(evaluateAuthGate({ currentLevel: "aal1", nextLevel: "aal2", verifiedFactorCount: 1, activeSession: true }), "mfa_challenge_required");
assert.equal(evaluateAuthGate({ currentLevel: "aal2", nextLevel: "aal2", verifiedFactorCount: 1, activeSession: true }), "ready");
assert.equal(evaluateAuthGate({ currentLevel: "aal2", nextLevel: "aal2", verifiedFactorCount: 2, activeSession: false }), "invalid_session");

assert.equal(minimumPasswordLength, 12);
assert.equal(passwordMeetsPolicy("short"), false);
assert.equal(passwordMeetsPolicy("twelve-chars"), false);
assert.equal(passwordMeetsPolicy("TwelveChars1!"), true);
assert.equal(passwordMeetsPolicy("twelvechars1!"), false);
assert.equal(passwordMeetsPolicy("TWELVECHARS1!"), false);
assert.equal(passwordMeetsPolicy("TwelveChars!!"), false);
assert.equal(passwordMeetsPolicy("TwelveChars12"), false);

const sessionId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
const token = `${encode({ alg: "none" })}.${encode({ sub: "SYNTHETIC", session_id: sessionId })}.signature`;
assert.equal(jwtSessionId(token), sessionId);
assert.equal(jwtSessionId(`${encode({})}.${encode({ session_id: "not-a-uuid" })}.signature`), null);
assert.equal(jwtSessionId(`${encode({})}.${encode({ session_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" })}.signature`), null);
assert.equal(jwtSessionId("broken"), null);

const bearerToken = "header.payload.signature-with-enough-length";
assert.deepEqual(extractRequestAccessToken(`Bearer ${bearerToken}`, undefined), { token: bearerToken, error: null });
assert.deepEqual(extractRequestAccessToken(null, bearerToken), { token: bearerToken, error: null });
assert.deepEqual(extractRequestAccessToken(`Bearer ${bearerToken}`, bearerToken), { token: bearerToken, error: null });
assert.deepEqual(extractRequestAccessToken("Basic credentials", undefined), { token: null, error: "invalid_authorization_header" });
assert.deepEqual(extractRequestAccessToken(`Bearer ${bearerToken}`, `${bearerToken}-other`), { token: null, error: "conflicting_auth_tokens" });

console.log("PASS topic 5 auth assurance: AAL2 gate, active session, strong password, strict session_id, bearer transport");
