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
import { CanonicalTibiaMap } from "@/components/shared/tibia-map";
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
  const [loadingPersonalReview, setLoadingPersonalReview] = useState(false);

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
    if (tab !== "setup") return;

    const clientId = getOrCreateClientId();
    if (!clientId) return;

    let active = true;
    setLoadingPersonalReview(true);

    callHuntNexusApi<any>({
      action: "player_profile_get",
      client_id: clientId,
    })
      .then((profileResponse) => {
        if (!active) return null;
        const proficiencySelections = profileResponse?.data?.profile?.proficiency_selections ?? {};

        return callHuntNexusApi<any>({
          action: "player_inventory_hunt_review",
          client_id: clientId,
          hunt_key: huntKey,
          vocation: search.vocation,
          level: search.level,
          proficiency_selections: proficiencySelections,
          frontier_limit: 12,
        });
      })
      .then((reviewResponse) => {
        if (!active || !reviewResponse) return;
        setPersonalReview(reviewResponse?.data ?? null);
      })
      .catch(() => {
        if (active) setPersonalReview(null);
      })
      .finally(() => {
        if (active) setLoadingPersonalReview(false);
      });

    return () => {
      active = false;
    };
  }, [tab, huntKey, search.vocation, search.level]);

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
  const setSummary = data.set_selection?.summary ?? {};

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
              <HeroMetric label="Sets co-vencedores" value={String(setSummary.co_winners ?? 0)} />
            </div>
          </div>
          <div className="relative grid min-h-64 place-items-center overflow-hidden border-l border-white/7 bg-slate-950/55 p-8">
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(34,211,238,.10),transparent_55%)]" />
            <div className="relative z-10">
              {media.hero_image_name ? (
                <div className="flex justify-center">
                  <CanonicalSprite kind="creature" name={media.hero_image_name} size="lg" className="scale-125" />
                </div>
              ) : (
                <CanonicalSpriteGroup names={monsters.slice(0,4).map((m:any) => m.name)} />
              )}
              <div className="mt-6 text-center text-[10px] uppercase tracking-[0.18em] text-slate-600">
                sprites canônicos da hunt
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
        {tab === "setup" && <Setup selection={data.set_selection} personalReview={personalReview} loadingPersonalReview={loadingPersonalReview} />}
        {tab === "spells" && <Spells spells={data.spells} composition={data.vocation_composition} />}
        {tab === "imbuements" && <Imbuements data={data.imbuements} />}
        {tab === "community" && <Community observed={data.observed} />}
      </section>
    </div>
  );
}

function Overview({ data }: { data:any }) {
  const factualElements = Array.isArray(data.factual?.elements) ? data.factual.elements : [];
  const perf = data.observed?.performance ?? {};
  return (
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
                <span className="text-sm font-black text-cyan-200">{formatNumber(Number(e.avg_modifier_percent || 0),1)}%</span>
              </div>
            ))}
        </div>
      </Panel>
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
  const max = Math.max(1, ...elements.map((e:any) => Number(e.damage_share || 0)));
  return (
    <div>
      <SectionTitle title="Dano recebido" subtitle="Observação real por vocação, sem substituir fatos canônicos." />
      <div className="mt-5 grid gap-5 xl:grid-cols-[1.1fr_.9fr]">
        <Panel title="Distribuição por elemento">
          <div className="space-y-4">
            {elements.map((e:any) => (
              <div key={e.element}>
                <div className="mb-1.5 flex items-center justify-between text-xs"><span className="capitalize text-slate-300">{e.element}</span><span className="text-slate-500">{formatNumber(Number(e.damage_share||0)*100,1)}%</span></div>
                <div className="h-2 overflow-hidden rounded-full bg-white/5"><div className="h-full rounded-full bg-cyan-400/55" style={{width:`${Math.max(3,Number(e.damage_share||0)/max*100)}%`}} /></div>
              </div>
            ))}
            {!elements.length && <Muted>Sem dano recebido observado para esta combinação.</Muted>}
          </div>
        </Panel>
        <Panel title="Picos observados">
          <div className="space-y-2">
            {elements.map((e:any) => <Metric key={e.element} label={`${e.element} max DPS mediano`} value={formatNumber(Number(e.median_max_dps || 0))} />)}
          </div>
        </Panel>
      </div>
    </div>
  );
}

