import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  Boxes,
  Flame,
  Loader2,
  MapPinned,
  ShieldCheck,
  Sparkles,
  Swords,
  Users,
} from "lucide-react";
import { CanonicalSprite, CanonicalSpriteGroup } from "@/components/shared/canonical-sprite";
import { CanonicalTibiaMap, parseMapperCoords } from "@/components/shared/tibia-map";
import { callHuntNexusApi, formatNumber } from "@/lib/api/huntnexus";
import { getOrCreateClientId } from "@/lib/client-id";

export const Route = createFileRoute("/hunts/$huntKey")({
  validateSearch: (search: Record<string, unknown>) => ({
    vocation: typeof search.vocation === "string" ? search.vocation : "EK",
    level: Number.isFinite(Number(search.level)) ? Number(search.level) : 700,
    setObjective: typeof search.setObjective === "string" ? search.setObjective : "balanced",
  }),
  component: HuntDetailPage,
});

const tabs = [
  { key: "overview", label: "Overview", icon: Activity },
  { key: "creatures", label: "Creatures", icon: Swords },
  { key: "map", label: "Map", icon: MapPinned },
  { key: "damage", label: "Damage", icon: ShieldCheck },
  { key: "setup", label: "Setup", icon: Boxes },
  { key: "spells", label: "Spells & Proficiency", icon: Sparkles },
  { key: "imbuements", label: "Imbuements", icon: Flame },
  { key: "community", label: "Community", icon: Users },
] as const;

type TabKey = (typeof tabs)[number]["key"];

