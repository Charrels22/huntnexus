import { createFileRoute, Link } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  BarChart3,
  Clock3,
  Coins,
  HeartPulse,
  Loader2,
  RefreshCw,
  ShieldAlert,
  Swords,
  Users,
} from "lucide-react";
import { callHuntNexusApi, formatNumber } from "@/lib/api/huntnexus";
import { CanonicalSprite } from "@/components/shared/canonical-sprite";
import { getOrCreateClientId } from "@/lib/client-id";

export const Route = createFileRoute("/sessions")({
  validateSearch: (search: Record<string, unknown>) => ({
    personal: typeof search.personal === "string" ? search.personal : undefined,
  }),
  component: SessionHistoryPage,
});

const tabs = [
  { key: "analyse", label: "Hunt Analyse", icon: BarChart3 },
  { key: "misc", label: "Misc", icon: Activity },
  { key: "damage", label: "Damage", icon: Swords },
  { key: "party", label: "Party Hunt", icon: Users },
] as const;

type TabKey = (typeof tabs)[number]["key"];

function SessionHistoryPage() {
  const search = Route.useSearch();
  const [tab, setTab] = useState<TabKey>("analyse");
  const [sessions, setSessions] = useState<any[]>([]);
  const [selectedId, setSelectedId] = useState<string>("");
  const [detail, setDetail] = useState<any>(null);
  const [loadingList, setLoadingList] = useState(true);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [error, setError] = useState("");

  async function loadSessions() {
    const clientId = getOrCreateClientId();
    if (!clientId) return;

    setLoadingList(true);
    setError("");
    try {
      const response = await callHuntNexusApi<any>({
        action: "player_session_list",
        client_id: clientId,
        limit: 50,
      });
      const rows = Array.isArray(response?.data?.sessions) ? response.data.sessions : [];
      setSessions(rows);

      const requested = search.personal && rows.some((row: any) => row.session_id === search.personal)
        ? search.personal
        : null;
      setSelectedId((current) => requested || current || rows[0]?.session_id || "");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoadingList(false);
    }
  }

  async function loadDetail(sessionId: string) {
    const clientId = getOrCreateClientId();
    if (!clientId || !sessionId) return;

    setLoadingDetail(true);
    setError("");
    try {
      const response = await callHuntNexusApi<any>({
        action: "player_session_detail",
        client_id: clientId,
        session_id: sessionId,
      });
      setDetail(response?.data ?? null);
    } catch (e) {
      setError((e as Error).message);
      setDetail(null);
    } finally {
      setLoadingDetail(false);
    }
  }

  useEffect(() => { void loadSessions(); }, [search.personal]);
  useEffect(() => { if (selectedId) void loadDetail(selectedId); }, [selectedId]);

  const selected = useMemo(
    () => sessions.find((s) => s.session_id === selectedId) ?? null,
    [sessions, selectedId],
  );

  return (
    <div className="mx-auto max-w-[1450px] space-y-6">
      <section className="rounded-3xl border border-white/8 bg-slate-950/55 p-5 md:p-6">
        <div className="grid gap-5 xl:grid-cols-[1fr_420px]">
          <div>
            <div className="text-xs uppercase tracking-[0.18em] text-cyan-400">Sessions</div>
            <h1 className="mt-1 text-3xl font-black text-white">Histórico e análise das hunts cadastradas.</h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-400">
              Abra uma sessão cadastrada para consultar Hunt Analyse, Misc, Damage e Party Hunt.
            </p>
            <div className="mt-5 flex flex-wrap gap-2">
              <button className="hn-primary-button" onClick={() => void loadSessions()} disabled={loadingList}>
                {loadingList ? <Loader2 className="size-4 animate-spin" /> : <RefreshCw className="size-4" />}
                Atualizar sessões
              </button>
              <span className="hn-secondary-button cursor-default">
                {sessions.length} sessões carregadas
              </span>
            </div>
          </div>

          <div className="rounded-2xl border border-white/7 bg-white/[0.025] p-4">
            <label className="text-xs font-medium text-slate-500">Sessão analisada</label>
            <select
              value={selectedId}
              onChange={(e) => setSelectedId(e.target.value)}
              className="hn-control mt-2"
              disabled={loadingList || sessions.length === 0}
            >
              {sessions.map((s) => (
                <option key={s.session_id} value={s.session_id}>
                  {decodeHtml(s.hunt_name || "Hunt sem local")} · {formatDuration(s.duration_seconds)} · {formatCompact(s.xp_per_hour)} XP/h
                </option>
              ))}
            </select>
            {selected && (
              <div className="mt-3 grid grid-cols-2 gap-2 text-xs">
                <Meta label="Vocação" value={selected.vocation || "—"} />
                <Meta label="Status" value={selected.status === "parsed" ? "Processada" : "Revisar"} />
              </div>
            )}
          </div>
        </div>
      </section>

      {error && (
        <div className="rounded-2xl border border-red-400/20 bg-red-400/8 p-4 text-sm text-red-200">
          {error}
        </div>
      )}

      <div className="grid gap-3 md:grid-cols-4">
        {tabs.map(({ key, label, icon: Icon }) => {
          const unavailable =
            key === "party" && detail && detail.availability?.party_hunt === false;
          return (
            <button
              key={key}
              onClick={() => setTab(key)}
              className={`hn-analyzer-tab ${tab === key ? "hn-analyzer-tab-active" : ""} ${unavailable ? "opacity-55" : ""}`}
            >
              <Icon className="size-5" />
              <span>{label}</span>
              {unavailable && <span className="text-[9px] uppercase tracking-wide">solo</span>}
            </button>
          );
        })}
      </div>

      <section className="min-h-[420px] rounded-3xl border border-white/8 bg-white/[0.025] p-5 md:p-6">
        {loadingDetail && (
          <div className="grid min-h-[360px] place-items-center text-slate-500">
            <Loader2 className="size-6 animate-spin text-cyan-300" />
          </div>
        )}

        {!loadingDetail && !detail && (
          <div className="grid min-h-[320px] place-items-center text-center">
            <div>
              <div className="text-xl font-bold text-white">Nenhuma hunt cadastrada</div>
              <p className="mt-2 max-w-md text-sm text-slate-500">Cole seus analyzers no Session Analyzer e salve a primeira hunt.</p>
              <Link to="/session" className="hn-primary-button mt-4">Cadastrar hunt</Link>
            </div>
          </div>
        )}

        {!loadingDetail && detail && tab === "analyse" && <Analyse data={detail} />}
        {!loadingDetail && detail && tab === "misc" && <Misc data={detail} />}
        {!loadingDetail && detail && tab === "damage" && <Damage data={detail} />}
        {!loadingDetail && detail && tab === "party" && <Party data={detail} />}
      </section>
    </div>
  );
}

