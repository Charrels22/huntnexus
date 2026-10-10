import { createFileRoute, Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import {
  Activity,
  ArrowRight,
  Coins,
  Compass,
  Flame,
  Gauge,
  ShieldCheck,
  Sparkles,
  Swords,
  TrendingUp,
  Users,
  type LucideIcon,
} from "lucide-react";
import { OfficialAssetSlot } from "@/components/shell/app-shell";
import { CanonicalSprite } from "@/components/shared/canonical-sprite";
import { callHuntNexusApi } from "@/lib/api/huntnexus";

export const Route = createFileRoute("/")({ component: DashboardPage });

const analyzerShortcuts: Array<{ title: string; text: string; icon: LucideIcon }> = [
  { title: "Hunt Analyse", text: "XP, loot, supplies e balance", icon: TrendingUp },
  { title: "Misc", text: "Consumo e dados auxiliares", icon: Gauge },
  { title: "Damage", text: "Dano, charms e recebido", icon: Swords },
  { title: "Party Hunt", text: "Contribuição de cada player", icon: Users },
];



function DashboardPage() {
  const [hunts, setHunts] = useState<any[]>([]);
  const [loadingHunts, setLoadingHunts] = useState(true);

  useEffect(() => {
    let active = true;
    callHuntNexusApi<any>({ action: "featured_hunts", limit: 8 })
      .then((response) => {
        if (!active) return;
        setHunts(Array.isArray(response?.data?.hunts) ? response.data.hunts : []);
      })
      .catch(() => { if (active) setHunts([]); })
      .finally(() => { if (active) setLoadingHunts(false); });
    return () => { active = false; };
  }, []);

  return (
    <div className="mx-auto max-w-[1450px] space-y-6">
      <section className="hn-hero overflow-hidden rounded-3xl border border-white/8 p-5 md:p-7">
        <div className="grid gap-6 xl:grid-cols-[1.3fr_.7fr]">
          <div className="space-y-5">
            <div className="inline-flex items-center gap-2 rounded-full border border-cyan-400/15 bg-cyan-400/8 px-3 py-1 text-xs text-cyan-200">
              <Sparkles className="size-3.5" />
              HuntNexus Optimizer
            </div>
            <div>
              <h1 className="max-w-3xl text-3xl font-black tracking-tight text-white md:text-5xl">
                Descubra onde caçar e o que usar sem transformar tudo em uma planilha.
              </h1>
              <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-400 md:text-base">
                Hunt, set, spells, proficiency e evidência da comunidade em uma experiência feita para jogador.
              </p>
            </div>
            <div className="flex flex-wrap gap-3">
              <Link to="/planner" className="hn-primary-button">
                <Compass className="size-4" /> Encontrar hunt
              </Link>
              <Link to="/session" className="hn-secondary-button">
                <Activity className="size-4" /> Analisar sessão
              </Link>
            </div>
          </div>
          <OfficialAssetSlot label="Arte oficial/canônica da área em destaque" />
        </div>
      </section>

      <section className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        {analyzerShortcuts.map(({ title, text, icon: Icon }) => (
          <Link key={title} to="/session" className="hn-feature-card group">
            <div className="grid size-10 place-items-center rounded-xl bg-cyan-400/10 text-cyan-300 transition group-hover:scale-105">
              <Icon className="size-5" />
            </div>
            <div>
              <div className="font-semibold text-white">{title}</div>
              <div className="mt-1 text-xs text-slate-500">{text}</div>
            </div>
            <ArrowRight className="ml-auto size-4 text-slate-600 transition group-hover:translate-x-1 group-hover:text-cyan-300" />
          </Link>
        ))}
      </section>

      <section>
        <div className="mb-4 flex items-end justify-between gap-3">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Base real</div>
            <h2 className="mt-1 text-2xl font-bold text-white">Hunts mais observadas na base</h2>
          </div>
          <Link to="/planner" className="text-sm text-cyan-300 hover:text-cyan-200">Abrir planner →</Link>
        </div>
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          {loadingHunts && Array.from({ length: 4 }).map((_, index) => (
            <div key={index} className="hn-hunt-card min-h-72 animate-pulse bg-white/[0.02]" />
          ))}
          {!loadingHunts && hunts.map((hunt) => (
            <article key={hunt.hunt_key} className="hn-hunt-card overflow-hidden">
              <div className="grid min-h-28 place-items-center border-b border-white/6 bg-slate-950/55 p-4">
                <CanonicalSprite kind="creature" name={hunt.hero_image_name} size="lg" />
              </div>
              <div className="space-y-4 p-4">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="text-lg font-bold text-white">{hunt.hunt_name}</div>
                    <div className="mt-1 text-xs text-slate-500">{hunt.city || "Tibia"} · observado</div>
                  </div>
                  <span className="rounded-full border border-emerald-400/15 bg-emerald-400/8 px-2 py-1 text-[10px] text-emerald-300">
                    {hunt.session_count} sessões
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <Metric icon={Flame} label="XP/h mediana" value={formatCompact(hunt.median_xp_per_hour)} />
                  <Metric icon={Coins} label="Profit/h mediano" value={formatCompact(hunt.median_balance_per_hour)} />
                </div>
                <div className="flex items-center justify-between gap-2 text-xs text-slate-500">
                  <span>{hunt.solo_sessions || 0} solo · {hunt.party_sessions || 0} party</span>
                  <ShieldCheck className="size-3.5 text-cyan-400" />
                </div>
              </div>
            </article>
          ))}
          {!loadingHunts && hunts.length === 0 && (
            <div className="col-span-full rounded-2xl border border-dashed border-white/8 p-8 text-center text-sm text-slate-600">
              Nenhuma hunt observada disponível no momento.
            </div>
          )}
        </div>
      </section>
    </div>
  );
}

function Metric({ icon: Icon, label, value }: { icon: typeof Flame; label: string; value: string }) {
  return (
    <div className="rounded-xl border border-white/6 bg-white/[0.025] p-3">
      <div className="flex items-center gap-1.5 text-[10px] uppercase tracking-wide text-slate-500">
        <Icon className="size-3" /> {label}
      </div>
      <div className="mt-1 text-sm font-bold text-slate-100">{value}</div>
    </div>
  );
}


function formatCompact(value: unknown) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "—";
  const abs = Math.abs(n);
  const sign = n < 0 ? "-" : "";
  if (abs >= 1_000_000) return `${sign}${(abs / 1_000_000).toFixed(2)}M`;
  if (abs >= 1_000) return `${sign}${Math.round(abs / 1_000)}k`;
  return String(Math.round(n));
}