function HuntDetailPage() {
  const { huntKey } = Route.useParams();
  const search = Route.useSearch();
  const [tab, setTab] = useState<TabKey>("overview");
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [personalReview, setPersonalReview] = useState<any>(null);
  const [ownedBuildOptions, setOwnedBuildOptions] = useState<any>(null);
  const [personalBuildPerformance, setPersonalBuildPerformance] = useState<any>(null);
  const [huntBuildChoice, setHuntBuildChoice] = useState<any>(null);
  const [savingBuildChoice, setSavingBuildChoice] = useState(false);
  const [loadingPersonalReview, setLoadingPersonalReview] = useState(false);
  const [setupLoad, setSetupLoad] = useState<{ key: string; data: any } | null>(null);
  const [setupLoading, setSetupLoading] = useState(false);
  const [setupError, setSetupError] = useState("");
  const [setupRetry, setSetupRetry] = useState(0);
  const [spellsLoad, setSpellsLoad] = useState<{ key: string; data: any } | null>(null);
  const [spellsLoading, setSpellsLoading] = useState(false);
  const [spellsError, setSpellsError] = useState("");
  const setupKey = [huntKey,search.vocation,search.level,search.setObjective].join("|");
  const spellsKey = [huntKey,search.vocation,search.level].join("|");


  useEffect(() => {
    let active = true;
    setLoading(true);
    setError("");
    callHuntNexusApi<any>({
      action: "hunt_detail",
      hunt_key: huntKey,
      vocation: search.vocation,
      level: search.level,
      set_objective: search.setObjective,
    })
      .then((response) => { if (active) setData(response?.data ?? null); })
      .catch((e) => { if (active) setError((e as Error).message); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [huntKey, search.vocation, search.level, search.setObjective]);

  useEffect(() => {
    if (tab !== "setup" || (setupLoad?.key === setupKey && setupRetry === 0)) return;
    let active = true;
    setSetupLoading(true);
    setSetupError("");
    callHuntNexusApi<any>({
      action: "hunt_detail_setup",
      hunt_key: huntKey,
      vocation: search.vocation,
      level: search.level,
      set_objective: search.setObjective,
      proficiency_selections: {},
      character_profile: {},
    })
      .then((response) => {
        if (active) setSetupLoad({ key: setupKey, data: response?.data ?? null });
      })
      .catch(() => {
        if (active) setSetupError("Não foi possível calcular o frontier universal. Os dados factuais e o seu Set Main continuam disponíveis.");
      })
      .finally(() => { if (active) setSetupLoading(false); });
    return () => { active = false; };
  }, [tab, setupKey, setupRetry]);

  useEffect(() => {
    if (tab !== "spells" || spellsLoad?.key === spellsKey) return;
    let active = true;
    setSpellsLoading(true);
    setSpellsError("");
    callHuntNexusApi<any>({
      action: "hunt_detail_spells",
      hunt_key: huntKey,
      vocation: search.vocation,
      level: search.level,
    })
      .then((response) => {
        if (active) setSpellsLoad({ key: spellsKey, data: response?.data ?? null });
      })
      .catch(() => {
        if (active) setSpellsError("A composição de spells não pôde ser carregada para esta configuração.");
      })
      .finally(() => { if (active) setSpellsLoading(false); });
    return () => { active = false; };
  }, [tab, spellsKey]);

  useEffect(() => {
    if (tab !== "setup") return;

    const clientId = getOrCreateClientId();
    if (!clientId) return;

    let active = true;
    setLoadingPersonalReview(true);

    callHuntNexusApi<any>({
      action: "player_profile_get",
      client_id: clientId,
    })
      .then(async (profileResponse) => {
        if (!active) return null;

        const profile = profileResponse?.data?.profile ?? {};
        const proficiencySelections = profile?.proficiency_selections ?? {};
        const stats = profile?.manual_stats ?? {};
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

        return Promise.all([
          callHuntNexusApi<any>({
            action: "player_inventory_hunt_review",
            client_id: clientId,
            hunt_key: huntKey,
            vocation: search.vocation,
            level: search.level,
            proficiency_selections: proficiencySelections,
            frontier_limit: 12,
          }),
          callHuntNexusApi<any>({
            action: "player_owned_build_options",
            client_id: clientId,
            hunt_key: huntKey,
            vocation: search.vocation,
            level: search.level,
            proficiency_selections: proficiencySelections,
            character_profile: characterProfile,
            option_limit: 3,
          }),
          callHuntNexusApi<any>({
            action: "player_hunt_build_choice_get",
            client_id: clientId,
            hunt_key: huntKey,
            vocation: search.vocation,
          }),
          callHuntNexusApi<any>({
            action: "player_session_build_performance",
            client_id: clientId,
            hunt_key: huntKey,
            vocation: search.vocation,
          }),
        ]);
      })
      .then((responses) => {
        if (!active || !responses) return;
        const [reviewResponse, optionsResponse, choiceResponse, performanceResponse] = responses;
        setPersonalReview(reviewResponse?.data ?? null);
        setOwnedBuildOptions(optionsResponse?.data ?? null);
        setHuntBuildChoice(choiceResponse?.data?.exists ? choiceResponse.data.choice : null);
        setPersonalBuildPerformance(performanceResponse?.data ?? null);
      })
      .catch(() => {
        if (active) {
          setPersonalReview(null);
          setOwnedBuildOptions(null);
          setPersonalBuildPerformance(null);
          setHuntBuildChoice(null);
        }
      })
      .finally(() => {
        if (active) setLoadingPersonalReview(false);
      });

    return () => {
      active = false;
    };
  }, [tab, huntKey, search.vocation, search.level]);

  async function chooseBuildForHunt(option:any) {
    const clientId = getOrCreateClientId();
    if (!clientId || !option || savingBuildChoice) return;

    setSavingBuildChoice(true);
    try {
      const response = await callHuntNexusApi<any>({
        action: "player_hunt_build_choice_save",
        client_id: clientId,
        hunt_key: huntKey,
        vocation: search.vocation,
        level: search.level,
        selection: option.selection ?? {},
        option_type: option.option_type === "main" ? "main" : "owned_variant",
        replacements: Array.isArray(option.replacements) ? option.replacements : [],
      });

      if (!response?.data?.saved) {
        throw new Error(response?.data?.error || "build_choice_not_saved");
      }

      setHuntBuildChoice({
        hunt_key: huntKey,
        vocation: search.vocation,
        selection: option.selection ?? {},
        option_type: option.option_type === "main" ? "main" : "owned_variant",
        replacements: Array.isArray(option.replacements) ? option.replacements : [],
      });
    } finally {
      setSavingBuildChoice(false);
    }
  }

  if (loading) {
    return <div className="grid min-h-[70vh] place-items-center"><Loader2 className="size-7 animate-spin text-cyan-300" /></div>;
  }

  if (error || !data) {
    return <div className="mx-auto max-w-3xl rounded-3xl border border-red-400/20 bg-red-400/8 p-6 text-red-200">{error || "Hunt não encontrada."}</div>;
  }

  const hunt = data.factual?.hunt ?? {};
  const perf = data.observed?.performance ?? {};
  const monsters = Array.isArray(data.factual?.monsters) ? data.factual.monsters : [];
  const media = data.media ?? {};
  const currentSetup = setupLoad?.key === setupKey ? setupLoad.data : null;
  const setSummary = currentSetup?.summary ?? {};
  const combatElements = (Array.isArray(data.factual?.elements) ? data.factual.elements : [])
    .filter((e:any) => ["physical","fire","ice","earth","energy","death","holy"].includes(String(e.element)))
    .filter((e:any) => e.avg_modifier_percent != null && Number.isFinite(Number(e.avg_modifier_percent)));
  const strongestElement = [...combatElements].sort(
    (a:any,b:any) => Number(b.avg_modifier_percent) - Number(a.avg_modifier_percent),
  )[0] ?? null;
  const mostResistedElement = [...combatElements]
    .filter((e:any) => Number(e.avg_modifier_percent) >= 0)
    .sort((a:any,b:any) => Number(a.avg_modifier_percent) - Number(b.avg_modifier_percent))[0] ?? null;
  const mapperCoords = parseMapperCoords(media?.mapper_location || hunt.location);

  return (
    <div className="mx-auto max-w-[1450px] space-y-5">
      <section className="hn-hero overflow-hidden rounded-3xl border border-white/8">
        <div className="grid xl:grid-cols-[1.15fr_.85fr]">
          <div className="p-5 md:p-7">
            <div className="text-xs uppercase tracking-[0.18em] text-cyan-400">{hunt.city || "Hunt"}</div>
            <h1 className="mt-2 text-4xl font-black tracking-tight text-white">{hunt.name || huntKey}</h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-400">
              {cleanLocation(hunt.location) || "Dados factuais e sessões reais reunidos pelo HuntNexus."}
            </p>
            <div className="mt-5 flex flex-wrap gap-2">
              <Badge>{search.vocation}</Badge>
              <Badge>Level {search.level}</Badge>
              <Badge>{labelObjective(search.setObjective)}</Badge>
              <Badge>{perf.session_count ? `${perf.session_count} sessões observadas` : "Sem sessões observadas"}</Badge>
            </div>
            <div className="mt-6 grid max-w-3xl gap-3 sm:grid-cols-3">
              <HeroMetric label="XP/h mediana" value={compact(perf.median_xp_per_hour)} />
              <HeroMetric label="Profit/h mediano" value={compact(perf.median_balance_per_hour)} />
              <HeroMetric label="Sets co-vencedores" value={currentSetup ? String(setSummary.co_winners ?? "—") : "Ver Setup"} />
            </div>
          </div>
          <div className="relative overflow-hidden border-l border-white/7 bg-slate-950/55 p-5 md:p-7">
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_38%,rgba(34,211,238,.11),transparent_55%)]" />
            <div className="relative z-10 flex h-full flex-col justify-between gap-5">
              <div>
                <div className="text-center text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-600">
                  Ecossistema da hunt
                </div>
                <div className="mt-4 flex items-end justify-center gap-1">
                  {media.hero_image_name && (
                    <CanonicalSprite
                      kind="creature"
                      name={media.hero_image_name}
                      size="lg"
                      className="z-10 scale-110 border-cyan-400/15"
                    />
                  )}
                  <CanonicalSpriteGroup
                    names={monsters
                      .filter((m:any) => m.name !== media.hero_image_name)
                      .slice(0,3)
                      .map((m:any) => m.name)}
                  />
                </div>
                <div className="mt-3 text-center text-[10px] text-slate-600">
                  {monsters.length} criatura{monsters.length === 1 ? "" : "s"} vinculada{monsters.length === 1 ? "" : "s"} · sprites canônicos
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <HeroFact
                  label="Melhor elemento médio"
                  value={
                    strongestElement
                      ? `${elementLabel(strongestElement.element)} · ${formatNumber(Number(strongestElement.avg_modifier_percent),1)}%`
                      : "—"
                  }
                />
                <HeroFact
                  label="Mais resistido em média"
                  value={
                    mostResistedElement
                      ? `${elementLabel(mostResistedElement.element)} · ${formatNumber(Number(mostResistedElement.avg_modifier_percent),1)}%`
                      : "—"
                  }
                />
                <HeroFact
                  label="Mapa"
                  value={mapperCoords ? `${mapperCoords.x}, ${mapperCoords.y}, ${mapperCoords.z}` : "Sem coordenada"}
                />
                <HeroFact
                  label="Fonte visual"
                  value={media.hero_image_name ? media.hero_image_name : "Composição de criaturas"}
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {tabs.map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`flex shrink-0 items-center gap-2 rounded-xl border px-3 py-2 text-xs font-semibold transition ${tab === key ? "border-cyan-400/30 bg-cyan-400/10 text-cyan-100" : "border-white/7 bg-white/[0.02] text-slate-500 hover:text-slate-200"}`}
          >
            <Icon className="size-3.5" /> {label}
          </button>
        ))}
      </div>

      <section className="rounded-3xl border border-white/8 bg-white/[0.025] p-5 md:p-6">
        {tab === "overview" && <Overview data={data} />}
        {tab === "creatures" && <Creatures monsters={monsters} observed={data.observed} />}
        {tab === "map" && <MapPanel hunt={hunt} media={media} />}
        {tab === "damage" && <Damage defensive={data.defensive} />}
        {tab === "setup" && (
          <Setup
            selection={currentSetup}
            loadingSelection={setupLoading}
            selectionError={setupError}
            onRetrySelection={() => { setSetupRetry((value) => value + 1); }}
            personalReview={personalReview}
            ownedBuildOptions={ownedBuildOptions}
            personalBuildPerformance={personalBuildPerformance}
            huntBuildChoice={huntBuildChoice}
            savingBuildChoice={savingBuildChoice}
            onChooseBuild={chooseBuildForHunt}
            loadingPersonalReview={loadingPersonalReview}
          />
        )}
        {tab === "spells" && (spellsLoading ? (
          <div className="grid min-h-[240px] place-items-center"><Loader2 className="size-5 animate-spin text-cyan-300" /></div>
        ) : spellsError ? (
          <Muted>{spellsError}</Muted>
        ) : spellsLoad?.key === spellsKey ? (
          <Spells spells={spellsLoad.data?.spells} composition={spellsLoad.data?.vocation_composition} />
        ) : <Muted>Carregando spells e composição da vocação...</Muted>)}
        {tab === "imbuements" && <Imbuements data={data.imbuements} />}
        {tab === "community" && <Community observed={data.observed} />}
      </section>
    </div>
  );
}

