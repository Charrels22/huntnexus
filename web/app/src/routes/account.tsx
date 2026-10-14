import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";
import {
  CheckCircle2,
  Cloud,
  KeyRound,
  Loader2,
  LockKeyhole,
  LogOut,
  Mail,
  Plus,
  RefreshCw,
  ShieldCheck,
  ShieldX,
  Smartphone,
} from "lucide-react";
import type { Factor, Session } from "@supabase/supabase-js";
import { callHuntNexusApi } from "@/lib/api/huntnexus";
import { getOrCreateClientId, setClientId } from "@/lib/client-id";
import { isolateClientAfterAuthLoss, markBoundClientId } from "@/lib/account-session-guard";
import { getSupabaseBrowserClient } from "@/integrations/supabase/client.browser";
import { evaluateAuthGate, minimumPasswordLength, passwordMeetsPolicy, type AuthGateState } from "@/lib/auth-security";

export const Route = createFileRoute("/account")({ component: AccountPage });

const unmergedGuestKey = "huntnexus.unmerged-guest-client-id.v1";
const clientUuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
type AuthMode = "signin" | "signup" | "recover-request" | "recover-update";
type TotpEnrollment = { id: string; qrCode: string; secret: string };

function AccountPage() {
  const [session, setSession] = useState<Session | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const [authMode, setAuthMode] = useState<AuthMode>("signin");
  const [authGate, setAuthGate] = useState<AuthGateState | "loading">("loading");
  const [verifiedFactors, setVerifiedFactors] = useState<Factor[]>([]);
  const [totpCode, setTotpCode] = useState("");
  const [totpEnrollment, setTotpEnrollment] = useState<TotpEnrollment | null>(null);
  const [factorAction, setFactorAction] = useState(false);
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
      if (data.session) void refreshAuthSecurity(data.session, true);
      else setAuthGate("loading");
    });

    const { data: subscription } = supabase.auth.onAuthStateChange((event, nextSession) => {
      if (!active) return;
      authStateEventSeen = true;
      const wasAuthenticated = Boolean(accessTokenRef.current);
      accessTokenRef.current = nextSession?.access_token ?? null;
      setSession(nextSession);
      if (event === "PASSWORD_RECOVERY") setAuthMode("recover-update");
      if (nextSession) {
        void refreshAuthSecurity(nextSession, event !== "PASSWORD_RECOVERY");
      } else {
        pendingSessionRef.current = null;
        setSyncInfo(null);
        setVerifiedFactors([]);
        setTotpEnrollment(null);
        setAuthGate("loading");
        // SIGNED_OUT can arrive from another tab or an expired/revoked session,
        // not only our local button. A canonical ID must never remain as an
        // apparent guest identity after the Auth session disappears.
        if ((event === "SIGNED_OUT" || event === "INITIAL_SESSION") &&
            isolateClientAfterAuthLoss(event === "SIGNED_OUT" && wasAuthenticated)) {
          setMessage("Sessão encerrada. Seus dados vinculados continuam protegidos; este navegador iniciou um novo perfil convidado.");
        }
      }
    });

    return () => {
      active = false;
      subscription.subscription.unsubscribe();
    };
  }, []);

  async function refreshAuthSecurity(currentSession: Session, allowAccountResolve = true) {
    const supabase = getSupabaseBrowserClient();
    if (!supabase || accessTokenRef.current !== currentSession.access_token) return;
    setAuthGate("loading");
    setError("");
    const [{ data: assurance, error: assuranceError }, { data: factorsData, error: factorsError }] = await Promise.all([
      supabase.auth.mfa.getAuthenticatorAssuranceLevel(),
      supabase.auth.mfa.listFactors(),
    ]);
    if (accessTokenRef.current !== currentSession.access_token) return;
    if (assuranceError || factorsError || !assurance || !factorsData) {
      setError("Não foi possível conferir a proteção da sessão.");
      setAuthGate("invalid_session");
      return;
    }
    const factors = factorsData.totp.filter((factor) => factor.status === "verified");
    setVerifiedFactors(factors);
    const nextGate = evaluateAuthGate({
      currentLevel: assurance.currentLevel,
      nextLevel: assurance.nextLevel,
      verifiedFactorCount: factors.length,
      activeSession: true,
    });
    setAuthGate(nextGate);
    if (nextGate === "ready" && allowAccountResolve) {
      void resolveAccount(currentSession);
    }
  }

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
      if (typeof canonical !== "string" || !clientUuidPattern.test(canonical)) {
        throw new Error("invalid_canonical_client_id");
      }
      setSyncInfo(response.data);
      if (canonical && canonical !== localClientId) {
        const guestPreserved = await preserveUnmergedGuestIfPresent(localClientId, requestedAccessToken);
        if (accessTokenRef.current !== requestedAccessToken) return;
        if (!setClientId(canonical) || !markBoundClientId(canonical)) {
          throw new Error("canonical_scope_not_persisted");
        }
        setMessage(guestPreserved
          ? "Conta recuperada. Seus dados convidados anteriores foram preservados separadamente e poderão ser retomados após sair da conta."
          : "Conta recuperada. Dados convidados de outro perfil não são mesclados automaticamente.");
        window.setTimeout(() => window.location.reload(), 350);
      } else {
        if (!markBoundClientId(canonical)) throw new Error("canonical_scope_not_persisted");
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

  async function submitCredentials() {
    const supabase = getSupabaseBrowserClient();
    const destination = email.trim();
    if (!supabase || !destination || sending || !passwordMeetsPolicy(password)) return;
    if (authMode === "signup" && password !== passwordConfirmation) {
      setError("A confirmação da senha não confere.");
      return;
    }
    setSending(true);
    setError("");
    setMessage("");
    try {
      const result = authMode === "signup"
        ? await supabase.auth.signUp({
            email: destination,
            password,
            options: { emailRedirectTo: window.location.origin + "/account" },
          })
        : await supabase.auth.signInWithPassword({ email: destination, password });
      if (result.error) {
        setError("Não foi possível autenticar: " + result.error.message);
      } else if (authMode === "signup" && !result.data.session) {
        setMessage("Conta criada. Confirme o e-mail e depois entre com sua senha.");
      } else {
        setMessage("Primeiro fator validado. Conclua a proteção por aplicativo autenticador.");
      }
    } catch {
      setError("Não foi possível autenticar agora. Verifique sua conexão e tente novamente.");
    } finally {
      setSending(false);
    }
  }

  async function requestPasswordRecovery() {
    const supabase = getSupabaseBrowserClient();
    const destination = email.trim();
    if (!supabase || !destination || sending) return;
    setSending(true);
    setError("");
    setMessage("");
    try {
      const { error: authError } = await supabase.auth.resetPasswordForEmail(destination, {
        redirectTo: window.location.origin + "/account",
      });
      if (authError) setError("Não foi possível iniciar a recuperação: " + authError.message);
      else setMessage("Se a conta existir, o e-mail de recuperação será enviado.");
    } catch {
      setError("Não foi possível iniciar a recuperação agora.");
    } finally {
      setSending(false);
    }
  }

  async function updateRecoveredPassword() {
    const supabase = getSupabaseBrowserClient();
    if (!supabase || sending || !passwordMeetsPolicy(password)) return;
    if (password !== passwordConfirmation) {
      setError("A confirmação da senha não confere.");
      return;
    }
    setSending(true);
    setError("");
    const { error: authError } = await supabase.auth.updateUser({ password });
    if (authError) setError("Não foi possível definir a nova senha: " + authError.message);
    else {
      setMessage("Senha alterada. O segundo fator continua obrigatório para acessar dados privados.");
      setPassword("");
      setPasswordConfirmation("");
      setAuthMode("signin");
      if (session) void refreshAuthSecurity(session);
    }
    setSending(false);
  }

  async function beginTotpEnrollment() {
    const supabase = getSupabaseBrowserClient();
    if (!supabase || factorAction) return;
    setFactorAction(true);
    setError("");
    const { data, error: enrollError } = await supabase.auth.mfa.enroll({
      factorType: "totp",
      friendlyName: verifiedFactors.length === 0 ? "HuntNexus principal" : `HuntNexus reserva ${verifiedFactors.length + 1}`,
    });
    if (enrollError || !data) setError("Não foi possível iniciar o segundo fator: " + (enrollError?.message ?? "erro desconhecido"));
    else setTotpEnrollment({ id: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret });
    setFactorAction(false);
  }

  async function verifyEnrollment() {
    const supabase = getSupabaseBrowserClient();
    if (!supabase || !session || !totpEnrollment || totpCode.trim().length !== 6 || factorAction) return;
    setFactorAction(true);
    setError("");
    const { error: verifyError } = await supabase.auth.mfa.challengeAndVerify({
      factorId: totpEnrollment.id,
      code: totpCode.trim(),
    });
    if (verifyError) setError("Código inválido ou expirado: " + verifyError.message);
    else {
      setTotpEnrollment(null);
      setTotpCode("");
      setMessage("Aplicativo autenticador confirmado.");
      const { data } = await supabase.auth.getSession();
      if (data.session) {
        accessTokenRef.current = data.session.access_token;
        setSession(data.session);
        await refreshAuthSecurity(data.session);
      }
    }
    setFactorAction(false);
  }

  async function verifyExistingFactor(factorId: string) {
    const supabase = getSupabaseBrowserClient();
    if (!supabase || !session || totpCode.trim().length !== 6 || factorAction) return;
    setFactorAction(true);
    setError("");
    const { error: verifyError } = await supabase.auth.mfa.challengeAndVerify({ factorId, code: totpCode.trim() });
    if (verifyError) setError("Código inválido ou expirado: " + verifyError.message);
    else {
      setTotpCode("");
      setMessage("Segundo fator confirmado.");
      const { data } = await supabase.auth.getSession();
      if (data.session) {
        accessTokenRef.current = data.session.access_token;
        setSession(data.session);
        await refreshAuthSecurity(data.session);
      }
    }
    setFactorAction(false);
  }

  async function removeBackupFactor(factorId: string) {
    const supabase = getSupabaseBrowserClient();
    if (!supabase || !session || verifiedFactors.length < 2 || authGate !== "ready" || factorAction) return;
    setFactorAction(true);
    setError("");
    const { error: unenrollError } = await supabase.auth.mfa.unenroll({ factorId });
    if (unenrollError) setError("Não foi possível remover o autenticador: " + unenrollError.message);
    else {
      setMessage("Autenticador reserva removido. Ao menos um fator verificado foi preservado.");
      await refreshAuthSecurity(session);
    }
    setFactorAction(false);
  }

  function restorePreviousGuest() {
    if (session || !recoverableGuestId || !clientUuidPattern.test(recoverableGuestId)) return;
    setClientId(recoverableGuestId);
    window.localStorage.removeItem(unmergedGuestKey);
    setRecoverableGuestId(null);
    window.location.reload();
  }

  async function signOut(scope: "local" | "global" = "local") {
    const supabase = getSupabaseBrowserClient();
    if (!supabase) return;
    const beforeSignOut = getOrCreateClientId();
    const { error: signOutError } = await supabase.auth.signOut({ scope });
    if (signOutError) {
      setError("Não foi possível encerrar sua sessão. Tente novamente.");
      return;
    }
    // A canonical client identity is protected by the authenticated account.
    // After sign-out, a new guest UUID prevents accidental 401s or access to
    // the previously bound profile without signing in again.
    accessTokenRef.current = null;
    pendingSessionRef.current = null;
    // If SIGNED_OUT already isolated this scope, do not rotate it twice.
    // Otherwise fall back to one protected cleanup after signOut succeeds.
    if (getOrCreateClientId() === beforeSignOut) {
      isolateClientAfterAuthLoss(true);
    }
    setSession(null);
    setSyncInfo(null);
    setMessage(scope === "global"
      ? "Sessões encerradas em todos os dispositivos. Os dados salvos continuam protegidos na conta."
      : "Sessão encerrada neste dispositivo. Os dados salvos continuam protegidos na conta.");
  }

  async function signOutOtherSessions() {
    const supabase = getSupabaseBrowserClient();
    if (!supabase || factorAction) return;
    setFactorAction(true);
    setError("");
    const { error: signOutError } = await supabase.auth.signOut({ scope: "others" });
    if (signOutError) setError("Não foi possível encerrar as outras sessões: " + signOutError.message);
    else setMessage("As outras sessões foram encerradas. Esta sessão continua ativa.");
    setFactorAction(false);
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

      {authMode === "recover-update" && session ? (
        <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
          <div className="flex items-start gap-3">
            <div className="grid size-10 place-items-center rounded-xl bg-cyan-400/10 text-cyan-300"><KeyRound className="size-4" /></div>
            <div><div className="font-bold text-white">Definir nova senha</div><div className="mt-1 text-xs text-slate-500">O link recupera apenas a senha. Seu autenticador continua obrigatório para abrir dados privados.</div></div>
          </div>
          <div className="mt-5 grid gap-3 sm:grid-cols-2">
            <PasswordInput value={password} placeholder={`Nova senha (${minimumPasswordLength}+ caracteres)`} autoComplete="new-password" onChange={setPassword} />
            <PasswordInput value={passwordConfirmation} placeholder="Confirmar nova senha" autoComplete="new-password" onChange={setPasswordConfirmation} onEnter={() => void updateRecoveredPassword()} />
          </div>
          <button className="hn-primary-button mt-3" disabled={sending || !passwordMeetsPolicy(password) || password !== passwordConfirmation} onClick={() => void updateRecoveredPassword()}>
            {sending ? <Loader2 className="size-4 animate-spin" /> : <KeyRound className="size-4" />}Salvar nova senha
          </button>
        </section>
      ) : !session ? (
        <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
          <div className="flex items-start gap-3">
            <div className="grid size-10 place-items-center rounded-xl bg-cyan-400/10 text-cyan-300"><LockKeyhole className="size-4" /></div>
            <div><div className="font-bold text-white">{authMode === "signup" ? "Criar conta protegida" : authMode === "recover-request" ? "Recuperar senha" : "Entrar com senha"}</div><div className="mt-1 text-xs text-slate-500">Senha e aplicativo autenticador protegem os dados. O e-mail sozinho não libera o perfil.</div></div>
          </div>
          <div className="mt-5 grid gap-3">
            <input type="email" autoComplete="email" aria-label="E-mail" className="hn-control" placeholder="seu@email.com" value={email} onChange={(event) => setEmail(event.target.value)} />
            {authMode !== "recover-request" && <PasswordInput value={password} placeholder={`Senha (${minimumPasswordLength}+ caracteres)`} autoComplete={authMode === "signup" ? "new-password" : "current-password"} onChange={setPassword} onEnter={() => void submitCredentials()} />}
            {authMode === "signup" && <PasswordInput value={passwordConfirmation} placeholder="Confirmar senha" autoComplete="new-password" onChange={setPasswordConfirmation} onEnter={() => void submitCredentials()} />}
            <button className="hn-primary-button" disabled={sending || !email.trim() || (authMode !== "recover-request" && !passwordMeetsPolicy(password)) || (authMode === "signup" && password !== passwordConfirmation)} onClick={() => void (authMode === "recover-request" ? requestPasswordRecovery() : submitCredentials())}>
              {sending ? <Loader2 className="size-4 animate-spin" /> : authMode === "recover-request" ? <Mail className="size-4" /> : <LockKeyhole className="size-4" />}
              {authMode === "signup" ? "Criar conta" : authMode === "recover-request" ? "Enviar recuperação" : "Entrar"}
            </button>
          </div>
          <div className="mt-4 flex flex-wrap gap-2 text-xs">
            {authMode !== "signin" && <button type="button" className="text-cyan-300 hover:text-cyan-200" onClick={() => setAuthMode("signin")}>Já tenho conta</button>}
            {authMode !== "signup" && <button type="button" className="text-cyan-300 hover:text-cyan-200" onClick={() => setAuthMode("signup")}>Criar conta</button>}
            {authMode !== "recover-request" && <button type="button" className="text-slate-400 hover:text-slate-300" onClick={() => setAuthMode("recover-request")}>Esqueci a senha</button>}
          </div>
          <div className="mt-4 rounded-xl border border-white/7 bg-white/[0.02] p-3 text-xs leading-5 text-slate-500">O modo convidado continua disponível. Uma conta representa o jogador e pode possuir vários personagens.</div>
        </section>
      ) : (
        <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div><div className="flex items-center gap-2 font-bold text-white"><ShieldCheck className="size-4 text-emerald-300" />Conta autenticada</div><div className="mt-1 text-sm text-slate-400">{session.user.email}</div></div>
            <button type="button" className="hn-secondary-button" onClick={() => void signOut("local")}><LogOut className="size-4" />Sair deste dispositivo</button>
          </div>
          {authGate === "loading" && <div className="mt-5 flex items-center gap-2 text-sm text-slate-400"><Loader2 className="size-4 animate-spin" />Verificando sessão e fatores...</div>}
          {authGate === "invalid_session" && <div className="mt-5 rounded-xl border border-red-300/15 bg-red-300/[0.035] p-4 text-sm text-red-200"><ShieldX className="mr-2 inline size-4" />A sessão não pôde ser validada. Entre novamente.</div>}
          {authGate === "mfa_enrollment_required" && !totpEnrollment && (
            <div className="mt-5 rounded-2xl border border-amber-300/15 bg-amber-300/[0.035] p-5">
              <div className="flex items-center gap-2 font-semibold text-amber-100"><Smartphone className="size-4" />Proteção obrigatória pendente</div>
              <p className="mt-2 text-xs leading-5 text-slate-400">Cadastre um aplicativo autenticador. Até concluir, Profile, personagens, inventário, sessões e builds permanecem bloqueados.</p>
              <button className="hn-primary-button mt-4" disabled={factorAction} onClick={() => void beginTotpEnrollment()}>{factorAction ? <Loader2 className="size-4 animate-spin" /> : <Plus className="size-4" />}Cadastrar autenticador</button>
            </div>
          )}
          {totpEnrollment && <TotpEnrollmentPanel enrollment={totpEnrollment} code={totpCode} busy={factorAction} onCode={setTotpCode} onVerify={() => void verifyEnrollment()} />}
          {authGate === "mfa_challenge_required" && verifiedFactors[0] && (
            <div className="mt-5 rounded-2xl border border-cyan-300/15 bg-cyan-300/[0.035] p-5">
              <div className="font-semibold text-cyan-100">Confirme o segundo fator</div>
              <p className="mt-2 text-xs leading-5 text-slate-400">Digite o código de seis dígitos do seu aplicativo autenticador.</p>
              <div className="mt-4 flex flex-col gap-3 sm:flex-row"><OtpInput value={totpCode} onChange={setTotpCode} onEnter={() => void verifyExistingFactor(verifiedFactors[0]!.id)} /><button className="hn-primary-button" disabled={factorAction || totpCode.trim().length !== 6} onClick={() => void verifyExistingFactor(verifiedFactors[0]!.id)}>{factorAction ? <Loader2 className="size-4 animate-spin" /> : <ShieldCheck className="size-4" />}Confirmar</button></div>
            </div>
          )}
          {authGate === "ready" && (
            <>
              <div className="mt-5 flex flex-wrap gap-2">
                <button type="button" className="hn-secondary-button" disabled={syncing} onClick={() => void resolveAccount(session)}>{syncing ? <Loader2 className="size-4 animate-spin" /> : <RefreshCw className="size-4" />}Sincronizar</button>
                <button type="button" className="hn-secondary-button" disabled={factorAction} onClick={() => void signOutOtherSessions()}>Encerrar outras sessões</button>
                <button type="button" className="hn-secondary-button" onClick={() => void signOut("global")}>Sair de todos</button>
                {!totpEnrollment && <button type="button" className="hn-secondary-button" disabled={factorAction} onClick={() => void beginTotpEnrollment()}><Plus className="size-4" />Adicionar autenticador reserva</button>}
              </div>
              <div className="mt-4 grid gap-2 sm:grid-cols-2">
                {verifiedFactors.map((factor, index) => <div key={factor.id} className="rounded-xl border border-white/7 bg-white/[0.02] p-3 text-xs text-slate-400"><div className="font-semibold text-slate-200">{factor.friendly_name || `Autenticador ${index + 1}`}</div><div className="mt-1">TOTP verificado</div>{verifiedFactors.length > 1 && <button className="mt-2 text-red-300 hover:text-red-200" disabled={factorAction} onClick={() => void removeBackupFactor(factor.id)}>Remover</button>}</div>)}
              </div>
            </>
          )}
          {authGate === "ready" && syncInfo?.client_id_changed && syncInfo?.guest_data_merge_applied === false && (
            <div role="status" className="mt-4 rounded-xl border border-amber-300/15 bg-amber-300/[0.035] px-4 py-3 text-xs leading-5 text-amber-100/90">
              Este navegador passou a acessar o perfil já associado à conta. Dados convidados anteriores não foram mesclados ou excluídos; a troca de identidade não transfere automaticamente inventário, sessões ou builds.
            </div>
          )}
          {authGate === "ready" && <div className="mt-5 grid gap-3 sm:grid-cols-2">
            <InfoCard title="Perfil vinculado" text={syncInfo?.resolved ? "Acesso protegido pela sua conta" : "Resolvendo..."} />
            <InfoCard title="Comportamento" text={syncInfo?.client_id_changed ? "Este dispositivo foi ligado aos dados já existentes da conta." : "Os dados atuais deste navegador são a base desta conta."} />
          </div>}
        </section>
      )}

      {!session && recoverableGuestId && (
        <section className="rounded-2xl border border-amber-300/15 bg-amber-300/[0.035] p-4 text-sm text-slate-300">
          <div className="font-semibold text-amber-100">Dados convidados anteriores encontrados neste navegador</div>
          <p className="mt-2 text-xs leading-5 text-slate-400">Esses dados não foram mesclados à conta. É possível voltar ao perfil convidado anterior enquanto estiver desconectado, sem excluir o que foi salvo na conta.</p>
          <button type="button" className="hn-secondary-button mt-3" onClick={restorePreviousGuest}>Retomar perfil convidado anterior</button>
        </section>
      )}
      {message && <div role="status" className="text-sm text-emerald-300">{message}</div>}
      {error && <div role="alert" className="text-sm text-red-300">{error}</div>}
    </div>
  );
}

