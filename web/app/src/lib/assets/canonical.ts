export type CanonicalAssetKind =
  | "hunt"
  | "creature"
  | "item"
  | "map"
  | "spell"
  | "character";

export type CanonicalAsset = {
  key: string;
  kind: CanonicalAssetKind;
  imageUrl: string | null;
  sourceUrl: string | null;
  sourceName: "Tibia" | "TibiaWiki" | "RubinOT" | "HuntNexus";
  canonical: boolean;
  notes?: string;
};

/**
 * Central asset registry for player-facing HuntNexus UI.
 *
 * Rules:
 * - Never fabricate game-world artwork.
 * - Hunt/creature/item/map visuals must be canonical or faithful source captures.
 * - Unknown assets resolve to null and the UI renders a neutral placeholder.
 * - Character presentation may use HuntNexus-stylized artwork separately.
 */
const registry = new Map<string, CanonicalAsset>();

export function registerCanonicalAsset(asset: CanonicalAsset) {
  registry.set(`${asset.kind}:${asset.key}`, asset);
}

export function getCanonicalAsset(kind: CanonicalAssetKind, key: string | null | undefined) {
  if (!key) return null;
  return registry.get(`${kind}:${key}`) ?? null;
}

export function canonicalAssetKey(kind: CanonicalAssetKind, key: string) {
  return `${kind}:${key}`;
}

// Seed only verified local/canonical assets here.
// Do not add generic fantasy fallback URLs.
export const canonicalAssetPolicy = {
  genericFantasyFallbackAllowed: false,
  stylizedCharacterAllowed: true,
  unknownAssetBehavior: "neutral_placeholder",
} as const;
