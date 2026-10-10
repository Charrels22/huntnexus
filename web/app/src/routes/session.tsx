import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import {
  BookOpenCheck,
  ChevronDown,
  ChevronUp,
  ClipboardPaste,
  Eraser,
  Gem,
  Save,
  Loader2,
  Sparkles,
  Swords,
  Tags,
  UserRound,
  Users,
} from "lucide-react";
import { callHuntNexusApi } from "@/lib/api/huntnexus";
import { getOrCreateClientId } from "@/lib/client-id";
import { detectAnalyzerType } from "@/lib/session-parser";

export const Route = createFileRoute("/session")({ component: SessionImportPage });

const analyzerTabs = [
  { key: "hunt", label: "Hunt Analyzer", icon: Swords, placeholder: "Cole aqui o Hunt Analyzer..." },
  { key: "party", label: "Party Hunt", icon: Users, placeholder: "Cole aqui o Party Hunt Analyzer..." },
  { key: "input", label: "Input Analyzer", icon: ClipboardPaste, placeholder: "Cole aqui o Input Analyzer..." },
  { key: "misc", label: "Miscellaneous", icon: BookOpenCheck, placeholder: "Cole aqui o Miscellaneous..." },
] as const;

type AnalyzerKey = (typeof analyzerTabs)[number]["key"];

type Draft = {
  hunt: string;
  party: string;
  input: string;
  misc: string;
  character: string;
  server: string;
  vocation: string;
  level: string;
  location: string;
  observation: string;
  tags: string[];
  type: "normal" | "bounty";
  favorite: boolean;
  publishHighscores: boolean;
  rareDrops: string;
};

const emptyDraft: Draft = {
  hunt: "",
  party: "",
  input: "",
  misc: "",
  character: "",
  server: "",
  vocation: "",
  level: "",
  location: "",
  observation: "",
  tags: [],
  type: "normal",
  favorite: false,
  publishHighscores: false,
  rareDrops: "",
};

const storageKey = "huntnexus.session-import.draft.v1";

