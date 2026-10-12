import { Link, useRouterState } from "@tanstack/react-router";
import {
  Activity,
  BarChart3,
  BookOpen,
  Boxes,
  ChevronRight,
  Compass,
  LayoutDashboard,
  Menu,
  Search,
  Shield,
  Sparkles,
  Swords,
  Users,
  UserRound,
  UserRoundCog,
  X,
} from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";
import { callHuntNexusApi } from "@/lib/api/huntnexus";
import { getOrCreateClientId } from "@/lib/client-id";
import { isolateClientAfterAuthLoss } from "@/lib/account-session-guard";
import { getSupabaseBrowserClient } from "@/integrations/supabase/client.browser";

const nav = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard },
  { to: "/planner", label: "Hunt Planner", icon: Compass },
  { to: "/session", label: "Session Analyzer", icon: Activity },
  { to: "/sessions", label: "Sessions", icon: BarChart3 },
  { to: "/loadouts", label: "Loadouts", icon: Boxes },
  { to: "/creatures", label: "Creatures", icon: Swords },
  { to: "/bosses", label: "Bosses", icon: Shield },
  { to: "/community", label: "Community", icon: Users },
  { to: "/profile", label: "Profile", icon: UserRound },
  { to: "/account", label: "Conta", icon: UserRoundCog },
] as const;

function Brand() {
  return (
    <Link to="/" className="group flex items-center gap-3">
      <div className="grid size-10 place-items-center rounded-xl border border-cyan-400/25 bg-cyan-400/10 shadow-[0_0_32px_rgba(34,211,238,.12)] transition group-hover:border-cyan-300/50">
        <Sparkles className="size-5 text-cyan-300" />
      </div>
      <div>
        <div className="text-lg font-black tracking-tight text-white">
          Hunt<span className="text-cyan-300">Nexus</span>
        </div>
        <div className="text-[10px] uppercase tracking-[0.22em] text-slate-500">Player Intelligence</div>
      </div>
    </Link>
  );
}

