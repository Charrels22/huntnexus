// FE-37: privacy-safe session import completeness and saved/detail consistency.
// This helper runs SERVER-SIDE with protected raw blocks. Never return raw text,
// player names, individual loot, creatures, or sources to the browser.
import { parseSessionImport, type ParsedSessionImport, type SessionImportBlocks } from "./session-parser";

export type BlockIntegrityStatus = "missing" | "unrecognized" | "partial" | "recognized";
type SectionKey = "hunt_analyse" | "misc" | "damage" | "party_hunt" | "availability" | "validation";
const sectionKeys: SectionKey[] = [
  "hunt_analyse", "misc", "damage", "party_hunt", "availability", "validation",
];
type RecordLike = Record<string, unknown>;
const asObject = (value: unknown): RecordLike =>
  value != null && typeof value === "object" && !Array.isArray(value)
    ? value as RecordLike : {};
const get = (obj: unknown, key: string): unknown => asObject(obj)[key];
const arrayLength = (value: unknown): number => Array.isArray(value) ? value.length : 0;
const present = (value: unknown): boolean => value != null;
function stable(value: unknown): string {
  return JSON.stringify(value,(_key,v)=>{
    if (!v || typeof v !== "object" || Array.isArray(v)) return v;
    return Object.fromEntries(Object.keys(v).sort().map(k=>[k,v[k]]));
  }) ?? "undefined";
}

export type SessionIntegrityReport = {
  stage: "fe37_session_integrity_readonly";
  blocks: Array<{
    key: "hunt" | "input" | "misc" | "party";
    status: BlockIntegrityStatus;
    supplied: boolean;
    observed_fields: number;
    note: string;
  }>;
  storage_consistency: {
    status: "consistent" | "mismatch";
    checked_sections: number;
    mismatched_sections: SectionKey[];
  };
  parser_version: string;
  current_parser_drift: {
    status: "same" | "different";
    differing_sections: SectionKey[];
    // A new parser may reinterpret an older session without changing the
    // stored/detail data. Drift alone is NOT evidence of storage corruption.
    not_a_persistence_error: true;
  };
  original_blocks_preserved: true;
  contains_raw_analyzer_text: false;
  requires_real_export_acceptance: true;
};

export function buildSessionIntegrityReport(args: {
  rawBlocks: SessionImportBlocks;
  storedParsedData: RecordLike;
  sessionDetail: RecordLike;
  parserVersion: string;
}): SessionIntegrityReport {
  const {rawBlocks, storedParsedData, sessionDetail, parserVersion} = args;
  const supplied = (key: keyof SessionImportBlocks) =>
    typeof rawBlocks[key] === "string" && rawBlocks[key]!.trim().length > 0;
  const hunt = asObject(storedParsedData.hunt_analyse);
  const damage = asObject(storedParsedData.damage);
  const misc = asObject(storedParsedData.misc);
  const party = asObject(storedParsedData.party_hunt);
  const validation = asObject(storedParsedData.validation);
  const warnings = Array.isArray(validation.warnings)
    ? validation.warnings.filter((v):v is string=>typeof v==="string") : [];
  const incomingRows =
    arrayLength(damage.incoming_by_element)+arrayLength(damage.incoming_by_source);
  const incomingScalars = Number(present(damage.incoming_total_damage))+
    Number(present(damage.incoming_max_dps));
  const combatStats = arrayLength(misc.combat_stats);
  const partyPlayers = arrayLength(party.players);
  const huntMetrics = ["duration_seconds","xp_gain","xp_per_hour","loot_value",
    "supplies_value","balance_value","total_damage","total_healing"]
    .filter(key=>present(hunt[key])).length;
  const block = (
    key:"hunt"|"input"|"misc"|"party",
    count:number,status:BlockIntegrityStatus,note:string,
  )=>({key,supplied:supplied(key),observed_fields:count,status,note});
  const blocks:SessionIntegrityReport["blocks"] = [
    !supplied("hunt")
      ? block("hunt",0,"missing","Hunt Analyzer não foi fornecido")
      : huntMetrics===0
        ? block("hunt",0,"unrecognized","Nenhuma métrica principal foi reconhecida")
        : warnings.some(w=>w==="invalid_duration_format"||
            w==="session_time_range_unrecognized"||w.startsWith("invalid_numeric_format:"))
          ? block("hunt",huntMetrics,"partial","Algumas métricas exigem revisão")
          : block("hunt",huntMetrics,"recognized","Métricas principais registradas"),
    !supplied("input")
      ? block("input",0,"missing","Damage Input não foi fornecido")
      : incomingRows+incomingScalars===0
        ? block("input",0,"unrecognized","Nenhum valor recebido reconhecido")
        : incomingRows===0 || incomingScalars===0 ||
            warnings.some(w=>w.startsWith("input_"))
          ? block("input",incomingRows+incomingScalars,"partial",
              "Há dados observados, mas o bloco é parcial ou requer revisão")
          : block("input",incomingRows+incomingScalars,"recognized",
              "Totais e discriminadores observados"),
    !supplied("misc")
      ? block("misc",0,"missing","Miscellaneous não foi fornecido")
      : combatStats===0
        ? block("misc",0,"unrecognized","Nenhum Combat Stat foi reconhecido")
        : block("misc",combatStats,"recognized","Combat Stats registrados"),
    !supplied("party")
      ? block("party",0,"missing","Party Hunt não foi fornecido")
      : partyPlayers===0
        ? block("party",0,"unrecognized","Nenhum participante foi reconhecido")
        : block("party",partyPlayers,"recognized","Participantes registrados"),
  ];
  const mismatchedSections = sectionKeys.filter(key=>{
    const saved=get(storedParsedData,key);
    const shown=get(sessionDetail,key);
    // Session detail RPC maps missing legacy sections to {} rather than null.
    return stable(saved ?? {})!==stable(shown ?? {});
  });
  const current:ParsedSessionImport = parseSessionImport(rawBlocks);
  const differingSections=sectionKeys.filter(key=>
    stable(get(storedParsedData,key) ?? {}) !== stable(get(current,key) ?? {})
  );
  return {
    stage:"fe37_session_integrity_readonly",
    blocks,
    storage_consistency:{
      status:mismatchedSections.length?"mismatch":"consistent",
      checked_sections:sectionKeys.length,
      mismatched_sections:mismatchedSections,
    },
    parser_version:parserVersion,
    current_parser_drift:{
      status:differingSections.length?"different":"same",
      differing_sections:differingSections,
      not_a_persistence_error:true,
    },
    original_blocks_preserved:true,
    contains_raw_analyzer_text:false,
    requires_real_export_acceptance:true,
  };
}
