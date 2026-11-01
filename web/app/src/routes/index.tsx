import { createFileRoute, Link } from "@tanstack/react-router";
import {
  Activity,
  ArrowDown,
  ArrowRight,
  Backpack,
  Check,
  ChevronDown,
  CircleHelp,
  Crosshair,
  Database,
  LockKeyhole,
  MapPin,
  Plus,
  Search,
  ShieldCheck,
  Sparkles,
  Swords,
  Trash2,
  UserRound,
  WandSparkles,
} from "lucide-react";
import { useEffect, useMemo, useState, type FormEvent, type ReactNode } from "react";
import { CanonicalSprite } from "@/components/shared/canonical-sprite";
import { getSupabaseBrowserClient } from "@/integrations/supabase/client.browser";
import { callHuntNexusApi } from "@/lib/api/huntnexus";
import { getOrCreateClientId } from "@/lib/client-id";
import { parseSessionImport, sessionImportWarningLabel } from "@/lib/session-parser";
import "./index.css";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "HuntNexus — seu próximo plano de hunt" },
      { name: "description", content: "Monte seu contexto de hunt, use seus personagens e organize seus dados de sessão em um só lugar." },
    ],
  }),
  component: HuntWorkspacePage,
});

const vocations = ["EK", "RP", "ED", "MS", "EM"] as const;
const playStyles = ["Solo", "Duo", "Party"] as const;
const huntStyles = ["Correndo", "Em box", "Parado"] as const;
const objectives = ["Equilíbrio", "XP", "Profit", "Sobrevivência"] as const;
const importFormats = [
  { key: "hunt", label: "Hunt Analyzer" },
  { key: "party", label: "Party Hunt" },
  { key: "input", label: "Input Analyser" },
  { key: "misc", label: "Miscellaneous" },
] as const;
type ImportTab = (typeof importFormats)[number]["key"];
type Vocation = (typeof vocations)[number];
type AuthState = "checking" | "signed-in" | "signed-out" | "unavailable";
type CharacterDraft = {
  character_name: string;
  vocation: Vocation | "";
  level: string;
  magic_level: string;
  sword: string;
  axe: string;
  club: string;
  distance: string;
  fist: string;
  shielding: string;
};
type SavedCharacter = {
  id: string;
  character_name: string;
  vocation: Vocation | null;
  level: number | null;
  manual_stats: Record<string, unknown>;
  proficiency_selections: Record<string, number[]>;
  defaults: Record<string, unknown>;
  is_default: boolean;
  updated_at: string;
  main_slots: number;
  backpack_items: number;
};
type InventoryItem = {
  inventory_id: string;
  selection_key: string;
  item_key: string;
  item_name: string;
  quantity: number;
  level_required?: number | null;
};
type Inventory = {
  main_set: Record<string, InventoryItem>;
  backpack: InventoryItem[];
  summary: { main_slots: number; backpack_items: number };
};
type SearchItem = {
  item_key: string;
  name: string;
  selection_key: string;
  level_required: number | null;
  eligible: boolean;
  blocking_reasons: string[];
};
const emptyDraft: CharacterDraft = {
  character_name: "", vocation: "", level: "", magic_level: "", sword: "", axe: "", club: "", distance: "", fist: "", shielding: "",
};

const previewCharacters: SavedCharacter[] = [
  {
    id: "synthetic-ms",
    character_name: "Arcane Example",
    vocation: "MS",
    level: 900,
    manual_stats: { magic_level: 120, shielding: 80 },
    proficiency_selections: {},
    defaults: {},
    is_default: true,
    updated_at: "2026-11-01T12:00:00.000Z",
    main_slots: 7,
    backpack_items: 14,
  },
  {
    id: "synthetic-ek",
    character_name: "Stone Example",
    vocation: "EK",
    level: 650,
    manual_stats: { magic_level: 10, sword: 115, shielding: 110 },
    proficiency_selections: {},
    defaults: {},
    is_default: false,
    updated_at: "2026-10-30T12:00:00.000Z",
    main_slots: 8,
    backpack_items: 9,
  },
];

function previewItem(name: string, selectionKey: string): InventoryItem {
  return {
    inventory_id: `synthetic-${selectionKey}-${name.toLowerCase().replaceAll(" ", "-")}`,
    selection_key: selectionKey,
    item_key: name.toLowerCase().replaceAll(" ", "-"),
    item_name: name,
    quantity: 1,
  };
}