function Analyse({ data }: { data: any }) {
  const a = data.hunt_analyse ?? {};
  const session = data.session ?? {};
  const profitPerHour = rate(a.balance_value, a.duration_seconds);
  return (
    <div className="space-y-6">
      <PanelHeader eyebrow="Hunt Analyse" title={decodeHtml(session.hunt_name_raw || session.hunt_key || "Sessão")} subtitle={formatDuration(a.duration_seconds)} />
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-6">
        <Kpi icon={BarChart3} label="XP/h" value={formatCompact(a.xp_per_hour)} />
        <Kpi icon={Coins} label="Profit/h" value={formatCompact(profitPerHour)} />
        <Kpi icon={Coins} label="Balance" value={formatCompact(a.balance_value)} />
        <Kpi icon={Swords} label="Damage" value={formatCompact(a.total_damage)} />
        <Kpi icon={HeartPulse} label="Healing" value={formatCompact(a.total_healing)} />
        <Kpi icon={Clock3} label="Kills" value={formatNumber(Number(a.total_kills || 0))} />
      </div>

      <div className="grid gap-4 xl:grid-cols-[1.3fr_.7fr]">
        <div className="hn-chart-placeholder">
          <div className="relative z-10">
            <div className="text-sm font-semibold text-slate-200">Resumo visual da sessão</div>
            <div className="mt-1 text-xs text-slate-500">A timeline detalhada entra quando tivermos snapshots temporais da sessão.</div>
          </div>
          <div className="absolute inset-x-6 bottom-6 flex h-28 items-end gap-2">
            {[38,52,48,65,58,79,67,86,72,90,81,88].map((h,i) => <div key={i} className="flex-1 rounded-t bg-cyan-400/20" style={{height:`${h}%`}} />)}
          </div>
        </div>
        <div className="space-y-3">
          <DataRow label="XP total" value={formatNumber(Number(a.xp_gain || 0))} />
          <DataRow label="Raw XP/h" value={formatCompact(a.raw_xp_per_hour)} />
          <DataRow label="Loot" value={a.loot_value == null ? "Não informado" : formatCompact(a.loot_value)} />
          <DataRow label="Supplies" value={a.supplies_value == null ? "Não informado" : formatCompact(a.supplies_value)} />
          <DataRow label="Party" value={Number(a.party_size || 1) > 1 ? `x${a.party_size}` : "Solo"} />
        </div>
      </div>
    </div>
  );
}

