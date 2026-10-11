import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Database, Loader2, ShieldCheck, Users } from "lucide-react";
import { CanonicalSprite } from "@/components/shared/canonical-sprite";
import { callHuntNexusApi, formatNumber } from "@/lib/api/huntnexus";

export const Route = createFileRoute("/community")({ component: CommunityHunts });

function CommunityHunts() {
  const [sessions,setSessions]=useState<any[]>([]);
  const [selectedId,setSelectedId]=useState<string|null>(null);
  const [detail,setDetail]=useState<any>(null);
  const [loading,setLoading]=useState(true);
  const [loadingDetail,setLoadingDetail]=useState(false);

  useEffect(()=>{
    let active=true;
    setLoading(true);
    callHuntNexusApi<any>({action:"session_list",limit:30,hunt_key:null})
      .then((response)=>{
        if(!active)return;
        const rows=Array.isArray(response?.data?.sessions)?response.data.sessions:[];
        setSessions(rows);
        setSelectedId((current)=>current&&rows.some((row:any)=>row.session_id===current)?current:rows[0]?.session_id??null);
      })
      .catch(()=>{if(active)setSessions([]);})
      .finally(()=>{if(active)setLoading(false);});
    return()=>{active=false;};
  },[]);

  useEffect(()=>{
    if(!selectedId){setDetail(null);return;}
    let active=true;
    setLoadingDetail(true);
    callHuntNexusApi<any>({action:"session_detail",session_id:selectedId})
      .then((response)=>{if(active)setDetail(response?.data??null);})
      .catch(()=>{if(active)setDetail(null);})
      .finally(()=>{if(active)setLoadingDetail(false);});
    return()=>{active=false;};
  },[selectedId]);

  const session=detail?.session;
  const creatures=Array.isArray(detail?.misc?.creatures)?detail.misc.creatures:[];
  const equipment=Array.isArray(detail?.misc?.equipment)?detail.misc.equipment:[];
  const incoming=Array.isArray(detail?.damage?.incoming_by_element)?detail.damage.incoming_by_element:[];
  const players=Array.isArray(detail?.party_hunt?.players)?detail.party_hunt.players:[];

  return <div className="mx-auto max-w-[1500px] space-y-6">
    <section className="hn-hero rounded-3xl border border-white/8 p-5 md:p-7">
      <div className="flex flex-col justify-between gap-5 xl:flex-row xl:items-end">
        <div>
          <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Community Hunts</div>
          <h1 className="mt-2 text-3xl font-black tracking-tight text-white md:text-4xl">Sessões observadas, não fatos canônicos.</h1>
          <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-400">A comunidade fornece evidência de XP, profit, dano, equipamentos e contexto real de caça. Esses dados ajudam o ranking, mas continuam separados da identidade canônica de monstros, itens e mecânicas.</p>
        </div>
        <div className="rounded-xl border border-amber-400/12 bg-amber-400/[0.035] px-4 py-3 text-xs leading-5 text-amber-100/65">
          Evidência observada · Tier C
        </div>
      </div>
    </section>

    <div className="grid gap-5 xl:grid-cols-[.72fr_1.28fr]">
      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-4">
        <div className="flex items-center justify-between"><div><div className="font-bold text-white">Sessões</div><div className="mt-1 text-xs text-slate-600">{sessions.length} recentes</div></div>{loading&&<Loader2 className="size-4 animate-spin text-cyan-300"/>}</div>
        <div className="mt-4 max-h-[760px] space-y-2 overflow-y-auto pr-1">
          {sessions.map((row:any)=><button key={row.session_id} type="button" onClick={()=>setSelectedId(row.session_id)} className={"w-full rounded-xl border p-3 text-left transition "+(selectedId===row.session_id?"border-cyan-400/25 bg-cyan-400/[0.07]":"border-white/6 bg-white/[0.02]")}>
            <div className="truncate text-sm font-bold text-slate-200">{decodeHtml(row.hunt_name_raw)||row.hunt_key||"Hunt não resolvida"}</div>
            <div className="mt-2 grid grid-cols-3 gap-2 text-[10px] text-slate-600"><span>{compact(row.xp_per_hour)} XP/h</span><span>{row.party_size||1} player(s)</span><span>{row.duration_seconds?Math.round(row.duration_seconds/60)+" min":"—"}</span></div>
          </button>)}
        </div>
      </section>

      <section className="min-w-0 rounded-3xl border border-white/8 bg-slate-950/45 p-4 md:p-6">
        {loadingDetail?<div className="grid min-h-[560px] place-items-center"><Loader2 className="size-6 animate-spin text-cyan-300"/></div>:session?<div className="space-y-6">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <div className="text-xs uppercase tracking-[.16em] text-cyan-400">{session.hunt_resolution_status||"community observation"}</div>
              <h2 className="mt-1 text-2xl font-black text-white">{decodeHtml(session.hunt_name_raw)||session.hunt_key||"Sessão observada"}</h2>
              <div className="mt-2 text-[10px] text-slate-600">Observada em {formatDate(session.observed_at)}</div>
            </div>
            <div className="flex items-center gap-2 rounded-full border border-white/7 px-3 py-1.5 text-[10px] text-slate-500"><ShieldCheck className="size-3.5 text-cyan-300"/>raw payload não exposto</div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <Kpi label="XP/h" value={compact(session.xp_per_hour)}/>
            <Kpi label="Balance" value={compact(session.balance_value)}/>
            <Kpi label="Damage" value={compact(session.total_damage)}/>
            <Kpi label="Healing" value={compact(session.total_healing)}/>
          </div>

          <div className="grid gap-4 lg:grid-cols-2">
            <Panel title="Criaturas" icon={Database}>
              <div className="space-y-2">{creatures.map((row:any)=><div key={(row.monster_key||row.monster_name_raw)+String(row.kills)} className="flex items-center gap-3 rounded-lg border border-white/6 bg-black/15 p-2"><CanonicalSprite kind="creature" name={row.monster_name_raw} size="sm"/><div className="min-w-0 flex-1"><div className="truncate text-xs font-semibold text-slate-300">{row.monster_name_raw}</div><div className="mt-1 text-[10px] text-slate-600">{row.kills??0} kills · {row.resolution_status||"raw"}</div></div></div>)}</div>
            </Panel>
            <Panel title="Dano recebido" icon={ShieldCheck}>
              <div className="space-y-2">{incoming.map((row:any)=><div key={row.element} className="flex items-center justify-between rounded-lg border border-white/6 bg-black/15 px-3 py-2 text-xs"><span className="text-slate-500">{elementLabel(row.element)}</span><span className="font-semibold text-slate-300">{compact(row.damage)} · {row.share_percent==null?"—":formatNumber(Number(row.share_percent),1)+"%"}</span></div>)}</div>
            </Panel>
          </div>

          {equipment.length>0&&<div>
            <Title title="Equipamento observado"/>
            <div className="mt-3 flex flex-wrap gap-2">{equipment.map((item:any)=><div key={item.item_key+item.slot_key} className="rounded-xl border border-white/7 bg-white/[0.02] p-2 text-center"><CanonicalSprite kind="item" name={item.item_name_raw} size="sm"/><div className="mt-1 max-w-[80px] truncate text-[9px] text-slate-600">{item.slot_key}</div></div>)}</div>
          </div>}

          {players.length>0&&<div>
            <Title title="Party observada"/>
            <div className="mt-3 grid gap-2 md:grid-cols-2">{players.map((p:any)=><div key={p.player_id} className="rounded-xl border border-white/6 bg-white/[0.02] p-3"><div className="flex items-center gap-2"><Users className="size-4 text-cyan-300"/><div className="text-xs font-semibold text-slate-200">{p.vocation||"Player"} · Lv {p.level||"—"}</div></div><div className="mt-2 text-[10px] text-slate-600">Damage {compact(p.damage)} · Healing {compact(p.healing)}</div></div>)}</div>
          </div>}

          <div className="rounded-xl border border-white/7 bg-white/[0.02] p-3 text-[10px] leading-5 text-slate-600">Esta sessão é evidência observacional. Ela pode informar ranking e contexto, mas não sobrescreve fatos canônicos nem prova causalidade de build, vocação ou equipamento.</div>
        </div>:<div className="grid min-h-[560px] place-items-center text-sm text-slate-600">Selecione uma sessão.</div>}
      </section>
    </div>
  </div>;
}