const previewInventory: Record<string, Inventory> = {
  "synthetic-ms": {
    main_set: {
      neck: previewItem("Blue Plasma Necklace", "neck"),
      head: previewItem("Cobra Hood", "head"),
      ring: previewItem("Ring of Blue Plasma", "ring"),
      weapon: previewItem("Falcon Wand", "weapon"),
      body: previewItem("Soulmantle", "body"),
      legs: previewItem("Soulstrider", "legs"),
      feet: previewItem("Nightmare Boots", "feet"),
    },
    backpack: [previewItem("Might Ring", "ring"), previewItem("Energy Ring", "ring"), previewItem("Magic Wall Rune", "rune")],
    summary: { main_slots: 7, backpack_items: 14 },
  },
  "synthetic-ek": {
    main_set: {
      neck: previewItem("Stone Skin Amulet", "neck"),
      head: previewItem("Cobra Hood", "head"),
      ring: previewItem("Might Ring", "ring"),
      weapon: previewItem("Soulcrusher", "weapon"),
      body: previewItem("Falcon Plate", "body"),
      offhand: previewItem("Falcon Shield", "offhand"),
      legs: previewItem("Falcon Greaves", "legs"),
      feet: previewItem("Pair of Nightmare Boots", "feet"),
    },
    backpack: [previewItem("Might Ring", "ring"), previewItem("Stone Skin Amulet", "neck")],
    summary: { main_slots: 8, backpack_items: 9 },
  },
};