function Misc({ data }: { data: any }) {
  const misc = data.misc ?? {};
  const equipment = Array.isArray(misc.equipment) ? misc.equipment : [];
  const stats = Array.isArray(misc.combat_stats) ? misc.combat_stats : [];
  const creatures = Array.isArray(misc.creatures) ? misc.creatures : [];
  return (
    <div className="space-y-6">
      <PanelHeader eyebrow="Misc" title="Contexto da sessão" subtitle="Equipamento, stats observados e criaturas." />
      <div className="grid gap-5 xl:grid-cols-3">
        <Block title="Equipment">
          {equipment.length ? (
            <div className="grid grid-cols-2 gap-2">
              {equipment.map((e:any, i:number) => (
                <div key={`${e.player_id}-${e.slot_key}-${i}`} className="grid grid-cols-[52px_1fr] items-center gap-2 rounded-xl border border-white/6 bg-slate-950/45 p-2">
                  <CanonicalSprite kind="item" name={e.item_name_raw || slugToName(e.item_key)} size="sm" />
                  <div className="min-w-0">
                    <div className="text-[10px] uppercase tracking-wide text-slate-600">{e.slot_key}</div>
                    <div className="mt-1 truncate text-sm font-semibold text-slate-200">{e.item_name_raw || slugToName(e.item_key) || "—"}</div>
                  </div>
                </div>
              ))}
            </div>
          ) : <Muted>Nenhum equipment normalizado nesta sessão.</Muted>}
        </Block>

        <Block title="Combat Stats">
          <div className="max-h-[420px] space-y-2 overflow-y-auto pr-1">
            {stats.slice(0,40).map((s:any, i:number) => (
              <DataRow key={`${s.player_id}-${s.stat_key}-${i}`} label={s.stat_name_raw || s.stat_key} value={formatStat(s)} />
            ))}
            {!stats.length && <Muted>Nenhum stat detalhado disponível.</Muted>}
          </div>
        </Block>

        <Block title="Creatures">
          <div className="space-y-2">
            {creatures.slice(0,20).map((c:any, i:number) => (
              <div key={`${c.monster_key || c.monster_name_raw}-${i}`} className="flex items-center justify-between rounded-xl border border-white/6 bg-slate-950/45 px-3 py-2">
                <div>
                  <div className="text-sm font-medium text-slate-200">{c.monster_name_raw || c.monster_key}</div>
                  <div className="text-[10px] text-slate-600">{c.resolution_status}</div>
                </div>
                <div className="text-sm font-black text-cyan-200">{formatNumber(Number(c.kills || 0))}</div>
              </div>
            ))}
            {!creatures.length && <Muted>Nenhuma criatura normalizada.</Muted>}
          </div>
        </Block>
      </div>
    </div>
  );
}

