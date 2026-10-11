const storageKey = "huntnexus.client-id.v1";

export function getOrCreateClientId() {
  if (typeof window === "undefined") return null;

  let value = window.localStorage.getItem(storageKey);
  if (value && /^[0-9a-f-]{36}$/i.test(value)) return value;

  value = window.crypto.randomUUID();
  window.localStorage.setItem(storageKey, value);
  return value;
}


export function setClientId(value: string) {
  if (typeof window === "undefined") return false;
  if (!/^[0-9a-f-]{36}$/i.test(value)) return false;

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
  return value && /^[0-9a-f-]{36}$/i.test(value) ? value : null;
}