function HuntWorkspacePage() {
  const [authState, setAuthState] = useState<AuthState>("checking");
  const [localPreview, setLocalPreview] = useState(false);
  const [clientId, setClientId] = useState<string | null>(null);
  const [characters, setCharacters] = useState<SavedCharacter[]>([]);
  const [selectedId, setSelectedId] = useState("");
  const [draft, setDraft] = useState<CharacterDraft>(emptyDraft);
  const [inventory, setInventory] = useState<Inventory>(emptyInventory());
  const [inventoryLoading, setInventoryLoading] = useState(false);
  const [savingCharacter, setSavingCharacter] = useState(false);
  const [characterEditorOpen, setCharacterEditorOpen] = useState(false);
  const [storageKind, setStorageKind] = useState<"main" | "backpack">("main");
  const [selectedMainItemId, setSelectedMainItemId] = useState<string | null>(null);
  const [itemSearch, setItemSearch] = useState("");
  const [searchResults, setSearchResults] = useState<SearchItem[]>([]);
  const [searchingItems, setSearchingItems] = useState(false);
  const [itemQuantity, setItemQuantity] = useState("1");
  const [huntName, setHuntName] = useState("");
  const [playStyle, setPlayStyle] = useState<(typeof playStyles)[number]>("Solo");
  const [huntStyle, setHuntStyle] = useState<(typeof huntStyles)[number]>("Correndo");
  const [objective, setObjective] = useState<(typeof objectives)[number]>("Equilíbrio");
  const [importTab, setImportTab] = useState<ImportTab>("hunt");
  const [sessionBlocks, setSessionBlocks] = useState<Record<ImportTab, string>>({ hunt: "", party: "", input: "", misc: "" });
  const [contributeAnonymously, setContributeAnonymously] = useState(false);
  const [planReady, setPlanReady] = useState(false);
  const [feedback, setFeedback] = useState("");
  const [error, setError] = useState("");
  const parsedSession = useMemo(() => parseSessionImport(sessionBlocks), [sessionBlocks]);
  const selectedCharacter = characters.find((character) => character.id === selectedId) ?? null;
  const mainItems = useMemo(() => Object.values(inventory.main_set), [inventory.main_set]);
  const selectedMainItem = mainItems.find((item) => item.inventory_id === selectedMainItemId) ?? null;
  const selectedImportFormat = importFormats.find((format) => format.key === importTab)?.label ?? "Hunt Analyzer";
  const hasSessionInput = Object.values(sessionBlocks).some((block) => block.trim().length > 0);
  const parsedCounts = [
    parsedSession.validation.creature_rows,
    parsedSession.validation.party_player_rows,
    parsedSession.validation.incoming_element_rows,
    parsedSession.validation.incoming_source_rows,
    parsedSession.validation.misc_stat_rows,
  ].reduce((total, value) => total + value, 0);

  useEffect(() => {
    if (typeof window !== "undefined" && window.location.hash === "#personagens") setCharacterEditorOpen(true);
  }, []);

  useEffect(() => {
    const previewRequested = import.meta.env.DEV
      && typeof window !== "undefined"
      && ["localhost", "127.0.0.1", "::1"].includes(window.location.hostname)
      && new URLSearchParams(window.location.search).get("preview") === "1";

    if (previewRequested) {
      const initial = previewCharacters[0]!;
      setLocalPreview(true);
      setAuthState("signed-in");
      setCharacters(previewCharacters);
      setSelectedId(initial.id);
      setDraft(characterToDraft(initial));
      setInventory(previewInventory[initial.id] ?? emptyInventory());
      return;
    }

    const supabase = getSupabaseBrowserClient();
    if (!supabase) {
      setAuthState("unavailable");
      return;
    }

    let active = true;
    let eventObserved = false;
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!active) return;
      eventObserved = true;
      setAuthState(session ? "signed-in" : "signed-out");
      if (!session) {
        setCharacters([]);
        setSelectedId("");
        setDraft(emptyDraft);
        setInventory(emptyInventory());
        setClientId(null);
      }
    });

    supabase.auth.getSession().then(({ data, error: sessionError }) => {
      if (!active || eventObserved) return;
      setAuthState(sessionError ? "unavailable" : data.session ? "signed-in" : "signed-out");
    }).catch(() => {
      if (active && !eventObserved) setAuthState("unavailable");
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (localPreview || authState !== "signed-in") return;
    let active = true;
    const id = getOrCreateClientId();
    if (!id) {
      setError("Não foi possível abrir a identidade desta conta.");
      return;
    }
    setClientId(id);
    callHuntNexusApi<any>({ action: "player_characters_get", client_id: id }).then((response) => {
      if (!active) return;
      const next = Array.isArray(response?.data?.characters) ? response.data.characters as SavedCharacter[] : [];
      const chosen = next.find((character) => character.id === selectedId)
        ?? next.find((character) => character.is_default)
        ?? next[0]
        ?? null;
      setCharacters(next);
      setSelectedId(chosen?.id ?? "");
      setDraft(characterToDraft(chosen));
      setCharacterEditorOpen(!chosen);
      if (chosen) setInventoryLoading(true);
    }).catch((loadError) => {
      if (active) setError(errorMessage(loadError, "Não foi possível sincronizar seus personagens."));
    });
    return () => { active = false; };
  }, [authState, localPreview]);

  useEffect(() => {
    setSelectedMainItemId(null);
    if (!selectedId) {
      setInventory(emptyInventory());
      setInventoryLoading(false);
      return;
    }
    if (localPreview) {
      setInventory(previewInventory[selectedId] ?? emptyInventory());
      setInventoryLoading(false);
      return;
    }
    if (authState !== "signed-in" || !clientId) return;
    let active = true;
    setInventoryLoading(true);
    callHuntNexusApi<any>({ action: "player_character_inventory_get", client_id: clientId, character_id: selectedId })
      .then((response) => { if (active) setInventory(normalizeInventory(response?.data)); })
      .catch((loadError) => { if (active) setError(errorMessage(loadError, "Não foi possível carregar o inventário.")); })
      .finally(() => { if (active) setInventoryLoading(false); });
    return () => { active = false; };
  }, [authState, clientId, localPreview, selectedId]);

  useEffect(() => {
    const query = itemSearch.trim();
    if (query.length < 2 || !draft.vocation || !draft.level || Number(draft.level) < 1) {
      setSearchResults([]);
      return;
    }
    if (localPreview) {
      const catalog: SearchItem[] = [
        { item_key: "demo-cobra-hood", name: "Cobra Hood", selection_key: "head", level_required: 0, eligible: true, blocking_reasons: [] },
        { item_key: "demo-soulmantle", name: "Soulmantle", selection_key: "body", level_required: 0, eligible: true, blocking_reasons: [] },
        { item_key: "demo-falcon-wand", name: "Falcon Wand", selection_key: "weapon", level_required: 0, eligible: true, blocking_reasons: [] },
        { item_key: "demo-soulcrusher", name: "Soulcrusher", selection_key: "weapon", level_required: 0, eligible: true, blocking_reasons: [] },
      ];
      setSearchResults(catalog.filter((item) => item.name.toLowerCase().includes(query.toLowerCase())));
      return;
    }
    let active = true;
    const timer = window.setTimeout(() => {
      setSearchingItems(true);
      callHuntNexusApi<any>({
        action: "player_inventory_search",
        vocation: draft.vocation,
        level: Number(draft.level),
        query,
        limit: 12,
      }).then((response) => {
        if (active) setSearchResults(Array.isArray(response?.data?.items) ? response.data.items : []);
      }).catch(() => { if (active) setSearchResults([]); })
        .finally(() => { if (active) setSearchingItems(false); });
    }, 220);
    return () => {
      active = false;
      window.clearTimeout(timer);
    };
  }, [draft.level, draft.vocation, itemSearch, localPreview]);

  function selectCharacter(id: string) {
    setSelectedId(id);
    setDraft(characterToDraft(characters.find((character) => character.id === id) ?? null));
    setError("");
    setFeedback("");
    setCharacterEditorOpen(false);
  }

  function startNewCharacter() {
    setSelectedId("");
    setDraft(emptyDraft);
    setInventory(emptyInventory());
    setItemSearch("");
    setSearchResults([]);
    setCharacterEditorOpen(true);
    setError("");
    setFeedback("Preencha nome, vocação e level para criar uma ficha privada.");
  }

  function updateDraft<Key extends keyof CharacterDraft>(key: Key, value: CharacterDraft[Key]) {
    setDraft((current) => ({ ...current, [key]: value }));
  }

  async function saveCharacter(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!draft.character_name.trim() || !draft.vocation || !draft.level || Number(draft.level) < 1) {
      setError("Informe nome, vocação e level do personagem.");
      return;
    }
    if (localPreview) {
      const previous = characters.find((character) => character.id === selectedId);
      const next: SavedCharacter = {
        id: previous?.id ?? `synthetic-${crypto.randomUUID()}`,
        character_name: draft.character_name.trim(),
        vocation: draft.vocation,
        level: Number(draft.level),
        manual_stats: { ...(previous?.manual_stats ?? {}), ...draftToStats(draft) },
        proficiency_selections: previous?.proficiency_selections ?? {},
        defaults: previous?.defaults ?? {},
        is_default: previous?.is_default ?? characters.length === 0,
        updated_at: new Date().toISOString(),
        main_slots: previous?.main_slots ?? 0,
        backpack_items: previous?.backpack_items ?? 0,
      };
      setCharacters((current) => previous ? current.map((character) => character.id === next.id ? next : character) : [...current, next]);
      setSelectedId(next.id);
      setCharacterEditorOpen(false);
      setFeedback("Ficha alterada somente na prévia local; nenhum dado foi salvo.");
      return;
    }
    if (authState !== "signed-in" || !clientId) {
      setError("Entre na sua conta HuntNexus para salvar personagens.");
      return;
    }
    setSavingCharacter(true);
    setError("");
    try {
      const existing = characters.find((character) => character.id === selectedId);
      const response = await callHuntNexusApi<any>({
        action: "player_character_save",
        client_id: clientId,
        character_id: selectedId || null,
        character: {
          character_name: draft.character_name.trim(),
          vocation: draft.vocation,
          level: Number(draft.level),
          manual_stats: { ...(existing?.manual_stats ?? {}), ...draftToStats(draft) },
          proficiency_selections: existing?.proficiency_selections ?? {},
          defaults: existing?.defaults ?? {},
        },
      });
      const savedId = typeof response?.data?.character_id === "string" ? response.data.character_id : selectedId;
      const refreshed = await callHuntNexusApi<any>({ action: "player_characters_get", client_id: clientId });
      const next = Array.isArray(refreshed?.data?.characters) ? refreshed.data.characters as SavedCharacter[] : [];
      setCharacters(next);
      setSelectedId(savedId);
      setDraft(characterToDraft(next.find((character) => character.id === savedId) ?? null));
      setCharacterEditorOpen(false);
      setFeedback("Personagem salvo na sua conta HuntNexus.");
    } catch (saveError) {
      setError(errorMessage(saveError, "Não foi possível salvar o personagem."));
    } finally {
      setSavingCharacter(false);
    }
  }

  async function addInventoryItem(item: SearchItem) {
    if (!selectedId) {
      setError("Salve o personagem antes de adicionar equipamentos.");
      return;
    }
    const quantity = storageKind === "backpack" ? Number(itemQuantity) || 1 : 1;
    if (localPreview) {
      const nextItem = previewItem(item.name, item.selection_key);
      setInventory((current) => storageKind === "main"
        ? { ...current, main_set: { ...current.main_set, [item.selection_key]: nextItem }, summary: { ...current.summary, main_slots: Object.keys({ ...current.main_set, [item.selection_key]: nextItem }).length } }
        : { ...current, backpack: [...current.backpack.filter((row) => row.item_key !== item.item_key), { ...nextItem, quantity }], summary: { ...current.summary, backpack_items: current.backpack.length + 1 } });
      setItemSearch("");
      setSearchResults([]);
      setFeedback("Equipamento adicionado somente à prévia local.");
      return;
    }
    if (!clientId) return;
    try {
      await callHuntNexusApi({ action: "player_character_inventory_put", client_id: clientId, character_id: selectedId, storage_kind: storageKind, item_key: item.item_key, quantity });
      const response = await callHuntNexusApi<any>({ action: "player_character_inventory_get", client_id: clientId, character_id: selectedId });
      setInventory(normalizeInventory(response?.data));
      setItemSearch("");
      setSearchResults([]);
      setFeedback(`${item.name} adicionado ao ${storageKind === "main" ? "Main" : "Backpack"}.`);
    } catch (addError) {
      setError(errorMessage(addError, "Não foi possível adicionar esse item."));
    }
  }

  async function removeInventoryItem(item: InventoryItem) {
    if (!selectedId) return;
    if (localPreview) {
      setInventory((current) => ({
        ...current,
        main_set: Object.fromEntries(Object.entries(current.main_set).filter(([, value]) => value.inventory_id !== item.inventory_id)),
        backpack: current.backpack.filter((value) => value.inventory_id !== item.inventory_id),
        summary: {
          main_slots: Object.values(current.main_set).filter((value) => value.inventory_id !== item.inventory_id).length,
          backpack_items: current.backpack.filter((value) => value.inventory_id !== item.inventory_id).length,
        },
      }));
      setSelectedMainItemId(null);
      return;
    }
    if (!clientId) return;
    try {
      await callHuntNexusApi({ action: "player_character_inventory_remove", client_id: clientId, character_id: selectedId, inventory_id: item.inventory_id });
      const response = await callHuntNexusApi<any>({ action: "player_character_inventory_get", client_id: clientId, character_id: selectedId });
      setInventory(normalizeInventory(response?.data));
      setSelectedMainItemId(null);
    } catch (removeError) {
      setError(errorMessage(removeError, "Não foi possível remover esse item."));
    }
  }

  function generatePlan(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPlanReady(true);
    document.getElementById("resultado")?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  const selectedSlotLabel = selectedMainItem ? slotLabel(selectedMainItem.selection_key) : "";

  return (
    <main className="hnx-root" id="inicio">
      <div className="hnx-background-grid" aria-hidden="true" />
      <header className="hnx-header">
        <a className="hnx-brand" href="#inicio" aria-label="HuntNexus, início">
          <span className="hnx-brand-mark"><Crosshair size={19} /></span>
          <span>Hunt<span>Nexus</span><small>HUNT WORKSPACE</small></span>
        </a>
        <nav className="hnx-nav" aria-label="Navegação da página">
          <a href="#montar">Montar hunt</a>
          <a href="#personagens">Personagens</a>
          <a href="#resultado">Minha resposta</a>
        </nav>
        <div className="hnx-account-area">
          {localPreview ? <span className="hnx-preview-status"><i /> Prévia local</span> : authState === "signed-in" ? <span className="hnx-account-status"><i /> Conta conectada</span> : <Link to="/account" className="hnx-login-link"><UserRound size={15} /> Entrar</Link>}
        </div>
      </header>

      <div className="hnx-page-wrap">
        <section className="hnx-hero">
          <div className="hnx-hero-copy">
            <div className="hnx-eyebrow"><span /> HUNT INTELLIGENCE · TIBIA + RUBINOT</div>
            <h1>Prepare a próxima hunt.<br /><span>Com tudo no lugar.</span></h1>
            <p>Use seu personagem, conte como você joga e traga dados reais da sessão. O plano aparece com as escolhas e as evidências organizadas.</p>
            <a className="hnx-primary-button" href="#montar">Montar meu plano <ArrowDown size={16} /></a>
          </div>
          <div className="hnx-hero-visual" aria-label="Personagem, hunt e equipamento conectados">
            <div className="hnx-orbit hnx-orbit-outer" />
            <div className="hnx-orbit hnx-orbit-inner" />
            <span className="hnx-orbit-node hnx-node-map"><MapPin size={17} /></span>
            <span className="hnx-orbit-node hnx-node-spell"><WandSparkles size={17} /></span>
            <span className="hnx-orbit-node hnx-node-gear"><ShieldCheck size={17} /></span>
            <div className="hnx-orbit-core"><Crosshair size={30} /><span>SEU PRÓXIMO<br />PLANO</span></div>
            <div className="hnx-orbit-caption">PERSONAGEM <i /> HUNT <i /> BUILD</div>
          </div>
        </section>

        <section className="hnx-workspace" id="montar" aria-label="Montagem do plano de hunt">
          <div className="hnx-column hnx-column-profile">
            <section className="hnx-panel hnx-character-panel" id="personagens">
              <PanelHeading icon={UserRound} eyebrow="SEU CONTEXTO" title="Personagem" detail="Escolha uma ficha e mantenha seu equipamento à mão." />
              {authState === "signed-in" || localPreview ? (
                <>
                  <div className="hnx-character-toolbar">
                    <select className="hnx-control" value={selectedId} onChange={(event) => selectCharacter(event.target.value)} aria-label="Escolher personagem">
                      <option value="">Escolher ou cadastrar personagem</option>
                      {characters.map((character) => <option key={character.id} value={character.id}>{character.character_name} · {character.vocation ?? "sem vocação"} · {character.level ?? "sem level"}</option>)}
                    </select>
                    <button type="button" className="hnx-icon-button" onClick={startNewCharacter} aria-label="Cadastrar personagem"><Plus size={18} /></button>
                  </div>

                  {selectedCharacter && !characterEditorOpen && (
                    <div className="hnx-character-summary">
                      <span className="hnx-avatar"><UserRound size={20} /></span>
                      <div className="hnx-character-summary-copy"><b>{selectedCharacter.character_name}</b><span>{selectedCharacter.vocation ?? "Vocação pendente"} <i /> Level {selectedCharacter.level ?? "pendente"}</span></div>
                      {selectedCharacter.is_default && <span className="hnx-default-pill"><Check size={12} /> Principal</span>}
                      <button type="button" className="hnx-text-button" onClick={() => setCharacterEditorOpen(true)}>Editar ficha</button>
                    </div>
                  )}

                  {characterEditorOpen && (
                    <form className="hnx-character-editor" onSubmit={(event) => void saveCharacter(event)}>
                      <div className="hnx-editor-heading"><span>{selectedId ? "FICHA SALVA" : "NOVA FICHA"}</span><button type="button" onClick={() => setCharacterEditorOpen(false)} aria-label="Fechar edição"><ChevronDown size={16} /></button></div>
                      <div className="hnx-form-grid">
                        <Field label="Nome"><input className="hnx-control" required maxLength={120} value={draft.character_name} onChange={(event) => updateDraft("character_name", event.target.value)} placeholder="Nome no jogo" /></Field>
                        <Field label="Level"><input className="hnx-control" required type="number" min="1" max="5000" value={draft.level} onChange={(event) => updateDraft("level", event.target.value)} placeholder="Ex.: 720" /></Field>
                        <Field label="Vocação"><select className="hnx-control" required value={draft.vocation} onChange={(event) => updateDraft("vocation", event.target.value as Vocation | "")}><option value="" disabled>Escolher</option>{vocations.map((vocation) => <option key={vocation}>{vocation}</option>)}</select></Field>
                        <Field label="Magic level"><input className="hnx-control" type="number" min="0" max="1000" value={draft.magic_level} onChange={(event) => updateDraft("magic_level", event.target.value)} placeholder="Opcional" /></Field>
                      </div>
                      <details className="hnx-skills-details"><summary>Skills de combate · opcionais</summary><div className="hnx-skill-grid">{(["sword", "axe", "club", "distance", "fist", "shielding"] as const).map((key) => <Field key={key} label={skillLabel(key)}><input className="hnx-control" type="number" min="0" max="1000" value={draft[key]} onChange={(event) => updateDraft(key, event.target.value)} placeholder="—" /></Field>)}</div></details>
                      {authState === "signed-out" && <p className="hnx-private-note"><LockKeyhole size={13} /> Entre para salvar a ficha em sua conta HuntNexus.</p>}
                      <button type="submit" className="hnx-small-primary" disabled={savingCharacter || (authState !== "signed-in" && !localPreview)}>{savingCharacter ? "Salvando…" : <><Check size={14} /> Salvar ficha</>}</button>
                    </form>
                  )}
                </>
              ) : (
                <div className="hnx-sign-in-card">
                  <LockKeyhole size={18} />
                  <div><b>Suas fichas ficam privadas</b><span>Entre para cadastrar personagens e carregar seus itens.</span></div>
                  <Link to="/account" className="hnx-small-primary">Entrar</Link>
                </div>
              )}

              {selectedCharacter && (
                <div className="hnx-equipment-area">
                  <div className="hnx-equipment-heading"><div><span className="hnx-section-label">INVENTÁRIO DO PERSONAGEM</span><h3>Main e Backpack</h3></div>{inventoryLoading && <span className="hnx-loading-dot" aria-label="Carregando inventário" />}</div>
                  <div className="hnx-storage-tabs" role="tablist" aria-label="Armazenamento">
                    <button type="button" role="tab" aria-selected={storageKind === "main"} className={storageKind === "main" ? "is-active" : ""} onClick={() => setStorageKind("main")}><ShieldCheck size={13} /> Main</button>
                    <button type="button" role="tab" aria-selected={storageKind === "backpack"} className={storageKind === "backpack" ? "is-active" : ""} onClick={() => setStorageKind("backpack")}><Backpack size={13} /> Backpack <span>{inventory.backpack.length}</span></button>
                  </div>

                  {storageKind === "main" ? (
                    <>
                      <div className="hnx-main-grid" aria-label="Itens equipados no Main">
                        {mainItems.length ? mainItems.map((item) => {
                          const selected = item.inventory_id === selectedMainItemId;
                          return <button key={item.inventory_id} type="button" className={`hnx-main-item ${selected ? "is-selected" : ""}`} onClick={() => setSelectedMainItemId(selected ? null : item.inventory_id)} aria-pressed={selected} aria-label={`${item.item_name}, ${slotLabel(item.selection_key)}`}><CanonicalSprite kind="item" name={item.item_name} size="sm" className="hnx-item-sprite" /><span>{item.item_name}</span></button>;
                        }) : <div className="hnx-empty-inventory">Seu Main ainda está vazio.</div>}
                      </div>
                      {selectedMainItem && <div className="hnx-selected-item"><CanonicalSprite kind="item" name={selectedMainItem.item_name} size="sm" /><div><b>{selectedMainItem.item_name}</b><span>{selectedSlotLabel} · item equipado</span></div><button type="button" onClick={() => void removeInventoryItem(selectedMainItem)} aria-label={`Remover ${selectedMainItem.item_name}`}><Trash2 size={15} /></button></div>}
                    </>
                  ) : (
                    <div className="hnx-backpack-list">
                      {inventory.backpack.length ? inventory.backpack.map((item) => <div className="hnx-backpack-row" key={item.inventory_id}><CanonicalSprite kind="item" name={item.item_name} size="sm" className="hnx-item-sprite" /><div><b>{item.item_name}</b><span>{slotLabel(item.selection_key)} · quantidade {item.quantity}</span></div><button type="button" onClick={() => void removeInventoryItem(item)} aria-label={`Remover ${item.item_name}`}><Trash2 size={14} /></button></div>) : <div className="hnx-empty-inventory">Nenhum item cadastrado na Backpack.</div>}
                    </div>
                  )}

                  <div className="hnx-item-search">
                    <div className="hnx-search-row"><Search size={15} /><input value={itemSearch} onChange={(event) => setItemSearch(event.target.value)} placeholder={storageKind === "main" ? "Buscar uma peça para equipar…" : "Buscar item para guardar na Backpack…"} /><input aria-label="Quantidade" type="number" min="1" max="9999" value={itemQuantity} disabled={storageKind === "main"} onChange={(event) => setItemQuantity(event.target.value)} /></div>
                    {itemSearch.trim().length >= 2 && <div className="hnx-search-results">{searchingItems ? <span className="hnx-muted-row">Buscando no catálogo…</span> : searchResults.length ? searchResults.map((item) => <div key={item.item_key}><div><b>{item.name}</b><span>{slotLabel(item.selection_key)}{item.level_required ? ` · level ${item.level_required}` : ""}{!item.eligible ? " · fora dos requisitos" : ""}</span></div><button type="button" disabled={!selectedId || (authState !== "signed-in" && !localPreview)} onClick={() => void addInventoryItem(item)}><Plus size={13} /> Adicionar</button></div>) : <span className="hnx-muted-row">Nenhum equipamento encontrado.</span>}</div>}
                  </div>
                </div>
              )}
            </section>

            <section className="hnx-trust-card"><span><Database size={16} /></span><div><b>Dados com contexto</b><p>Tibia e RubinOT compartilham a base factual. Mecânicas exclusivas do RubinOT, como RTC, aparecem separadas.</p></div></section>
          </div>

          <div className="hnx-column">
            <form className="hnx-panel hnx-hunt-form" onSubmit={generatePlan}>
              <PanelHeading icon={Crosshair} eyebrow="MONTE SEU CENÁRIO" title="Sua próxima hunt" detail="Diga o que você quer caçar e como costuma jogar." />
              <Field label="Hunt ou criaturas"><div className="hnx-input-with-icon"><MapPin size={15} /><input value={huntName} onChange={(event) => { setHuntName(event.target.value); setPlanReady(false); }} placeholder="Ex.: Roshamuul, Grim Reaper…" /></div></Field>
              <div className="hnx-form-grid hnx-form-grid-three">
                <ChoiceField label="Com quem você joga?" value={playStyle} options={playStyles} onChange={setPlayStyle} />
                <ChoiceField label="Como você caça?" value={huntStyle} options={huntStyles} onChange={setHuntStyle} />
                <ChoiceField label="Prioridade" value={objective} options={objectives} onChange={setObjective} />
              </div>

              <section className="hnx-session-import" aria-label="Dados da sessão">
                <div className="hnx-import-heading"><span><Activity size={15} /></span><div><b>Trazer dados da sua sessão</b><small>Cole os analisadores para dar contexto à resposta.</small></div><CircleHelp size={15} /></div>
                <div className="hnx-import-tabs" role="tablist" aria-label="Formato do texto colado">
                  {importFormats.map((format) => <button key={format.key} type="button" role="tab" aria-selected={importTab === format.key} className={importTab === format.key ? "is-active" : ""} onClick={() => setImportTab(format.key)}>{format.label}</button>)}
                </div>
                <textarea aria-label={`Dados colados: ${selectedImportFormat}`} value={sessionBlocks[importTab]} onChange={(event) => { setSessionBlocks((current) => ({ ...current, [importTab]: event.target.value })); setPlanReady(false); }} placeholder={`Cole aqui os dados do ${selectedImportFormat}…`} />
                {hasSessionInput && <div className="hnx-import-summary"><span><Check size={13} /> Leitura local</span><b>{parsedCounts} grupos reconhecidos</b>{parsedSession.validation.warnings.slice(0, 2).map((warning) => <small key={warning}>{sessionImportWarningLabel(warning)}</small>)}</div>}
                <label className="hnx-community-toggle"><input type="checkbox" checked={contributeAnonymously} onChange={(event) => setContributeAnonymously(event.target.checked)} /><span><Check size={12} /></span><span><b>Contribuir anonimamente</b><small>Opcional; sem nome do personagem. A prévia não envia os dados.</small></span></label>
              </section>

              <div className="hnx-form-footer"><span><LockKeyhole size={13} /> Conteúdo da sessão é privado por padrão.</span><button className="hnx-primary-button" type="submit"><Sparkles size={15} /> Montar plano <ArrowRight size={15} /></button></div>
            </form>

            <section className="hnx-panel hnx-answer-panel" id="resultado" aria-labelledby="answer-title">
              <div className="hnx-answer-top"><div><span className="hnx-section-label">RESPOSTA ORGANIZADA</span><h2 id="answer-title">Seu plano de hunt</h2></div><span className="hnx-answer-status"><i /> {planReady ? "Cenário atualizado" : "Aguardando cenário"}</span></div>
              <div className="hnx-answer-identity"><span className="hnx-answer-icon"><Swords size={17} /></span><div><small>HUNT</small><b>{huntName.trim() || "Sua próxima hunt"}</b><span>{selectedCharacter ? `${selectedCharacter.character_name} · ${selectedCharacter.vocation ?? "sem vocação"} · level ${selectedCharacter.level ?? "—"}` : `${draft.vocation || "Escolha uma vocação"} · level ${draft.level || "—"}`} · {playStyle} · {huntStyle}</span></div></div>
              <div className="hnx-answer-block"><div className="hnx-answer-block-heading"><span><WandSparkles size={15} /> Magias e rotação</span><small>PASSO A PASSO</small></div><div className="hnx-rotation-step"><i>01</i><div><b>Preparação</b><span>Magia de apoio e condições da hunt</span></div></div><div className="hnx-rotation-step"><i>02</i><div><b>Ciclo principal</b><span>Sequência a ajustar pela vocação e pelo alvo</span></div></div><div className="hnx-rotation-step"><i>03</i><div><b>Defesa e recuperação</b><span>Ajuste conforme o dano observado</span></div></div></div>
              <div className="hnx-answer-equipment"><span><ShieldCheck size={15} /> Equipamentos</span><b>{selectedCharacter ? `Main ${inventory.summary.main_slots} · Backpack ${inventory.summary.backpack_items}` : "Escolha um personagem para usar seu inventário"}</b></div>
              <div className="hnx-answer-note"><Database size={14} /><span>{planReady ? "O cenário foi atualizado. O motor de recomendação ainda precisa ser ligado aos dados validados." : "A resposta final vai reunir hunt, magias, equipamentos e a origem de cada recomendação."}</span></div>
              {contributeAnonymously && <div className="hnx-contribution-note"><Check size={13} /> A opção de contribuição está marcada; nenhum dado foi enviado nesta prévia.</div>}
            </section>
          </div>
        </section>

        {(feedback || error) && <div role={error ? "alert" : "status"} className={`hnx-feedback ${error ? "is-error" : ""}`}>{error || feedback}<button type="button" onClick={() => { setError(""); setFeedback(""); }} aria-label="Fechar mensagem">×</button></div>}
        <footer className="hnx-footer"><span>HuntNexus · espaço de preparação</span><span>Base comum de Tibia + RubinOT <i /> RTC exclusivo do RubinOT</span><a href="#inicio">Voltar ao início ↑</a></footer>
      </div>
    </main>
  );
}