function Panel({title,icon:Icon,children}:{title:string;icon:any;children:React.ReactNode}){return <div className="rounded-2xl border border-white/7 bg-white/[0.02] p-4"><div className="mb-3 flex items-center gap-2 text-xs font-semibold uppercase tracking-[.13em] text-slate-400"><Icon className="size-3.5 text-cyan-300"/>{title}</div>{children}</div>;}
function Kpi({label,value}:{label:string;value:string}){return <div className="rounded-xl border border-white/7 bg-white/[0.02] p-3"><div className="text-[10px] text-slate-600">{label}</div><div className="mt-1 text-xl font-black text-white">{value}</div></div>;}
function Title({title}:{title:string}){return <div className="text-sm font-bold text-white">{title}</div>;}
function compact(value:unknown){const n=Number(value);if(!Number.isFinite(n))return "—";if(Math.abs(n)>=1_000_000)return (n/1_000_000).toFixed(2)+"M";if(Math.abs(n)>=1_000)return Math.round(n/1_000)+"k";return String(Math.round(n));}
function decodeHtml(value:unknown){if(typeof value!=="string")return "";return value.replaceAll("&#39;","'").replaceAll("&amp;","&").replaceAll("&quot;","\"");}
function elementLabel(value:string){return ({physical:"Physical",fire:"Fire",ice:"Ice",earth:"Earth",energy:"Energy",death:"Death",holy:"Holy",agony:"Agony"} as Record<string,string>)[value]??value;}
function formatDate(value:unknown){if(typeof value!=="string")return "—";const d=new Date(value);return Number.isNaN(d.getTime())?"—":d.toLocaleString("pt-BR");}
