import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";
import { CheckCircle2, Cloud, Loader2, LogOut, Mail, RefreshCw, ShieldCheck } from "lucide-react";
import type { Session } from "@supabase/supabase-js";
import { callHuntNexusApi } from "@/lib/api/huntnexus";
import { getOrCreateClientId, setClientId } from "@/lib/client-id";
import { getSupabaseBrowserClient } from "@/integrations/supabase/client.browser";

export const Route = createFileRoute("/account")({ component: AccountPage });

const unmergedGuestKey = "huntnexus.unmerged-guest-client-id.v1";
const clientUuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function AccountPage() {
  const [session, setSession] = useState<Session | null>(null);
  const [email, setEmail] = useState("");
  const [sending, setSending] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [syncInfo, setSyncInfo] = useState<any>(null);
  const [recoverableGuestId, setRecoverableGuestId] = useState<string | null>(null);
  const resolvingRef = useRef(false);
  const pendingSessionRef = useRef<Session | null>(null);
  const accessTokenRef = useRef<string | null>(null);

  useEffect(() => {
    const supabase = getSupabaseBrowserClient();
    if (!supabase) return;
    let active = true;
    let authStateEventSeen = false;
    const previouslyGuest = window.localStorage.getItem(unmergedGuestKey);
    if (previouslyGuest && clientUuidPattern.test(previouslyGuest)) {
      setRecoverableGuestId(previouslyGuest);
    }

    supabase.auth.getSession().then(({ data }) => {
      if (!active || authStateEventSeen) return;
      accessTokenRef.current = data.session?.access_token ?? null;
      setSession(data.session ?? null);
      if (data.session) void resolveAccount(data.session);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange((event, nextSession) => {
      if (!active) return;
      authStateEventSeen = true;
      const wasAuthenticated = Boolean(accessTokenRef.current);
      accessTokenRef.current = nextSession?.access_token ?? null;
      setSession(nextSession);
      if (nextSession) {
        void resolveAccount(nextSession);
      } else {
        pendingSessionRef.current = null;
        setSyncInfo(null);
        // SIGNED_OUT can arrive from another tab or an expired/revoked session,
        // not only our local button. A canonical ID must never remain as an
        // apparent guest identity after the Auth session disappears.
        if (event === "SIGNED_OUT" && wasAuthenticated) {
          window.localStorage.removeItem("huntnexus.session-import.draft.v1");
          window.sessionStorage.removeItem("huntnexus.open-player-session");
          setClientId(window.crypto.randomUUID());
          setMessage("Sessão encerrada. Seus dados vinculados continuam protegidos; este navegador iniciou um novo perfil convidado.");
        }
      }
    });

    return () => {
      active = false;
      subscription.subscription.unsubscribe();
    };
  }, []);

  async function preserveUnmergedGuestIfPresent(clientId: string, token: string): Promise<boolean> {
    try {
      const [profile, inventory, sessions] = await Promise.all([
        callHuntNexusApi<any>({ action: "player_profile_get", client_id: clientId, access_token: token }),
        callHuntNexusApi<any>({ action: "player_inventory_get", client_id: clientId, access_token: token }),
        callHuntNexusApi<any>({ action: "player_session_list", client_id: clientId, limit: 1, access_token: token }),
      ]);
      if (accessTokenRef.current !== token) return false;
      const hasGuestData = profile?.data?.exists === true
        || Number(inventory?.data?.summary?.main_slots ?? 0) > 0
        || Number(inventory?.data?.summary?.backpack_items ?? 0) > 0
        || Number(sessions?.data?.summary?.returned ?? 0) > 0;
      if (hasGuestData) {
        window.localStorage.setItem(unmergedGuestKey, clientId);
        setRecoverableGuestId(clientId);
      }
      return hasGuestData;
    } catch {
      // Another signed-in account's bound identity is not a recoverable guest.
      // Scope protection remains authoritative.
      return false;
    }
  }

  async function resolveAccount(currentSession: Session) {
    const localClientId = getOrCreateClientId();
    if (!localClientId || !currentSession.access_token) return;
    if (resolvingRef.current) {
      // A TOKEN_REFRESHED event may arrive while the previous token is still
      // being resolved. Do not silently discard the newest valid session.
      if (accessTokenRef.current === currentSession.access_token) {
        pendingSessionRef.current = currentSession;
      }
      return;
    }
    resolvingRef.current = true;
    setSyncing(true);
    setError("");
    try {
      const requestedAccessToken = currentSession.access_token;
      const response = await callHuntNexusApi<any>({
        action: "account_resolve",
        access_token: currentSession.access_token,
        local_client_id: localClientId,
      });
      if (accessTokenRef.current !== requestedAccessToken) return;
      if (!response?.data?.resolved) throw new Error(response?.data?.error || "account_not_resolved");
      const canonical = response.data.canonical_client_id;
      setSyncInfo(response.data);
      if (canonical && canonical !== localClientId) {
        const guestPreserved = await preserveUnmergedGuestIfPresent(localClientId, requestedAccessToken);
        if (accessTokenRef.current !== requestedAccessToken) return;
        setClientId(canonical);
        setMessage(guestPreserved
          ? "Conta recuperada. Seus dados convidados anteriores foram preservados separadamente e poderão ser retomados após sair da conta."
          : "Conta recuperada. Dados convidados de outro perfil não são mesclados automaticamente.");
        window.setTimeout(() => window.location.reload(), 350);
      } else {
        setMessage(response.data.created
          ? "Conta vinculada aos dados atuais deste navegador."
          : "Conta sincronizada.");
      }
    } catch {
      if (accessTokenRef.current === currentSession.access_token) {
        setError("Não foi possível sincronizar a conta com seus dados do HuntNexus.");
      }
    } finally {
      resolvingRef.current = false;
      setSyncing(false);
      const pending = pendingSessionRef.current;
      pendingSessionRef.current = null;
      if (pending && pending.access_token !== currentSession.access_token &&
          accessTokenRef.current === pending.access_token) {
        void resolveAccount(pending);
      }
    }
  }

  async function sendMagicLink() {
    const supabase = getSupabaseBrowserClient();
    const destination = email.trim();
    if (!supabase || !destination || sending) return;
    setSending(true);
    setError("");
    setMessage("");
    try {
      const { error: authError } = await supabase.auth.signInWithOtp({
        email: destination,
        options: {
          emailRedirectTo: window.location.origin + "/account",
          shouldCreateUser: true,
        },
      });
      if (authError) setError("Não foi possível enviar o link: " + authError.message);
      else setMessage("Solicitação recebida. Confira sua caixa de entrada e spam para acessar a conta.");
    } catch {
      setError("Não foi possível solicitar o link agora. Verifique sua conexão e tente novamente.");
    } finally {
      // An unexpected network exception must not leave the OTP form locked.
      setSending(false);
    }
  }

  function restorePreviousGuest() {
    if (session || !recoverableGuestId || !clientUuidPattern.test(recoverableGuestId)) return;
    setClientId(recoverableGuestId);
    window.localStorage.removeItem(unmergedGuestKey);
    setRecoverableGuestId(null);
    window.location.reload();
  }

  async function signOut() {
    const supabase = getSupabaseBrowserClient();
    if (!supabase) return;
    const beforeSignOut = getOrCreateClientId();
    const { error: signOutError } = await supabase.auth.signOut();
    if (signOutError) {
      setError("Não foi possível encerrar sua sessão. Tente novamente.");
      return;
    }
    // A canonical client identity is protected by the authenticated account.
    // After sign-out, a new guest UUID prevents accidental 401s or access to
    // the previously bound profile without signing in again.
    accessTokenRef.current = null;
    pendingSessionRef.current = null;
    // Raw analyzer drafts can contain player names and private combat data.
    // Do not leak a signed-in account's unsaved draft into guest mode.
    window.localStorage.removeItem("huntnexus.session-import.draft.v1");
    window.sessionStorage.removeItem("huntnexus.open-player-session");
    // The Auth SIGNED_OUT event normally rotates the UUID already. Avoid a
    // second rotation, while keeping a fallback if the event was not emitted.
    if (getOrCreateClientId() === beforeSignOut) {
      setClientId(window.crypto.randomUUID());
    }
    setSession(null);
    setSyncInfo(null);
    setMessage("Sessão encerrada. Os dados salvos continuam na sua conta; rascunhos locais não salvos foram limpos e este navegador iniciou um novo perfil convidado.");
  }

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <section className="hn-hero rounded-3xl border border-white/8 p-6 md:p-8">
        <div className="grid gap-6 xl:grid-cols-[1.1fr_.9fr]">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Conta HuntNexus</div>
            <h1 className="mt-2 text-3xl font-black tracking-tight text-white md:text-4xl">Sincronize seu personagem entre dispositivos.</h1>
            <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-400">Profile, Set Main, BP, sessões e builds continuam privados e passam a usar a mesma identidade canônica quando você entra na sua conta. Dados convidados de outro perfil não são mesclados automaticamente.</p>
          </div>
          <div className="rounded-2xl border border-white/7 bg-slate-950/45 p-5">
            <div className="flex items-center gap-2 text-sm font-semibold text-slate-200"><Cloud className="size-4 text-cyan-300" />Status da sincronização</div>
            <div className="mt-4 space-y-2">
              <StatusRow label="Conta" value={session?.user?.email || "Modo convidado"} ok={Boolean(session)} />
              <StatusRow label="Dados" value={syncInfo?.resolved ? "Sincronizados" : session ? "Sincronizando..." : "Somente neste navegador"} ok={Boolean(syncInfo?.resolved)} />
              <StatusRow label="Privacidade" value="Dados pessoais separados da comunidade" ok />
            </div>
          </div>
        </div>
      </section>

      {!session ? (
        <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
          <div className="flex items-start gap-3">
            <div className="grid size-10 place-items-center rounded-xl bg-cyan-400/10 text-cyan-300"><Mail className="size-4" /></div>
            <div><div className="font-bold text-white">Entrar por e-mail</div><div className="mt-1 text-xs text-slate-500">Sem senha. Você recebe um link de acesso no e-mail.</div></div>
          </div>
          <div className="mt-5 flex flex-col gap-3 sm:flex-row">
            <input type="email" className="hn-control flex-1" placeholder="seu@email.com" value={email} onChange={(event) => setEmail(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") void sendMagicLink(); }} />
            <button className="hn-primary-button" disabled={sending || !email.trim()} onClick={() => void sendMagicLink()}>
              {sending ? <Loader2 className="size-4 animate-spin" /> : <Mail className="size-4" />}
              Enviar link
            </button>
          </div>
          <div className="mt-4 rounded-xl border border-white/7 bg-white/[0.02] p-3 text-xs leading-5 text-slate-500">O modo convidado continua disponível. Criar uma conta serve para recuperar os mesmos dados em outro navegador ou computador.</div>
        </section>
      ) : (
        <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div><div className="flex items-center gap-2 font-bold text-white"><ShieldCheck className="size-4 text-emerald-300" />Conta autenticada</div><div className="mt-1 text-sm text-slate-400">{session.user.email}</div></div>
            <div className="flex flex-wrap gap-2">
              <button type="button" className="hn-secondary-button" disabled={syncing} onClick={() => void resolveAccount(session)}>{syncing ? <Loader2 className="size-4 animate-spin" /> : <RefreshCw className="size-4" />}Sincronizar</button>
              <button type="button" className="hn-secondary-button" onClick={() => void signOut()}><LogOut className="size-4" />Sair</button>
            </div>
          </div>
          {syncInfo?.client_id_changed && syncInfo?.guest_data_merge_applied === false && (
            <div role="status" className="mt-4 rounded-xl border border-amber-300/15 bg-amber-300/[0.035] px-4 py-3 text-xs leading-5 text-amber-100/90">
              Este navegador passou a acessar o perfil já associado à conta. Dados convidados anteriores não foram mesclados ou excluídos; a troca de identidade não transfere automaticamente inventário, sessões ou builds.
            </div>
          )}
          <div className="mt-5 grid gap-3 sm:grid-cols-2">
            <InfoCard title="Perfil vinculado" text={syncInfo?.resolved ? "Acesso protegido pela sua conta" : "Resolvendo..."} />
            <InfoCard title="Comportamento" text={syncInfo?.client_id_changed ? "Este dispositivo foi ligado aos dados já existentes da conta." : "Os dados atuais deste navegador são a base desta conta."} />
          </div>
        </section>
      )}

      {!session && recoverableGuestId && (
        <section className="rounded-2xl border border-amber-300/15 bg-amber-300/[0.035] p-4 text-sm text-slate-300">
          <div className="font-semibold text-amber-100">Dados convidados anteriores encontrados neste navegador</div>
          <p className="mt-2 text-xs leading-5 text-slate-400">Esses dados não foram mesclados à conta. É possível voltar ao perfil convidado anterior enquanto estiver desconectado, sem excluir o que foi salvo na conta.</p>
          <button type="button" className="hn-secondary-button mt-3" onClick={restorePreviousGuest}>Retomar perfil convidado anterior</button>
        </section>
      )}
      {message && <div className="text-sm text-emerald-300">{message}</div>}
      {error && <div className="text-sm text-red-300">{error}</div>}
    </div>
  );
}

function StatusRow({ label, value, ok = false }: { label:string; value:string; ok?:boolean }) {
  return <div className="flex items-center justify-between gap-3 rounded-xl border border-white/6 bg-white/[0.025] px-3 py-2.5"><span className="text-xs text-slate-500">{label}</span><span className="flex items-center gap-1.5 text-xs font-semibold text-slate-300">{ok && <CheckCircle2 className="size-3.5 text-emerald-300" />}{value}</span></div>;
}

function InfoCard({ title, text }: { title:string; text:string }) {
  return <div className="rounded-xl border border-white/7 bg-white/[0.02] p-4"><div className="text-[10px] uppercase tracking-wide text-slate-600">{title}</div><div className="mt-2 break-all text-sm font-semibold text-slate-300">{text}</div></div>;
}