function PanelHeading({ icon: Icon, eyebrow, title, detail }: { icon: typeof Crosshair; eyebrow: string; title: string; detail: string }) {
  return <div className="hnx-panel-heading"><span className="hnx-panel-heading-icon"><Icon size={16} /></span><div><span className="hnx-section-label">{eyebrow}</span><h2>{title}</h2><p>{detail}</p></div></div>;
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return <label className="hnx-field"><span>{label}</span>{children}</label>;
}

function ChoiceField<Value extends string>({ label, value, options, onChange }: { label: string; value: Value; options: readonly Value[]; onChange: (value: Value) => void }) {
  return <fieldset className="hnx-choice-field"><legend>{label}</legend><div>{options.map((option) => <button type="button" key={option} className={option === value ? "is-active" : ""} aria-pressed={option === value} onClick={() => onChange(option)}>{option}</button>)}</div></fieldset>;
}

function emptyInventory(): Inventory {
  return { main_set: {}, backpack: [], summary: { main_slots: 0, backpack_items: 0 } };
}

function normalizeInventory(value: any): Inventory {
  return {
    main_set: value?.main_set && typeof value.main_set === "object" ? value.main_set : {},
    backpack: Array.isArray(value?.backpack) ? value.backpack : [],
    summary: { main_slots: Number(value?.summary?.main_slots ?? 0), backpack_items: Number(value?.summary?.backpack_items ?? 0) },
  };
}

