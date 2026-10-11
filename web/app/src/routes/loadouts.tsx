import { createFileRoute, Link } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { Loader2, Search, Shield, Sparkles, Swords } from "lucide-react";
import { CanonicalSprite } from "@/components/shared/canonical-sprite";
import { callHuntNexusApi, formatNumber } from "@/lib/api/huntnexus";
import { getOrCreateClientId } from "@/lib/client-id";

export const Route = createFileRoute("/loadouts")({ component: LoadoutExplorer });

function LoadoutExplorer() {
  const [vocation,setVocation]=useState("EK");
  const [level,setLevel]=useState("700");
  const [objective,setObjective]=useState("balanced");
  const [query,setQuery]=useState("");
  const [hunts,setHunts]=useState<any[]>([]);
  const [hunt,setHunt]=useState<any>(null);
  const [profile,setProfile]=useState<any>(null);
  const [preview,setPreview]=useState<any>(null);
  const [loading,setLoading]=useState(false);
  const [searching,setSearching]=useState(false);

  useEffect(()=>{
    const clientId=getOrCreateClientId();
    if(!clientId) return;
    callHuntNexusApi<any>({action:"player_profile_get",client_id:clientId})
      .then((response)=>{
        const p=response?.data?.profile;
        if(!p) return;
        setProfile(p);
        if(["EK","RP","ED","MS","EM"].includes(p.vocation)) setVocation(p.vocation);
        if(p.level) setLevel(String(p.level));
      })
      .catch(()=>undefined);
  },[]);

  useEffect(()=>{
    let active=true;
    const timer=window.setTimeout(()=>{
      setSearching(true);
      callHuntNexusApi<any>({action:"search_hunts",query:query.trim(),limit:20})
        .then((response)=>{
          if(!active) return;
          const rows=Array.isArray(response?.data) ? response.data : response?.data?.hunts ?? [];
          setHunts(Array.isArray(rows)?rows:[]);
          setHunt((current:any)=>current && rows.some((row:any)=>row.hunt_key===current.hunt_key) ? current : rows[0] ?? null);
        })
        .catch(()=>{if(active)setHunts([]);})
        .finally(()=>{if(active)setSearching(false);});
    },query.trim()?220:0);
    return()=>{active=false;window.clearTimeout(timer);};
  },[query]);

  const characterProfile=useMemo(()=>{
    const stats=profile?.manual_stats??{};
    const family=stats.weapon_family;
    const base=family==="sword"?stats.sword:family==="axe"?stats.axe:family==="club"?stats.club:(family==="bow"||family==="crossbow")?stats.distance:family==="fist"?stats.fist:undefined;
    return Object.fromEntries(Object.entries({
      weapon_family:family,
      effective_weapon_skill:validFinal(base,stats.effective_weapon_skill),
      effective_magic_level:validFinal(stats.magic_level,stats.effective_magic_level),
      effective_shielding:validFinal(stats.shielding,stats.effective_shielding),
      effective_distance_skill:validFinal(stats.distance,stats.effective_distance_skill),
      effective_fist_skill:validFinal(stats.fist,stats.effective_fist_skill),
    }).filter(([,value])=>value!==undefined&&value!==null&&value!==""));
  },[profile]);

  async function analyze(){
    if(!hunt?.hunt_key||!Number(level)) return;
    setLoading(true);
    try{
      const response=await callHuntNexusApi<any>({
        action:"loadout_preview",
        hunt_key:hunt.hunt_key,
        vocation,
        level:Number(level),
        objective,
        per_dimension:2,
        character_profile:characterProfile,
      });
      setPreview(response?.data??null);
    }finally{setLoading(false);}
  }

  const slots=preview?.selected_slots??{};
  const imbuements=preview?.imbuement_preview?.fixed_slots??{};

  return <div className="mx-auto max-w-[1500px] space-y-6">
    <section className="hn-hero rounded-3xl border border-white/8 p-5 md:p-7">
      <div className="grid gap-5 xl:grid-cols-[1fr_auto] xl:items-end">
        <div>
          <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Loadout Explorer</div>
          <h1 className="mt-2 text-3xl font-black tracking-tight text-white md:text-4xl">Explore o catálogo sem confundir preview com seu set.</h1>
          <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-400">Esta tela explora candidatos universais e Imbuements compatíveis. Seu Set Main e sua BP continuam sendo tratados separadamente no Profile e no Setup da hunt.</p>
        </div>
        <div className="grid grid-cols-3 gap-2">
          <select className="hn-control" value={vocation} onChange={(e)=>setVocation(e.target.value)}>
            <option value="EK">EK</option><option value="RP">RP</option><option value="ED">ED</option><option value="MS">MS</option><option value="EM">EM</option>
          </select>
          <input className="hn-control w-24" type="number" min="1" value={level} onChange={(e)=>setLevel(e.target.value)} />
          <select className="hn-control" value={objective} onChange={(e)=>setObjective(e.target.value)}>
            <option value="balanced">Balanced</option><option value="offense">Offense</option><option value="defense">Defense</option><option value="sustain">Sustain</option><option value="utility">Utility</option>
          </select>
        </div>
      </div>
    </section>

    <div className="grid gap-5 xl:grid-cols-[.65fr_1.35fr]">
      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-500"/>
          <input className="hn-control pl-10" value={query} onChange={(e)=>setQuery(e.target.value)} placeholder="Buscar hunt..."/>
          {searching&&<Loader2 className="absolute right-3 top-1/2 size-4 -translate-y-1/2 animate-spin text-cyan-300"/>}
        </div>
        <div className="mt-3 max-h-[600px] space-y-2 overflow-y-auto">
          {hunts.map((row:any)=><button key={row.hunt_key} type="button" onClick={()=>setHunt(row)} className={"w-full rounded-xl border p-3 text-left transition "+(hunt?.hunt_key===row.hunt_key?"border-cyan-400/25 bg-cyan-400/[0.07]":"border-white/6 bg-white/[0.02]")}>
            <div className="text-sm font-semibold text-slate-200">{row.name||row.hunt_name}</div>
            <div className="mt-1 text-[10px] text-slate-600">{row.city||"—"} · {row.observed_sessions??0} sessões observadas</div>
          </button>)}
        </div>
        <button type="button" disabled={!hunt||loading} onClick={()=>void analyze()} className="hn-primary-button mt-4 w-full justify-center">
          {loading?<Loader2 className="size-4 animate-spin"/>:<Sparkles className="size-4"/>}Analisar loadout
        </button>
      </section>

      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-4 md:p-6">
        {!preview?<div className="grid min-h-[520px] place-items-center text-center"><div><Swords className="mx-auto size-8 text-slate-700"/><div className="mt-3 text-sm font-semibold text-slate-400">Selecione uma hunt e analise o catálogo.</div></div></div>:
        <div className="space-y-6">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div><div className="text-xs uppercase tracking-[.16em] text-cyan-400">{hunt?.name||hunt?.hunt_name}</div><h2 className="mt-1 text-2xl font-black text-white">Preview de loadout</h2></div>
            <span className="rounded-full border border-amber-400/15 bg-amber-400/[0.04] px-3 py-1.5 text-[10px] text-amber-200">Não é set final</span>
          </div>

          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {Object.entries(slots).map(([slot,item]:any)=><div key={slot} className="flex items-center gap-3 rounded-xl border border-white/7 bg-white/[0.02] p-3">
              <CanonicalSprite kind="item" name={item?.name} size="sm"/>
              <div className="min-w-0"><div className="text-[9px] uppercase tracking-wide text-slate-600">{slot}</div><div className="mt-1 truncate text-xs font-bold text-slate-200">{item?.name||"—"}</div><div className="mt-1 text-[10px] text-slate-600">imbue slots {item?.imbue_slots??0}</div></div>
            </div>)}
          </div>

          {preview?.hand_options&&<div>
            <Title title="Configurações de mão"/>
            <div className="mt-3 grid gap-3 md:grid-cols-2">
              <HandCard title="1 mão + off-hand" data={preview.hand_options.one_handed}/>
              <HandCard title="2 mãos" data={preview.hand_options.two_handed}/>
            </div>
          </div>}

          <div>
            <Title title="Imbuements compatíveis por peça"/>
            <div className="mt-3 grid gap-3 md:grid-cols-2">
              {Object.entries(imbuements).map(([slot,row]:any)=><div key={slot} className="rounded-xl border border-white/6 bg-white/[0.02] p-3">
                <div className="text-xs font-semibold text-slate-200">{slot} · {row?.name}</div>
                <div className="mt-2 flex flex-wrap gap-1.5">
                  {[...(row?.protection_candidates??[]),...(row?.skill_candidates??[]),...(row?.core_offense_sustain_candidates??[])].slice(0,8).map((imb:any)=><span key={imb.imbuement_key} className="rounded-full border border-white/7 px-2 py-1 text-[9px] text-slate-500">{imb.name}</span>)}
                </div>
              </div>)}
            </div>
          </div>

          <div className="rounded-xl border border-white/7 bg-white/[0.02] p-3 text-[10px] leading-5 text-slate-600">
            {preview?.methodology?.final_damage_formula_applied?"Fórmula final aplicada.":"Sem fórmula final de DPS inventada."} {preview?.methodology?.combined_numeric_score?"Score combinado aplicado.":"Sem score numérico cruzando métricas incompatíveis."}
          </div>

          {hunt?.hunt_key&&<Link to="/hunts/$huntKey" params={{huntKey:hunt.hunt_key}} search={{vocation,level:Number(level),setObjective:objective}} className="hn-secondary-button inline-flex">Abrir Setup completo da hunt</Link>}
        </div>}
      </section>
    </div>
  </div>;
}