function Damage({ data }: { data: any }) {
  const d = data.damage ?? {};
  const elements = Array.isArray(d.incoming_by_element) ? d.incoming_by_element : [];
  const sources = Array.isArray(d.incoming_by_source) ? d.incoming_by_source : [];
  const maxShare = Math.max(1, ...elements.map((x:any) => Number(x.share_percent || 0)));
  return (
    <div className="space-y-6">
      <PanelHeader eyebrow="Damage" title="Dano causado e recebido" subtitle="Breakdown normalizado da sessão." />
      <div className="grid gap-3 sm:grid-cols-3">
        <Kpi icon={Swords} label="Damage dealt" value={formatCompact(d.total_damage)} />
        <Kpi icon={ShieldAlert} label="Elementos recebidos" value={String(elements.length)} />
        <Kpi icon={Activity} label="Charm damage" value={d.charm_damage_available ? "Disponível" : "Ainda não normalizado"} />
      </div>

      <div className="grid gap-5 xl:grid-cols-2">
        <Block title="Dano recebido por elemento">
          <div className="space-y-3">
            {elements.map((e:any, i:number) => (
              <div key={`${e.player_id}-${e.element}-${i}`}>
                <div className="mb-1.5 flex items-center justify-between text-xs">
                  <span className="capitalize text-slate-300">{e.element}</span>
                  <span className="text-slate-500">{formatNumber(Number(e.damage || 0))} · {formatNumber(Number(e.share_percent || 0),1)}%</span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-white/5">
                  <div className="h-full rounded-full bg-cyan-400/55 transition-all" style={{width:`${Math.max(3,(Number(e.share_percent || 0)/maxShare)*100)}%`}} />
                </div>
              </div>
            ))}
            {!elements.length && <Muted>Dano recebido por elemento não disponível nesta sessão.</Muted>}
          </div>
        </Block>

        <Block title="Maiores fontes de dano recebido">
          <div className="space-y-2">
            {sources.slice(0,12).map((s:any, i:number) => (
              <DataRow key={`${s.player_id}-${s.monster_key}-${i}`} label={s.monster_name_raw || s.monster_key || "Fonte"} value={`${formatNumber(Number(s.damage || 0))} · ${formatNumber(Number(s.share_percent || 0),1)}%`} />
            ))}
            {!sources.length && <Muted>Fontes de dano recebido não disponíveis.</Muted>}
          </div>
        </Block>
      </div>

      {!d.charm_damage_available && (
        <div className="rounded-2xl border border-amber-400/15 bg-amber-400/[0.04] p-4 text-sm text-amber-100/80">
          Charm damage existe como requisito do produto, mas ainda não há campo normalizado no banco atual. O HuntNexus não exibe zero nem inventa contribuição enquanto esse parsing não estiver disponível.
        </div>
      )}
    </div>
  );
}

