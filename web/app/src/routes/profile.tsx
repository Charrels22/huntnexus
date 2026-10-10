import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import {
  CheckCircle2,
  Cloud,
  Loader2,
  RefreshCw,
  Save,
  Search,
  ShieldCheck,
  Sparkles,
  Swords,
  UserRound,
  Wifi,
  WifiOff,
} from "lucide-react";
import { callHuntNexusApi } from "@/lib/api/huntnexus";
import { getOrCreateClientId } from "@/lib/client-id";

export const Route = createFileRoute("/profile")({ component: ProfilePage });

type FormState = {
  character_name: string;
  world_name: string;
  vocation: string;
  level: string;
  online: boolean | null;
  former_names: string[];
  official_lookup_at: string | null;
  official_lookup_status: string | null;
  weapon_family: string;
  sword: string;
  axe: string;
  club: string;
  distance: string;
  fist: string;
  shielding: string;
  magic_level: string;
  effective_weapon_skill: string;
  effective_magic_level: string;
  effective_shielding: string;
  effective_distance_skill: string;
  effective_fist_skill: string;
  hunt_objective: "xp" | "profit" | "balanced";
  set_objective: "offense" | "defense" | "sustain" | "utility" | "balanced";
  party_size: string;
};

const emptyForm: FormState = {
  character_name: "",
  world_name: "",
  vocation: "",
  level: "",
  online: null,
  former_names: [],
  official_lookup_at: null,
  official_lookup_status: null,
  weapon_family: "",
  sword: "",
  axe: "",
  club: "",
  distance: "",
  fist: "",
  shielding: "",
  magic_level: "",
  effective_weapon_skill: "",
  effective_magic_level: "",
  effective_shielding: "",
  effective_distance_skill: "",
  effective_fist_skill: "",
  hunt_objective: "balanced",
  set_objective: "balanced",
  party_size: "1",
};

