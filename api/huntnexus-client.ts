export type HuntNexusVocation = "EK" | "RP" | "ED" | "MS";
export type HuntObjective = "xp" | "profit" | "balanced";
export type CharacterWeaponFamily = "sword" | "axe" | "club";

export type CharacterCombatProfile = {
  weaponFamily: CharacterWeaponFamily;
  effectiveWeaponSkill?: number;
  effectiveMagicLevel?: number;
  effectiveShielding?: number;
};

export type ProficiencyPreviewInput = {
  weaponFamily: CharacterWeaponFamily;
  oneHandActivePerkOrders?: number[];
  twoHandActivePerkOrders?: number[];
  effectiveWeaponSkill?: number;
  effectiveMagicLevel?: number;
};

export type ApiEnvelope<T> = {
  data: T;
  warnings?: unknown[];
};

export type RecommendInput = {
  vocation: HuntNexusVocation;
  level: number;
  objective?: HuntObjective;
  partySize?: number;
  limit?: number;
  defensiveItemsPerSlot?: number;
  characterProfile?: CharacterCombatProfile;
  oneHandActivePerkOrders?: number[];
  twoHandActivePerkOrders?: number[];
};

export type BossBuildInput = {
  bossKey: string;
  vocation: HuntNexusVocation;
  level: number;
};

export type HuntLookup = {
  hunt_key: string;
  name: string;
  city?: string | null;
  vocation?: string | null;
  level_knights?: string | null;
  level_paladins?: string | null;
  level_mages?: string | null;
  observed_sessions: number;
  has_observed_incoming_damage: boolean;
};

export type BossLookup = {
  boss_key: string;
  name: string;
  encounter_type: string;
  final_build_blocked: boolean;
  readiness_status: string;
  guards: unknown[];
};

export class HuntNexusApi {
  constructor(
    private readonly endpoint: string,
    private readonly anonKey?: string,
  ) {}

  private async post<T>(body: unknown): Promise<ApiEnvelope<T>> {
    const headers: Record<string, string> = { "Content-Type": "application/json" };

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

    return payload as ApiEnvelope<T>;
  }

  recommend<T = unknown>(input: RecommendInput) {
    return this.post<T>({
      action: "recommend",
      vocation: input.vocation,
      level: input.level,
      objective: input.objective ?? "balanced",
      party_size: input.partySize ?? 1,
      limit: input.limit ?? 5,
      defensive_items_per_slot: input.defensiveItemsPerSlot ?? 3,
      character_profile: input.characterProfile
        ? {
            weapon_family: input.characterProfile.weaponFamily,
            effective_weapon_skill: input.characterProfile.effectiveWeaponSkill,
            effective_magic_level: input.characterProfile.effectiveMagicLevel,
            effective_shielding: input.characterProfile.effectiveShielding,
          }
        : undefined,
      one_hand_active_perk_orders: input.oneHandActivePerkOrders ?? [],
      two_hand_active_perk_orders: input.twoHandActivePerkOrders ?? [],
    });
  }

  profileContract<T = unknown>(vocation: HuntNexusVocation) {
    return this.post<T>({ action: "profile_contract", vocation });
  }

  handContextBatch<T = unknown>(input: {
    huntKeys: string[];
    level: number;
    characterProfile: CharacterCombatProfile;
    oneHandActivePerkOrders?: number[];
    twoHandActivePerkOrders?: number[];
  }) {
    return this.post<T>({
      action: "hand_context_batch",
      hunt_keys: input.huntKeys,
      level: input.level,
      character_profile: {
        weapon_family: input.characterProfile.weaponFamily,
        effective_weapon_skill: input.characterProfile.effectiveWeaponSkill,
        effective_magic_level: input.characterProfile.effectiveMagicLevel,
        effective_shielding: input.characterProfile.effectiveShielding,
      },
      one_hand_active_perk_orders: input.oneHandActivePerkOrders ?? [],
      two_hand_active_perk_orders: input.twoHandActivePerkOrders ?? [],
    });
  }

  proficiencyPreview<T = unknown>(input: ProficiencyPreviewInput) {
    return this.post<T>({
      action: "proficiency_preview",
      weapon_family: input.weaponFamily,
      one_hand_active_perk_orders: input.oneHandActivePerkOrders ?? [],
      two_hand_active_perk_orders: input.twoHandActivePerkOrders ?? [],
      effective_weapon_skill: input.effectiveWeaponSkill,
      effective_magic_level: input.effectiveMagicLevel,
    });
  }

  bossBuild<T = unknown>(input: BossBuildInput) {
    return this.post<T>({
      action: "boss_build",
      boss_key: input.bossKey,
      vocation: input.vocation,
      level: input.level,
    });
  }

  async searchHunts(query = "", limit = 20): Promise<HuntLookup[]> {
    const r = await this.post<HuntLookup[]>({ action: "search_hunts", query, limit });
    return r.data;
  }

  async searchBosses(query = "", limit = 20): Promise<BossLookup[]> {
    const r = await this.post<BossLookup[]>({ action: "search_bosses", query, limit });
    return r.data;
  }

  health<T = unknown>() {
    return this.post<T>({ action: "health" });
  }
}
