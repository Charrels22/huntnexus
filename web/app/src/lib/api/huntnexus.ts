export async function callHuntNexusApi<T = unknown>(body: Record<string, unknown>): Promise<T> {
  const response = await fetch("/api/huntnexus", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
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
