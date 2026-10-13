export type PlannerContext = {
  vocation?: string;
  level?: number;
  setObjective?: string;
  huntObjective?: string;
  party?: number;
};

// URL context is public character configuration, never identity or ownership.
export function parsePlannerContext(search: Record<string, unknown>): PlannerContext {
  const result: PlannerContext = {};
  if (["EK", "RP", "ED", "MS", "EM"].includes(String(search.vocation))) result.vocation = String(search.vocation);
  const level = Number(search.level);
  if (Number.isInteger(level) && level >= 1 && level <= 5000) result.level = level;
  if (["offense", "defense", "sustain", "utility", "balanced"].includes(String(search.setObjective))) result.setObjective = String(search.setObjective);
  if (["xp", "profit", "balanced"].includes(String(search.huntObjective))) result.huntObjective = String(search.huntObjective);
  const party = Number(search.party);
  if (Number.isInteger(party) && party >= 1 && party <= 5) result.party = party;
  return result;
}
