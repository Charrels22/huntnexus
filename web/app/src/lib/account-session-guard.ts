import { getStoredClientId, setClientId } from "./client-id";

const boundScopeKey = "huntnexus.bound-client-id.v1";
const analyzerDraftKey = "huntnexus.session-import.draft.v1";
const openSessionKey = "huntnexus.open-player-session";

// Record the authenticated scope only after account_resolve has succeeded.
// A guest UUID is not an authenticated identity and must never be marked early.
export function markBoundClientId(canonicalId: string): boolean {
  if (typeof window === "undefined" || getStoredClientId() !== canonicalId) return false;
  window.localStorage.setItem(boundScopeKey, canonicalId);
  return true;
}

// Called after SIGNED_OUT, or on INITIAL_SESSION without Auth when the last
// browser visit was linked. Idempotent across the account and global shell.
export function isolateClientAfterAuthLoss(hadAuthenticatedSession = false): boolean {
  if (typeof window === "undefined") return false;
  const boundScope = window.localStorage.getItem(boundScopeKey);
  const current = getStoredClientId();
  const rotate = Boolean(current && (hadAuthenticatedSession || boundScope === current));
  const scrub = hadAuthenticatedSession || Boolean(boundScope);
  if (rotate) setClientId(window.crypto.randomUUID());
  if (scrub) {
    window.localStorage.removeItem(analyzerDraftKey);
    window.sessionStorage.removeItem(openSessionKey);
  }
  window.localStorage.removeItem(boundScopeKey);
  return Boolean(rotate || scrub);
}
