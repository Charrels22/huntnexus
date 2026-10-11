export async function callHuntNexusApi<T = unknown>(body: Record<string, unknown>): Promise<T> {
  let payload: Record<string, unknown> = body;

  if (typeof window !== "undefined" && typeof body["access_token"] !== "string") {
    try {
      const { getSupabaseBrowserClient } = await import("@/integrations/supabase/client.browser");
      const supabase = getSupabaseBrowserClient();
      const { data } = supabase ? await supabase.auth.getSession() : { data: { session: null } };
      const accessToken = data.session?.access_token;
      if (accessToken) payload = { ...body, access_token: accessToken };
    } catch {
      // Guest mode remains valid when no authenticated browser session exists.
    }
  }

  const response = await fetch("/api/huntnexus", {
    method: "POST",
    headers: { "content-type": "application/json" },
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
