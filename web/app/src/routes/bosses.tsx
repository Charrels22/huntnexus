import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { AlertTriangle, Loader2, Search, Shield, Sparkles, Swords } from "lucide-react";
import { CanonicalSprite } from "@/components/shared/canonical-sprite";
import { callHuntNexusApi, formatNumber } from "@/lib/api/huntnexus";
import { getOrCreateClientId } from "@/lib/client-id";

export const Route = createFileRoute("/bosses")({ component: BossExplorer });

function BossExplorer() {
  const [query, setQuery] = useState("");
  const [bosses, setBosses] = useState<any[]>([]);
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const [vocation, setVocation] = useState("EK");
  const [level, setLevel] = useState("700");
  const [preview, setPreview] = useState<any>(null);
  const [warnings, setWarnings] = useState<any[]>([]);
  const [loadingList, setLoadingList] = useState(true);
  const [loadingPreview, setLoadingPreview] = useState(false);

  useEffect(() => {
    const clientId = getOrCreateClientId();
    if (!clientId) return;

    callHuntNexusApi<any>({ action: "player_profile_get", client_id: clientId })
      .then((response) => {
        const profile = response?.data?.profile;
        if (!profile) return;
        if (["EK","RP","ED","MS","EM"].includes(profile.vocation)) setVocation(profile.vocation);
        if (profile.level) setLevel(String(profile.level));
      })
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    let active = true;
    const timer = window.setTimeout(() => {
      setLoadingList(true);
      callHuntNexusApi<any>({
        action: "search_bosses",
        query: query.trim(),
        limit: 30,
      })
        .then((response) => {
          if (!active) return;
          const rows = Array.isArray(response?.data) ? response.data : [];
          setBosses(rows);
          setSelectedKey((current) => current && rows.some((row:any) => row.boss_key === current)
            ? current
            : rows[0]?.boss_key ?? null);
        })
        .catch(() => {
          if (active) setBosses([]);
        })
        .finally(() => {
          if (active) setLoadingList(false);
        });
    }, query.trim() ? 220 : 0);

    return () => {
      active = false;
      window.clearTimeout(timer);
    };
  }, [query]);

  useEffect(() => {
    if (!selectedKey || !vocation || !Number(level)) {
      setPreview(null);
      return;
    }

    let active = true;
    setLoadingPreview(true);

    callHuntNexusApi<any>({
      action: "boss_build",
      boss_key: selectedKey,
      vocation,
      level: Number(level),
    })
      .then((response) => {
        if (!active) return;
        setPreview(response?.data ?? null);
        setWarnings(Array.isArray(response?.warnings) ? response.warnings : []);
      })
      .catch(() => {
        if (!active) return;
        setPreview(null);
        setWarnings([]);
      })
      .finally(() => {
        if (active) setLoadingPreview(false);
      });

    return () => {
      active = false;
    };
  }, [selectedKey,vocation,level]);

  const boss = preview?.boss_profile?.boss;
  const combat = preview?.boss_profile?.factual_combat;
  const elements = Array.isArray(preview?.boss_profile?.element_profile) ? preview.boss_profile.element_profile : [];
  const mechanics = Array.isArray(preview?.boss_profile?.mechanics) ? preview.boss_profile.mechanics : [];
  const adds = Array.isArray(preview?.boss_profile?.adds) ? preview.boss_profile.adds : [];
  const spells = preview?.spell_evidence ?? {};

  return (
    <div className="mx-auto max-w-[1500px] space-y-6">
      <section className="hn-hero rounded-3xl border border-white/8 p-5 md:p-7">
        <div className="grid gap-5 xl:grid-cols-[1fr_auto] xl:items-end">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Boss Explorer</div>
            <h1 className="mt-2 text-3xl font-black tracking-tight text-white md:text-4xl">Bosses com evidência separada de mecânica.</h1>
            <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-400">
              Perfil base, elementos, spells e mecânicas são apresentados separadamente. O HuntNexus não chama um build de final quando faltam mecânicas atuais da sala.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <select className="hn-control min-w-40" value={vocation} onChange={(event) => setVocation(event.target.value)}>
              <option value="EK">Elite Knight</option>
              <option value="RP">Royal Paladin</option>
              <option value="ED">Elder Druid</option>
              <option value="MS">Master Sorcerer</option>
              <option value="EM">Exalted Monk</option>
            </select>
            <input className="hn-control w-28" type="number" min="1" value={level} onChange={(event) => setLevel(event.target.value)} />
          </div>
        </div>

        <div className="relative mt-5 max-w-2xl">
          <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-500" />
          <input className="hn-control pl-10" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar boss..." />
          {loadingList && <Loader2 className="absolute right-3 top-1/2 size-4 -translate-y-1/2 animate-spin text-cyan-300" />}
        </div>
      </section>

      <div className="grid gap-5 xl:grid-cols-[.72fr_1.28fr]">
        <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-4">
          <div className="mb-3 text-sm font-bold text-white">Bosses</div>
          <div className="max-h-[760px] space-y-2 overflow-y-auto pr-1">
            {bosses.map((row:any) => {
              const active = selectedKey === row.boss_key;
              return (
                <button
                  type="button"
                  key={row.boss_key}
                  onClick={() => setSelectedKey(row.boss_key)}
                  className={"flex w-full items-center gap-3 rounded-xl border p-3 text-left transition " + (active
                    ? "border-cyan-400/25 bg-cyan-400/[0.07]"
                    : "border-white/6 bg-white/[0.02] hover:border-white/12")}
                >
                  <CanonicalSprite kind="creature" name={row.name} size="sm" />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-bold text-slate-200">{row.name}</div>
                    <div className="mt-1 text-[10px] text-slate-600">{row.encounter_type || "boss"} · {readinessLabel(row.readiness_status)}</div>
                  </div>
                </button>
              );
            })}
          </div>
        </section>

        <section className="min-w-0 rounded-3xl border border-white/8 bg-slate-950/45 p-4 md:p-6">
          {loadingPreview ? (
            <div className="grid min-h-[560px] place-items-center"><Loader2 className="size-6 animate-spin text-cyan-300" /></div>
          ) : boss ? (
            <div className="space-y-6">
              <div className="flex flex-col gap-5 sm:flex-row">
                <CanonicalSprite kind="creature" name={boss.name} size="lg" />
                <div className="min-w-0 flex-1">
                  <div className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan-400">{boss.encounter_type || "Boss"}</div>
                  <h2 className="mt-1 text-2xl font-black text-white md:text-3xl">{boss.name}</h2>
                  <div className="mt-3 flex flex-wrap gap-2">
                    <Meta label="Status" value={readinessLabel(preview?.readiness?.readiness_status)} />
                    <Meta label="Vocação" value={vocation} />
                    <Meta label="Level" value={level} />
                    <Meta label="Final build" value={preview?.final_build_available ? "Disponível" : "Não declarado"} />
                  </div>
                </div>
              </div>

              {!preview?.final_build_available && (
                <div className="rounded-xl border border-amber-400/15 bg-amber-400/[0.045] p-3 text-xs leading-5 text-amber-100/70">
                  <div className="flex items-center gap-2 font-semibold text-amber-200"><AlertTriangle className="size-4" />Build final não forçado</div>
                  <div className="mt-1">{preview?.methodology?.note || "Faltam mecânicas atuais suficientes para declarar uma configuração final."}</div>
                </div>
              )}

              <div className="grid gap-4 lg:grid-cols-3">
                <Panel icon={Swords} title="Combate factual">
                  <Metric label="Ataque principal" value={combat?.attack_type || "—"} />
                  <Metric label="Max damage" value={combat?.max_damage == null ? "—" : formatNumber(Number(combat.max_damage))} />
                  <Metric label="Usa spells" value={combat?.uses_spells == null ? "—" : combat.uses_spells ? "Sim" : "Não"} />
                </Panel>

                <Panel icon={Shield} title="Elementos">
                  <div className="space-y-2">
                    {elements.slice(0,8).map((row:any) => (
                      <div key={row.element} className="flex items-center justify-between gap-2 text-[11px]">
                        <span className="text-slate-500">{elementLabel(row.element)}</span>
                        <span className={Number(row.avg_modifier_percent) > 100 ? "text-emerald-300" : Number(row.avg_modifier_percent) < 100 ? "text-amber-300" : "text-slate-400"}>
                          {formatNumber(Number(row.avg_modifier_percent),2)}%
                        </span>
                      </div>
                    ))}
                  </div>
                </Panel>

                <Panel icon={Sparkles} title="Sala">
                  <Metric label="Mecânicas" value={String(mechanics.length)} />
                  <Metric label="Adds" value={String(adds.length)} />
                  <Metric label="Build final" value={preview?.final_build_available ? "Sim" : "Não"} />
                </Panel>
              </div>

              {combat?.abilities_raw && (
                <div>
                  <SectionTitle title="Abilities da fonte" />
                  <div className="mt-3 rounded-xl border border-white/6 bg-white/[0.02] p-3 text-xs leading-5 text-slate-500">
                    {cleanWikiText(combat.abilities_raw)}
                  </div>
                </div>
              )}

              <SpellSection title="Ataques single target" rows={spells.single_target_attacks} />
              <SpellSection title="Ataques multi target" rows={spells.multi_target_attacks} />
              <SpellSection title="Healing" rows={spells.healing} />
              <SpellSection title="Support" rows={spells.support} />

              {mechanics.length > 0 && (
                <div>
                  <SectionTitle title="Mecânicas atuais catalogadas" />
                  <div className="mt-3 space-y-2">
                    {mechanics.map((row:any,index:number) => (
                      <div key={String(index)} className="rounded-xl border border-white/6 bg-white/[0.02] p-3 text-xs leading-5 text-slate-400">
                        {row.description || row.mechanic_text || row.raw_text || JSON.stringify(row)}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {warnings.length > 0 && (
                <div>
                  <SectionTitle title="Warnings globais" />
                  <div className="mt-3 space-y-2">
                    {warnings.slice(0,8).map((row:any,index:number) => (
                      <div key={String(index)} className="rounded-xl border border-amber-400/10 bg-amber-400/[0.03] p-3 text-[11px] leading-5 text-amber-100/60">
                        {row.message || row.note || JSON.stringify(row)}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ) : (
            <div className="grid min-h-[560px] place-items-center text-sm text-slate-600">Selecione um boss.</div>
          )}
        </section>
      </div>
    </div>
  );
}

function Panel({ icon:Icon, title, children }: { icon:any; title:string; children:React.ReactNode }) {
  return <div className="rounded-2xl border border-white/7 bg-white/[0.02] p-4"><div className="mb-3 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.13em] text-slate-400"><Icon className="size-3.5 text-cyan-300" />{title}</div>{children}</div>;
}

function Metric({ label, value }: { label:string; value:string }) {
  return <div className="mb-2 flex items-center justify-between gap-3 text-[11px]"><span className="text-slate-600">{label}</span><span className="text-right font-semibold text-slate-300">{value}</span></div>;
}

function Meta({ label, value }: { label:string; value:string }) {
  return <span className="rounded-full border border-white/7 bg-white/[0.025] px-3 py-1.5 text-[10px] text-slate-500"><strong className="mr-1 text-slate-300">{label}</strong>{value}</span>;
}

function SpellSection({ title, rows }: { title:string; rows:any }) {
  const values = Array.isArray(rows) ? rows : [];
  if (!values.length) return null;
  return (
    <div>
      <SectionTitle title={title} />
      <div className="mt-3 grid gap-2 md:grid-cols-2">
        {values.map((spell:any,index:number) => (
          <div key={(spell.spell_key || spell.name || "spell") + String(index)} className="rounded-xl border border-white/6 bg-white/[0.02] p-3">
            <div className="text-xs font-semibold text-slate-200">{spell.name || spell.spell_key}</div>
            <div className="mt-1 flex flex-wrap gap-2 text-[10px] text-slate-600">
              {spell.element && <span>{elementLabel(spell.element)}</span>}
              {spell.base_power != null && <span>Power {spell.base_power}</span>}
              {spell.cooldown_seconds != null && <span>CD {spell.cooldown_seconds}s</span>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function SectionTitle({ title }: { title:string }) {
  return <div className="text-sm font-bold text-white">{title}</div>;
}

function readinessLabel(value:unknown) {
  if (value === "base_profile_available") return "Perfil base disponível";
  if (value === "room_mechanics_available") return "Mecânicas disponíveis";
  if (value === "ready") return "Pronto";
  return String(value || "Em validação");
}

function elementLabel(value:string) {
  return ({ physical:"Physical",fire:"Fire",ice:"Ice",earth:"Earth",energy:"Energy",death:"Death",holy:"Holy",drown:"Drown",life_drain:"Life Drain",healing:"Healing" } as Record<string,string>)[value] ?? value;
}

function cleanWikiText(value:unknown) {
  if (typeof value !== "string") return "—";
  return value.replaceAll("{{Ability List|","").replaceAll("{{","").replaceAll("}}","").replaceAll("|"," · ").trim();
}