function HandCard({title,data}:{title:string;data:any}){
  const item=data?.item??data?.main_hand;
  return <div className="rounded-xl border border-white/7 bg-white/[0.02] p-3"><div className="text-xs font-semibold text-slate-300">{title}</div>{data?.available?<div className="mt-3 flex items-center gap-3"><CanonicalSprite kind="item" name={item?.name} size="sm"/><div><div className="text-xs font-bold text-white">{item?.name||"—"}</div><div className="mt-1 text-[10px] text-slate-600">{data?.off_hand?.name?"+ "+data.off_hand.name:""} · proxy {formatNumber(Number(item?.effective_attack_proxy??0),2)}</div></div></div>:<div className="mt-2 text-xs text-slate-600">Indisponível</div>}</div>;
}
function Title({title}:{title:string}){return <div className="text-sm font-bold text-white">{title}</div>;}
function validFinal(baseValue:unknown,finalValue:unknown){const base=Number(baseValue),fin=Number(finalValue);const hb=baseValue!==undefined&&baseValue!==null&&baseValue!==""&&Number.isFinite(base);const hf=finalValue!==undefined&&finalValue!==null&&finalValue!==""&&Number.isFinite(fin);if(!hf)return hb?base:undefined;if(!hb)return fin;return fin>=base?fin:base;}