function ProfilePage() {
  const [form, setForm] = useState<FormState>(emptyForm);
  const [loading, setLoading] = useState(true);
  const [lookingUp, setLookingUp] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    const clientId = getOrCreateClientId();
    if (!clientId) return;

    callHuntNexusApi<any>({ action: "player_profile_get", client_id: clientId })
      .then((response) => {
        const p = response?.data?.profile;
        if (!p) return;
        const stats = p.manual_stats ?? {};
        const defaults = p.defaults ?? {};
        setForm({
          ...emptyForm,
          character_name: p.character_name ?? "",
          world_name: p.world_name ?? "",
          vocation: p.vocation ?? "",
          level: p.level == null ? "" : String(p.level),
          online: typeof p.online === "boolean" ? p.online : null,
          former_names: Array.isArray(p.former_names) ? p.former_names : [],
          official_lookup_at: p.official_lookup_at ?? null,
          official_lookup_status: p.official_lookup_status ?? null,
          weapon_family: stats.weapon_family ?? "",
          sword: toString(stats.sword),
          axe: toString(stats.axe),
          club: toString(stats.club),
          distance: toString(stats.distance),
          fist: toString(stats.fist),
          shielding: toString(stats.shielding),
          magic_level: toString(stats.magic_level),
          effective_weapon_skill: toString(stats.effective_weapon_skill),
          effective_magic_level: toString(stats.effective_magic_level),
          effective_shielding: toString(stats.effective_shielding),
          effective_distance_skill: toString(stats.effective_distance_skill),
          effective_fist_skill: toString(stats.effective_fist_skill),
          hunt_objective: defaults.hunt_objective ?? "balanced",
          set_objective: defaults.set_objective ?? "balanced",
          party_size: String(defaults.party_size ?? 1),
        });
      })
      .catch(() => setError("Não foi possível carregar o perfil salvo."))
      .finally(() => setLoading(false));
  }, []);

  const officialFields = useMemo(
    () => [form.character_name, form.world_name, form.vocation, form.level].filter(Boolean).length,
    [form.character_name, form.world_name, form.vocation, form.level],
  );

  function patch<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((current) => ({ ...current, [key]: value }));
  }

  async function lookup() {
    const name = form.character_name.trim();
    if (name.length < 2 || lookingUp) return;

    setLookingUp(true);
    setError("");
    setMessage("");

    try {
      const response = await callHuntNexusApi<any>({ action: "character_lookup", name });
      if (!response?.data) {
        setError("Personagem não encontrado ou consulta do RubinOT indisponível. Você pode preencher o perfil manualmente.");
        patch("official_lookup_status", response?.lookup_status ?? "not_found");
        return;
      }

      const p = response.data;
      setForm((current) => ({
        ...current,
        character_name: p.character_name || current.character_name,
        world_name: p.world_name || current.world_name,
        vocation: p.vocation || current.vocation,
        level: p.level == null ? current.level : String(p.level),
        online: typeof p.online === "boolean" ? p.online : current.online,
        former_names: Array.isArray(p.former_names) ? p.former_names : [],
        official_lookup_at: response.looked_up_at ?? new Date().toISOString(),
        official_lookup_status: "found",
      }));
      setMessage("Dados públicos carregados do RubinOT.");
    } catch {
      setError("Não foi possível consultar o RubinOT agora. O preenchimento manual continua disponível.");
    } finally {
      setLookingUp(false);
    }
  }

  async function save() {
    const clientId = getOrCreateClientId();
    if (!clientId || saving) return;

    setSaving(true);
    setError("");
    setMessage("");

    const manualStats = compactObject({
      weapon_family: form.weapon_family,
      sword: numberOrNull(form.sword),
      axe: numberOrNull(form.axe),
      club: numberOrNull(form.club),
      distance: numberOrNull(form.distance),
      fist: numberOrNull(form.fist),
      shielding: numberOrNull(form.shielding),
      magic_level: numberOrNull(form.magic_level),
      effective_weapon_skill: numberOrNull(form.effective_weapon_skill),
      effective_magic_level: numberOrNull(form.effective_magic_level),
      effective_shielding: numberOrNull(form.effective_shielding),
      effective_distance_skill: numberOrNull(form.effective_distance_skill),
      effective_fist_skill: numberOrNull(form.effective_fist_skill),
    });

    try {
      const response = await callHuntNexusApi<any>({
        action: "player_profile_save",
        client_id: clientId,
        profile: {
          character_name: form.character_name,
          world_name: form.world_name,
          vocation: form.vocation,
          level: form.level,
          online: form.online,
          former_names: form.former_names,
          official_lookup_at: form.official_lookup_at,
          official_lookup_status: form.official_lookup_status,
          manual_stats: manualStats,
          proficiency_selections: {},
          defaults: {
            hunt_objective: form.hunt_objective,
            set_objective: form.set_objective,
            party_size: Number(form.party_size),
          },
        },
      });

      if (!response?.data?.saved) throw new Error("profile_not_saved");
      setMessage("Perfil salvo. Planner e Session Analyzer passarão a reutilizar esses dados.");
      window.dispatchEvent(new Event("huntnexus:profile-changed"));
    } catch {
      setError("Não foi possível salvar o perfil.");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return <div className="grid min-h-[70vh] place-items-center"><Loader2 className="size-7 animate-spin text-cyan-300" /></div>;
  }

  return (
    <div className="mx-auto max-w-[1320px] space-y-6">
      <section className="hn-hero overflow-hidden rounded-3xl border border-white/8 p-5 md:p-7">
        <div className="grid gap-6 xl:grid-cols-[1fr_.8fr]">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Character Profile</div>
            <h1 className="mt-2 text-3xl font-black tracking-tight text-white md:text-4xl">Seu personagem como contexto padrão do HuntNexus.</h1>
            <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-400">
              Busque o personagem no RubinOT para preencher os dados públicos. Skills, valores efetivos e Proficiency continuam sob seu controle.
            </p>

            <div className="mt-6 flex max-w-2xl gap-2">
              <div className="relative flex-1">
                <UserRound className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-500" />
                <input
                  className="hn-control pl-10"
                  value={form.character_name}
                  onChange={(e) => patch("character_name", e.target.value)}
                  onKeyDown={(e) => { if (e.key === "Enter") void lookup(); }}
                  placeholder="Nome do personagem no RubinOT"
                />
              </div>
              <button className="hn-primary-button shrink-0" onClick={() => void lookup()} disabled={lookingUp || form.character_name.trim().length < 2}>
                {lookingUp ? <Loader2 className="size-4 animate-spin" /> : <Search className="size-4" />}
                Buscar
              </button>
            </div>

            {message && <div className="mt-4 text-sm text-emerald-300">{message}</div>}
            {error && <div className="mt-4 text-sm text-amber-200">{error}</div>}
          </div>

          <div className="rounded-2xl border border-white/7 bg-slate-950/45 p-5">
            <div className="flex items-center justify-between">
              <div className="text-sm font-semibold text-slate-200">RubinOT oficial</div>
              {form.online === true ? <Wifi className="size-4 text-emerald-300" /> : form.online === false ? <WifiOff className="size-4 text-slate-600" /> : <Cloud className="size-4 text-slate-600" />}
            </div>
            <div className="mt-4 grid grid-cols-2 gap-2">
              <Summary label="Nome" value={form.character_name || "—"} />
              <Summary label="Mundo" value={form.world_name || "—"} />
              <Summary label="Vocação" value={form.vocation || "—"} />
              <Summary label="Level" value={form.level || "—"} />
            </div>
            <div className="mt-3 text-[11px] text-slate-500">
              {officialFields === 4 ? "Perfil público identificado." : "Você pode preencher ou corrigir os campos manualmente."}
            </div>
            {form.former_names.length > 0 && (
              <div className="mt-3 rounded-xl border border-white/6 bg-white/[0.025] p-3 text-xs text-slate-400">
                Nomes anteriores: {form.former_names.join(", ")}
              </div>
            )}
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
        <SectionTitle icon={ShieldCheck} title="Dados públicos" subtitle="Preenchidos pela busca quando o RubinOT disponibiliza; todos continuam editáveis." />
        <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <Field label="Mundo"><input className="hn-control" value={form.world_name} onChange={(e) => patch("world_name", e.target.value)} /></Field>
          <Field label="Vocação">
            <select className="hn-control" value={form.vocation} onChange={(e) => patch("vocation", e.target.value)}>
              <option value="">Selecionar</option>
              <option value="EK">Elite Knight</option><option value="RP">Royal Paladin</option><option value="ED">Elder Druid</option><option value="MS">Master Sorcerer</option><option value="EM">Exalted Monk</option>
            </select>
          </Field>
          <Field label="Level"><input className="hn-control" type="number" min="1" value={form.level} onChange={(e) => patch("level", e.target.value)} /></Field>
          <Field label="Status">
            <div className="hn-control flex items-center gap-2">
              {form.online === true ? <><span className="size-2 rounded-full bg-emerald-400" /> Online</> : form.online === false ? <><span className="size-2 rounded-full bg-slate-600" /> Offline</> : "Não informado"}
            </div>
          </Field>
        </div>
      </section>

      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
        <SectionTitle icon={Swords} title="Skills e contexto do optimizer" subtitle="Valores que não dependem da página pública do RubinOT." />
        <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Field label="Weapon family">
            <select className="hn-control" value={form.weapon_family} onChange={(e) => patch("weapon_family", e.target.value)}>
              <option value="">Automático / não informado</option>
              <option value="sword">Sword</option><option value="axe">Axe</option><option value="club">Club</option><option value="distance">Distance</option><option value="fist">Fist</option><option value="rod">Rod</option><option value="wand">Wand</option>
            </select>
          </Field>
          <Field label="Sword"><NumberInput value={form.sword} onChange={(v) => patch("sword", v)} /></Field>
          <Field label="Axe"><NumberInput value={form.axe} onChange={(v) => patch("axe", v)} /></Field>
          <Field label="Club"><NumberInput value={form.club} onChange={(v) => patch("club", v)} /></Field>
          <Field label="Distance"><NumberInput value={form.distance} onChange={(v) => patch("distance", v)} /></Field>
          <Field label="Fist"><NumberInput value={form.fist} onChange={(v) => patch("fist", v)} /></Field>
          <Field label="Shielding"><NumberInput value={form.shielding} onChange={(v) => patch("shielding", v)} /></Field>
          <Field label="Magic Level"><NumberInput value={form.magic_level} onChange={(v) => patch("magic_level", v)} /></Field>
        </div>

        <div className="mt-6 border-t border-white/7 pt-5">
          <div className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan-400">Valores efetivos</div>
          <p className="mt-1 text-xs text-slate-500">Use quando bônus/equipment alterarem o valor usado no optimizer.</p>
          <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            <Field label="Weapon skill"><NumberInput value={form.effective_weapon_skill} onChange={(v) => patch("effective_weapon_skill", v)} /></Field>
            <Field label="Magic level"><NumberInput value={form.effective_magic_level} onChange={(v) => patch("effective_magic_level", v)} /></Field>
            <Field label="Shielding"><NumberInput value={form.effective_shielding} onChange={(v) => patch("effective_shielding", v)} /></Field>
            <Field label="Distance"><NumberInput value={form.effective_distance_skill} onChange={(v) => patch("effective_distance_skill", v)} /></Field>
            <Field label="Fist"><NumberInput value={form.effective_fist_skill} onChange={(v) => patch("effective_fist_skill", v)} /></Field>
          </div>
        </div>

        <div className="mt-5 rounded-2xl border border-amber-400/10 bg-amber-400/[0.035] p-4 text-xs leading-5 text-slate-500">
          Weapon Proficiency continuará vinculada às árvores/itens exatos do nosso banco. Não vou transformar isso em um campo numérico genérico.
        </div>
      </section>

      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
        <SectionTitle icon={Sparkles} title="Preferências padrão" subtitle="Usadas automaticamente quando você abrir o Hunt Planner." />
        <div className="mt-5 grid gap-4 sm:grid-cols-3">
          <Field label="Objetivo da hunt">
            <select className="hn-control" value={form.hunt_objective} onChange={(e) => patch("hunt_objective", e.target.value as FormState["hunt_objective"])}>
              <option value="xp">XP</option><option value="profit">Profit</option><option value="balanced">Balanced</option>
            </select>
          </Field>
          <Field label="Objetivo do set">
            <select className="hn-control" value={form.set_objective} onChange={(e) => patch("set_objective", e.target.value as FormState["set_objective"])}>
              <option value="offense">Offense</option><option value="defense">Defense</option><option value="sustain">Sustain</option><option value="utility">Utility</option><option value="balanced">Balanced</option>
            </select>
          </Field>
          <Field label="Party padrão">
            <select className="hn-control" value={form.party_size} onChange={(e) => patch("party_size", e.target.value)}>
              <option value="1">Solo</option><option value="2">Duo</option><option value="3">Trio</option><option value="4">x4</option><option value="5">x5+</option>
            </select>
          </Field>
        </div>
      </section>

      <div className="flex flex-wrap items-center gap-3 border-t border-white/8 pt-5">
        <button className="hn-primary-button" onClick={() => void save()} disabled={saving}>
          {saving ? <Loader2 className="size-4 animate-spin" /> : <Save className="size-4" />}
          Salvar perfil
        </button>
        <button className="hn-secondary-button" onClick={() => void lookup()} disabled={lookingUp || form.character_name.trim().length < 2}>
          <RefreshCw className={`size-4 ${lookingUp ? "animate-spin" : ""}`} />
          Atualizar do RubinOT
        </button>
        {form.official_lookup_status === "found" && <span className="inline-flex items-center gap-1.5 text-xs text-emerald-300"><CheckCircle2 className="size-3.5" /> Dados públicos vinculados</span>}
      </div>
    </div>
  );
}

