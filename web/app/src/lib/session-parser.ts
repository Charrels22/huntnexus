export type SessionImportBlocks = {
  hunt?: string;
  party?: string;
  input?: string;
  misc?: string;
};

export type AnalyzerType = "hunt" | "party" | "input" | "misc";

export function detectAnalyzerType(text: string): AnalyzerType | null {
  const normalized = text.replace(/\r\n?/g, "\n").trim();
  if (!normalized) return null;

  if (/Killed Monsters:?/i.test(normalized) || /XP Gain\s*:/i.test(normalized) || /Looted Items:?/i.test(normalized)) {
    return "hunt";
  }

  if (/Damage Types:?/i.test(normalized) || /Damage Sources:?/i.test(normalized)) {
    return "input";
  }

  if (/Session data\s*:\s*From/i.test(normalized)) {
    const playerSignals = (normalized.match(/(?:^|\n)[^:\n]+(?:\s+\(Leader\))?\s*\n\s*Loot\s*:/gi) ?? []).length;
    if (playerSignals > 0 || /Loot Type\s*:/i.test(normalized)) return "party";
  }

  if (/^(?:[A-Za-z][^:\n]{1,60})\s*:\s*.+$/m.test(normalized)) {
    return "misc";
  }

  return null;
}

type ParsedMetricMap = Record<string, number | null>;

function lines(text: string | undefined) {
  return (text ?? "")
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function parseIntegerLike(value: string | undefined): number | null {
  if (!value) return null;
  const negative = value.trim().startsWith("-");
  const digits = value.replace(/[^0-9]/g, "");
  if (!digits) return null;
  const parsed = Number(digits);
  if (!Number.isFinite(parsed)) return null;
  return negative ? -parsed : parsed;
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
  if (!raw) return null;
  const h = raw.match(/(\d+)\s*:\s*(\d+)\s*h/i);
  if (h?.[1] && h?.[2]) return Number(h[1]) * 3600 + Number(h[2]) * 60;
  const hm = raw.match(/(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?/i);
  if (hm && (hm[1] || hm[2])) return Number(hm[1] || 0) * 3600 + Number(hm[2] || 0) * 60;
  return null;
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

  const out: Array<{ monster_name_raw: string; kills: number }> = [];
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
    out.push({ monster_name_raw: monsterName.trim(), kills });
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

function parseInputAnalyzer(textLines: string[]) {
  const elements: Array<Record<string, unknown>> = [];
  const sources: Array<Record<string, unknown>> = [];
  let section: "elements" | "sources" | null = null;

  for (const line of textLines) {
    if (/damage types|elements/i.test(line) && !line.includes(":")) {
      section = "elements";
      continue;
    }
    if (/damage sources|sources/i.test(line) && !line.includes(":")) {
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

    if (section === "elements" || knownElement) {
      elements.push({ element: normalized.replace(/\s+/g, "_"), damage: value, share_percent: share });
    } else if (section === "sources") {
      sources.push({ source_name_raw: label, damage: value, share_percent: share });
    }
  }

  return { elements, sources };
}

function parseMisc(textLines: string[]) {
  const stats: Array<{ key: string; name_raw: string; numeric_value: number | null; raw_value: string }> = [];
  for (const line of textLines) {
    const match = line.match(/^(.+?)\s*:\s*(.+)$/);
    if (!match) continue;
    const rawName = match[1];
    const rawValue = match[2];
    if (!rawName || !rawValue) continue;
    const name = rawName.trim();
    const raw = rawValue.trim();
    stats.push({
      key: slug(name),
      name_raw: name,
      numeric_value: parseDecimalLike(raw),
      raw_value: raw,
    });
  }
  return stats;
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

export function parseSessionImport(blocks: SessionImportBlocks) {
  const huntLines = lines(blocks.hunt);
  const partyLines = lines(blocks.party);
  const inputLines = lines(blocks.input);
  const miscLines = lines(blocks.misc);

  const primary = huntLines.length ? huntLines : partyLines;
  const range = parseSessionRange(primary);
  const creatures = parseKilledMonsters(huntLines);
  const partyPlayers = parsePartyPlayers(partyLines);
  const input = parseInputAnalyzer(inputLines);
  const miscStats = parseMisc(miscLines);

  const metrics: ParsedMetricMap = {
    duration_seconds: parseDurationSeconds(primary),
    xp_gain: metric(huntLines, ["XP Gain"]),
    xp_per_hour: metric(huntLines, ["XP/h"]),
    raw_xp_per_hour: metric(huntLines, ["Raw XP/h", "Raw XP/hour"]),
    loot_value: metric(primary, ["Loot"]),
    supplies_value: metric(primary, ["Supplies"]),
    balance_value: metric(primary, ["Balance"]),
    total_damage: metric(primary, ["Damage"]),
    total_healing: metric(primary, ["Healing"]),
  };

  const recognizedMetricCount = Object.values(metrics).filter((value) => value != null).length;
  const warnings: string[] = [];
  if (!huntLines.length) warnings.push("hunt_analyzer_missing");
  if (recognizedMetricCount === 0) warnings.push("no_primary_metrics_recognized");
  if (partyLines.length && partyPlayers.length === 0) warnings.push("party_block_present_but_no_players_recognized");
  if (inputLines.length && input.elements.length === 0 && input.sources.length === 0) warnings.push("input_block_present_but_no_damage_rows_recognized");

  return {
    hunt_analyse: {
      ...metrics,
      session_data_raw: range.raw,
      session_from_raw: range.from_raw,
      session_to_raw: range.to_raw,
      total_kills: creatures.reduce((sum, row) => sum + row.kills, 0),
    },
    misc: {
      creatures,
      combat_stats: miscStats,
      raw_misc_available: miscLines.length > 0,
    },
    damage: {
      total_damage: metrics.total_damage,
      incoming_by_element: input.elements,
      incoming_by_source: input.sources,
      charm_damage: [],
      charm_damage_available: false,
    },
    party_hunt: {
      party_size: partyPlayers.length || (partyLines.length ? null : 1),
      players: partyPlayers,
    },
    availability: {
      hunt_analyse: recognizedMetricCount > 0,
      misc: miscStats.length > 0 || creatures.length > 0,
      damage: metrics.total_damage != null || input.elements.length > 0 || input.sources.length > 0,
      party_hunt: partyPlayers.length > 1,
      charm_damage: false,
    },
    validation: {
      has_primary_hunt_analyzer: huntLines.length > 0,
      recognized_metric_count: recognizedMetricCount,
      creature_rows: creatures.length,
      party_player_rows: partyPlayers.length,
      incoming_element_rows: input.elements.length,
      incoming_source_rows: input.sources.length,
      misc_stat_rows: miscStats.length,
      warnings,
    },
    methodology: {
      stage: "session_parser_v1",
      raw_blocks_preserved: true,
      unknown_values_invented: false,
      community_evidence_written: false,
    },
  };
}
