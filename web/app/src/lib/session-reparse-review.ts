import type { ParsedSessionImport } from "./session-parser";

type Dictionary = Record<string, unknown>;
type Value = string | number | boolean | null;
function object(value: unknown): Dictionary {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Dictionary : {};
}
function at(value: unknown, path: string): unknown {
  return path.split(".").reduce<unknown>((current, key) => object(current)[key], value);
}
function primitive(value: unknown): Value {
  if (value == null || value === "") return null;
  return typeof value === "string" || typeof value === "number" ||
    typeof value === "boolean" ? value : null;
}
const metricFields = [
  ["hunt_analyse.duration_seconds", "Duração (segundos)"],
  ["hunt_analyse.xp_gain", "XP total"],
  ["hunt_analyse.raw_xp_gain", "Raw XP total"],
  ["hunt_analyse.xp_per_hour", "XP/h"],
  ["hunt_analyse.raw_xp_per_hour", "Raw XP/h"],
  ["hunt_analyse.loot_value", "Loot"],
  ["hunt_analyse.supplies_value", "Supplies"],
  ["hunt_analyse.balance_value", "Balance"],
  ["hunt_analyse.total_damage", "Dano causado"],
  ["hunt_analyse.total_healing", "Cura"],
  ["hunt_analyse.total_kills", "Criaturas mortas"],
  ["damage.incoming_total_damage", "Dano recebido"],
  ["damage.incoming_max_dps", "DPS recebido máximo"],
  ["damage.charm_damage_total", "Charm damage observado"],
  ["party_hunt.party_size", "Quantidade na party"],
  ["party_hunt.totals.loot_value", "Loot da party"],
  ["party_hunt.totals.supplies_value", "Supplies da party"],
  ["party_hunt.totals.balance_value", "Balance da party"],
  ["party_hunt.totals.total_damage", "Dano da party"],
  ["party_hunt.totals.total_healing", "Healing da party"],
] as const;
const counts = [
  ["misc.creatures", "Linhas de criaturas"],
  ["misc.looted_items", "Itens de loot"],
  ["misc.combat_stats", "Combat Stats"],
  ["damage.incoming_by_element", "Elementos recebidos"],
  ["damage.incoming_by_source", "Fontes de dano recebido"],
  ["party_hunt.players", "Jogadores da party"],
] as const;
const availabilities = [
  ["availability.hunt_analyse", "Hunt Analyzer disponível"],
  ["availability.misc", "Misc disponível"],
  ["availability.damage", "Damage disponível"],
  ["availability.party_hunt", "Party Hunt disponível"],
  ["availability.charm_damage", "Charm observado"],
] as const;
export type ReparseDifference = {
  key: string; label: string; before: Value; after: Value; regression: boolean;
};
export type ReparseReview = {
  stage: "session_reparse_review_v1";
  changes: ReparseDifference[];
  unchanged_metric_count: number;
  warnings_before: string[];
  warnings_after: string[];
  regression_reasons: string[];
  safe_to_apply: boolean;
  changed: boolean;
  no_raw_text_exposed: true;
};
function warnings(value: unknown) {
  const raw = at(value, "validation.warnings");
  return Array.isArray(raw) ? raw.filter((w):w is string=>typeof w === "string") : [];
}
export function buildSessionReparseReview(
  previous: Dictionary,
  next: ParsedSessionImport,
  previousParserVersion: string,
): ReparseReview {
  const changes: ReparseDifference[] = [];
  let unchanged = 0;
  const regressionReasons: string[] = [];
  const compare = (key: string, label: string, before: Value, after: Value, regression: boolean) => {
    if (before === after) { unchanged++; return; }
    changes.push({key,label,before,after,regression});
    if (regression) regressionReasons.push("Perda de dado antes conhecido em " + label);
  };
  for (const [key,label] of metricFields) {
    const before = primitive(at(previous,key));
    const after = primitive(at(next,key));
    compare(key,label,before,after,before !== null && after === null);
  }
  for (const [key,label] of counts) {
    const oldRows = at(previous,key);
    const newRows = at(next,key);
    const before = Array.isArray(oldRows) ? oldRows.length : null;
    const after = Array.isArray(newRows) ? newRows.length : null;
    compare(key + ".count",label,before,after,
      before !== null && (after === null || after < before));
  }
  // Reparsed names and per-source rows can contain private or detailed facts.
  // Compare them only server-side and block any rewriting that is not purely
  // additive. Do NOT emit row contents, names or text in the API diff.
  const observedRowPaths = [
    ...counts,
    ["damage.charm_damage", "Charm damage observado"],
  ] as const;
  for (const [key,label] of observedRowPaths) {
    const before = at(previous,key);
    const after = at(next,key);
    if (!Array.isArray(before) || before.length === 0) continue;
    if (!Array.isArray(after) ||
        !before.every((row) => after.some((candidate) =>
          JSON.stringify(candidate) === JSON.stringify(row)))) {
      regressionReasons.push("Conteúdo anteriormente registrado não foi preservado em " + label);
    }
  }
  const privateTextPaths = [
    ["hunt_analyse.session_data_raw", "intervalo original da hunt"],
    ["hunt_analyse.session_from_raw", "início original da hunt"],
    ["hunt_analyse.session_to_raw", "fim original da hunt"],
    ["party_hunt.totals.loot_type_raw", "tipo de loot da party"],
  ] as const;
  for (const [key,label] of privateTextPaths) {
    const before = primitive(at(previous,key));
    const after = primitive(at(next,key));
    if (before !== null && before !== after) {
      regressionReasons.push("Texto registrado mudou em " + label);
    }
  }
  for (const [key,label] of availabilities) {
    const before = primitive(at(previous,key));
    const after = primitive(at(next,key));
    compare(key,label,before,after,before === true && after === false);
  }
  const warningsBefore = warnings(previous);
  const warningsAfter = warnings(next);
  for (const added of warningsAfter.filter(w => !warningsBefore.includes(w))) {
    regressionReasons.push("Novo alerta do parser: " + added);
  }
  if (next.validation.recognized_metric_count === 0 ||
      !next.validation.has_primary_hunt_analyzer) {
    regressionReasons.push("Hunt Analyzer original não tem métricas principais reconhecidas");
  }
  const changed = changes.length > 0 ||
    previousParserVersion !== next.methodology.stage ||
    warningsBefore.join("\n") !== warningsAfter.join("\n");
  return {
    stage:"session_reparse_review_v1",
    changes,
    unchanged_metric_count:unchanged,
    warnings_before:warningsBefore,
    warnings_after:warningsAfter,
    regression_reasons:[...new Set(regressionReasons)],
    safe_to_apply:regressionReasons.length === 0 && changed,
    changed,
    no_raw_text_exposed:true,
  };
}
