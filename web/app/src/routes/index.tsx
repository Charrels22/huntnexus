import { createFileRoute, Link } from "@tanstack/react-router";
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
} from "lucide-react";
import { OfficialAssetSlot } from "@/components/shell/app-shell";

export const Route = createFileRoute("/")({ component: DashboardPage });

const analyzerShortcuts = [
  { title: "Hunt Analyse", text: "XP, loot, supplies e balance", icon: TrendingUp },
  { title: "Misc", text: "Consumo e dados auxiliares", icon: Gauge },
  { title: "Damage", text: "Dano, charms e recebido", icon: Swords },
  { title: "Party Hunt", text: "Contribuição de cada player", icon: Users },
];

const hunts = [
  { key: "cobra-bastion", name: "Cobra Bastion", vocation: "EK", xp: "—", profit: "—", confidence: "Dados reais", risk: "Fire / Physical" },
  { key: "iksupan-last-stand", name: "Iksupan Last Stand", vocation: "RP", xp: "—", profit: "—", confidence: "Dados reais", risk: "Mixed" },
  { key: "nimmersatts-breeding-ground", name: "Nimmersatt's Breeding Ground", vocation: "ED", xp: "—", profit: "—", confidence: "Dados reais", risk: "Mixed" },
  { key: "grounds-of-undeath", name: "Grounds of Undeath", vocation: "EM", xp: "13.1M", profit: "2.64M", confidence: "2 sessões", risk: "Physical / Fire / Death" },
];

function DashboardPage() {
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
        {[
          ["Hunt Analyse", "XP, loot, supplies e balance", TrendingUp],
          ["Misc", "Consumo e dados auxiliares", Gauge],
          ["Damage", "Dano, charms e recebido", Swords],
          ["Party Hunt", "Contribuição de cada player", Users],
        ].map(([title, text, Icon]) => (
          <Link key={String(title)} to="/session" className="hn-feature-card group">
            <div className="grid size-10 place-items-center rounded-xl bg-cyan-400/10 text-cyan-300 transition group-hover:scale-105">
              <Icon className="size-5" />
            </div>
            <div>
              <div className="font-semibold text-white">{title as string}</div>
              <div className="mt-1 text-xs text-slate-500">{text as string}</div>
            </div>
            <ArrowRight className="ml-auto size-4 text-slate-600 transition group-hover:translate-x-1 group-hover:text-cyan-300" />
          </Link>
        ))}
      </section>

      <section>
        <div className="mb-4 flex items-end justify-between gap-3">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Base real</div>
            <h2 className="mt-1 text-2xl font-bold text-white">Hunts que já conseguimos explicar</h2>
          </div>
          <Link to="/planner" className="text-sm text-cyan-300 hover:text-cyan-200">Abrir planner →</Link>
        </div>
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          {hunts.map((hunt) => (
            <article key={hunt.key} className="hn-hunt-card">
              <OfficialAssetSlot label="Imagem oficial da hunt" compact />
              <div className="space-y-4 p-4">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="text-lg font-bold text-white">{hunt.name}</div>
                    <div className="mt-1 text-xs text-slate-500">{hunt.vocation} · regressão validada</div>
                  </div>
                  <span className="rounded-full border border-emerald-400/15 bg-emerald-400/8 px-2 py-1 text-[10px] text-emerald-300">
                    {hunt.confidence}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <Metric icon={Flame} label="XP/h" value={hunt.xp} />
                  <Metric icon={Coins} label="Profit/h" value={hunt.profit} />
                </div>
                <div className="flex items-center gap-2 text-xs text-slate-400">
                  <ShieldCheck className="size-3.5 text-cyan-400" /> {hunt.risk}
                </div>
              </div>
            </article>
          ))}
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