function StatusRow({ label, value, ok = false }: { label:string; value:string; ok?:boolean }) {
  return <div className="flex items-center justify-between gap-3 rounded-xl border border-white/6 bg-white/[0.025] px-3 py-2.5"><span className="text-xs text-slate-500">{label}</span><span className="flex items-center gap-1.5 text-xs font-semibold text-slate-300">{ok && <CheckCircle2 className="size-3.5 text-emerald-300" />}{value}</span></div>;
}

function InfoCard({ title, text }: { title:string; text:string }) {
  return <div className="rounded-xl border border-white/7 bg-white/[0.02] p-4"><div className="text-[10px] uppercase tracking-wide text-slate-600">{title}</div><div className="mt-2 break-all text-sm font-semibold text-slate-300">{text}</div></div>;
}

function PasswordInput({ value, placeholder, autoComplete, onChange, onEnter }: { value:string; placeholder:string; autoComplete:"current-password"|"new-password"; onChange:(value:string)=>void; onEnter?:()=>void }) {
  return <input type="password" autoComplete={autoComplete} aria-label={placeholder} className="hn-control" placeholder={placeholder} value={value} onChange={(event) => onChange(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") onEnter?.(); }} />;
}

function OtpInput({ value, onChange, onEnter }: { value:string; onChange:(value:string)=>void; onEnter:()=>void }) {
  return <input inputMode="numeric" autoComplete="one-time-code" className="hn-control flex-1" aria-label="Código de seis dígitos" placeholder="000000" maxLength={6} value={value} onChange={(event) => onChange(event.target.value.replace(/\D/g, "").slice(0, 6))} onKeyDown={(event) => { if (event.key === "Enter") onEnter(); }} />;
}

function TotpEnrollmentPanel({ enrollment, code, busy, onCode, onVerify }: { enrollment:TotpEnrollment; code:string; busy:boolean; onCode:(value:string)=>void; onVerify:()=>void }) {
  return <div className="mt-5 rounded-2xl border border-cyan-300/15 bg-cyan-300/[0.035] p-5">
    <div className="font-semibold text-cyan-100">Cadastrar aplicativo autenticador</div>
    <p className="mt-2 text-xs leading-5 text-slate-400">Leia o QR code no autenticador. Guarde a chave em local seguro e confirme um código. Um segundo autenticador pode ser cadastrado como recuperação.</p>
    <div className="mt-4 grid gap-4 md:grid-cols-[180px_1fr]">
      <img src={enrollment.qrCode} alt="QR code para cadastrar TOTP" className="size-44 rounded-xl bg-white p-2" />
      <div><div className="text-[10px] uppercase tracking-wide text-slate-500">Chave manual</div><code className="mt-2 block break-all rounded-lg bg-slate-950/70 p-3 text-xs text-slate-300">{enrollment.secret}</code><div className="mt-3 flex flex-col gap-3 sm:flex-row"><OtpInput value={code} onChange={onCode} onEnter={onVerify} /><button className="hn-primary-button" disabled={busy || code.trim().length !== 6} onClick={onVerify}>{busy ? <Loader2 className="size-4 animate-spin" /> : <ShieldCheck className="size-4" />}Verificar</button></div></div>
    </div>
  </div>;
}