function characterToDraft(character: SavedCharacter | null): CharacterDraft {
  const stats = character?.manual_stats ?? {};
  const stat = (key: string) => stats[key] == null ? "" : String(stats[key]);
  return {
    ...emptyDraft,
    character_name: character?.character_name ?? "",
    vocation: character?.vocation ?? "",
    level: character?.level == null ? "" : String(character.level),
    magic_level: stat("magic_level"),
    sword: stat("sword"),
    axe: stat("axe"),
    club: stat("club"),
    distance: stat("distance"),
    fist: stat("fist"),
    shielding: stat("shielding"),
  };
}

function draftToStats(draft: CharacterDraft) {
  return Object.fromEntries(([
    "magic_level", "sword", "axe", "club", "distance", "fist", "shielding",
  ] as const).map((key) => [key, draft[key] === "" ? null : Number(draft[key])]));
}

function slotLabel(value: string) {
  return ({ head: "Helmet", helmet: "Helmet", neck: "Amuleto", amulet: "Amuleto", ring: "Ring", weapon: "Weapon", body: "Armor", armor: "Armor", offhand: "Off-hand", shield: "Off-hand", legs: "Legs", feet: "Boots", boots: "Boots", ammunition: "Ammo", rune: "Rune" } as Record<string, string>)[value] ?? value ?? "Item";
}

function skillLabel(value: string) {
  return ({ sword: "Sword", axe: "Axe", club: "Club", distance: "Distance", fist: "Fist", shielding: "Shielding" } as Record<string, string>)[value] ?? value;
}

function errorMessage(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : "";
  if (["character_library_requires_bound_account", "authentication_required_for_bound_client"].includes(message)) return "Vincule sua conta HuntNexus antes de salvar a ficha.";
  if (message === "rpc_failed") return "A biblioteca ainda não está disponível no banco conectado.";
  return message || fallback;
}