export function AppShell({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const [mobileOpen, setMobileOpen] = useState(false);
  const [recentSessions, setRecentSessions] = useState<any[]>([]);

  useEffect(() => {
    let active = true;

    const loadRecent = () => {
      const clientId = getOrCreateClientId();
      if (!clientId) return;

      callHuntNexusApi<any>({ action: "player_session_list", client_id: clientId, limit: 2 })
        .then((response) => {
          if (!active) return;
          setRecentSessions(Array.isArray(response?.data?.sessions) ? response.data.sessions : []);
        })
        .catch(() => { if (active) setRecentSessions([]); });
    };

    loadRecent();
    window.addEventListener("huntnexus:player-sessions-changed", loadRecent);

    return () => {
      active = false;
      window.removeEventListener("huntnexus:player-sessions-changed", loadRecent);
    };
  }, []);

  useEffect(() => {
    const supabase = getSupabaseBrowserClient();
    if (!supabase) return;
    let hadAuthenticatedSession = false;
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      const previouslyAuthenticated = hadAuthenticatedSession;
      hadAuthenticatedSession = Boolean(session);
      // Account already owns its signed-out messaging and cleanup.
      if (window.location.pathname === "/account" || session) return;
      if (event !== "SIGNED_OUT" && event !== "INITIAL_SESSION") return;
      if (isolateClientAfterAuthLoss(event === "SIGNED_OUT" && previouslyAuthenticated)) {
        // Unmount any private Profile, Inventory, Planner and Session state.
        // A new page load also discards in-flight responses from the old scope.
        setRecentSessions([]);
        window.location.replace("/account");
      }
    });
    return () => subscription.unsubscribe();
  }, [pathname]);

  return (
    <div className="hn-app min-h-screen bg-background text-foreground">
      <div className="hn-backdrop" />
      <header className="sticky top-0 z-40 border-b border-white/7 bg-slate-950/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-[1700px] items-center gap-4 px-4 lg:px-6">
          <button
            type="button"
            className="grid size-10 place-items-center rounded-lg border border-white/10 bg-white/5 lg:hidden"
            onClick={() => setMobileOpen((v) => !v)}
            aria-label="Abrir navegação"
          >
            {mobileOpen ? <X className="size-5" /> : <Menu className="size-5" />}
          </button>
          <Brand />
          <div className="ml-auto hidden w-full max-w-xl items-center md:flex">
            <div className="relative w-full">
              <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-500" />
              <input
                className="hn-search w-full rounded-xl border border-white/8 bg-white/[0.035] py-2.5 pl-10 pr-4 text-sm text-slate-200 outline-none transition placeholder:text-slate-600 focus:border-cyan-400/35 focus:bg-white/[0.055]"
                placeholder="Buscar hunts, criaturas, itens..."
              />
            </div>
          </div>
          <div className="hidden items-center gap-2 xl:flex">
            <span className="rounded-full border border-emerald-400/15 bg-emerald-400/8 px-3 py-1 text-xs text-emerald-300">
              Optimizer online
            </span>
          </div>
        </div>
      </header>

      <div className="mx-auto flex max-w-[1700px]">
        <aside
          className={`fixed inset-y-16 left-0 z-30 w-64 border-r border-white/7 bg-slate-950/96 p-3 backdrop-blur-xl transition-transform lg:sticky lg:top-16 lg:h-[calc(100vh-4rem)] lg:translate-x-0 ${mobileOpen ? "translate-x-0" : "-translate-x-full"}`}
        >
          <nav className="space-y-1">
            {nav.map((item) => {
              const Icon = item.icon;
              const active =
                item.to === "/"
                  ? pathname === "/"
                  : pathname === item.to || pathname.startsWith(`${item.to}/`);
              return (
                <Link
                  key={item.to}
                  to={item.to}
                  onClick={() => setMobileOpen(false)}
                  className={`group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition ${active ? "border border-cyan-400/15 bg-cyan-400/10 text-cyan-100 shadow-[inset_3px_0_0_rgba(34,211,238,.7)]" : "text-slate-400 hover:bg-white/5 hover:text-slate-100"}`}
                >
                  <Icon className={`size-4 ${active ? "text-cyan-300" : "text-slate-500 group-hover:text-slate-300"}`} />
                  <span>{item.label}</span>
                  {active && <ChevronRight className="ml-auto size-3.5 text-cyan-400" />}
                </Link>
              );
            })}
          </nav>

          <div className="mt-6 rounded-2xl border border-white/7 bg-white/[0.025] p-4">
            <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">
              <BarChart3 className="size-3.5" />
              Sessões recentes
            </div>
            <div className="mt-3 space-y-2 text-xs text-slate-400">
              {recentSessions.map((session) => (
                <Link key={session.session_id} to="/sessions" className="block rounded-lg bg-white/[0.025] p-2.5 transition hover:bg-white/[0.05]">
                  <div className="truncate font-medium text-slate-200">{decodeHtml(session.hunt_name || "Hunt sem local")}</div>
                  <div className="mt-1 text-slate-500">{formatCompact(session.xp_per_hour)} XP/h · {session.vocation || "sem vocação"}</div>
                </Link>
              ))}
              {recentSessions.length === 0 && (
                <div className="rounded-lg border border-dashed border-white/7 p-2.5 text-slate-600">Nenhuma sessão recente.</div>
              )}
            </div>
          </div>

          <div className="absolute bottom-4 left-3 right-3">
            <div className="rounded-xl border border-amber-400/10 bg-amber-400/[0.035] p-3 text-[11px] leading-relaxed text-slate-500">
              Conteúdo canônico de Tibia/RubinOT mantém assets oficiais. O HuntNexus estiliza a interface, não o jogo.
            </div>
          </div>
        </aside>

        {mobileOpen && (
          <button
            type="button"
            aria-label="Fechar navegação"
            className="fixed inset-0 top-16 z-20 bg-black/60 lg:hidden"
            onClick={() => setMobileOpen(false)}
          />
        )}

        <main className="relative min-w-0 flex-1 px-4 py-5 lg:px-7 lg:py-7">
          {children}
        </main>
      </div>
    </div>
  );
}

export function OfficialAssetSlot({
  label,
  compact = false,
}: {
  label: string;
  compact?: boolean;
}) {
  return (
    <div className={`hn-asset-slot relative overflow-hidden rounded-xl border border-white/8 bg-slate-900/80 ${compact ? "min-h-24" : "min-h-40"}`}>
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_70%_20%,rgba(34,211,238,.08),transparent_35%),linear-gradient(135deg,rgba(255,255,255,.025),transparent)]" />
      <div className="absolute inset-x-0 bottom-0 border-t border-white/6 bg-slate-950/75 px-3 py-2 text-[10px] uppercase tracking-[0.16em] text-slate-500">
        {label}
      </div>
      <div className="grid h-full min-h-[inherit] place-items-center">
        <div className="flex items-center gap-2 text-xs text-slate-600">
          <BookOpen className="size-4" />
          asset canônico
        </div>
      </div>
    </div>
  );
}


function formatCompact(value: unknown) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "—";
  if (Math.abs(n) >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (Math.abs(n) >= 1_000) return `${Math.round(n / 1_000)}k`;
  return String(Math.round(n));
}

function decodeHtml(value: string) {
  return value.replaceAll("&#39;", "'").replaceAll("&amp;", "&").replaceAll("&quot;", '"');
}
