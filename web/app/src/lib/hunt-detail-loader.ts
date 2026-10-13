type Rpc = (name: string, params: Record<string, unknown>) => Promise<any>;

// Factual data is required; auxiliary failures are explicit and never become zero samples.
export async function loadHuntDetail(rpc: Rpc, huntKey: string, vocation: string) {
  const specifications = [
    ["factual", "huntnexus_hunt_factual_profile", false],
    ["observed", "huntnexus_hunt_observed_profile", false],
    ["vocation_observed", "huntnexus_hunt_vocation_observation_sample", true],
    ["defensive", "huntnexus_hunt_defensive_profile", true],
    ["imbuements", "huntnexus_imbuement_hunt_context_universal", true],
    ["media", "huntnexus_hunt_media_context", false],
    ["evidence", "huntnexus_hunt_evidence_context", false],
  ] as const;
  const settled = await Promise.allSettled(specifications.map(([, name, needsVocation]) =>
    rpc(name, { p_hunt_key: huntKey, ...(needsVocation ? { p_vocation: vocation } : {}) })));
  const factual = settled[0];
  if (!factual || factual.status !== "fulfilled" || !factual.value || factual.value.error) throw new Error("Required factual hunt data unavailable");
  const data: Record<string, any> = {};
  const availability: Record<string, boolean> = {};
  specifications.forEach(([key], index) => {
    const response = settled[index];
    const available = response?.status === "fulfilled" && response.value !== null && response.value !== undefined && !response.value.error;
    availability[key] = available;
    data[key] = available && response?.status === "fulfilled" ? response.value : null;
  });
  return { ...data, availability };
}
