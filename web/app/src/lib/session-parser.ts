export type SessionImportBlocks = {
  hunt?: string;
  party?: string;
  input?: string;
  misc?: string;
};

export type AnalyzerType = "hunt" | "party" | "input" | "misc";

export function sessionImportWarningLabel(warning: string): string {
  if (warning.startsWith("invalid_numeric_format:")) {
    return `Formato numérico não reconhecido em ${warning.slice("invalid_numeric_format:".length)}`;
  }
  const labels: Record<string, string> = {
    hunt_analyzer_missing: "Hunt Analyzer ausente",
    no_primary_metrics_recognized: "Métricas principais não reconhecidas",
    invalid_duration_format: "Duração não reconhecida na linha Session (aceitos HH:MMh, HH:MM, HH:MM:SS ou 1h 30m)",
    session_time_range_unrecognized: "O intervalo de datas da sessão não pôde ser interpretado",
    party_block_present_but_no_players_recognized: "Party enviada, mas nenhum jogador foi reconhecido",
    input_block_present_but_no_damage_rows_recognized: "Damage Input enviado sem linhas de dano reconhecidas",
  };
  return labels[warning] ?? warning;
}


export function detectAnalyzerType(text: string): AnalyzerType | null {
  const normalized = text.replace(/\r\n?/g, "\n").trim();
  if (!normalized) return null;

  // A Party Hunt Analyzer can also contain XP fields. Detect strong party
  // evidence first, otherwise the generic XP Gain rule mislabels it as Hunt.
  const partyHeader = /(?:^|\n)\s*Loot Type\s*:/i.test(normalized);
  const hasSessionContext = /(?:^|\n)\s*(?:Session data\s*:\s*From|Session\s*:)/i.test(normalized);
  if (partyHeader && hasSessionContext) return "party";
  if (/Session data\s*:\s*From/i.test(normalized)) {
    const playerSignals = (normalized.match(/(?:^|\n)[^:\n]+(?:\s+\(Leader\))?\s*\n\s*Loot\s*:/gi) ?? []).length;
    if (playerSignals > 0) return "party";
  }

  if (/Killed Monsters:?/i.test(normalized) || /XP Gain\s*:/i.test(normalized) || /Looted Items:?/i.test(normalized)) {
    return "hunt";
  }

  if (/Damage Types:?/i.test(normalized) || /Damage Sources:?/i.test(normalized)) {
    return "input";
  }

  if (/^(?:[A-Za-z][^:\n]{1,60})\s*:\s*.+$/m.test(normalized)) {
    return "misc";
  }

  return null;
}

export type HuntAnalyzerMetrics = {
  duration_seconds: number | null;
  raw_xp_gain: number | null;
  xp_gain: number | null;
  xp_per_hour: number | null;
  raw_xp_per_hour: number | null;
  loot_value: number | null;
  supplies_value: number | null;
  balance_value: number | null;
  total_damage: number | null;
  damage_per_hour: number | null;
  total_healing: number | null;
  healing_per_hour: number | null;
};

export type ParsedSessionImport = {
  hunt_analyse: HuntAnalyzerMetrics & {
    session_data_raw: string | null;
    session_from_raw: string | null;
    session_to_raw: string | null;
    total_kills: number | null;
    party_size: number | null;
  };
  misc: {
    creatures: Array<{
      monster_name_raw: string;
      monster_key: string | null;
      resolution_status: "raw_name";
      kills: number;
    }>;
    combat_stats: Array<{
      stat_key: string;
      stat_name_raw: string;
      numeric_value: number | null;
      raw_value: string;
      unit: string;
    }>;
    looted_items: Array<{
      item_name_raw: string;
      item_name: string;
      indefinite_article: "a" | "an" | null;
      amount: number;
    }>;
    raw_misc_available: boolean;
  };
  damage: {
    total_damage: number | null;
    incoming_total_damage: number | null;
    incoming_max_dps: number | null;
    incoming_by_element: Array<Record<string, unknown>>;
    incoming_by_source: Array<Record<string, unknown>>;
    charm_damage: Array<{
      source_name_raw: string;
      damage: number;
      damage_per_hour: number | null;
    }>;
    charm_damage_total: number | null;
    charm_damage_per_hour: number | null;
    charm_damage_status: "observed" | "not_observed";
    charm_damage_available: boolean;
  };
  party_hunt: {
    party_size: number | null;
    totals: {
      duration_seconds: number | null;
      loot_value: number | null;
      supplies_value: number | null;
      balance_value: number | null;
      total_damage: number | null;
      total_healing: number | null;
      loot_type_raw: string | null;
    };
    players: Array<Record<string, unknown>>;
  };
  availability: {
    hunt_analyse: boolean;
    misc: boolean;
    damage: boolean;
    party_hunt: boolean;
    charm_damage: boolean;
  };
  validation: {
    has_primary_hunt_analyzer: boolean;
    recognized_metric_count: number;
    creature_rows: number;
    looted_item_rows: number;
    party_player_rows: number;
    incoming_element_rows: number;
    incoming_source_rows: number;
    misc_stat_rows: number;
    warnings: string[];
  };
  methodology: {
    stage: "session_parser_v2";
    raw_blocks_preserved: true;
    unknown_values_invented: false;
    community_evidence_written: false;
  };
};