function Overview({ data }: { data:any }) {
  const factualElements = Array.isArray(data.factual?.elements) ? data.factual.elements : [];
  const perf = data.observed?.performance ?? {};
  const hunt = data.factual?.hunt ?? {};
  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-3">
        <CanonicalLevelCard label="Knight" value={hunt.level_knights} />
        <CanonicalLevelCard label="Paladin" value={hunt.level_paladins} />
        <CanonicalLevelCard label="Mages" value={hunt.level_mages} />
      </div>

      <div className="grid gap-5 xl:grid-cols-[1fr_.9fr]">
      <Panel title="Performance observada">
        <div className="grid gap-3 sm:grid-cols-2">
          <Metric label="Sessões" value={formatNumber(Number(perf.session_count || 0))} />
          <Metric label="Duração média" value={perf.avg_duration_minutes != null ? `${formatNumber(Number(perf.avg_duration_minutes),1)} min` : "—"} />
          <Metric label="XP/h mínima" value={compact(perf.min_xp_per_hour)} />
          <Metric label="XP/h máxima" value={compact(perf.max_xp_per_hour)} />
          <Metric label="Damage médio" value={compact(perf.avg_total_damage)} />
          <Metric label="Healing médio" value={compact(perf.avg_total_healing)} />
        </div>
      </Panel>

      <Panel title="Perfil elemental factual">
        <div className="space-y-2">
          {factualElements
            .filter((e:any) => ["physical","fire","ice","earth","energy","death","holy"].includes(String(e.element)))
            .map((e:any) => (
              <div key={e.element} className="flex items-center justify-between rounded-xl border border-white/6 bg-slate-950/45 px-3 py-2">
                <span className="capitalize text-sm text-slate-300">{e.element}</span>
                <span className="text-sm font-black text-cyan-200">{e.avg_modifier_percent == null ? "Não informado" : `${formatNumber(Number(e.avg_modifier_percent),1)}%`}</span>
              </div>
            ))}
        </div>
      </Panel>
      </div>
    </div>
  );
}

