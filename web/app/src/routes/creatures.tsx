import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { Crosshair, Loader2, MapPin, Search, Shield, Sparkles, Swords } from "lucide-react";
import { CanonicalSprite } from "@/components/shared/canonical-sprite";
import { callHuntNexusApi, formatNumber } from "@/lib/api/huntnexus";

export const Route = createFileRoute("/creatures")({ component: CreatureExplorer });

function CreatureExplorer() {
  const [query, setQuery] = useState("");
  const [creatures, setCreatures] = useState<any[]>([]);
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const [detail, setDetail] = useState<any>(null);
  const [loadingList, setLoadingList] = useState(true);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    const timer = window.setTimeout(() => {
      setLoadingList(true);
      setError("");
      callHuntNexusApi<any>({
        action: "search_creatures",
        query: query.trim(),
        limit: 30,
      })
        .then((response) => {
          if (!active) return;
          const rows = Array.isArray(response?.data?.creatures) ? response.data.creatures : [];
          setCreatures(rows);
          setSelectedKey((current) => current && rows.some((row:any) => row.creature_key === current)
            ? current
            : rows[0]?.creature_key ?? null);
        })
        .catch(() => {
          if (!active) return;
          setCreatures([]);
          setError("Não foi possível carregar o catálogo de criaturas.");
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
    if (!selectedKey) {
      setDetail(null);
      return;
    }

    let active = true;
    setLoadingDetail(true);

    callHuntNexusApi<any>({
      action: "creature_detail",
      creature_key: selectedKey,
    })
      .then((response) => {
        if (active) setDetail(response?.data ?? null);
      })
      .catch(() => {
        if (active) setDetail(null);
      })
      .finally(() => {
        if (active) setLoadingDetail(false);
      });

    return () => {
      active = false;
    };
  }, [selectedKey]);

  const selected = detail?.creature ?? null;
  const vulnerabilities = Array.isArray(detail?.vulnerabilities) ? detail.vulnerabilities : [];
  const abilities = Array.isArray(detail?.abilities) ? detail.abilities : [];
  const loot = Array.isArray(detail?.loot) ? detail.loot : [];

  const strongest = useMemo(() => {
    return vulnerabilities
      .filter((row:any) => Number.isFinite(Number(row.modifier_percent)))
      .sort((a:any,b:any) => Number(b.modifier_percent) - Number(a.modifier_percent))[0] ?? null;
  }, [vulnerabilities]);

  return (
    <div className="mx-auto max-w-[1500px] space-y-6">
      <section className="hn-hero rounded-3xl border border-white/8 p-5 md:p-7">
        <div className="flex flex-col justify-between gap-5 xl:flex-row xl:items-end">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Creature Explorer</div>
            <h1 className="mt-2 text-3xl font-black tracking-tight text-white md:text-4xl">Catálogo factual de criaturas.</h1>
            <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-400">
              HP, experiência, localização, resistências, ataques e loot vêm do catálogo canônico. Valores desconhecidos continuam desconhecidos.
            </p>
          </div>

          <div className="relative w-full max-w-xl">
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-500" />
            <input
              className="hn-control pl-10"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Buscar criatura..."
            />
            {loadingList && <Loader2 className="absolute right-3 top-1/2 size-4 -translate-y-1/2 animate-spin text-cyan-300" />}
          </div>
        </div>
      </section>

      {error && <div className="text-sm text-red-300">{error}</div>}

      <div className="grid gap-5 xl:grid-cols-[.8fr_1.2fr]">
        <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-4 md:p-5">
          <div className="flex items-center justify-between gap-3">
            <div>
              <div className="font-bold text-white">Criaturas</div>
              <div className="mt-1 text-xs text-slate-600">{creatures.length} resultados exibidos</div>
            </div>
            <Swords className="size-4 text-cyan-300" />
          </div>

          <div className="mt-4 max-h-[760px] space-y-2 overflow-y-auto pr-1">
            {creatures.map((creature:any) => {
              const active = selectedKey === creature.creature_key;
              return (
                <button
                  type="button"
                  key={creature.creature_key}
                  onClick={() => setSelectedKey(creature.creature_key)}
                  className={"flex w-full items-center gap-3 rounded-xl border p-3 text-left transition " + (active
                    ? "border-cyan-400/25 bg-cyan-400/[0.07]"
                    : "border-white/6 bg-white/[0.02] hover:border-white/12")}
                >
                  <CanonicalSprite kind="creature" name={creature.name} size="sm" />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-bold text-slate-200">{creature.name}</div>
                    <div className="mt-1 flex flex-wrap gap-x-3 gap-y-1 text-[10px] text-slate-600">
                      <span>HP {formatCompact(creature.hitpoints)}</span>
                      <span>XP {formatCompact(creature.experience)}</span>
                      {creature.primary_type && <span>{creature.primary_type}</span>}
                    </div>
                  </div>
                </button>
              );
            })}

            {!loadingList && creatures.length === 0 && (
              <div className="rounded-xl border border-dashed border-white/8 p-6 text-center text-sm text-slate-600">
                Nenhuma criatura encontrada.
              </div>
            )}
          </div>
        </section>

        <section className="min-w-0 rounded-3xl border border-white/8 bg-slate-950/45 p-4 md:p-6">
          {loadingDetail ? (
            <div className="grid min-h-[520px] place-items-center">
              <Loader2 className="size-6 animate-spin text-cyan-300" />
            </div>
          ) : selected ? (
            <div className="space-y-6">
              <div className="flex flex-col gap-5 sm:flex-row sm:items-start">
                <CanonicalSprite kind="creature" name={selected.name} size="lg" />
                <div className="min-w-0 flex-1">
                  <div className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan-400">
                    {selected.creature_class || "Criatura"}
                  </div>
                  <h2 className="mt-1 text-2xl font-black text-white md:text-3xl">{selected.name}</h2>
                  <div className="mt-3 flex flex-wrap gap-2">
                    <MetaPill label="HP" value={formatCompact(selected.hitpoints)} />
                    <MetaPill label="XP" value={formatCompact(selected.experience)} />
                    <MetaPill label="Tipo" value={selected.primary_type || "—"} />
                    <MetaPill label="Implementado" value={selected.implemented || "—"} />
                  </div>
                  {selected.location && (
                    <div className="mt-4 flex items-start gap-2 text-xs leading-5 text-slate-500">
                      <MapPin className="mt-0.5 size-3.5 shrink-0 text-cyan-400" />
                      <span>{selected.location}</span>
                    </div>
                  )}
                </div>
              </div>

              <div className="grid gap-4 lg:grid-cols-3">
                <InfoPanel icon={Shield} title="Resistências">
                  <div className="space-y-2">
                    {vulnerabilities.filter((row:any) => !["healing","life_drain","drown"].includes(row.element)).map((row:any) => (
                      <ResistanceRow key={row.element} element={row.element} modifier={Number(row.modifier_percent)} />
                    ))}
                    {vulnerabilities.length === 0 && <Muted>Nenhuma resistência normalizada disponível.</Muted>}
                  </div>
                  {strongest && Number(strongest.modifier_percent) > 100 && (
                    <div className="mt-3 text-[10px] leading-4 text-slate-600">
                      Maior modificador observado: {elementLabel(strongest.element)} {formatNumber(Number(strongest.modifier_percent),2)}%.
                    </div>
                  )}
                </InfoPanel>

                <InfoPanel icon={Crosshair} title="Combate">
                  <div className="grid grid-cols-2 gap-2">
                    <TinyMetric label="Armor" value={selected.armor || "—"} />
                    <TinyMetric label="Speed" value={selected.speed || "—"} />
                    <TinyMetric label="Max damage" value={selected.max_damage || "—"} />
                    <TinyMetric label="Spawn" value={selected.spawn_type || "—"} />
                  </div>
                  <div className="mt-3 text-[10px] leading-4 text-slate-600">
                    Campos “?” ou ausentes não são estimados pelo HuntNexus.
                  </div>
                </InfoPanel>

                <InfoPanel icon={Sparkles} title="Fonte">
                  <div className="space-y-2 text-xs text-slate-500">
                    <div>Catálogo canônico Tibia/RubinOT</div>
                    <div>Vulnerabilidades normalizadas: {detail?.summary?.vulnerability_rows ?? 0}</div>
                    <div>Linhas de habilidade: {detail?.summary?.ability_rows ?? 0}</div>
                    <div>Loot catalogado: {detail?.summary?.loot_rows ?? 0}</div>
                  </div>
                </InfoPanel>
              </div>

              {abilities.length > 0 && (
                <div>
                  <SectionTitle title="Habilidades e ataques" />
                  <div className="mt-3 space-y-2">
                    {abilities.slice(0,12).map((ability:any,index:number) => (
                      <div key={String(index) + String(ability.abilities_raw)} className="rounded-xl border border-white/6 bg-white/[0.02] p-3">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <div className="text-xs font-semibold text-slate-300">{ability.attack_type || "Ability"}</div>
                          {ability.max_damage != null && <span className="text-[10px] text-slate-600">Max {formatCompact(ability.max_damage)}</span>}
                        </div>
                        <div className="mt-1 break-words text-[11px] leading-5 text-slate-500">{cleanWikiText(ability.abilities_raw)}</div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {loot.length > 0 && (
                <div>
                  <SectionTitle title="Loot catalogado" />
                  <div className="mt-3 grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
                    {loot.slice(0,30).map((item:any,index:number) => (
                      <div key={item.item_name + String(index)} className="flex items-center gap-3 rounded-xl border border-white/6 bg-white/[0.02] p-2.5">
                        <CanonicalSprite kind="item" name={item.item_name} size="sm" />
                        <div className="min-w-0">
                          <div className="truncate text-xs font-semibold text-slate-200">{item.item_name}</div>
                          <div className="mt-1 text-[10px] text-slate-600">{[item.rarity,item.chance].filter(Boolean).join(" · ") || "Chance não normalizada"}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {(selected.notes || selected.strategy || selected.behaviour) && (
                <div>
                  <SectionTitle title="Notas da fonte" />
                  <div className="mt-3 grid gap-3 lg:grid-cols-3">
                    {selected.notes && <TextBlock label="Notas" text={selected.notes} />}
                    {selected.strategy && <TextBlock label="Estratégia" text={selected.strategy} />}
                    {selected.behaviour && <TextBlock label="Comportamento" text={selected.behaviour} />}
                  </div>
                </div>
              )}
            </div>
          ) : (
            <div className="grid min-h-[520px] place-items-center text-sm text-slate-600">
              Selecione uma criatura.
            </div>
          )}
        </section>
      </div>
    </div>
  );
}

function InfoPanel({ icon: Icon, title, children }: { icon:any; title:string; children:React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-white/7 bg-white/[0.02] p-4">
      <div className="mb-3 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.13em] text-slate-400">
        <Icon className="size-3.5 text-cyan-300" />
        {title}
      </div>
      {children}
    </div>
  );
}

function ResistanceRow({ element, modifier }: { element:string; modifier:number }) {
  const status = modifier === 0 ? "Imune" : modifier < 100 ? "Resiste" : modifier > 100 ? "Vulnerável" : "Neutro";
  return (
    <div className="flex items-center justify-between gap-3 rounded-lg border border-white/5 bg-black/15 px-2.5 py-2">
      <span className="text-[11px] text-slate-400">{elementLabel(element)}</span>
      <span className={"text-[10px] font-semibold " + (modifier > 100 ? "text-emerald-300" : modifier < 100 ? "text-amber-300" : "text-slate-500")}>
        {formatNumber(modifier,2)}% · {status}
      </span>
    </div>
  );
}

function MetaPill({ label, value }: { label:string; value:string }) {
  return <span className="rounded-full border border-white/7 bg-white/[0.025] px-3 py-1.5 text-[10px] text-slate-500"><strong className="mr-1 text-slate-300">{label}</strong>{value}</span>;
}

function TinyMetric({ label, value }: { label:string; value:string }) {
  return <div className="rounded-lg border border-white/6 bg-black/15 p-2"><div className="text-[9px] text-slate-600">{label}</div><div className="mt-1 truncate text-xs font-bold text-slate-300">{value}</div></div>;
}

function TextBlock({ label, text }: { label:string; text:string }) {
  return <div className="rounded-xl border border-white/6 bg-white/[0.02] p-3"><div className="text-[10px] uppercase tracking-wide text-slate-600">{label}</div><div className="mt-2 text-xs leading-5 text-slate-400">{cleanWikiText(text)}</div></div>;
}

function SectionTitle({ title }: { title:string }) {
  return <div className="text-sm font-bold text-white">{title}</div>;
}

function Muted({ children }: { children:React.ReactNode }) {
  return <div className="text-xs text-slate-600">{children}</div>;
}

function formatCompact(value:unknown) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "—";
  if (Math.abs(n) >= 1_000_000) return (n / 1_000_000).toFixed(1) + "M";
  if (Math.abs(n) >= 1_000) return Math.round(n / 1_000) + "k";
  return String(Math.round(n));
}

function elementLabel(value:string) {
  return ({
    physical:"Physical",
    fire:"Fire",
    ice:"Ice",
    earth:"Earth",
    energy:"Energy",
    death:"Death",
    holy:"Holy",
    healing:"Healing",
    life_drain:"Life Drain",
    drown:"Drown",
  } as Record<string,string>)[value] ?? value;
}

function cleanWikiText(value:unknown) {
  if (typeof value !== "string") return "—";
  return value
    .replaceAll("{{Ability List|", "")
    .replaceAll("{{Sound List|", "")
    .replaceAll("{{", "")
    .replaceAll("}}", "")
    .replaceAll("|", " · ")
    .trim();
}