function SectionTitle({ icon: Icon, title, subtitle }: { icon: typeof Swords; title: string; subtitle: string }) {
  return <div className="flex items-start gap-3"><div className="grid size-10 place-items-center rounded-xl bg-cyan-400/10 text-cyan-300"><Icon className="size-4" /></div><div><div className="font-bold text-white">{title}</div><div className="mt-1 text-xs text-slate-500">{subtitle}</div></div></div>;
}
function Field({ label, children }: { label: string; children: React.ReactNode }) { return <label className="space-y-2 text-xs font-medium text-slate-400"><span>{label}</span>{children}</label>; }
function NumberInput({ value, onChange }: { value: string; onChange: (value: string) => void }) { return <input className="hn-control" type="number" min="0" value={value} onChange={(e) => onChange(e.target.value)} />; }
function Summary({ label, value }: { label: string; value: string }) { return <div className="rounded-xl border border-white/6 bg-white/[0.025] p-3"><div className="text-[10px] uppercase tracking-wide text-slate-600">{label}</div><div className="mt-1 truncate text-sm font-bold text-slate-200">{value}</div></div>; }
function toString(value: unknown) { return value == null ? "" : String(value); }
function numberOrNull(value: string) { const n = Number(value); return value.trim() && Number.isFinite(n) ? n : null; }
function compactObject<T extends Record<string, unknown>>(input: T) { return Object.fromEntries(Object.entries(input).filter(([,value]) => value !== null && value !== "")); }
