export async function callHuntNexusApi<T = unknown>(body: Record<string, unknown>): Promise<T> {
  let accessToken = typeof body["access_token"] === "string" ? body["access_token"] : null;
  const payload: Record<string, unknown> = accessToken
    ? Object.fromEntries(Object.entries(body).filter(([key]) => key !== "access_token"))
    : body;

  if (typeof window !== "undefined" && !accessToken) {
    try {
      const { getSupabaseBrowserClient } = await import("@/integrations/supabase/client.browser");
      const supabase = getSupabaseBrowserClient();
      const { data } = supabase ? await supabase.auth.getSession() : { data: { session: null } };
      accessToken = data.session?.access_token ?? null;
    } catch {
      // Guest mode remains valid when no authenticated browser session exists.
    }
  }

  const headers: Record<string, string> = { "content-type": "application/json" };
  if (accessToken) headers.authorization = `Bearer ${accessToken}`;

  const response = await fetch("/api/huntnexus", {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data?.detail ?? data?.error ?? `HTTP ${response.status}`);
  }

  return data as T;
}

export function formatNumber(value: unknown, digits = 0) {
  return typeof value === "number"
    ? value.toLocaleString("pt-BR", { maximumFractionDigits: digits })
    : "—";
}
