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

export type RequestAccessTokenResult = {
  token: string | null;
  error: "invalid_authorization_header" | "invalid_auth_token" | "conflicting_auth_tokens" | null;
};

export const minimumPasswordLength = 12;
export const strongPasswordSymbols = "!@#$%^&*()_+-=[]{};'\\:\"|<>?,./`~";

export function evaluateAuthGate(input: AuthGateInput): AuthGateState {
  if (!input.activeSession) return "invalid_session";
  if (input.verifiedFactorCount < 1 || input.nextLevel !== "aal2") {
    return "mfa_enrollment_required";
  }
  if (input.currentLevel !== "aal2") return "mfa_challenge_required";
  return "ready";
}

export function passwordMeetsPolicy(password: string): boolean {
  return password.length >= minimumPasswordLength
    && /[a-z]/.test(password)
    && /[A-Z]/.test(password)
    && /[0-9]/.test(password)
    && Array.from(strongPasswordSymbols).some((character) => password.includes(character));
}

export function extractRequestAccessToken(
  authorizationHeader: string | null,
  bodyAccessToken: unknown,
): RequestAccessTokenResult {
  let headerToken: string | null = null;
  if (authorizationHeader !== null) {
    const match = /^Bearer\s+(\S+)$/i.exec(authorizationHeader.trim());
    if (!match?.[1]) return { token: null, error: "invalid_authorization_header" };
    headerToken = match[1];
  }

  const bodyToken = typeof bodyAccessToken === "string" ? bodyAccessToken : null;
  for (const token of [headerToken, bodyToken]) {
    if (token !== null && (token.length < 20 || token.length > 8192 || /\s/.test(token))) {
      return { token: null, error: "invalid_auth_token" };
    }
  }
  if (headerToken && bodyToken && headerToken !== bodyToken) {
    return { token: null, error: "conflicting_auth_tokens" };
  }
  return { token: headerToken ?? bodyToken, error: null };
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
    return typeof sessionId === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(sessionId)
      ? sessionId
      : null;
  } catch {
    return null;
  }
}
