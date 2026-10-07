import { createClient } from "@supabase/supabase-js";

function isOpaqueKey(value: string) {
  return value.startsWith("sb_publishable_") || value.startsWith("sb_secret_");
}

function supabaseFetch(key: string): typeof fetch {
  return (input, init) => {
    const headers = new Headers(
      typeof Request !== "undefined" && input instanceof Request ? input.headers : undefined,
    );
    if (init?.headers) new Headers(init.headers).forEach((value, name) => headers.set(name, value));
    if (isOpaqueKey(key) && headers.get("Authorization") === `Bearer ${key}`) {
      headers.delete("Authorization");
    }
    headers.set("apikey", key);
    return fetch(input, { ...init, headers });
  };
}

function createAdmin() {
  const url = process.env["SUPABASE_URL"];
  const key = process.env["SUPABASE_SERVICE_ROLE_KEY"];
  if (!url || !key) throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
  return createClient(url, key, {
    global: { fetch: supabaseFetch(key) },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

let admin: ReturnType<typeof createAdmin> | undefined;
export const supabaseAdmin = new Proxy({} as ReturnType<typeof createAdmin>, {
  get(_, prop, receiver) {
    if (!admin) admin = createAdmin();
    return Reflect.get(admin, prop, receiver);
  },
});
