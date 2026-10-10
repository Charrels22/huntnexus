import { createFileRoute, Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Loader2, Search, SlidersHorizontal, Sparkles } from "lucide-react";
import { callHuntNexusApi } from "@/lib/api/huntnexus";
import { OfficialAssetSlot } from "@/components/shell/app-shell";
import { CanonicalSprite } from "@/components/shared/canonical-sprite";
import { getOrCreateClientId } from "@/lib/client-id";

export const Route = createFileRoute("/planner")({ component: PlannerPage });

type FinalResponse = { data?: any; warnings?: any[]; error?: string; detail?: string };

function PlannerPage() {
  const [vocation, setVocation] = useState("EK");
  const [level, setLevel] = useState("700");
  const [huntObjective, setHuntObjective] = useState("balanced");
  const [setObjective, setSetObjective] = useState("offense");
  const [party, setParty] = useState("1");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);
  const [error, setError] = useState("");
  const [savedProfile, setSavedProfile] = useState<any>(null);

  useEffect(() => {
    const clientId = getOrCreateClientId();
    if (!clientId) return;

    callHuntNexusApi<any>({ action: "player_profile_get", client_id: clientId })
      .then((response) => {
        const profile = response?.data?.profile;
        if (!profile) return;
        setSavedProfile(profile);
        if (profile.vocation) setVocation(profile.vocation);
        if (profile.level) setLevel(String(profile.level));
        if (profile.defaults?.hunt_objective) setHuntObjective(profile.defaults.hunt_objective);
        if (profile.defaults?.set_objective) setSetObjective(profile.defaults.set_objective);
        if (profile.defaults?.party_size) setParty(String(profile.defaults.party_size));
      })
      .catch(() => undefined);
  }, []);

  async function run() {
    setLoading(true); setError("");
    try {
      const stats = savedProfile?.manual_stats ?? {};
      const weaponFamily = stats.weapon_family;
      const familyBaseSkill =
        weaponFamily === "sword" ? stats.sword :
        weaponFamily === "axe" ? stats.axe :
        weaponFamily === "club" ? stats.club :
        (weaponFamily === "bow" || weaponFamily === "crossbow") ? stats.distance :
        weaponFamily === "fist" ? stats.fist :
        undefined;

      const characterProfile = Object.fromEntries(
        Object.entries({
          weapon_family: weaponFamily,
          effective_weapon_skill: validFinalStat(familyBaseSkill, stats.effective_weapon_skill),
          effective_magic_level: validFinalStat(stats.magic_level, stats.effective_magic_level),
          effective_shielding: validFinalStat(stats.shielding, stats.effective_shielding),
          effective_distance_skill: validFinalStat(stats.distance, stats.effective_distance_skill),
          effective_fist_skill: validFinalStat(stats.fist, stats.effective_fist_skill),
        }).filter(([, value]) => value !== undefined && value !== null && value !== ""),
      );

      const clientId = getOrCreateClientId();

      const response = await callHuntNexusApi<FinalResponse>({
        action: "planner_personalized",
        client_id: clientId,
        vocation,
        level: Number(level),
        objective: huntObjective,
        party_size: Number(party),
        limit: 3,
        character_profile: characterProfile,
        proficiency_selections: savedProfile?.proficiency_selections ?? {},
      });
      setResult(response.data ?? response);
    } catch (e) {
      setError((e as Error).message);
      setResult(null);
    } finally {
      setLoading(false);
    }
  }

  const results = Array.isArray(result?.results) ? result.results : [];

  return (
    <div className="mx-auto max-w-[1450px] space-y-6">
      <section className="rounded-3xl border border-white/8 bg-slate-950/55 p-5 backdrop-blur-xl md:p-6">
        <div className="mb-5 flex items-center gap-3">
          <div className="grid size-11 place-items-center rounded-xl bg-cyan-400/10 text-cyan-300"><SlidersHorizontal className="size-5" /></div>
          <div>
            <div className="text-xs uppercase tracking-[0.18em] text-cyan-400">Hunt Planner</div>
            <h1 className="text-2xl font-bold text-white">Monte o contexto do seu personagem</h1>
          </div>
          {savedProfile?.character_name && (
            <div className="ml-auto hidden rounded-full border border-emerald-400/15 bg-emerald-400/8 px-3 py-1 text-xs text-emerald-300 md:block">
              {savedProfile.character_name} · {savedProfile.world_name || "RubinOT"}
            </div>
          )}
        </div>
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-6">
          <Field label="Vocação">
            <select value={vocation} onChange={(e) => setVocation(e.target.value)} className="hn-control">
              <option value="EK">Elite Knight</option><option value="RP">Royal Paladin</option><option value="ED">Elder Druid</option><option value="MS">Master Sorcerer</option><option value="EM">Exalted Monk</option>
            </select>
          </Field>
          <Field label="Level"><input className="hn-control" type="number" min="1" value={level} onChange={(e) => setLevel(e.target.value)} /></Field>
          <Field label="Objetivo da hunt">
            <select className="hn-control" value={huntObjective} onChange={(e) => setHuntObjective(e.target.value)}>
              <option value="xp">XP</option><option value="profit">Profit</option><option value="balanced">Balanced</option>
            </select>
          </Field>
          <Field label="Objetivo do set">
            <select className="hn-control" value={setObjective} onChange={(e) => setSetObjective(e.target.value)}>
              <option value="offense">Offense</option><option value="defense">Defense</option><option value="sustain">Sustain</option><option value="utility">Utility</option><option value="balanced">Balanced</option>
            </select>
          </Field>
          <Field label="Party">
            <select className="hn-control" value={party} onChange={(e) => setParty(e.target.value)}>
              <option value="1">Solo</option><option value="2">Duo</option><option value="3">Trio</option><option value="4">x4</option><option value="5">x5+</option>
            </select>
          </Field>
          <div className="flex items-end">
            <button className="hn-primary-button w-full justify-center" onClick={run} disabled={loading}>
              {loading ? <Loader2 className="size-4 animate-spin" /> : <Search className="size-4" />} Encontrar hunts
            </button>
          </div>
        </div>
      </section>

      {error && <div className="rounded-2xl border border-red-400/20 bg-red-400/8 p-4 text-sm text-red-200">{error}</div>}

      {!result && !loading && (
        <section className="grid gap-4 xl:grid-cols-[1.1fr_.9fr]">
          <div className="rounded-3xl border border-white/8 bg-white/[0.025] p-6">
            <div className="flex items-center gap-2 text-cyan-300"><Sparkles className="size-4" /> O optimizer está pronto</div>
            <h2 className="mt-3 text-2xl font-bold text-white">A hunt e o set são avaliados separadamente.</h2>
            <p className="mt-2 max-w-xl text-sm leading-6 text-slate-400">
              XP/Profit escolhem a hunt. Offense/Defense/Sustain/Utility filtram os sets. Sem score universal inventado.
            </p>
          </div>
          <OfficialAssetSlot label="Preview oficial da hunt selecionada" />
        </section>
      )}

      {results.length > 0 && (
        <section className="space-y-4">
          <div>
            <div className="text-xs uppercase tracking-[0.18em] text-cyan-400">Resultado</div>
            <h2 className="mt-1 text-2xl font-bold text-white">Hunts recomendadas</h2>
          </div>
          <div className="grid gap-4 xl:grid-cols-3">
            {results.map((row: any, index: number) => {
              const hunt = row.hunt ?? {};
              const ownedBuilds = row.owned_builds ?? {};
              const ownedOptions = Array.isArray(ownedBuilds.options) ? ownedBuilds.options : [];
              const mainOption = ownedOptions.find((option:any) => option.option_type === "main") ?? null;
              const ownedVariants = ownedOptions.filter((option:any) => option.option_type === "owned_variant");
              const savedChoice = row.saved_owned_choice?.exists ? row.saved_owned_choice.choice : null;
              return (
                <article key={hunt.hunt_key ?? index} className="hn-hunt-card overflow-hidden">
                  <OfficialAssetSlot label="Imagem oficial/canônica da hunt" compact />
                  <div className="p-4">
                    <div className="text-[10px] uppercase tracking-[0.16em] text-cyan-400">#{row.hunt_rank_order ?? index + 1}</div>
                    <h3 className="mt-1 text-xl font-bold text-white">{hunt.hunt_name ?? hunt.hunt_key}</h3>
                    <div className="mt-3 grid grid-cols-3 gap-2 text-center text-xs">
                      <Mini label="XP/h" value={formatMetric(hunt.median_xp_per_hour)} />
                      <Mini label="Profit/h" value={formatMetric(hunt.median_balance_per_hour)} />
                      <Mini label="Conf." value={hunt.confidence_score != null ? `${Math.round(Number(hunt.confidence_score) * 100)}%` : "—"} />
                    </div>
                    {mainOption && (
                      <div className="mt-4 rounded-xl border border-cyan-400/12 bg-cyan-400/[0.025] p-3">
                        <div className="flex items-center justify-between gap-2">
                          <div>
                            <div className="text-xs font-semibold text-cyan-100">Com os seus itens</div>
                            <div className="mt-1 text-[10px] text-slate-500">
                              Main + {ownedVariants.length} alternativa{ownedVariants.length === 1 ? "" : "s"} viável{ownedVariants.length === 1 ? "" : "is"} da BP
                            </div>
                          </div>
                          {savedChoice && (
                            <span className="rounded-full border border-emerald-400/20 bg-emerald-400/[0.06] px-2 py-1 text-[9px] font-semibold text-emerald-300">
                              Build salva
                            </span>
                          )}
                        </div>

                        <div className="mt-3 flex flex-wrap gap-1.5">
                          {Object.entries(mainOption.selection ?? {}).slice(0,8).map(([slot,itemKey]) => (
                            <div
                              key={slot}
                              title={String(itemKey)}
                              className="rounded-lg border border-white/6 bg-black/20 p-1.5"
                            >
                              <CanonicalSprite kind="item" name={slugToName(String(itemKey))} size="sm" />
                            </div>
                          ))}
                        </div>

                        {ownedBuilds?.summary?.discarded_as_main_dominated > 0 && (
                          <div className="mt-2 text-[10px] text-slate-600">
                            {ownedBuilds.summary.discarded_as_main_dominated} variação(ões) da BP foram descartadas por serem inferiores ao Main quando comparáveis.
                          </div>
                        )}
                      </div>
                    )}

                    <div className="mt-3 rounded-xl border border-white/6 bg-white/[0.025] p-3">
                      <div className="text-xs font-semibold text-slate-300">Setup universal completo</div>
                      <div className="mt-1 text-xs leading-5 text-slate-500">
                        Calculado ao abrir a hunt. O Planner prioriza velocidade e usa aqui ranking factual + seus itens.
                      </div>
                    </div>
                    {hunt.hunt_key && (
                      <Link
                        to="/hunts/$huntKey"
                        params={{ huntKey: hunt.hunt_key }}
                        search={{
                          vocation,
                          level: Number(level),
                          setObjective,
                        }}
                        className="hn-primary-button mt-4 w-full justify-center"
                      >
                        Ver hunt e setup
                      </Link>
                    )}
                  </div>
                </article>
              );
            })}
          </div>
        </section>
      )}
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return <label className="space-y-2 text-xs font-medium text-slate-400"><span>{label}</span>{children}</label>;
}
function Mini({ label, value }: { label: string; value: string }) {
  return <div className="rounded-lg bg-white/[0.025] p-2"><div className="text-slate-500">{label}</div><div className="mt-1 font-bold text-slate-100">{value}</div></div>;
}
function formatMetric(value: unknown) {
  if (typeof value !== "number") return "—";
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${Math.round(value / 1_000)}k`;
  return String(Math.round(value));
}


function slugToName(value: string) {
  return value
    .split("-")
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function validFinalStat(baseValue: unknown, finalValue: unknown) {
  const base = Number(baseValue);
  const finalNumber = Number(finalValue);
  const hasBase = baseValue !== undefined && baseValue !== null && baseValue !== "" && Number.isFinite(base);
  const hasFinal = finalValue !== undefined && finalValue !== null && finalValue !== "" && Number.isFinite(finalNumber);

  if (!hasFinal) return hasBase ? base : undefined;
  if (!hasBase) return finalNumber;
  return finalNumber >= base ? finalNumber : base;
}