function Creatures({ monsters, observed }: { monsters:any[]; observed:any }) {
  const mix = new Map((observed?.kill_mix ?? []).map((m:any) => [m.monster_key, m]));
  return (
    <div>
      <SectionTitle title="Criaturas" subtitle="Catálogo factual + presença observada nas sessões." />
      <div className="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {monsters.map((m:any) => {
          const seen:any = mix.get(m.key);
          return (
            <div key={m.key} className="grid grid-cols-[80px_1fr] gap-3 rounded-2xl border border-white/7 bg-slate-950/40 p-3">
              <CanonicalSprite kind="creature" name={m.name} size="md" />
              <div className="min-w-0">
                <div className="font-bold text-white">{m.name}</div>
                <div className="mt-2 text-xs text-slate-500">{seen ? `${formatNumber(Number(seen.kills || 0))} kills observadas` : "Sem kills observadas"}</div>
                {seen?.kill_share != null && <div className="mt-1 text-xs text-cyan-300">{formatNumber(Number(seen.kill_share)*100,1)}% do mix</div>}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function MapPanel({ hunt, media }: { hunt:any; media:any }) {
  return (
    <div>
      <SectionTitle title="Map" subtitle="Minimap real do Tibia centralizado na coordenada factual da hunt." />
      <div className="mt-5 grid gap-5 xl:grid-cols-[1.2fr_.8fr]">
        <CanonicalTibiaMap location={media?.mapper_location || hunt.location} label={hunt.name || "Hunt"} />
        <Panel title="Localização">
          <div className="space-y-3">
            <Metric label="Cidade" value={hunt.city || "—"} />
            <Metric label="Local" value={cleanLocation(hunt.location) || "—"} />
            <div className="rounded-xl border border-white/6 bg-white/[0.025] p-3 text-xs leading-5 text-slate-500">
              O mapa usa os dados visuais do minimap do Tibia. Não é uma ilustração gerada pelo HuntNexus.
            </div>
          </div>
        </Panel>
      </div>
    </div>
  );
}

function Damage({ defensive }: { defensive:any }) {
  const elements = Array.isArray(defensive?.elements) ? defensive.elements : [];
  const max = Math.max(0, ...elements.map((e:any) => e.damage_share == null ? 0 : Number(e.damage_share) || 0));
  return (
    <div>
      <SectionTitle title="Dano recebido" subtitle="Observação real por vocação, sem substituir fatos canônicos." />
      <div className="mt-5 grid gap-5 xl:grid-cols-[1.1fr_.9fr]">
        <Panel title="Distribuição por elemento">
          <div className="space-y-4">
            {elements.map((e:any) => (
              <div key={e.element}>
                <div className="mb-1.5 flex items-center justify-between text-xs"><span className="capitalize text-slate-300">{e.element}</span><span className="text-slate-500">{e.damage_share == null ? "Sem percentual observado" : `${formatNumber(Number(e.damage_share)*100,1)}%`}</span></div>
                <div className="h-2 overflow-hidden rounded-full bg-white/5">
                  {e.damage_share != null && max > 0 && (
                    <div className="h-full rounded-full bg-cyan-400/55" style={{width:`${Math.max(0,Math.min(100,Number(e.damage_share)/max*100))}%`}} />
                  )}
                </div>
              </div>
            ))}
            {!elements.length && <Muted>Sem dano recebido observado para esta combinação.</Muted>}
          </div>
        </Panel>
        <Panel title="Picos observados">
          <div className="space-y-2">
            {elements.map((e:any) => <Metric key={e.element} label={`${e.element} max DPS mediano`} value={e.median_max_dps == null ? "Não observado" : formatNumber(Number(e.median_max_dps))} />)}
          </div>
        </Panel>
      </div>
    </div>
  );
}

function Setup({
  selection,
  loadingSelection,
  selectionError,
  onRetrySelection,
  personalReview,
  ownedBuildOptions,
  personalBuildPerformance,
  huntBuildChoice,
  savingBuildChoice,
  onChooseBuild,
  loadingPersonalReview,
}: {
  selection:any;
  loadingSelection:boolean;
  selectionError:string;
  onRetrySelection:() => void;
  personalReview:any;
  ownedBuildOptions:any;
  personalBuildPerformance:any;
  huntBuildChoice:any;
  savingBuildChoice:boolean;
  onChooseBuild:(option:any) => Promise<void>;
  loadingPersonalReview:boolean;
}) {
  const [selectedOwnedOption, setSelectedOwnedOption] = useState(1);
  const sets = Array.isArray(selection?.selected_sets) ? selection.selected_sets : [];
  const mainSet = Array.isArray(personalReview?.baseline?.main_set) ? personalReview.baseline.main_set : [];
  const ownedAlternatives = Array.isArray(personalReview?.owned_alternatives) ? personalReview.owned_alternatives : [];
  const frontierCandidates = Array.isArray(personalReview?.frontier_candidates) ? personalReview.frontier_candidates : [];
  const backpackCandidates = frontierCandidates.filter((item:any) => item.ownership === "backpack");
  const externalCandidates = frontierCandidates.filter((item:any) => item.ownership === "external");
  const ownedOptions = Array.isArray(ownedBuildOptions?.options) ? ownedBuildOptions.options : [];

  return (
    <div>
      <SectionTitle title="Setup da hunt" subtitle="Seu Set Main permanece como baseline; BP e itens externos aparecem separados." />

      <div className="mt-5 rounded-2xl border border-amber-400/15 bg-amber-400/[0.025] p-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <div className="text-sm font-bold text-white">Opções com os seus itens</div>
            <div className="mt-1 text-xs text-slate-500">
              A 1ª opção é o Set Main. A 2ª/3ª só usam peças da BP que passaram pelo filtro contextual e não ficaram dominadas pelo Main quando comparáveis.
            </div>
          </div>
          <span className="rounded-full border border-white/7 px-2.5 py-1 text-[10px] text-slate-500">
            {ownedBuildOptions?.summary?.discarded_as_main_dominated ?? 0} variações descartadas
          </span>
        </div>

        {loadingPersonalReview ? (
          <div className="grid min-h-[150px] place-items-center">
            <Loader2 className="size-5 animate-spin text-cyan-300" />
          </div>
        ) : ownedOptions.length ? (
          <div className="mt-4 grid gap-3 xl:grid-cols-3">
            {ownedOptions.map((option:any) => (
              <OwnedBuildOptionCard
                key={option.option_order}
                option={option}
                personalReview={personalReview}
                selected={selectedOwnedOption === option.option_order}
                chosen={sameBuildSelection(huntBuildChoice?.selection, option.selection)}
                savingChoice={savingBuildChoice}
                onSelect={() => setSelectedOwnedOption(option.option_order)}
                onChoose={() => void onChooseBuild(option)}
              />
            ))}
          </div>
        ) : (
          <div className="mt-4 text-sm text-slate-500">Cadastre o Set Main no Profile para gerar opções personalizadas.</div>
        )}

        {ownedOptions.length > 1 && (
          <OwnedBuildComparison
            option={ownedOptions.find((option:any) => option.option_order === selectedOwnedOption) ?? ownedOptions[0]}
            personalReview={personalReview}
          />
        )}
      </div>

      <PrivateBuildPerformance data={personalBuildPerformance} />

      <div className="mt-5 grid gap-5 xl:grid-cols-[1.05fr_.95fr]">
        <Panel title="Seu Set Main">
          {loadingPersonalReview ? (
            <div className="grid min-h-[160px] place-items-center"><Loader2 className="size-5 animate-spin text-cyan-300" /></div>
          ) : mainSet.length ? (
            <div className="grid gap-2 sm:grid-cols-2">
              {mainSet.map((item:any) => (
                <div key={item.selection_key} className="grid grid-cols-[52px_1fr_auto] items-center gap-2 rounded-xl border border-white/6 bg-white/[0.025] p-2">
                  <CanonicalSprite kind="item" name={item.item_name} size="sm" />
                  <div className="min-w-0">
                    <div className="text-[10px] uppercase tracking-wide text-slate-600">{item.selection_key}</div>
                    <div className="mt-1 truncate text-xs font-semibold text-slate-200">{item.item_name}</div>
                  </div>
                  <span className={`rounded-full border px-2 py-1 text-[9px] ${
                    item.on_context_frontier
                      ? "border-emerald-400/20 bg-emerald-400/[0.06] text-emerald-300"
                      : "border-white/7 text-slate-500"
                  }`}>
                    {item.on_context_frontier ? "frontier" : "baseline"}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <Muted>Cadastre seu Set Main no Profile para comparar esta hunt com o equipamento que você realmente usa.</Muted>
          )}
        </Panel>

        <Panel title="Alternativas que você já possui">
          {ownedAlternatives.length ? (
            <div className="space-y-2">
              {ownedAlternatives.map((item:any) => (
                <div key={item.item_key} className="grid grid-cols-[52px_1fr_auto] items-center gap-2 rounded-xl border border-white/6 bg-white/[0.025] p-2">
                  <CanonicalSprite kind="item" name={item.item_name} size="sm" />
                  <div className="min-w-0">
                    <div className="text-[10px] uppercase tracking-wide text-slate-600">{item.selection_key}</div>
                    <div className="mt-1 truncate text-xs font-semibold text-slate-200">{item.item_name}</div>
                  </div>
                  <span className={`rounded-full border px-2 py-1 text-[9px] ${
                    item.on_context_frontier
                      ? "border-cyan-400/20 bg-cyan-400/[0.06] text-cyan-200"
                      : "border-white/7 text-slate-600"
                  }`}>
                    {item.on_context_frontier ? "candidata" : "BP"}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <Muted>Nenhuma alternativa da BP cadastrada.</Muted>
          )}
        </Panel>
      </div>

      {backpackCandidates.length > 0 && (
        <div className="mt-5 rounded-2xl border border-cyan-400/12 bg-cyan-400/[0.025] p-4">
          <div className="text-sm font-semibold text-cyan-100">Peças da BP que chegaram ao frontier contextual</div>
          <div className="mt-3 flex flex-wrap gap-2">
            {backpackCandidates.map((item:any) => (
              <span key={item.item_key} className="rounded-full border border-cyan-400/15 bg-cyan-400/[0.05] px-3 py-1.5 text-xs text-cyan-200">
                {item.item_name}
              </span>
            ))}
          </div>
          <div className="mt-3 text-[11px] text-slate-500">Isso indica relevância contextual no item-level Pareto; não significa troca automática nem vencedor único.</div>
        </div>
      )}

      {externalCandidates.length > 0 && (
        <div className="mt-5">
          <div className="mb-3 flex items-end justify-between gap-3">
            <div>
              <div className="text-sm font-semibold text-slate-200">Sugestões externas</div>
              <div className="mt-1 text-xs text-slate-600">Itens contextuais que não constam no seu Set Main nem na BP.</div>
            </div>
            <span className="text-[10px] text-slate-600">{externalCandidates.length} candidatos</span>
          </div>
          <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
            {externalCandidates.slice(0,12).map((item:any) => (
              <div key={`${item.selection_key}-${item.item_key}`} className="grid grid-cols-[52px_1fr] items-center gap-2 rounded-xl border border-white/6 bg-slate-950/35 p-2">
                <CanonicalSprite kind="item" name={item.item_name} size="sm" />
                <div className="min-w-0">
                  <div className="text-[10px] uppercase tracking-wide text-slate-600">{item.selection_key}</div>
                  <div className="mt-1 truncate text-xs font-semibold text-slate-300">{item.item_name}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="mt-7 border-t border-white/7 pt-5">
        <SectionTitle title="Frontier universal" subtitle={selection ? `${selection?.summary?.co_winners ?? sets.length} co-vencedores preservados no catálogo completo` : "Cálculo completo executado somente ao abrir o Setup"} />
      </div>

      <div className="mt-5 grid gap-4 xl:grid-cols-2">
        {sets.slice(0,8).map((set:any, index:number) => {
          const slots = set.selection ?? {};
          return (
            <div key={set.set_order ?? index} className="rounded-2xl border border-white/7 bg-slate-950/40 p-4">
              <div className="flex items-center justify-between"><div className="font-bold text-white">Opção {index+1}</div><Badge>{set.selection_policy?.set_objective ?? "balanced"}</Badge></div>
              <div className="mt-4 grid grid-cols-2 gap-2">
                {Object.entries(slots).map(([slot,item]) => (
                  <div key={slot} className="grid grid-cols-[52px_1fr] items-center gap-2 rounded-xl border border-white/6 bg-white/[0.025] p-2">
                    <CanonicalSprite kind="item" name={slugToName(String(item))} size="sm" />
                    <div className="min-w-0">
                      <div className="text-[10px] uppercase tracking-wide text-slate-600">{slot}</div>
                      <div className="mt-1 break-words text-xs font-semibold text-slate-200">{slugToName(String(item))}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          );
        })}
        {loadingSelection && <div className="flex items-center gap-2 text-xs text-cyan-300"><Loader2 className="size-4 animate-spin" />Calculando combinações universais...</div>}
        {selectionError && (
          <div className="col-span-full rounded-xl border border-amber-400/15 bg-amber-400/[0.035] p-3 text-xs text-amber-200">
            {selectionError}
            <button type="button" className="ml-3 underline" onClick={onRetrySelection}>Tentar novamente</button>
          </div>
        )}
        {!sets.length && !loadingSelection && !selectionError && selection && <Muted>Nenhum set selecionável para esta configuração.</Muted>}
      </div>
    </div>
  );
}

function Spells({ spells, composition }: { spells:any; composition:any }) {
  const groups = Object.entries(spells ?? {}).filter(([,v]) => Array.isArray(v)) as Array<[string,any[]]>;
  return (
    <div>
      <SectionTitle title="Spells & Proficiency" subtitle="Somente candidatos elegíveis e contexto da vocação." />
      <div className="mt-5 grid gap-5 xl:grid-cols-2">
        <Panel title="Spells">
          <div className="space-y-4">
            {groups.slice(0,8).map(([key,list]) => (
              <div key={key}>
                <div className="mb-2 text-[10px] uppercase tracking-[.16em] text-slate-600">{key.replaceAll("_"," ")}</div>
                <div className="flex flex-wrap gap-2">
                  {list.slice(0,10).map((s:any,i:number) => <Badge key={s.spell_key ?? i}>{s.name ?? s.words ?? s.spell_key}</Badge>)}
                </div>
              </div>
            ))}
          </div>
        </Panel>
        <Panel title="Composição da vocação">
          <pre className="max-h-[420px] overflow-auto whitespace-pre-wrap text-xs leading-5 text-slate-500">{JSON.stringify(compactComposition(composition),null,2)}</pre>
        </Panel>
      </div>
    </div>
  );
}

function Imbuements({ data }: { data:any }) {
  const priorities = Array.isArray(data?.defensive_priority) ? data.defensive_priority : [];
  const usage = Array.isArray(data?.community_observed_usage) ? data.community_observed_usage : [];
  return (
    <div>
      <SectionTitle title="Imbuements" subtitle="Prioridade defensiva baseada no dano observado; uso comunitário continua Tier C." />
      <div className="mt-5 grid gap-5 xl:grid-cols-2">
        <Panel title="Prioridade defensiva">
          <div className="space-y-2">{priorities.map((x:any) => <Metric key={x.imbuement_key} label={x.name} value={`${x.element} · ${formatNumber(Number(x.powerful_value||0),1)}%`} />)}{!priorities.length && <Muted>Sem prioridade defensiva calculável.</Muted>}</div>
        </Panel>
        <Panel title="Uso comunitário observado">
          <div className="space-y-2">{usage.slice(0,10).map((x:any) => <Metric key={x.imbuement_key} label={x.name} value={`${x.observed_profiles}/${x.eligible_profiles} perfis`} />)}{!usage.length && <Muted>Sem uso comunitário observado.</Muted>}</div>
        </Panel>
      </div>
    </div>
  );
}

function Community({ observed }: { observed:any }) {
  const p = observed?.performance ?? {};
  const mix = Array.isArray(observed?.kill_mix) ? observed.kill_mix : [];
  return (
    <div>
      <SectionTitle title="Community" subtitle="Sessões reais como evidência, sem misturar observação com fato oficial." />
      <div className="mt-5 grid gap-5 xl:grid-cols-[.8fr_1.2fr]">
        <Panel title="Amostra">
          <div className="space-y-2">
            <Metric label="Sessões" value={formatNumber(Number(p.session_count || 0))} />
            <Metric label="Solo" value={formatNumber(Number(p.solo_sessions || 0))} />
            <Metric label="Duo" value={formatNumber(Number(p.duo_sessions || 0))} />
            <Metric label="Party" value={formatNumber(Number(p.party_sessions || 0))} />
          </div>
        </Panel>
        <Panel title="Kill mix observado">
          <div className="space-y-2">
            {mix.map((m:any) => <Metric key={m.monster_key} label={m.monster_name || m.monster_key} value={`${formatNumber(Number(m.kills||0))} · ${formatNumber(Number(m.kill_share||0)*100,1)}%`} />)}
          </div>
        </Panel>
      </div>
    </div>
  );
}

function PrivateBuildPerformance({ data }: { data:any }) {
  const builds = Array.isArray(data?.builds) ? data.builds : [];
  if (!builds.length) return null;

  return (
    <div className="mt-5 rounded-2xl border border-violet-400/12 bg-violet-400/[0.025] p-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <div className="text-sm font-bold text-white">Seus resultados por build</div>
          <div className="mt-1 text-xs text-slate-500">
            Medianas das suas sessões privadas desta hunt. Comparação descritiva; não prova que o equipamento causou a diferença.
          </div>
        </div>
        <span className="rounded-full border border-white/7 px-2.5 py-1 text-[10px] text-slate-500">
          {data?.summary?.sessions ?? 0} sessões · {data?.summary?.distinct_builds ?? builds.length} builds
        </span>
      </div>

      <div className="mt-4 grid gap-3 xl:grid-cols-3">
        {builds.slice(0,6).map((build:any, index:number) => (
          <div key={build.build_signature ?? index} className="rounded-xl border border-white/7 bg-slate-950/45 p-3">
            <div className="flex items-center justify-between gap-2">
              <div>
                <div className="text-xs font-semibold text-slate-200">
                  {build.option_type === "owned_variant" ? "Build alternativa" : "Set Main"}
                </div>
                <div className="mt-1 text-[10px] text-slate-600">{build.session_count} sessão(ões)</div>
              </div>
              <span className={`rounded-full border px-2 py-1 text-[9px] ${buildSampleClass(build.sample_status)}`}>
                {buildSampleLabel(build.sample_status)}
              </span>
            </div>

            <div className="mt-3 flex flex-wrap gap-1.5">
              {(Array.isArray(build.items) ? build.items : []).slice(0,8).map((item:any) => (
                <div key={`${item.selection_key}-${item.item_key}`} title={item.item_name || item.item_key} className="rounded-lg border border-white/6 bg-black/20 p-1.5">
                  <CanonicalSprite kind="item" name={item.item_name || slugToName(item.item_key)} size="sm" />
                </div>
              ))}
            </div>

            <div className="mt-3 grid grid-cols-2 gap-2">
              <BuildPerfMetric label="XP/h" value={formatCompactMetric(build.median_xp_per_hour)} />
              <BuildPerfMetric label="Profit/h" value={formatCompactMetric(build.median_profit_per_hour)} />
              <BuildPerfMetric label="Damage/h" value={formatCompactMetric(build.median_damage_per_hour)} />
              <BuildPerfMetric label="Healing/h" value={formatCompactMetric(build.median_healing_per_hour)} />
            </div>
          </div>
        ))}
      </div>

      <div className="mt-3 text-[10px] leading-4 text-slate-600">
        Amostras pequenas são mantidas visíveis, mas não são tratadas como evidência suficiente para declarar uma build melhor.
      </div>
    </div>
  );
}

function BuildPerfMetric({ label, value }: { label:string; value:string }) {
  return (
    <div className="rounded-lg border border-white/6 bg-white/[0.02] p-2">
      <div className="text-[9px] text-slate-600">{label}</div>
      <div className="mt-1 text-xs font-bold text-slate-200">{value}</div>
    </div>
  );
}

function buildSampleLabel(status:string) {
  return ({
    single_session:"1 sessão",
    very_low_sample:"amostra muito baixa",
    low_sample:"amostra baixa",
    observed_sample:"amostra observada",
  } as Record<string,string>)[status] ?? "amostra";
}

function buildSampleClass(status:string) {
  if (status === "observed_sample") return "border-emerald-400/15 bg-emerald-400/[0.05] text-emerald-300";
  if (status === "low_sample") return "border-cyan-400/15 bg-cyan-400/[0.05] text-cyan-200";
  return "border-amber-400/15 bg-amber-400/[0.05] text-amber-200";
}

function formatCompactMetric(value:unknown) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "—";
  const abs = Math.abs(n);
  const sign = n < 0 ? "-" : "";
  if (abs >= 1_000_000) return `${sign}${(abs / 1_000_000).toFixed(2)}M`;
  if (abs >= 1_000) return `${sign}${Math.round(abs / 1_000)}k`;
  return String(Math.round(n));
}

function OwnedBuildOptionCard({
  option,
  personalReview,
  selected,
  chosen,
  savingChoice,
  onSelect,
  onChoose,
}: {
  option:any;
  personalReview:any;
  selected:boolean;
  chosen:boolean;
  savingChoice:boolean;
  onSelect:() => void;
  onChoose:() => void;
}) {
  const selection = option?.selection ?? {};
  const replacements = Array.isArray(option?.replacements) ? option.replacements : [];
  const mainRows = Array.isArray(personalReview?.baseline?.main_set) ? personalReview.baseline.main_set : [];
  const ownedRows = Array.isArray(personalReview?.owned_alternatives) ? personalReview.owned_alternatives : [];
  const itemByKey = new Map(
    [...mainRows, ...ownedRows].map((item:any) => [item.item_key, item]),
  );
  const mainBySlot = new Map(mainRows.map((item:any) => [item.selection_key, item.item_key]));
  const slots = orderedBuildSlots(selection);
  const replacementSlots = new Set(replacements.map((item:any) => item.selection_key));

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onSelect}
      onKeyDown={(event) => {
        if (event.key === "Enter" || event.key === " ") onSelect();
      }}
      className={`group w-full cursor-pointer rounded-2xl border p-4 text-left transition ${
        selected
          ? option.option_type === "main"
            ? "border-amber-300/70 bg-amber-400/[0.10] shadow-[0_0_0_1px_rgba(252,211,77,.08)]"
            : "border-cyan-300/45 bg-cyan-400/[0.07] shadow-[0_0_0_1px_rgba(34,211,238,.06)]"
          : "border-white/7 bg-slate-950/45 hover:border-white/14"
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-sm font-black text-white">{option.option_order}ª opção</div>
          <div className="mt-1 text-[11px] text-slate-500">
            {option.option_type === "main" ? "Seu Set Main" : `${replacements.length} troca${replacements.length === 1 ? "" : "s"} com a BP`}
          </div>
        </div>

        {chosen ? (
          <span className="rounded-full border border-emerald-300/25 bg-emerald-300 px-2.5 py-1 text-[10px] font-black text-slate-950">Nesta hunt</span>
        ) : option.option_type === "main" ? (
          <span className="rounded-full bg-amber-300 px-2.5 py-1 text-[10px] font-black text-slate-950">Main</span>
        ) : option.dominates_main ? (
          <span className="rounded-full border border-emerald-400/20 bg-emerald-400/[0.06] px-2.5 py-1 text-[10px] text-emerald-300">supera Main</span>
        ) : (
          <span className="rounded-full border border-cyan-400/20 bg-cyan-400/[0.06] px-2.5 py-1 text-[10px] text-cyan-200">alternativa</span>
        )}
      </div>

      <div className="mt-4 grid grid-cols-4 gap-2">
        {slots.map(([slot,itemKey]) => {
          const row:any = itemByKey.get(String(itemKey));
          const changed = replacementSlots.has(slot) || (
            option.option_type !== "main" &&
            mainBySlot.has(slot) &&
            mainBySlot.get(slot) !== itemKey
          );

          return (
            <div
              key={slot}
              title={row?.item_name || slugToName(String(itemKey))}
              className={`relative rounded-xl border p-2 text-center transition ${
                changed
                  ? "border-cyan-300/35 bg-cyan-400/[0.08]"
                  : option.option_type === "main"
                    ? "border-amber-300/12 bg-black/20"
                    : "border-white/6 bg-black/20"
              }`}
            >
              {changed && (
                <span className="absolute -right-1 -top-1 rounded-full border border-cyan-300/30 bg-cyan-300 px-1.5 py-0.5 text-[8px] font-black text-slate-950">
                  BP
                </span>
              )}
              <CanonicalSprite kind="item" name={row?.item_name || slugToName(String(itemKey))} size="sm" />
              <div className="mt-1 truncate text-[9px] uppercase tracking-wide text-slate-600">{buildSlotLabel(slot)}</div>
            </div>
          );
        })}
      </div>

      {replacements.length > 0 ? (
        <div className="mt-3 flex flex-wrap gap-1.5">
          {replacements.map((replacement:any) => (
            <span
              key={`${replacement.selection_key}-${replacement.item_key}`}
              className="rounded-full border border-cyan-400/15 bg-cyan-400/[0.045] px-2 py-1 text-[9px] font-semibold text-cyan-200"
            >
              {buildSlotLabel(replacement.selection_key)} · {replacement.item_name}
            </span>
          ))}
        </div>
      ) : (
        <div className="mt-3 text-[10px] text-amber-200/75">Referência atual do personagem</div>
      )}

      <div className="mt-3 border-t border-white/6 pt-3 text-[10px] leading-4 text-slate-600">
        {humanOwnedBuildReason(option)}
      </div>

      <div className="mt-3 flex items-center justify-between gap-2">
        <span className="text-[9px] text-slate-700">
          {chosen ? "Selecionada apenas para esta hunt" : "Não altera seu Set Main"}
        </span>
        <button
          type="button"
          disabled={chosen || savingChoice}
          onClick={(event) => {
            event.stopPropagation();
            onChoose();
          }}
          className={`rounded-lg border px-2.5 py-1.5 text-[10px] font-semibold transition ${
            chosen
              ? "cursor-default border-emerald-400/20 bg-emerald-400/[0.08] text-emerald-300"
              : "border-cyan-400/15 bg-cyan-400/[0.04] text-cyan-200 hover:border-cyan-300/30 hover:bg-cyan-400/[0.08]"
          } disabled:opacity-60`}
        >
          {chosen ? "Em uso nesta hunt" : savingChoice ? "Salvando..." : "Usar nesta hunt"}
        </button>
      </div>
    </div>
  );
}

function OwnedBuildComparison({ option, personalReview }: { option:any; personalReview:any }) {
  if (!option || option.option_type === "main") {
    return (
      <div className="mt-4 rounded-xl border border-amber-400/10 bg-amber-400/[0.025] p-3 text-xs text-slate-500">
        <span className="font-semibold text-amber-200/80">1ª opção:</span> seu Set Main continua sendo a referência da hunt.
      </div>
    );
  }

  const replacements = Array.isArray(option.replacements) ? option.replacements : [];
  const details = Array.isArray(option.replacement_details) ? option.replacement_details : [];
  const mainRows = Array.isArray(personalReview?.baseline?.main_set) ? personalReview.baseline.main_set : [];
  const mainBySlot = new Map(mainRows.map((item:any) => [item.selection_key, item]));

  return (
    <div className="mt-4 rounded-xl border border-cyan-400/10 bg-cyan-400/[0.025] p-3">
      <div className="text-xs font-semibold text-cyan-100">O que muda nesta opção</div>
      <div className="mt-3 space-y-3">
        {replacements.map((replacement:any) => {
          const previous:any = mainBySlot.get(replacement.selection_key);
          const detail = details.find((item:any) => item.selection_key === replacement.selection_key);
          const toHighlights = effectContextHighlights(detail?.to_context);
          const fromHighlights = effectContextHighlights(detail?.from_context);
          const incomingAvailable = detail?.to_context?.incoming_damage?.available === true;

          return (
            <div key={replacement.selection_key} className="rounded-xl border border-white/6 bg-black/15 p-3">
              <div className="grid gap-3 md:grid-cols-[1fr_auto_1fr] md:items-center">
                <div className="flex items-center gap-2">
                  <CanonicalSprite kind="item" name={previous?.item_name || slugToName(String(previous?.item_key || ""))} size="sm" />
                  <div className="min-w-0">
                    <div className="text-[9px] uppercase tracking-wide text-slate-600">{buildSlotLabel(replacement.selection_key)} · Main</div>
                    <div className="truncate text-xs font-semibold text-slate-400">{previous?.item_name || "Main"}</div>
                  </div>
                </div>

                <span className="hidden text-sm font-black text-cyan-300 md:block">→</span>

                <div className="flex items-center gap-2 md:justify-end">
                  <CanonicalSprite kind="item" name={replacement.item_name} size="sm" />
                  <div className="min-w-0 md:text-right">
                    <div className="text-[9px] uppercase tracking-wide text-cyan-500">BP · candidata</div>
                    <div className="truncate text-xs font-semibold text-cyan-100">{replacement.item_name}</div>
                  </div>
                </div>
              </div>

              <div className="mt-3 grid gap-3 lg:grid-cols-2">
                <BuildAttributeBlock
                  title="Main traz"
                  highlights={fromHighlights}
                  empty="Sem efeitos normalizados adicionais."
                />
                <BuildAttributeBlock
                  title="Peça da BP traz"
                  highlights={toHighlights}
                  empty="Sem efeitos normalizados adicionais."
                  accent
                />
              </div>

              {!incomingAvailable && hasProtectionHighlight(toHighlights) && (
                <div className="mt-2 rounded-lg border border-amber-400/10 bg-amber-400/[0.035] px-2.5 py-2 text-[10px] leading-4 text-amber-100/60">
                  Esta peça possui proteção elemental, mas não há dano observado suficiente nesta hunt para afirmar que essa proteção é superior à do Main.
                </div>
              )}
            </div>
          );
        })}
      </div>
      <div className="mt-3 text-[10px] leading-4 text-slate-600">{humanOwnedBuildReason(option)}</div>
    </div>
  );
}

function BuildAttributeBlock({
  title,
  highlights,
  empty,
  accent = false,
}: {
  title:string;
  highlights:string[];
  empty:string;
  accent?:boolean;
}) {
  return (
    <div>
      <div className={`text-[9px] font-semibold uppercase tracking-wide ${accent ? "text-cyan-500" : "text-slate-600"}`}>{title}</div>
      {highlights.length ? (
        <div className="mt-1.5 flex flex-wrap gap-1.5">
          {highlights.slice(0,8).map((label) => (
            <span
              key={label}
              className={`rounded-full border px-2 py-1 text-[9px] ${
                accent
                  ? "border-cyan-400/15 bg-cyan-400/[0.045] text-cyan-100"
                  : "border-white/7 bg-white/[0.025] text-slate-400"
              }`}
            >
              {label}
            </span>
          ))}
        </div>
      ) : (
        <div className="mt-1 text-[10px] text-slate-700">{empty}</div>
      )}
    </div>
  );
}

function effectContextHighlights(context:any) {
  if (!context || typeof context !== "object") return [];

  const groups = context?.effect_profile?.groups ?? {};
  const out:string[] = [];

  const protection = groups?.protection;
  if (protection && typeof protection === "object" && !Array.isArray(protection)) {
    for (const [element,value] of Object.entries(protection)) {
      const n = Number(value);
      if (Number.isFinite(n)) out.push(`Proteção ${labelElement(element)} ${formatSigned(n, "%")}`);
    }
  }

  const vulnerabilities = Array.isArray(groups?.vulnerabilities) ? groups.vulnerabilities : [];
  for (const effect of vulnerabilities) {
    const value = Number(effect?.value);
    if (Number.isFinite(value)) out.push(`${friendlyEffectKey(effect?.effect_key)} ${formatSigned(value, unitSuffix(effect?.unit))}`);
  }

  for (const groupName of ["magic_skill","skill","offense","leech","magic_shield","movement","special"]) {
    const values = Array.isArray(groups?.[groupName]) ? groups[groupName] : [];
    for (const effect of values) {
      const value = Number(effect?.value);
      const label = friendlyEffectKey(effect?.effect_key);
      if (Number.isFinite(value)) out.push(`${label} ${formatSigned(value, unitSuffix(effect?.unit))}`);
      else if (label) out.push(label);
    }
  }

  const activePerks = Array.isArray(context?.effect_profile?.proficiency?.active_effects)
    ? context.effect_profile.proficiency.active_effects
    : [];
  for (const perk of activePerks) {
    if (perk?.description) out.push(`Perk: ${perk.description}`);
  }

  return [...new Set(out)].filter(Boolean);
}

function hasProtectionHighlight(highlights:string[]) {
  return highlights.some((label) => label.startsWith("Proteção "));
}

function labelElement(value:string) {
  return ({
    physical:"Physical",
    fire:"Fire",
    ice:"Ice",
    earth:"Earth",
    energy:"Energy",
    death:"Death",
    holy:"Holy",
  } as Record<string,string>)[value] ?? slugToName(value);
}

function friendlyEffectKey(value:unknown) {
  const key = String(value ?? "");
  const known:Record<string,string> = {
    magic_level:"Magic Level",
    energy_magic_level:"Energy Magic Level",
    death_magic_level:"Death Magic Level",
    fire_magic_level:"Fire Magic Level",
    ice_magic_level:"Ice Magic Level",
    earth_magic_level:"Earth Magic Level",
    holy_magic_level:"Holy Magic Level",
    critical_chance:"Critical Chance",
    critical_extra_damage:"Critical Extra Damage",
    life_leech:"Life Leech",
    mana_leech:"Mana Leech",
    magic_shield_capacity:"Magic Shield",
    speed:"Speed",
  };
  return known[key] ?? slugToName(key.replaceAll("_","-"));
}

function unitSuffix(unit:unknown) {
  const value = String(unit ?? "").toLowerCase();
  if (value === "percent" || value === "%") return "%";
  if (value === "levels" || value === "level") return "";
  return "";
}

function formatSigned(value:number, suffix = "") {
  return `${value > 0 ? "+" : ""}${formatNumber(value,2)}${suffix}`;
}

function orderedBuildSlots(selection:any) {
  const order = ["neck","head","ring","weapon","body","offhand","legs","feet","ammunition"];
  const entries = Object.entries(selection ?? {});
  return entries.sort(([a],[b]) => {
    const ai = order.indexOf(a);
    const bi = order.indexOf(b);
    return (ai < 0 ? 99 : ai) - (bi < 0 ? 99 : bi);
  });
}

function buildSlotLabel(slot:string) {
  return ({
    neck:"Amuleto",
    head:"Helmet",
    ring:"Ring",
    weapon:"Weapon",
    body:"Armor",
    offhand:"Off-hand",
    legs:"Legs",
    feet:"Boots",
    ammunition:"Ammo",
  } as Record<string,string>)[slot] ?? slot;
}

function sameBuildSelection(a:any, b:any) {
  if (!a || !b || typeof a !== "object" || typeof b !== "object") return false;
  const aEntries = Object.entries(a).sort(([ka],[kb]) => ka.localeCompare(kb));
  const bEntries = Object.entries(b).sort(([ka],[kb]) => ka.localeCompare(kb));
  return JSON.stringify(aEntries) === JSON.stringify(bEntries);
}

function humanOwnedBuildReason(option:any) {
  if (option?.option_type === "main") return "Set Main cadastrado e preservado como baseline.";
  if (option?.dominates_main) return "Esta variação da BP supera o Main nas dimensões em que a comparação é exata.";
  if (option?.exact_comparable) return "Esta variação passou pelo frontier contextual e não ficou dominada pelo Main.";
  return "Esta variação passou pelo filtro contextual, mas não é totalmente comparável ao Main; por isso é mostrada como alternativa, não como upgrade.";
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

function SectionTitle({ title, subtitle }: { title:string; subtitle:string }) { return <div><div className="text-xs uppercase tracking-[.18em] text-cyan-400">Hunt Detail</div><h2 className="mt-1 text-2xl font-bold text-white">{title}</h2><p className="mt-1 text-sm text-slate-500">{subtitle}</p></div>; }
function Panel({ title, children }: { title:string; children:React.ReactNode }) { return <div className="rounded-2xl border border-white/7 bg-slate-950/35 p-4"><div className="mb-4 text-sm font-semibold text-slate-200">{title}</div>{children}</div>; }
function Metric({ label, value }: { label:string; value:string }) { return <div className="flex items-center justify-between gap-4 rounded-xl border border-white/6 bg-white/[0.025] px-3 py-2.5"><span className="text-xs text-slate-500">{label}</span><span className="text-sm font-bold text-slate-200">{value}</span></div>; }
function HeroFact({ label, value }: { label:string; value:string }) {
  return (
    <div className="rounded-xl border border-white/7 bg-black/20 px-3 py-2.5">
      <div className="text-[9px] uppercase tracking-wide text-slate-600">{label}</div>
      <div className="mt-1 truncate text-xs font-bold text-slate-200">{value}</div>
    </div>
  );
}

function CanonicalLevelCard({ label, value }: { label:string; value:unknown }) {
  const clean = value == null || String(value).trim() === "" ? null : String(value);
  return (
    <div className="rounded-2xl border border-white/7 bg-slate-950/35 p-4">
      <div className="text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-600">{label}</div>
      <div className="mt-1 text-xl font-black text-white">{clean ? `Level ${clean}` : "Não publicado"}</div>
      <div className="mt-1 text-[10px] text-slate-600">guidance canônico da fonte</div>
    </div>
  );
}

function elementLabel(value:unknown) {
  return ({
    physical:"Physical",
    fire:"Fire",
    ice:"Ice",
    earth:"Earth",
    energy:"Energy",
    death:"Death",
    holy:"Holy",
  } as Record<string,string>)[String(value)] ?? String(value ?? "—");
}

function HeroMetric({ label, value }: { label:string; value:string }) { return <div className="rounded-xl border border-white/7 bg-slate-950/35 p-3"><div className="text-[10px] uppercase tracking-wide text-slate-500">{label}</div><div className="mt-1 text-xl font-black text-white">{value}</div></div>; }
function Badge({ children }: { children:React.ReactNode }) { return <span className="rounded-full border border-cyan-400/15 bg-cyan-400/8 px-2.5 py-1 text-[10px] font-semibold text-cyan-200">{children}</span>; }
function Muted({ children }: { children:React.ReactNode }) { return <div className="rounded-xl border border-dashed border-white/7 p-4 text-xs text-slate-600">{children}</div>; }
function compact(value:unknown) { if(value == null || value === "") return "—"; const n=Number(value); if(!Number.isFinite(n)) return "—"; const a=Math.abs(n),s=n<0?"-":""; if(a>=1e6)return `${s}${(a/1e6).toFixed(2)}M`; if(a>=1e3)return `${s}${Math.round(a/1e3)}k`; return String(Math.round(n)); }
function labelObjective(v:string){ return ({offense:"Offense",defense:"Defense",sustain:"Sustain",utility:"Utility",balanced:"Balanced"} as Record<string,string>)[v] ?? v; }
function cleanLocation(v:unknown){ if(typeof v!=="string") return ""; return v.replace(/\{\{[^}]+\}\}/g,"").trim(); }
function slugToName(value:string){ return value.split("-").filter(Boolean).map((part)=>part.charAt(0).toUpperCase()+part.slice(1)).join(" "); }
function compactComposition(v:any){ if(!v||typeof v!=="object")return v; return {vocation:v.vocation ?? v.context?.vocation, level:v.level ?? v.context?.level, profile:v.profile ?? v.composition ?? v.methodology}; }
