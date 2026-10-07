export type HuntNexusVocation = "EK" | "RP" | "ED" | "MS" | "EM";
export type HuntObjective = "xp" | "profit" | "balanced";

export type RecommendInput = {
  vocation: HuntNexusVocation;
  level: number;
  objective?: HuntObjective;
  partySize?: number;
  limit?: number;
  defensiveItemsPerSlot?: number;
};

export type BossBuildInput = {
  bossKey: string;
  vocation: HuntNexusVocation;
  level: number;
};

export class HuntNexusApi {
  constructor(
    private readonly endpoint: string,
    private readonly anonKey?: string,
  ) {}

  private async post<T>(body: unknown): Promise<T> {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };

    if (this.anonKey) {
      headers.apikey = this.anonKey;
      headers.Authorization = `Bearer ${this.anonKey}`;
    }

    const response = await fetch(this.endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
    });

    const payload = await response.json();

    if (!response.ok) {
      throw new Error(payload?.detail || payload?.error || "HuntNexus API request failed");
    }

    return payload.data as T;
  }

  recommend<T = unknown>(input: RecommendInput): Promise<T> {
    return this.post<T>({
      action: "recommend",
      vocation: input.vocation,
      level: input.level,
      objective: input.objective ?? "balanced",
      party_size: input.partySize ?? 1,
      limit: input.limit ?? 5,
      defensive_items_per_slot: input.defensiveItemsPerSlot ?? 3,
    });
  }

  bossBuild<T = unknown>(input: BossBuildInput): Promise<T> {
    return this.post<T>({
      action: "boss_build",
      boss_key: input.bossKey,
      vocation: input.vocation,
      level: input.level,
    });
  }
}
