export type AssuranceLevel = string | null;

export type AuthGateInput = {
  currentLevel: AssuranceLevel;
  nextLevel: AssuranceLevel;
  verifiedFactorCount: number;
  activeSession: boolean;
};

export type AuthGateState =
  | "ready"
  | "invalid_session"
  | "mfa_enrollment_required"
  | "mfa_challenge_required";

export const minimumPasswordLength = 12;

export function evaluateAuthGate(input: AuthGateInput): AuthGateState {
  if (!input.activeSession) return "invalid_session";
  if (input.verifiedFactorCount < 1 || input.nextLevel !== "aal2") {
    return "mfa_enrollment_required";
  }
  if (input.currentLevel !== "aal2") return "mfa_challenge_required";
  return "ready";
}

export function passwordMeetsPolicy(password: string): boolean {
  return password.length >= minimumPasswordLength;
}

export function jwtSessionId(accessToken: string): string | null {
  try {
    const parts = accessToken.split(".");
    if (parts.length !== 3) return null;
    const encodedPayload = parts[1];
    if (!encodedPayload) return null;
    const base64 = encodedPayload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const payload = JSON.parse(atob(padded)) as Record<string, unknown>;
    const sessionId = payload["session_id"];
    return typeof sessionId === "string" && /^[0-9a-f-]{36}$/i.test(sessionId)
      ? sessionId
      : null;
  } catch {
    return null;
  }
}