function Setup({ selection, personalReview, loadingPersonalReview }: { selection:any; personalReview:any; loadingPersonalReview:boolean }) {
  const sets = Array.isArray(selection?.selected_sets) ? selection.selected_sets : [];
  const mainSet = Array.isArray(personalReview?.baseline?.main_set) ? personalReview.baseline.main_set : [];
  const ownedAlternatives = Array.isArray(personalReview?.owned_alternatives) ? personalReview.owned_alternatives : [];
  const frontierCandidates = Array.isArray(personalReview?.frontier_candidates) ? personalReview.frontier_candidates : [];
  const backpackCandidates = frontierCandidates.filter((item:any) => item.ownership === "backpack");
  const externalCandidates = frontierCandidates.filter((item:any) => item.ownership === "external");

  return (
    <div>
      <SectionTitle title="Setup da hunt" subtitle="Seu Set Main permanece como baseline; BP e itens externos aparecem separados." />

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
        <SectionTitle title="Frontier universal" subtitle={`${selection?.summary?.co_winners ?? sets.length} co-vencedores preservados no catálogo completo`} />
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
        {!sets.length && <Muted>Nenhum set selecionável para esta configuração.</Muted>}
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

function SectionTitle({ title, subtitle }: { title:string; subtitle:string }) { return <div><div className="text-xs uppercase tracking-[.18em] text-cyan-400">Hunt Detail</div><h2 className="mt-1 text-2xl font-bold text-white">{title}</h2><p className="mt-1 text-sm text-slate-500">{subtitle}</p></div>; }
function Panel({ title, children }: { title:string; children:React.ReactNode }) { return <div className="rounded-2xl border border-white/7 bg-slate-950/35 p-4"><div className="mb-4 text-sm font-semibold text-slate-200">{title}</div>{children}</div>; }
function Metric({ label, value }: { label:string; value:string }) { return <div className="flex items-center justify-between gap-4 rounded-xl border border-white/6 bg-white/[0.025] px-3 py-2.5"><span className="text-xs text-slate-500">{label}</span><span className="text-sm font-bold text-slate-200">{value}</span></div>; }
function HeroMetric({ label, value }: { label:string; value:string }) { return <div className="rounded-xl border border-white/7 bg-slate-950/35 p-3"><div className="text-[10px] uppercase tracking-wide text-slate-500">{label}</div><div className="mt-1 text-xl font-black text-white">{value}</div></div>; }
function Badge({ children }: { children:React.ReactNode }) { return <span className="rounded-full border border-cyan-400/15 bg-cyan-400/8 px-2.5 py-1 text-[10px] font-semibold text-cyan-200">{children}</span>; }
function Muted({ children }: { children:React.ReactNode }) { return <div className="rounded-xl border border-dashed border-white/7 p-4 text-xs text-slate-600">{children}</div>; }
function compact(value:unknown) { const n=Number(value); if(!Number.isFinite(n)) return "—"; const a=Math.abs(n),s=n<0?"-":""; if(a>=1e6)return `${s}${(a/1e6).toFixed(2)}M`; if(a>=1e3)return `${s}${Math.round(a/1e3)}k`; return String(Math.round(n)); }
function labelObjective(v:string){ return ({offense:"Offense",defense:"Defense",sustain:"Sustain",utility:"Utility",balanced:"Balanced"} as Record<string,string>)[v] ?? v; }
function cleanLocation(v:unknown){ if(typeof v!=="string") return ""; return v.replace(/\{\{[^}]+\}\}/g,"").trim(); }
function slugToName(value:string){ return value.split("-").filter(Boolean).map((part)=>part.charAt(0).toUpperCase()+part.slice(1)).join(" "); }
function compactComposition(v:any){ if(!v||typeof v!=="object")return v; return {vocation:v.vocation ?? v.context?.vocation, level:v.level ?? v.context?.level, profile:v.profile ?? v.composition ?? v.methodology}; }
