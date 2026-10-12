const storageKey = "huntnexus.client-id.v1";
// A UUID is a guest capability and eventually a bound account scope. Reject
// malformed stored values rather than letting them flow into private APIs.
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function getOrCreateClientId() {
  if (typeof window === "undefined") return null;

  let value = window.localStorage.getItem(storageKey);
  if (value && uuidPattern.test(value)) return value;

  value = window.crypto.randomUUID();
  window.localStorage.setItem(storageKey, value);
  return value;
}


export function setClientId(value: string) {
  if (typeof window === "undefined") return false;
  if (!uuidPattern.test(value)) return false;

  const previous = window.localStorage.getItem(storageKey);
  window.localStorage.setItem(storageKey, value);

  if (previous !== value) {
    window.dispatchEvent(new CustomEvent("huntnexus:client-id-changed", {
      detail: { previous, current: value },
    }));
  }

  return true;
}

export function getStoredClientId() {
  if (typeof window === "undefined") return null;
  const value = window.localStorage.getItem(storageKey);
  return value && uuidPattern.test(value) ? value : null;
}