function Party({ data }: { data: any }) {
  const p = data.party_hunt ?? {};
  const players = Array.isArray(p.players) ? p.players : [];
  const totalDamage = players.reduce((sum:number, x:any) => sum + Number(x.damage || 0), 0);
  const totalHealing = players.reduce((sum:number, x:any) => sum + Number(x.healing || 0), 0);

  if (!data.availability?.party_hunt) {
    return <Empty title="Sessão solo" text="Party Hunt só aparece como análise comparativa quando a sessão contém mais de um jogador." />;
  }

  return (
    <div className="space-y-6">
      <PanelHeader eyebrow="Party Hunt" title={`Party x${p.party_size || players.length}`} subtitle="Contribuição observada por membro." />
      <div className="grid gap-4 xl:grid-cols-2">
        {players.map((player:any) => {
          const damageShare = totalDamage > 0 ? Number(player.damage || 0) / totalDamage * 100 : 0;
          const healingShare = totalHealing > 0 ? Number(player.healing || 0) / totalHealing * 100 : 0;
          return (
            <div key={player.player_id} className="rounded-2xl border border-white/7 bg-slate-950/45 p-4">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="text-lg font-bold text-white">{player.vocation || "Player"}</div>
                  <div className="text-xs text-slate-500">Level {player.level ?? "—"}</div>
                </div>
                <span className="rounded-full border border-cyan-400/15 bg-cyan-400/8 px-3 py-1 text-xs text-cyan-200">{formatNumber(damageShare,1)}% dmg</span>
              </div>
              <div className="mt-4 grid grid-cols-2 gap-2">
                <Mini label="Damage" value={formatCompact(player.damage)} />
                <Mini label="Healing" value={formatCompact(player.healing)} />
                <Mini label="Damage share" value={`${formatNumber(damageShare,1)}%`} />
                <Mini label="Healing share" value={`${formatNumber(healingShare,1)}%`} />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function PanelHeader({ eyebrow, title, subtitle }: { eyebrow:string; title:string; subtitle:string }) {
  return <div><div className="text-xs uppercase tracking-[0.16em] text-cyan-400">{eyebrow}</div><div className="mt-1 flex flex-wrap items-baseline gap-3"><h2 className="text-2xl font-bold text-white">{title}</h2><span className="text-xs text-slate-500">{subtitle}</span></div></div>;
}
function Kpi({ icon: Icon, label, value }: any) {
  return <div className="rounded-2xl border border-white/6 bg-slate-950/50 p-4"><Icon className="size-4 text-cyan-300" /><div className="mt-4 text-xs text-slate-500">{label}</div><div className="mt-1 text-xl font-black text-white">{value}</div></div>;
}
function Block({ title, children }: { title:string; children:React.ReactNode }) {
  return <div className="rounded-2xl border border-white/7 bg-slate-950/35 p-4"><div className="mb-4 text-sm font-semibold text-slate-200">{title}</div>{children}</div>;
}
function DataRow({ label, value }: { label:string; value:string }) {
  return <div className="flex items-center justify-between gap-4 rounded-xl border border-white/6 bg-slate-950/45 px-3 py-2.5"><span className="text-xs text-slate-500">{label}</span><span className="text-sm font-semibold text-slate-200">{value}</span></div>;
}
function Meta({ label, value }: { label:string; value:string }) {
  return <div className="rounded-lg bg-white/[0.025] p-2"><div className="text-[10px] text-slate-600">{label}</div><div className="mt-1 font-semibold text-slate-300">{value}</div></div>;
}
function Mini({ label, value }: { label:string; value:string }) {
  return <div className="rounded-xl border border-white/6 bg-white/[0.025] p-3"><div className="text-[10px] text-slate-600">{label}</div><div className="mt-1 text-sm font-bold text-slate-200">{value}</div></div>;
}
function Muted({ children }: { children:React.ReactNode }) {
  return <div className="rounded-xl border border-dashed border-white/7 p-4 text-xs text-slate-600">{children}</div>;
}
function Empty({ title, text }: { title:string; text:string }) {
  return <div className="grid min-h-[320px] place-items-center text-center"><div><div className="text-xl font-bold text-white">{title}</div><p className="mt-2 max-w-md text-sm text-slate-500">{text}</p></div></div>;
}

function formatDuration(seconds: unknown) {
  const total = Number(seconds || 0);
  if (!Number.isFinite(total) || total <= 0) return "—";
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  return h > 0 ? `${h}h ${String(m).padStart(2,"0")}m` : `${m}m`;
}
function formatCompact(value: unknown) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "—";
  const abs = Math.abs(n);
  const sign = n < 0 ? "-" : "";
  if (abs >= 1_000_000) return `${sign}${(abs/1_000_000).toFixed(2)}M`;
  if (abs >= 1_000) return `${sign}${Math.round(abs/1_000)}k`;
  return formatNumber(n);
}
function rate(value: unknown, seconds: unknown) {
  const v = Number(value);
  const s = Number(seconds);
  return Number.isFinite(v) && Number.isFinite(s) && s > 0 ? v * 3600 / s : null;
}
function formatStat(stat:any) {
  if (stat?.numeric_value == null) return "—";
  return `${formatNumber(Number(stat.numeric_value),2)}${stat.unit === "percent" ? "%" : ""}`;
}
function slugToName(value:unknown) {
  if (typeof value !== "string") return "";
  return value.split("-").filter(Boolean).map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(" ");
}
function decodeHtml(value:string) {
  return value
    .replaceAll("&#39;", "'")
    .replaceAll("&amp;", "&")
    .replaceAll("&quot;", '"');
}