function lines(text: string | undefined) {
  return (text ?? "")
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function parseIntegerLike(value: string | undefined): number | null {
  if (value == null) return null;
  const raw = value.trim();
  const plainInteger = /^[+-]?[0-9]+$/;
  const groupedInteger = /^[+-]?[0-9]{1,3}(?:[,\.\s][0-9]{3})+$/;
  if (!plainInteger.test(raw) && !groupedInteger.test(raw)) return null;
  const parsed = Number(raw.replace(/[,\.\s]/g, ""));
  return Number.isSafeInteger(parsed) ? parsed : null;
}

function parseDecimalLike(value: string | undefined): number | null {
  if (!value) return null;
  const cleaned = value.trim().replace(/%/g, "").replace(/\s/g, "");
  if (!cleaned) return null;

  if (/^-?\d{1,3}(,\d{3})+$/.test(cleaned) || /^-?\d+$/.test(cleaned)) {
    return Number(cleaned.replace(/,/g, ""));
  }

  const normalized = cleaned.includes(",") && !cleaned.includes(".")
    ? cleaned.replace(",", ".")
    : cleaned.replace(/,/g, "");
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

function metric(textLines: string[], labels: string[]): number | null {
  for (const line of textLines) {
    for (const label of labels) {
      const match = line.match(new RegExp("^" + escapeRegex(label) + "\\s*:\\s*(.+)$", "i"));
      if (match?.[1]) return parseIntegerLike(match[1]);
    }
  }
  return null;
}

function textMetric(textLines: string[], labels: string[]): string | null {
  for (const line of textLines) {
    for (const label of labels) {
      const match = line.match(new RegExp("^" + escapeRegex(label) + "\\s*:\\s*(.+)$", "i"));
      if (match?.[1]) return match[1].trim();
    }
  }
  return null;
}

function parseDurationSeconds(textLines: string[]) {
  const raw = textMetric(textLines, ["Session"]);
  if (raw) {
    // Tibia commonly exports HH:MMh; retain earlier 1h 30m support and
    // accept clock-style HH:MM / HH:MM:SS without guessing from XP/h.
    const clock = raw.match(/^(\d+)\s*:\s*([0-5]\d)(?::([0-5]\d))?\s*h?$/i);
    if (clock?.[1] && clock?.[2]) {
      const seconds = Number(clock[1]) * 3600 + Number(clock[2]) * 60 + Number(clock[3] || 0);
      return Number.isSafeInteger(seconds) ? seconds : null;
    }
    const hm = raw.match(/^(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?$/i);
    if (hm && (hm[1] || hm[2])) {
      const hours = Number(hm[1] || 0);
      const minutes = Number(hm[2] || 0);
      if (minutes >= 60) return null;
      const seconds = hours * 3600 + minutes * 60;
      return Number.isSafeInteger(seconds) ? seconds : null;
    }
    // Explicitly invalid Session text must remain invalid, never masked by
    // guessed time or inferred XP/h.
    return null;
  }

  // If the Session line is absent, timestamps copied in "Session data" are
  // primary evidence for elapsed time. Interpret both timestamps in the same
  // offset-free clock space; reject calendar overflow and reversed intervals.
  const range = parseSessionRange(textLines);
  if (!range.from_raw || !range.to_raw) return null;
  function timestamp(value: string): number | null {
    const match = value.match(/^(\d{4})-(\d{2})-(\d{2})[, T]+(\d{2}):(\d{2}):(\d{2})$/);
    if (!match) return null;
    const [year, month, day, hour, minute, second] = match.slice(1).map(Number);
    if (!year || !month || !day || hour == null || minute == null || second == null) return null;
    const stamp = Date.UTC(year, month - 1, day, hour, minute, second);
    const date = new Date(stamp);
    if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 ||
        date.getUTCDate() !== day || date.getUTCHours() !== hour ||
        date.getUTCMinutes() !== minute || date.getUTCSeconds() !== second) return null;
    return stamp;
  }
  const start = timestamp(range.from_raw);
  const end = timestamp(range.to_raw);
  if (start == null || end == null || end < start) return null;
  const seconds = (end - start) / 1000;
  return seconds <= 7 * 86400 ? seconds : null;
}

function parseSessionRange(textLines: string[]) {
  const raw = textMetric(textLines, ["Session data"]);
  if (!raw) return { raw: null, from_raw: null, to_raw: null };
  const match = raw.match(/^From\s+(.+?)\s+to\s+(.+)$/i);
  return {
    raw,
    from_raw: match?.[1]?.trim() ?? null,
    to_raw: match?.[2]?.trim() ?? null,
  };
}

function parseKilledMonsters(textLines: string[]) {
  const start = textLines.findIndex((line) => /^Killed Monsters:?$/i.test(line));
  if (start < 0) return [];

  const out: Array<{
    monster_name_raw: string;
    monster_key: string | null;
    resolution_status: "raw_name";
    kills: number;
  }> = [];
  for (let i = start + 1; i < textLines.length; i++) {
    const line = textLines[i];
    if (!line) continue;
    if (/^(Looted Items|Loot|Supplies|Balance|Damage|Healing|Session|XP Gain|XP\/h):/i.test(line)) break;
    const match = line.match(/^(\d[\d,]*)x\s+(.+)$/i);
    if (!match) continue;
    const kills = parseIntegerLike(match[1]);
    if (kills == null) continue;
    const monsterName = match[2];
    if (!monsterName) continue;
    out.push({
      monster_name_raw: monsterName.trim(),
      monster_key: null,
      resolution_status: "raw_name",
      kills,
    });
  }
  return out;
}

function parseLootedItems(textLines: string[]) {
  const start = textLines.findIndex((line) => /^Looted Items:?$/i.test(line));
  if (start < 0) return [];

  const out: Array<{
    item_name_raw: string;
    item_name: string;
    indefinite_article: "a" | "an" | null;
    amount: number;
  }> = [];
  for (let i = start + 1; i < textLines.length; i++) {
    const line = textLines[i];
    if (!line) continue;
    if (/^(Session|Raw XP Gain|XP Gain|Raw XP\/h|XP\/h|Loot|Supplies|Balance|Damage|Damage\/h|Healing|Healing\/h|Killed Monsters):/i.test(line)) break;

    const match = line.match(/^(\d[\d,]*)x\s+(.+)$/i);
    if (!match?.[1] || !match?.[2]) continue;

    const amount = parseIntegerLike(match[1]);
    if (amount == null) continue;

    const itemNameRaw = match[2].trim();
    const articleMatch = itemNameRaw.match(/^(a|an)\s+(.+)$/i);
    const indefiniteArticle = articleMatch?.[1]?.toLowerCase() === "an"
      ? "an"
      : articleMatch?.[1]
        ? "a"
        : null;
    const itemName = articleMatch?.[2]?.trim() || itemNameRaw;

    out.push({
      item_name_raw: itemNameRaw,
      item_name: itemName,
      indefinite_article: indefiniteArticle,
      amount,
    });
  }
  return out;
}

function parsePartyPlayers(textLines: string[]) {
  const globalLabels = new Set(["session", "session data", "loot type", "loot", "supplies", "balance", "damage", "healing"]);
  const players: Array<Record<string, unknown>> = [];

  for (let i = 0; i < textLines.length; i++) {
    const line = textLines[i];
    if (!line) continue;
    if (line.includes(":")) continue;
    if (/^(Killed Monsters|Looted Items)$/i.test(line)) continue;

    const next = textLines.slice(i + 1, i + 7);
    const hasPlayerMetrics = next.some((candidate) => /^(Loot|Supplies|Balance|Damage|Healing)\s*:/i.test(candidate));
    if (!hasPlayerMetrics) continue;

    const name = line.replace(/\s*\(Leader\)\s*$/i, "").trim();
    if (!name || globalLabels.has(name.toLowerCase())) continue;

    const block: string[] = [];
    for (let j = i + 1; j < textLines.length && block.length < 8; j++) {
      const candidate = textLines[j];
      if (!candidate) continue;
      if (!candidate.includes(":") && block.length > 0) break;
      block.push(candidate);
    }

    const loot = metric(block, ["Loot"]);
    const supplies = metric(block, ["Supplies"]);
    const balance = metric(block, ["Balance"]);
    const damage = metric(block, ["Damage"]);
    const healing = metric(block, ["Healing"]);

    if ([loot, supplies, balance, damage, healing].every((value) => value == null)) continue;

    players.push({
      name,
      leader: /\(Leader\)/i.test(line),
      loot,
      supplies,
      balance,
      damage,
      healing,
    });
  }

  return players;
}

function partyHeaderLines(textLines: string[]) {
  for (let i = 0; i < textLines.length; i++) {
    const line = textLines[i];
    if (!line || line.includes(":")) continue;

    const next = textLines.slice(i + 1, i + 7);
    const hasPlayerMetrics = next.some((candidate) => /^(Loot|Supplies|Balance|Damage|Healing)\s*:/i.test(candidate));
    if (hasPlayerMetrics) return textLines.slice(0, i);
  }

  return textLines;
}

function parseInputAnalyzer(textLines: string[]) {
  const elements: Array<Record<string, unknown>> = [];
  const sources: Array<Record<string, unknown>> = [];
  let section: "elements" | "sources" | null = null;
  let totalDamage: number | null = null;
  let maxDps: number | null = null;

  for (const line of textLines) {
    const totalMatch = line.match(/^(?:Total|Received Damage Total)\s*:\s*([\d,.]+)$/i);
    if (totalMatch?.[1]) {
      totalDamage = parseIntegerLike(totalMatch[1]);
      continue;
    }

    const maxDpsMatch = line.match(/^Max[ -]?DPS\s*:\s*([\d,.]+)$/i);
    if (maxDpsMatch?.[1]) {
      maxDps = parseIntegerLike(maxDpsMatch[1]);
      continue;
    }

    if (/^(damage types|elements)\s*:?$/i.test(line)) {
      section = "elements";
      continue;
    }
    if (/^(damage sources|sources)\s*:?$/i.test(line)) {
      section = "sources";
      continue;
    }

    const match = line.match(/^(.+?)\s*:\s*([\d,.]+)(?:\s*\(([-\d,.]+)%\))?$/);
    if (!match) continue;

    const rawLabel = match[1];
    const rawValue = match[2];
    if (!rawLabel || !rawValue) continue;
    const label = rawLabel.trim();
    const value = parseIntegerLike(rawValue);
    const share = match[3] ? parseDecimalLike(match[3]) : null;
    if (value == null) continue;

    const normalized = label.toLowerCase();
    const knownElement = ["physical","fire","ice","earth","energy","death","holy","life drain","mana drain","drowning"].includes(normalized);

    if (section === "elements" || (section === null && knownElement)) {
      elements.push({ element: normalized.replace(/\s+/g, "_"), damage: value, share_percent: share });
    } else if (section === "sources") {
      sources.push({ source_name_raw: label, damage: value, share_percent: share });
    }
  }

  return { elements, sources, totalDamage, maxDps };
}

function parseMisc(textLines: string[]) {
  const stats: Array<{ stat_key: string; stat_name_raw: string; numeric_value: number | null; raw_value: string; unit: string }> = [];
  for (const line of textLines) {
    const match = line.match(/^(.+?)\s*:\s*(.+)$/);
    if (!match) continue;
    const rawName = match[1];
    const rawValue = match[2];
    if (!rawName || !rawValue) continue;
    const name = rawName.trim();
    const raw = rawValue.trim();
    stats.push({
      stat_key: slug(name),
      stat_name_raw: name,
      numeric_value: parseDecimalLike(raw),
      raw_value: raw,
      unit: raw.includes("%") ? "percent" : "raw",
    });
  }
  return stats;
}

function parseObservedCharmDamage(miscStats: Array<{
  stat_key: string;
  stat_name_raw: string;
  numeric_value: number | null;
  raw_value: string;
  unit: string;
}>) {
  const totalKeys = new Set([
    "charm_damage",
    "charms_damage",
    "damage_from_charms",
    "charm_dmg",
  ]);
  const perHourKeys = new Set([
    "charm_damage_h",
    "charm_damage_hour",
    "charm_damage_per_hour",
    "charms_damage_h",
    "charms_damage_per_hour",
  ]);

  const totalRow = miscStats.find((row) => totalKeys.has(row.stat_key) && row.numeric_value != null);
  const perHourRow = miscStats.find((row) => perHourKeys.has(row.stat_key) && row.numeric_value != null);

  const rows = miscStats
    .filter((row) => /^charm_[a-z0-9_]+_damage$/.test(row.stat_key) && !totalKeys.has(row.stat_key))
    .filter((row) => row.numeric_value != null)
    .map((row) => ({
      source_name_raw: row.stat_name_raw,
      damage: Number(row.numeric_value),
      damage_per_hour: null,
    }));

  const observed = totalRow != null || perHourRow != null || rows.length > 0;

  return {
    rows,
    total: totalRow?.numeric_value ?? (rows.length ? rows.reduce((sum, row) => sum + row.damage, 0) : null),
    perHour: perHourRow?.numeric_value ?? null,
    observed,
  };
}

function slug(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function escapeRegex(value: string) {
  return value.replace(/[.*+?^$()|[\]\\{}]/g, "\\$&");
}

export function parseSessionImport(blocks: SessionImportBlocks): ParsedSessionImport {
  const huntLines = lines(blocks.hunt);
  const partyLines = lines(blocks.party);
  const inputLines = lines(blocks.input);
  const miscLines = lines(blocks.misc);

  const primary = huntLines.length ? huntLines : partyLines;
  const range = parseSessionRange(primary);
  const creatures = parseKilledMonsters(huntLines);
  const lootedItems = parseLootedItems(huntLines);
  const partyPlayers = parsePartyPlayers(partyLines);
  const partyHeader = partyHeaderLines(partyLines);
  const input = parseInputAnalyzer(inputLines);
  const miscStats = parseMisc(miscLines);
  const observedCharm = parseObservedCharmDamage(miscStats);

  // Hunt metrics belong to the individual Hunt Analyzer only. Party Hunt
  // aggregate Loot/Supplies/Balance/Damage/Healing are never attributed to a
  // particular character when only the party block was supplied.
  const metrics: HuntAnalyzerMetrics = {
    duration_seconds: parseDurationSeconds(primary),
    raw_xp_gain: metric(huntLines, ["Raw XP Gain"]),
    xp_gain: metric(huntLines, ["XP Gain"]),
    xp_per_hour: metric(huntLines, ["XP/h"]),
    raw_xp_per_hour: metric(huntLines, ["Raw XP/h", "Raw XP/hour"]),
    loot_value: metric(huntLines, ["Loot"]),
    supplies_value: metric(huntLines, ["Supplies"]),
    balance_value: metric(huntLines, ["Balance"]),
    total_damage: metric(huntLines, ["Damage"]),
    damage_per_hour: metric(huntLines, ["Damage/h", "Damage/hour"]),
    total_healing: metric(huntLines, ["Healing"]),
    healing_per_hour: metric(huntLines, ["Healing/h", "Healing/hour"]),
  };

  const partyTotals = {
    duration_seconds: parseDurationSeconds(partyHeader),
    loot_value: metric(partyHeader, ["Loot"]),
    supplies_value: metric(partyHeader, ["Supplies"]),
    balance_value: metric(partyHeader, ["Balance"]),
    total_damage: metric(partyHeader, ["Damage"]),
    total_healing: metric(partyHeader, ["Healing"]),
    loot_type_raw: textMetric(partyHeader, ["Loot Type"]),
  };
  const partySize = partyPlayers.length || (partyLines.length ? null : 1);

  const recognizedMetricCount = Object.values(metrics).filter((value) => value != null).length;
  const warnings: string[] = [];
  if (!huntLines.length) warnings.push("hunt_analyzer_missing");
  if (recognizedMetricCount === 0) warnings.push("no_primary_metrics_recognized");
  if (textMetric(primary, ["Session"]) !== null && metrics.duration_seconds === null) warnings.push("invalid_duration_format");
  if (textMetric(primary, ["Session"]) === null &&
      textMetric(primary, ["Session data"]) !== null &&
      metrics.duration_seconds === null) warnings.push("session_time_range_unrecognized");
  if (partyLines.length && partyPlayers.length === 0) warnings.push("party_block_present_but_no_players_recognized");
  if (inputLines.length && input.elements.length === 0 && input.sources.length === 0) warnings.push("input_block_present_but_no_damage_rows_recognized");

  for (const [label, source, aliases] of [
    ["Raw XP Gain", huntLines, ["Raw XP Gain"]],
    ["XP Gain", huntLines, ["XP Gain"]],
    ["XP/h", huntLines, ["XP/h"]],
    ["Raw XP/h", huntLines, ["Raw XP/h", "Raw XP/hour"]],
    ["Loot", huntLines, ["Loot"]],
    ["Supplies", huntLines, ["Supplies"]],
    ["Balance", huntLines, ["Balance"]],
    ["Damage", huntLines, ["Damage"]],
    ["Damage/h", huntLines, ["Damage/h", "Damage/hour"]],
    ["Healing", huntLines, ["Healing"]],
    ["Healing/h", huntLines, ["Healing/h", "Healing/hour"]],
  ] as Array<[string, string[], string[]]>) {
    if (textMetric(source, aliases) !== null && metric(source, aliases) === null) {
      warnings.push(`invalid_numeric_format:${label}`);
    }
  }


  return {
    hunt_analyse: {
      ...metrics,
      session_data_raw: range.raw,
      session_from_raw: range.from_raw,
      session_to_raw: range.to_raw,
      total_kills: huntLines.some((line) => /^Killed Monsters:?$/i.test(line))
        ? creatures.reduce((sum, row) => sum + row.kills, 0)
        : null,
      party_size: partySize,
    },
    misc: {
      creatures,
      combat_stats: miscStats,
      looted_items: lootedItems,
      raw_misc_available: miscLines.length > 0,
    },
    damage: {
      total_damage: metrics.total_damage,
      incoming_total_damage: input.totalDamage,
      incoming_max_dps: input.maxDps,
      incoming_by_element: input.elements,
      incoming_by_source: input.sources,
      charm_damage: observedCharm.rows,
      charm_damage_total: observedCharm.total,
      charm_damage_per_hour: observedCharm.perHour,
      charm_damage_status: observedCharm.observed ? "observed" : "not_observed",
      charm_damage_available: observedCharm.observed,
    },
    party_hunt: {
      party_size: partySize,
      totals: partyTotals,
      players: partyPlayers,
    },
    availability: {
      hunt_analyse: huntLines.length > 0 && recognizedMetricCount > 0,
      misc: miscStats.length > 0 || creatures.length > 0 || lootedItems.length > 0,
      damage: metrics.total_damage != null || input.elements.length > 0 || input.sources.length > 0,
      party_hunt: partyPlayers.length > 1,
      charm_damage: observedCharm.observed,
    },
    validation: {
      has_primary_hunt_analyzer: huntLines.length > 0,
      recognized_metric_count: recognizedMetricCount,
      creature_rows: creatures.length,
      looted_item_rows: lootedItems.length,
      party_player_rows: partyPlayers.length,
      incoming_element_rows: input.elements.length,
      incoming_source_rows: input.sources.length,
      misc_stat_rows: miscStats.length,
      warnings,
    },
    methodology: {
      stage: "session_parser_v2",
      raw_blocks_preserved: true,
      unknown_values_invented: false,
      community_evidence_written: false,
    },
  };
}