function SessionImportPage() {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<AnalyzerKey>("hunt");
  const [draft, setDraft] = useState<Draft>(emptyDraft);
  const [rareOpen, setRareOpen] = useState(false);
  const [infoOpen, setInfoOpen] = useState(true);
  const [tagInput, setTagInput] = useState("");
  const [savedAt, setSavedAt] = useState<string>("");
  const [saving, setSaving] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [validationWarnings, setValidationWarnings] = useState<string[]>([]);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(storageKey);
      if (raw) setDraft({ ...emptyDraft, ...JSON.parse(raw) });
    } catch {}
  }, []);

  const active = analyzerTabs.find((tab) => tab.key === activeTab)!;
  const analyzerCount = useMemo(
    () => [draft.hunt, draft.party, draft.input, draft.misc].filter((value) => value.trim()).length,
    [draft.hunt, draft.party, draft.input, draft.misc],
  );
  const canPrepare = draft.hunt.trim().length > 0;

  function patch<K extends keyof Draft>(key: K, value: Draft[K]) {
    setDraft((current) => ({ ...current, [key]: value }));
  }

  function saveDraft() {
    localStorage.setItem(storageKey, JSON.stringify(draft));
    setSavedAt(new Date().toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" }));
  }

  function clearAll() {
    setDraft(emptyDraft);
    localStorage.removeItem(storageKey);
    setTagInput("");
    setSavedAt("");
  }

  function addTag() {
    const tag = tagInput.trim();
    if (!tag || draft.tags.includes(tag)) return;
    patch("tags", [...draft.tags, tag]);
    setTagInput("");
  }

  function acceptAnalyzerText(text: string) {
    if (!text.trim()) return;
    const detected = detectAnalyzerType(text) ?? activeTab;
    patch(detected, text);
    setActiveTab(detected);
  }

  async function submitHunt() {
    const clientId = getOrCreateClientId();
    if (!clientId || !canPrepare || saving) return;

    setSaving(true);
    setSubmitError("");
    setValidationWarnings([]);

    try {
      const response = await callHuntNexusApi<any>({
        action: "session_import_save",
        client_id: clientId,
        blocks: {
          hunt: draft.hunt,
          party: draft.party,
          input: draft.input,
          misc: draft.misc,
        },
        metadata: {
          character: draft.character,
          server: draft.server,
          vocation: draft.vocation,
          level: draft.level,
          location: draft.location,
          observation: draft.observation,
          tags: draft.tags,
          type: draft.type,
          favorite: draft.favorite,
          publishHighscores: draft.publishHighscores,
          rareDrops: draft.rareDrops,
        },
      });

      const warnings = Array.isArray(response?.parsed?.validation?.warnings)
        ? response.parsed.validation.warnings
        : [];
      setValidationWarnings(warnings);

      const sessionId = response?.data?.session_id;
      if (!sessionId) throw new Error("A sessão foi processada, mas não retornou identificador.");

      localStorage.removeItem(storageKey);
      sessionStorage.setItem("huntnexus.open-player-session", sessionId);
      window.dispatchEvent(new Event("huntnexus:player-sessions-changed"));
      await navigate({ to: "/sessions" });
    } catch (e) {
      setSubmitError((e as Error).message || "Não foi possível salvar a hunt.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="mx-auto max-w-[1280px] space-y-6">
      <section className="overflow-hidden rounded-3xl border border-white/8 bg-slate-950/55">
        <div className="border-b border-white/7 p-5 md:p-6">
          <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Session Analyzer</div>
          <h1 className="mt-1 text-3xl font-black tracking-tight text-white">Cadastrar uma hunt</h1>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-400">
            Cole os analyzers da sessão. O HuntNexus identifica cada bloco, cruza as informações e depois organiza a hunt em Hunt Analyse, Misc, Damage e Party Hunt.
          </p>
        </div>

        <div className="p-5 md:p-6">
          <div className="flex flex-wrap gap-2">
            {analyzerTabs.map(({ key, label, icon: Icon }) => {
              const filled = Boolean(draft[key].trim());
              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => setActiveTab(key)}
                  className={`flex items-center gap-2 rounded-xl border px-3 py-2 text-sm font-semibold transition ${activeTab === key ? "border-cyan-400/35 bg-cyan-400/10 text-cyan-100" : "border-white/7 bg-white/[0.025] text-slate-400 hover:border-white/12 hover:text-slate-200"}`}
                >
                  <Icon className="size-4" />
                  {label}
                  {filled && <span className="size-1.5 rounded-full bg-emerald-400" />}
                </button>
              );
            })}
          </div>

          <div className="mt-4">
            <textarea
              value={draft[activeTab]}
              onChange={(e) => patch(activeTab, e.target.value)}
              onPaste={(e) => {
                const pasted = e.clipboardData.getData("text");
                const detected = detectAnalyzerType(pasted);
                if (!detected || detected === activeTab) return;
                e.preventDefault();
                acceptAnalyzerText(pasted);
              }}
              placeholder={active.placeholder}
              spellCheck={false}
              className="min-h-[260px] w-full resize-y rounded-2xl border border-white/10 bg-[#080d18] p-4 font-mono text-sm leading-6 text-slate-200 outline-none transition placeholder:text-slate-600 focus:border-cyan-400/35 focus:shadow-[0_0_0_3px_rgba(34,211,238,.05)]"
            />
          </div>

          <div className="mt-3 flex flex-wrap items-center justify-between gap-3 text-xs">
            <div className="text-slate-500">
              {analyzerCount}/4 blocos preenchidos · colagens são redirecionadas automaticamente quando o tipo é reconhecido
              {!draft.hunt.trim() && <span className="ml-2 text-amber-300/80">Hunt Analyzer é o bloco principal</span>}
            </div>
            <button
              type="button"
              onClick={() => navigator.clipboard?.readText().then((text) => acceptAnalyzerText(text)).catch(() => undefined)}
              className="inline-flex items-center gap-2 text-slate-400 transition hover:text-cyan-200"
            >
              <ClipboardPaste className="size-3.5" />
              Colar da área de transferência
            </button>
          </div>
        </div>
      </section>

      <section className="overflow-hidden rounded-2xl border border-white/8 bg-slate-950/45">
        <button
          type="button"
          onClick={() => setRareOpen((value) => !value)}
          className="flex w-full items-center gap-3 p-5 text-left"
        >
          <Gem className="size-4 text-amber-300" />
          <div className="font-semibold text-white">Adicionar drops raros</div>
          <div className="ml-auto">{rareOpen ? <ChevronUp className="size-4 text-slate-500" /> : <ChevronDown className="size-4 text-slate-500" />}</div>
        </button>
        {rareOpen && (
          <div className="border-t border-white/7 p-5">
            <textarea
              value={draft.rareDrops}
              onChange={(e) => patch("rareDrops", e.target.value)}
              placeholder="Itens raros, observações de loot ou drops que você queira destacar..."
              className="hn-control min-h-28 resize-y"
            />
          </div>
        )}
      </section>

      <section className="overflow-hidden rounded-3xl border border-white/8 bg-slate-950/45">
        <button
          type="button"
          onClick={() => setInfoOpen((value) => !value)}
          className="flex w-full items-center gap-3 p-5 text-left"
        >
          <Sparkles className="size-4 text-cyan-300" />
          <div>
            <div className="font-semibold text-white">Informações adicionais</div>
            <div className="mt-1 text-xs text-slate-500">Opcional — melhora filtros, histórico e comparações.</div>
          </div>
          <div className="ml-auto">{infoOpen ? <ChevronUp className="size-4 text-slate-500" /> : <ChevronDown className="size-4 text-slate-500" />}</div>
        </button>

        {infoOpen && (
          <div className="border-t border-white/7 p-5">
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
              <Field label="Personagem" icon={UserRound}>
                <input className="hn-control" value={draft.character} onChange={(e) => patch("character", e.target.value)} placeholder="Nome do personagem" />
              </Field>
              <Field label="Servidor">
                <input className="hn-control" value={draft.server} onChange={(e) => patch("server", e.target.value)} placeholder="Servidor" />
              </Field>
              <Field label="Vocação" icon={Swords}>
                <select className="hn-control" value={draft.vocation} onChange={(e) => patch("vocation", e.target.value)}>
                  <option value="">Detectar / escolher</option>
                  <option value="EK">Elite Knight</option>
                  <option value="RP">Royal Paladin</option>
                  <option value="ED">Elder Druid</option>
                  <option value="MS">Master Sorcerer</option>
                  <option value="EM">Exalted Monk</option>
                </select>
              </Field>
              <Field label="Level">
                <input className="hn-control" type="number" min="1" value={draft.level} onChange={(e) => patch("level", e.target.value)} placeholder="Level" />
              </Field>
            </div>

            <div className="mt-4 grid gap-4 xl:grid-cols-[1fr_1fr]">
              <Field label="Local">
                <input className="hn-control" value={draft.location} onChange={(e) => patch("location", e.target.value)} placeholder="Hunt / local" />
              </Field>
              <Field label="Observação">
                <input className="hn-control" value={draft.observation} onChange={(e) => patch("observation", e.target.value)} placeholder="Observação opcional" />
              </Field>
            </div>

            <div className="mt-5">
              <div className="mb-2 flex items-center gap-2 text-xs font-medium text-slate-400"><Tags className="size-3.5" /> Tags</div>
              <div className="flex flex-wrap gap-2">
                {draft.tags.map((tag) => (
                  <button
                    key={tag}
                    type="button"
                    onClick={() => patch("tags", draft.tags.filter((value) => value !== tag))}
                    className="rounded-full border border-cyan-400/15 bg-cyan-400/8 px-3 py-1 text-xs text-cyan-200"
                    title="Clique para remover"
                  >
                    {tag} ×
                  </button>
                ))}
                <div className="flex min-w-[220px] gap-2">
                  <input
                    className="hn-control h-9 min-h-9"
                    value={tagInput}
                    onChange={(e) => setTagInput(e.target.value)}
                    onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addTag(); } }}
                    placeholder="Adicionar tag"
                  />
                  <button type="button" className="hn-secondary-button h-9 py-1" onClick={addTag}>+</button>
                </div>
              </div>
            </div>

            <div className="mt-5 flex flex-wrap gap-2">
              <Toggle active={draft.type === "normal"} onClick={() => patch("type", "normal")}>Normal</Toggle>
              <Toggle active={draft.type === "bounty"} onClick={() => patch("type", "bounty")}>Bounty</Toggle>
              <Toggle active={draft.favorite} onClick={() => patch("favorite", !draft.favorite)}>Favorita</Toggle>
              <Toggle active={draft.publishHighscores} onClick={() => patch("publishHighscores", !draft.publishHighscores)}>Publicar em rankings</Toggle>
            </div>
          </div>
        )}
      </section>

      <section className="flex flex-col gap-3 border-t border-white/8 pt-5 sm:flex-row sm:items-center">
        <button type="button" className="hn-secondary-button justify-center" onClick={saveDraft}>
          <Save className="size-4" />
          Salvar rascunho
        </button>

        <button
          type="button"
          disabled={!canPrepare || saving}
          onClick={() => void submitHunt()}
          className="hn-primary-button justify-center disabled:cursor-not-allowed disabled:opacity-40"
          title={canPrepare ? "Parsear, validar e salvar a hunt" : "Cole o Hunt Analyzer primeiro"}
        >
          {saving ? <Loader2 className="size-4 animate-spin" /> : <Save className="size-4" />}
          {saving ? "Processando..." : "Salvar hunt"}
        </button>

        {savedAt && <span className="text-xs text-emerald-300/80">Rascunho salvo às {savedAt}</span>}

        <button type="button" onClick={clearAll} className="ml-auto inline-flex items-center gap-2 px-3 py-2 text-xs text-slate-500 transition hover:text-red-300">
          <Eraser className="size-3.5" />
          Limpar tudo
        </button>
      </section>

      {submitError && (
        <div className="rounded-2xl border border-red-400/20 bg-red-400/8 p-4 text-sm text-red-200">
          {submitError}
        </div>
      )}

      {validationWarnings.length > 0 && (
        <div className="rounded-2xl border border-amber-400/15 bg-amber-400/[0.04] p-4 text-xs leading-5 text-amber-100/80">
          O parser salvou a entrada, mas marcou pontos para revisão: {validationWarnings.join(", ")}.
        </div>
      )}

      <div className="rounded-2xl border border-cyan-400/10 bg-cyan-400/[0.03] p-4 text-xs leading-5 text-slate-500">
        As hunts cadastradas ficam separadas da base comunitária. O texto original dos analyzers é preservado para permitir reprocessamento futuro sem perda de informação.
        <Link to="/sessions" className="ml-1 text-cyan-300 hover:text-cyan-200">Ver minhas sessões →</Link>
      </div>
    </div>
  );
}

function Field({ label, icon: Icon, children }: { label: string; icon?: typeof UserRound; children: React.ReactNode }) {
  return (
    <label className="space-y-2 text-xs font-medium text-slate-400">
      <span className="flex items-center gap-1.5">{Icon && <Icon className="size-3.5" />}{label}</span>
      {children}
    </label>
  );
}

function Toggle({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-xl border px-3 py-2 text-xs font-medium transition ${active ? "border-cyan-400/25 bg-cyan-400/10 text-cyan-200" : "border-white/7 bg-white/[0.02] text-slate-500 hover:text-slate-300"}`}
    >
      {children}
    </button>
  );
}
