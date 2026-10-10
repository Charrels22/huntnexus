import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Activity, BarChart3, Coins, HeartPulse, Swords, Users } from "lucide-react";

export const Route = createFileRoute("/session")({ component: SessionAnalyzerPage });

const tabs = [
  { key: "analyse", label: "Hunt Analyse", icon: BarChart3 },
  { key: "misc", label: "Misc", icon: Activity },
  { key: "damage", label: "Damage", icon: Swords },
  { key: "party", label: "Party Hunt", icon: Users },
];

function SessionAnalyzerPage() {
  const [tab, setTab] = useState("analyse");
  return (
    <div className="mx-auto max-w-[1450px] space-y-6">
      <section className="rounded-3xl border border-white/8 bg-slate-950/55 p-5 md:p-6">
        <div className="text-xs uppercase tracking-[0.18em] text-cyan-400">Session Analyzer</div>
        <h1 className="mt-1 text-3xl font-black text-white">Sua hunt, desmontada em dados úteis.</h1>
        <p className="mt-2 max-w-2xl text-sm text-slate-400">
          Mesma ideia do Hunt Analyzer: dados reais da sessão do player, apresentados no layout HuntNexus.
        </p>
        <div className="mt-5 flex flex-wrap gap-2">
          <button className="hn-primary-button">Importar Hunt Analyzer</button>
          <button className="hn-secondary-button">Abrir sessão salva</button>
        </div>
      </section>

      <div className="grid gap-3 md:grid-cols-4">
        {tabs.map(({ key, label, icon: Icon }) => (
          <button key={key} onClick={() => setTab(key)} className={`hn-analyzer-tab ${tab === key ? "hn-analyzer-tab-active" : ""}`}>
            <Icon className="size-5" /><span>{label}</span>
          </button>
        ))}
      </div>

      <section className="rounded-3xl border border-white/8 bg-white/[0.025] p-5 md:p-6">
        {tab === "analyse" && <Analyse />}
        {tab === "misc" && <Empty title="Misc" text="Consumíveis, supplies, metadata e demais campos reais da sessão entram aqui." />}
        {tab === "damage" && <Empty title="Damage" text="Damage dealt/received, charms, elementos e fontes de dano serão exibidos em gráficos e breakdowns." />}
        {tab === "party" && <Empty title="Party Hunt" text="Participação por player, dano, healing e composição da party serão mostrados quando houver dados." />}
      </section>
    </div>
  );
}

function Analyse() {
  return (
    <div className="space-y-5">
      <div>
        <div className="text-xs uppercase tracking-[0.16em] text-cyan-400">Hunt Analyse</div>
        <h2 className="mt-1 text-2xl font-bold text-white">Resumo da sessão</h2>
      </div>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Kpi icon={BarChart3} label="XP/h" value="—" />
        <Kpi icon={Coins} label="Profit/h" value="—" />
        <Kpi icon={HeartPulse} label="Supplies" value="—" />
        <Kpi icon={Swords} label="Kills" value="—" />
      </div>
      <div className="hn-chart-placeholder">
        <div className="absolute inset-x-6 bottom-6 flex h-28 items-end gap-2">
          {[30,55,42,75,63,86,71,92,78,66,88,74].map((h,i) => <div key={i} className="flex-1 rounded-t bg-cyan-400/20" style={{height:`${h}%`}} />)}
        </div>
        <div className="relative z-10 text-sm font-medium text-slate-300">Timeline da sessão</div>
      </div>
    </div>
  );
}
function Empty({ title, text }: { title: string; text: string }) {
  return <div className="grid min-h-72 place-items-center text-center"><div><div className="text-xl font-bold text-white">{title}</div><p className="mt-2 max-w-md text-sm text-slate-500">{text}</p></div></div>;
}
function Kpi({ icon: Icon, label, value }: any) {
  return <div className="rounded-2xl border border-white/6 bg-slate-950/50 p-4"><Icon className="size-4 text-cyan-300" /><div className="mt-4 text-xs text-slate-500">{label}</div><div className="mt-1 text-2xl font-black text-white">{value}</div></div>;
}
