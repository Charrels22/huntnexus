// FE-39: immutable, client-safe presentation of factual provenance.
// Source coverage is NOT a measure of community hunt sample size or quality.
export type HuntEvidenceSummary = {
  status: "complete" | "incomplete" | "unavailable";
  sourceName: string;
  sourceLayer: string | null;
  sourceTier: string | null;
  sourceUrl: string | null;
  lastUpdated: string | null;
  snapshotRecorded: boolean;
  coverage: Array<{ key:string; label:string; observed:number | null; total:number | null; complete:boolean }>;
  observedSessions: number | null;
  vocationSourcedSessions: number | null;
  observationalWarning: string;
};

function count(value: unknown): number | null {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 ? value : null;
}
function sourceUrl(value: unknown): string | null {
  if (typeof value !== "string") return null;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" ? parsed.href : null;
  } catch { return null; }
}
function recordedDate(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return null;
  return new Intl.DateTimeFormat("pt-BR",{day:"2-digit",month:"2-digit",year:"numeric",timeZone:"UTC"}).format(date);
}
function obj(value: unknown): Record<string,any> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string,any> : {};
}
export function describeHuntEvidence(
  evidence: unknown,
  observed: unknown,
  vocationObserved: unknown,
): HuntEvidenceSummary {
  const proof=obj(evidence), coverage=obj(proof.coverage), source=obj(proof.source);
  const performance=obj(obj(observed).performance);
  const vocationSample=obj(obj(vocationObserved).sample);
  const present=proof.methodology?.stage==="hunt_evidence_context_fe39_v1";
  const total=present?count(coverage.creature_count):null;
  const dimensions=[
    {key:"elements",label:"Elementos",observed:present?count(coverage.creatures_with_elements):null,complete:coverage.elements_complete===true},
    {key:"detail",label:"Detalhes das criaturas",observed:present?count(coverage.creatures_with_detail):null,complete:coverage.creature_detail_complete===true},
    {key:"abilities",label:"Habilidades",observed:present?count(coverage.creatures_with_abilities):null,complete:coverage.abilities_complete===true},
    {key:"loot",label:"Loot",observed:present?count(coverage.creatures_with_loot):null,complete:coverage.loot_complete===true},
  ].map(d=>({...d,total,complete:present&&total!==null&&total>0&&d.observed===total&&d.complete}));
  const observedSessions=count(performance.session_count);
  const vocationSourcedSessions=count(vocationSample.sourced_session_count);
  return {
    status:!present?"unavailable":proof.source_core_complete===true?"complete":"incomplete",
    sourceName:present && typeof source.name==="string" && source.name.trim()?source.name:"Fonte não identificada",
    sourceLayer:present && typeof source.layer==="string"?source.layer:null,
    sourceTier:present && typeof source.tier==="string"?source.tier:null,
    sourceUrl:present?sourceUrl(source.url):null,
    lastUpdated:present?recordedDate(source.source_last_updated):null,
    snapshotRecorded:present && source.snapshot_recorded===true,
    coverage:dimensions,
    observedSessions,
    vocationSourcedSessions,
    observationalWarning:observedSessions===null
      ?"Sessões de desempenho indisponíveis; o conteúdo factual permanece independente."
      :observedSessions===0
      ?"Sem sessões de desempenho observadas; o conteúdo factual permanece independente."
      :observedSessions<3
        ?"Amostra geral limitada: não use os resultados como garantia de XP ou profit."
        :"Medianas históricas não garantem desempenho para sua vocação, level ou setup.",
  };
}
