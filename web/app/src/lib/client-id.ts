const storageKey = "huntnexus.client-id.v1";

export function getOrCreateClientId() {
  if (typeof window === "undefined") return null;

  let value = window.localStorage.getItem(storageKey);
  if (value && /^[0-9a-f-]{36}$/i.test(value)) return value;

  value = window.crypto.randomUUID();
  window.localStorage.setItem(storageKey, value);
  return value;
}
