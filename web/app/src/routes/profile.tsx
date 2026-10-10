import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  Backpack,
  Check,
  ChevronDown,
  Loader2,
  Plus,
  Save,
  ShieldCheck,
  Sparkles,
  Swords,
  Trash2,
  UserRound,
} from "lucide-react";
import { callHuntNexusApi } from "@/lib/api/huntnexus";
import { getOrCreateClientId } from "@/lib/client-id";
import { CanonicalSprite } from "@/components/shared/canonical-sprite";

export const Route = createFileRoute("/profile")({ component: ProfilePage });

type FormState = {
  character_name: string;
  world_name: string;
  vocation: string;
  level: string;
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

type ProficiencyPerk = {
  perk_order: number;
  level_number: number | null;
  effect_key: string;
  numeric_value: number | null;
  unit: string | null;
  scope: string | null;
  spell_key: string | null;
  description_raw: string;
};

type InventoryItem = {
  inventory_id: string;
  selection_key: string;
  item_key: string;
  item_name: string;
  quantity: number;
  item_domain?: string | null;
  item_family?: string | null;
  level_required?: number | null;
  hands?: string | null;
  weapon_class?: string | null;
  imbue_slots?: number | null;
};

type InventorySearchItem = {
  item_key: string;
  name: string;
  selection_key: string;
  item_domain: string;
  item_family: string;
  level_required: number | null;
  eligible: boolean;
  blocking_reasons: string[];
};

type InventoryState = {
  main_set: Record<string, InventoryItem>;
  backpack: InventoryItem[];
  summary: { main_slots: number; backpack_items: number };
};

type ProficiencyTree = {
  item_key: string;
  item_name: string;
  weapon_family: string;
  level_required: number | null;
  eligible: boolean;
  levels_declared: number | null;
  topology_status: string | null;
  perk_count: number;
  perks: ProficiencyPerk[];
};

const emptyForm: FormState = {
  character_name: "",
  world_name: "",
  vocation: "",
  level: "",
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
  const [proficiencySelections, setProficiencySelections] = useState<Record<string, number[]>>({});
  const [proficiencyTrees, setProficiencyTrees] = useState<ProficiencyTree[]>([]);
  const [openTreeKey, setOpenTreeKey] = useState<string | null>(null);
  const [inventory, setInventory] = useState<InventoryState>({ main_set: {}, backpack: [], summary: { main_slots: 0, backpack_items: 0 } });
  const [inventoryLoading, setInventoryLoading] = useState(false);
  const [inventoryTarget, setInventoryTarget] = useState<{ storageKind: "main" | "backpack"; selectionKey: string | null } | null>(null);
  const [inventoryQuery, setInventoryQuery] = useState("");
  const [inventoryResults, setInventoryResults] = useState<InventorySearchItem[]>([]);
  const [inventorySearching, setInventorySearching] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingProficiency, setLoadingProficiency] = useState(false);
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

        setProficiencySelections(
          p.proficiency_selections && typeof p.proficiency_selections === "object"
            ? p.proficiency_selections
            : {},
        );
      })
      .catch(() => setError("Não foi possível carregar o perfil salvo."))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    const clientId = getOrCreateClientId();
    if (!clientId) return;

    setInventoryLoading(true);
    callHuntNexusApi<any>({ action: "player_inventory_get", client_id: clientId })
      .then((response) => {
        const data = response?.data;
        if (!data) return;
        setInventory({
          main_set: data.main_set && typeof data.main_set === "object" ? data.main_set : {},
          backpack: Array.isArray(data.backpack) ? data.backpack : [],
          summary: {
            main_slots: Number(data?.summary?.main_slots || 0),
            backpack_items: Number(data?.summary?.backpack_items || 0),
          },
        });
      })
      .catch(() => undefined)
      .finally(() => setInventoryLoading(false));
  }, []);

  useEffect(() => {
    if (!inventoryTarget || inventoryQuery.trim().length < 2) {
      setInventoryResults([]);
      return;
    }

    const level = Number(form.level);
    if (!form.vocation || !Number.isFinite(level) || level < 1) {
      setInventoryResults([]);
      return;
    }

    let active = true;
    setInventorySearching(true);
    const timer = window.setTimeout(() => {
      callHuntNexusApi<any>({
        action: "player_inventory_search",
        vocation: form.vocation,
        level,
        query: inventoryQuery.trim(),
        selection_key: inventoryTarget.selectionKey,
        limit: 20,
      })
        .then((response) => {
          if (!active) return;
          setInventoryResults(Array.isArray(response?.data?.items) ? response.data.items : []);
        })
        .catch(() => {
          if (active) setInventoryResults([]);
        })
        .finally(() => {
          if (active) setInventorySearching(false);
        });
    }, 220);

    return () => {
      active = false;
      window.clearTimeout(timer);
    };
  }, [inventoryTarget, inventoryQuery, form.vocation, form.level]);

  useEffect(() => {
    const options = weaponFamilyOptions(form.vocation);
    if (!options.length) return;

    const allowed = options.map((option) => option.value);
    if (allowed.includes(form.weapon_family)) return;

    if (options.length === 1) {
      patch("weapon_family", options[0]!.value);
    }
  }, [form.vocation]);

  useEffect(() => {
    const level = Number(form.level);
    if (!form.vocation || !Number.isFinite(level) || level < 1 || !form.weapon_family) {
      setProficiencyTrees([]);
      return;
    }

    let active = true;
    setLoadingProficiency(true);

    callHuntNexusApi<any>({
      action: "player_profile_proficiency_catalog",
      vocation: form.vocation,
      level,
      weapon_family: form.weapon_family,
    })
      .then((response) => {
        if (!active) return;
        const trees = Array.isArray(response?.data?.trees) ? response.data.trees : [];
        setProficiencyTrees(trees);
      })
      .catch(() => {
        if (active) setProficiencyTrees([]);
      })
      .finally(() => {
        if (active) setLoadingProficiency(false);
      });

    return () => {
      active = false;
    };
  }, [form.vocation, form.level, form.weapon_family]);

  const effectiveWarnings = useMemo(() => {
    const warnings: string[] = [];

    const magic = compareFinalStat("Magic Level", form.magic_level, form.effective_magic_level);
    if (magic) warnings.push(magic);

    const shield = compareFinalStat("Shielding", form.shielding, form.effective_shielding);
    if (shield) warnings.push(shield);

    const distance = compareFinalStat("Distance", form.distance, form.effective_distance_skill);
    if (distance) warnings.push(distance);

    const fist = compareFinalStat("Fist", form.fist, form.effective_fist_skill);
    if (fist) warnings.push(fist);

    const baseWeapon = baseWeaponSkill(form);
    const weapon = compareFinalStat("Weapon Skill", baseWeapon, form.effective_weapon_skill);
    if (weapon) warnings.push(weapon);

    return warnings;
  }, [form]);

  const selectedPerkCount = useMemo(
    () => Object.values(proficiencySelections).reduce((sum, rows) => sum + rows.length, 0),
    [proficiencySelections],
  );

  function patch<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((current) => ({ ...current, [key]: value }));
  }

  async function reloadInventory() {
    const clientId = getOrCreateClientId();
    if (!clientId) return;

    setInventoryLoading(true);
    try {
      const response = await callHuntNexusApi<any>({ action: "player_inventory_get", client_id: clientId });
      const data = response?.data;
      setInventory({
        main_set: data?.main_set && typeof data.main_set === "object" ? data.main_set : {},
        backpack: Array.isArray(data?.backpack) ? data.backpack : [],
        summary: {
          main_slots: Number(data?.summary?.main_slots || 0),
          backpack_items: Number(data?.summary?.backpack_items || 0),
        },
      });
    } finally {
      setInventoryLoading(false);
    }
  }

  function openInventoryPicker(storageKind: "main" | "backpack", selectionKey: string | null = null) {
    setInventoryTarget({ storageKind, selectionKey });
    setInventoryQuery("");
    setInventoryResults([]);
  }

  async function putInventoryItem(item: InventorySearchItem) {
    const clientId = getOrCreateClientId();
    if (!clientId || !inventoryTarget) return;

    if (inventoryTarget.storageKind === "main" && !item.eligible) {
      setError("Este item está bloqueado para o level/vocação atual e não pode ser colocado no Set Main.");
      return;
    }

    setError("");
    await callHuntNexusApi<any>({
      action: "player_inventory_put",
      client_id: clientId,
      storage_kind: inventoryTarget.storageKind,
      item_key: item.item_key,
      quantity: 1,
    });
    setInventoryTarget(null);
    setInventoryQuery("");
    setInventoryResults([]);
    await reloadInventory();
    window.dispatchEvent(new Event("huntnexus:inventory-changed"));
  }

  async function removeInventoryItem(inventoryId: string) {
    const clientId = getOrCreateClientId();
    if (!clientId) return;

    await callHuntNexusApi<any>({
      action: "player_inventory_remove",
      client_id: clientId,
      inventory_id: inventoryId,
    });
    await reloadInventory();
    window.dispatchEvent(new Event("huntnexus:inventory-changed"));
  }

  function togglePerk(itemKey: string, perkOrder: number) {
    setProficiencySelections((current) => {
      const selected = new Set(current[itemKey] ?? []);
      if (selected.has(perkOrder)) selected.delete(perkOrder);
      else selected.add(perkOrder);

      const next = { ...current };
      const values = [...selected].sort((a, b) => a - b);
      if (values.length) next[itemKey] = values;
      else delete next[itemKey];
      return next;
    });
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
          online: null,
          former_names: [],
          official_lookup_at: null,
          official_lookup_status: null,
          manual_stats: manualStats,
          proficiency_selections: proficiencySelections,
          defaults: {
            hunt_objective: form.hunt_objective,
            set_objective: form.set_objective,
            party_size: Number(form.party_size),
          },
        },
      });

      if (!response?.data?.saved) throw new Error("profile_not_saved");
      setMessage("Perfil salvo. Hunt Planner e Session Analyzer usarão esses dados automaticamente.");
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

  const hasRegisteredCharacter = Boolean(form.character_name.trim() && form.vocation && form.level);
  const mainVisualItems = Object.values(inventory.main_set).slice(0, 6);

  return (
    <div className="mx-auto max-w-[1320px] space-y-6">
      {hasRegisteredCharacter ? (
        <section className="hn-hero overflow-hidden rounded-3xl border border-white/8">
          <div className="grid min-h-[250px] xl:grid-cols-[1fr_.9fr]">
            <div className="p-5 md:p-7">
              <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Character Profile</div>
              <div className="mt-3 flex flex-wrap items-end gap-x-4 gap-y-2">
                <h1 className="text-3xl font-black tracking-tight text-white md:text-4xl">{form.character_name}</h1>
                <span className="rounded-full border border-cyan-400/15 bg-cyan-400/[0.06] px-3 py-1 text-xs font-semibold text-cyan-200">
                  {vocationLabel(form.vocation)}
                </span>
              </div>
              <div className="mt-4 flex flex-wrap gap-2">
                <CharacterMeta label="Level" value={form.level} />
                <CharacterMeta label="Mundo" value={form.world_name || "—"} />
                <CharacterMeta label="Weapon" value={weaponFamilyOptions(form.vocation).find((x) => x.value === form.weapon_family)?.label || "—"} />
                <CharacterMeta label="ML" value={form.magic_level || "—"} />
              </div>
              <div className="mt-5 text-xs text-slate-500">
                Perfil ativo no Hunt Planner, Session Analyzer e optimizer.
              </div>
            </div>

            <div className="relative overflow-hidden border-l border-white/7 bg-slate-950/50 p-6">
              <div className={`absolute inset-0 ${vocationBackdrop(form.vocation)}`} />
              <div className="relative z-10 flex h-full min-h-[200px] items-center justify-center">
                <div className="w-full max-w-[520px]">
                  <div className="text-center text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-600">
                    Set Main
                  </div>
                  {mainVisualItems.length ? (
                    <div className="mt-4 flex flex-wrap justify-center gap-3">
                      {mainVisualItems.map((item) => (
                        <div key={item.inventory_id} className="rounded-2xl border border-white/8 bg-black/20 p-3 shadow-lg">
                          <CanonicalSprite kind="item" name={item.item_name} size="md" />
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="mt-4 grid min-h-[110px] place-items-center rounded-2xl border border-dashed border-white/8 text-center">
                      <div>
                        <Swords className="mx-auto size-6 text-slate-700" />
                        <div className="mt-2 text-xs text-slate-600">Cadastre o Set Main para completar o visual do personagem.</div>
                      </div>
                    </div>
                  )}
                  <div className="mt-4 text-center text-xs font-bold text-slate-300">{vocationLabel(form.vocation)}</div>
                </div>
              </div>
            </div>
          </div>
        </section>
      ) : (
        <section className="hn-hero overflow-hidden rounded-3xl border border-white/8 p-5 md:p-7">
          <div className="grid gap-6 xl:grid-cols-[1.1fr_.9fr]">
            <div>
              <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">Character Profile</div>
              <h1 className="mt-2 text-3xl font-black tracking-tight text-white md:text-4xl">Cadastre seu personagem uma vez.</h1>
              <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-400">
                O perfil vira o contexto padrão do Hunt Planner, Session Analyzer e optimizer.
              </p>
              <div className="mt-5 rounded-2xl border border-white/7 bg-slate-950/35 p-4 text-xs leading-5 text-slate-500">
                Preencha nome, mundo, vocação e level. Depois disso, este bloco vira o resumo compacto do personagem.
              </div>
            </div>

            <div className="rounded-2xl border border-white/7 bg-slate-950/45 p-5">
              <div className="flex items-center gap-2 text-sm font-semibold text-slate-200">
                <UserRound className="size-4 text-cyan-300" />
                Novo personagem
              </div>
              <div className="mt-4 grid grid-cols-2 gap-2">
                <Summary label="Nome" value={form.character_name || "—"} />
                <Summary label="Mundo" value={form.world_name || "—"} />
                <Summary label="Vocação" value={form.vocation || "—"} />
                <Summary label="Level" value={form.level || "—"} />
              </div>
            </div>
          </div>
        </section>
      )}

      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
        <SectionTitle icon={ShieldCheck} title="Personagem" subtitle="Informações básicas reutilizadas em todo o HuntNexus." />
        <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <Field label="Nome"><input className="hn-control" value={form.character_name} onChange={(e) => patch("character_name", e.target.value)} /></Field>
          <Field label="Mundo"><input className="hn-control" value={form.world_name} onChange={(e) => patch("world_name", e.target.value)} /></Field>
          <Field label="Vocação">
            <select className="hn-control" value={form.vocation} onChange={(e) => patch("vocation", e.target.value)}>
              <option value="">Selecionar</option>
              <option value="EK">Elite Knight</option>
              <option value="RP">Royal Paladin</option>
              <option value="ED">Elder Druid</option>
              <option value="MS">Master Sorcerer</option>
              <option value="EM">Exalted Monk</option>
            </select>
          </Field>
          <Field label="Level"><input className="hn-control" type="number" min="1" value={form.level} onChange={(e) => patch("level", e.target.value)} /></Field>
        </div>
      </section>

      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
        <SectionTitle icon={Swords} title="Skills e contexto do optimizer" subtitle="Use os valores reais do personagem e, quando necessário, o valor final com bônus." />

        <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Field label="Weapon family">
            <select className="hn-control" value={form.weapon_family} onChange={(e) => patch("weapon_family", e.target.value)}>
              <option value="">Não informado</option>
              {weaponFamilyOptions(form.vocation).map((option) => (
                <option key={option.value} value={option.value}>{option.label}</option>
              ))}
            </select>
          </Field>

          {form.vocation === "EK" && (
            <>
              <Field label="Sword"><NumberInput value={form.sword} onChange={(v) => patch("sword", v)} /></Field>
              <Field label="Axe"><NumberInput value={form.axe} onChange={(v) => patch("axe", v)} /></Field>
              <Field label="Club"><NumberInput value={form.club} onChange={(v) => patch("club", v)} /></Field>
            </>
          )}

          {form.vocation === "RP" && (
            <Field label="Distance"><NumberInput value={form.distance} onChange={(v) => patch("distance", v)} /></Field>
          )}

          {form.vocation === "EM" && (
            <Field label="Fist"><NumberInput value={form.fist} onChange={(v) => patch("fist", v)} /></Field>
          )}

          <Field label="Shielding"><NumberInput value={form.shielding} onChange={(v) => patch("shielding", v)} /></Field>
          <Field label="Magic Level"><NumberInput value={form.magic_level} onChange={(v) => patch("magic_level", v)} /></Field>
        </div>

        <div className="mt-6 border-t border-white/7 pt-5">
          <div className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan-400">Valores finais com bônus</div>
          <p className="mt-1 text-xs text-slate-500">
            Opcional. Informe o valor final, não apenas o bônus. Ex.: ML base 110 +2 de equipamento = <strong className="text-slate-300">112</strong>.
          </p>
          <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {form.vocation === "EK" && (
              <Field label="Weapon skill final"><NumberInput value={form.effective_weapon_skill} onChange={(v) => patch("effective_weapon_skill", v)} /></Field>
            )}
            {form.vocation === "RP" && (
              <Field label="Distance final"><NumberInput value={form.effective_distance_skill} onChange={(v) => patch("effective_distance_skill", v)} /></Field>
            )}
            {form.vocation === "EM" && (
              <Field label="Fist final"><NumberInput value={form.effective_fist_skill} onChange={(v) => patch("effective_fist_skill", v)} /></Field>
            )}
            <Field label="Magic level final"><NumberInput value={form.effective_magic_level} onChange={(v) => patch("effective_magic_level", v)} /></Field>
            <Field label="Shielding final"><NumberInput value={form.effective_shielding} onChange={(v) => patch("effective_shielding", v)} /></Field>
          </div>

          {effectiveWarnings.length > 0 && (
            <div className="mt-4 rounded-xl border border-amber-400/15 bg-amber-400/[0.05] p-3 text-xs leading-5 text-amber-100/80">
              <div className="flex items-center gap-2 font-semibold text-amber-200">
                <AlertTriangle className="size-4" />
                Valor final inconsistente
              </div>
              <div className="mt-1">{effectiveWarnings.join(" ")}</div>
              <div className="mt-1 text-slate-500">Enquanto isso não for corrigido, o Planner ignora o valor final menor e usa o skill base.</div>
            </div>
          )}
        </div>
      </section>

      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
        <SectionTitle
          icon={Sparkles}
          title="Weapon Proficiency"
          subtitle="Marque somente os perks que estão ativos no seu personagem para cada arma."
        />

        <div className="mt-4 flex flex-wrap items-center gap-2 text-xs">
          <span className="rounded-full border border-white/7 bg-white/[0.025] px-3 py-1.5 text-slate-400">
            {proficiencyTrees.length} árvores compatíveis
          </span>
          <span className="rounded-full border border-cyan-400/15 bg-cyan-400/[0.05] px-3 py-1.5 text-cyan-200">
            {selectedPerkCount} perks selecionados
          </span>
          {loadingProficiency && <Loader2 className="size-4 animate-spin text-cyan-300" />}
        </div>

        {!form.weapon_family && (
          <div className="mt-4 rounded-xl border border-white/7 bg-white/[0.02] p-4 text-sm text-slate-500">
            Selecione a Weapon Family para carregar as árvores compatíveis.
          </div>
        )}

        {form.weapon_family && !loadingProficiency && proficiencyTrees.length === 0 && (
          <div className="mt-4 rounded-xl border border-white/7 bg-white/[0.02] p-4 text-sm text-slate-500">
            Nenhuma árvore de proficiency encontrada para esta combinação de vocação, level e família.
          </div>
        )}

        {proficiencyTrees.length > 0 && (
          <div className="mt-5 space-y-3">
            {proficiencyTrees.map((tree) => {
              const selected = new Set(proficiencySelections[tree.item_key] ?? []);
              const isOpen = openTreeKey === tree.item_key;

              return (
                <article key={tree.item_key} className="overflow-hidden rounded-2xl border border-white/7 bg-slate-950/45">
                  <button
                    type="button"
                    onClick={() => setOpenTreeKey((current) => current === tree.item_key ? null : tree.item_key)}
                    className="flex w-full items-center gap-3 p-4 text-left transition hover:bg-white/[0.025]"
                  >
                    <CanonicalSprite kind="item" name={tree.item_name} size="md" />
                    <div className="min-w-0 flex-1">
                      <div className="truncate font-bold text-white">{tree.item_name}</div>
                      <div className="mt-1 text-[11px] text-slate-500">
                        Level {tree.level_required ?? "—"} · {tree.perk_count} perks · {selected.size} ativos
                      </div>
                    </div>
                    <ChevronDown className={`size-4 shrink-0 text-slate-500 transition-transform duration-200 ${isOpen ? "rotate-180" : ""}`} />
                  </button>

                  {isOpen && (
                    <div className="border-t border-white/7 p-4">
                      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                        <div>
                          <div className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan-400">Mapa de perks</div>
                          <div className="mt-1 text-[11px] text-slate-500">Ordem preservada da fonte. Conexões exatas ainda não são inferidas.</div>
                        </div>
                        <span className="rounded-full border border-white/7 px-2.5 py-1 text-[10px] text-slate-500">
                          {tree.levels_declared ?? "?"} níveis declarados
                        </span>
                      </div>

                      <div className="relative overflow-hidden rounded-2xl border border-white/6 bg-[#07101b] p-4">
                        <div className="pointer-events-none absolute left-6 right-6 top-1/2 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />
                        <div className="relative grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
                          {tree.perks.map((perk) => {
                            const active = selected.has(perk.perk_order);
                            return (
                              <button
                                key={perk.perk_order}
                                type="button"
                                onClick={() => togglePerk(tree.item_key, perk.perk_order)}
                                title={perk.description_raw || perk.effect_key}
                                className={`group relative min-h-[126px] rounded-2xl border p-3 text-center transition ${
                                  active
                                    ? "border-emerald-400/50 bg-emerald-400/[0.08] shadow-[0_0_0_1px_rgba(52,211,153,.06)]"
                                    : "border-white/8 bg-slate-950/75 hover:border-cyan-400/25 hover:bg-cyan-400/[0.035]"
                                }`}
                              >
                                <span className={`absolute right-2 top-2 grid size-5 place-items-center rounded-full border ${
                                  active
                                    ? "border-emerald-300 bg-emerald-300 text-slate-950"
                                    : "border-white/12 bg-slate-950 text-transparent"
                                }`}>
                                  <Check className="size-3.5" />
                                </span>

                                <div className="mx-auto grid size-16 place-items-center rounded-2xl border border-white/8 bg-black/25">
                                  <ProficiencyPerkIcon perk={perk} />
                                </div>

                                <div className="mt-2 text-[10px] font-black uppercase tracking-wide text-slate-500">
                                  Perk {perk.perk_order}
                                </div>
                                <div className="mt-1 line-clamp-2 text-[11px] font-semibold leading-4 text-slate-300">
                                  {perk.description_raw || perk.effect_key}
                                </div>
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    </div>
                  )}
                </article>
              );
            })}
          </div>
        )}

        <div className="mt-4 rounded-xl border border-amber-400/10 bg-amber-400/[0.035] p-4 text-xs leading-5 text-slate-500">
          A fonte atual confirma a ordem dos perks, mas não prova todas as conexões/dependências da árvore. Por isso o HuntNexus não desbloqueia perks automaticamente nem presume que selecionar um perk ativa os anteriores.
        </div>
      </section>

      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
        <SectionTitle
          icon={Backpack}
          title="Set Main e itens da BP"
          subtitle="Seu Set Main é a base. A BP contém alternativas que o HuntNexus pode considerar para hunts específicas."
        />

        <div className="mt-4 rounded-xl border border-cyan-400/10 bg-cyan-400/[0.03] p-4 text-xs leading-5 text-slate-500">
          Regra do personagem: <strong className="text-slate-300">o Set Main continua sendo o padrão.</strong> Itens da BP podem substituir ou mesclar peças somente quando houver contexto factual para isso. Itens que você não possui serão mostrados separadamente como sugestões externas.
        </div>

        <div className="mt-5 grid gap-5 xl:grid-cols-[1.15fr_.85fr]">
          <div className="rounded-2xl border border-white/7 bg-[#07101b] p-4">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="font-bold text-white">Set Main</div>
                <div className="mt-1 text-[11px] text-slate-500">{inventory.summary.main_slots} slots cadastrados</div>
              </div>
              {inventoryLoading && <Loader2 className="size-4 animate-spin text-cyan-300" />}
            </div>

            <div className="mx-auto mt-5 grid max-w-[620px] grid-cols-3 gap-3">
              {mainSetSlots(form.vocation).map((slot) => {
                const item = inventory.main_set[slot.key];
                return (
                  <div key={slot.key} className="min-w-0">
                    <div className="mb-1 text-center text-[10px] uppercase tracking-wide text-slate-600">{slot.label}</div>
                    <div className={`relative rounded-2xl border p-2 transition ${
                      item ? "border-emerald-400/25 bg-emerald-400/[0.04]" : "border-white/7 bg-slate-950/60"
                    }`}>
                      <button
                        type="button"
                        onClick={() => openInventoryPicker("main", slot.key)}
                        className="grid min-h-[116px] w-full place-items-center rounded-xl text-center transition hover:bg-white/[0.025]"
                      >
                        {item ? (
                          <div className="grid place-items-center">
                            <CanonicalSprite kind="item" name={item.item_name} size="md" />
                            <div className="mt-2 line-clamp-2 text-[11px] font-semibold leading-4 text-slate-200">{item.item_name}</div>
                          </div>
                        ) : (
                          <div className="grid place-items-center gap-2 text-slate-600">
                            <Plus className="size-5" />
                            <span className="text-[10px]">Adicionar</span>
                          </div>
                        )}
                      </button>

                      {item && (
                        <button
                          type="button"
                          onClick={() => void removeInventoryItem(item.inventory_id)}
                          className="absolute right-1.5 top-1.5 grid size-7 place-items-center rounded-lg border border-white/7 bg-slate-950/90 text-slate-600 transition hover:border-red-400/20 hover:text-red-300"
                          title="Remover do Set Main"
                        >
                          <Trash2 className="size-3.5" />
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="rounded-2xl border border-white/7 bg-slate-950/45 p-4">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="font-bold text-white">Itens na BP</div>
                <div className="mt-1 text-[11px] text-slate-500">{inventory.summary.backpack_items} alternativas cadastradas</div>
              </div>
              <button type="button" onClick={() => openInventoryPicker("backpack", null)} className="hn-secondary-button">
                <Plus className="size-4" />
                Adicionar
              </button>
            </div>

            {inventory.backpack.length ? (
              <div className="mt-4 max-h-[520px] space-y-2 overflow-y-auto pr-1">
                {inventory.backpack.map((item) => (
                  <div key={item.inventory_id} className="flex items-center gap-3 rounded-xl border border-white/6 bg-white/[0.02] p-2.5">
                    <CanonicalSprite kind="item" name={item.item_name} size="sm" />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-semibold text-slate-200">{item.item_name}</div>
                      <div className="mt-1 text-[10px] text-slate-600">
                        {slotLabel(item.selection_key)} · {item.item_family || item.item_domain || "item"}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => void removeInventoryItem(item.inventory_id)}
                      className="grid size-8 shrink-0 place-items-center rounded-lg border border-white/7 text-slate-600 transition hover:border-red-400/20 hover:text-red-300"
                      title="Remover da BP"
                    >
                      <Trash2 className="size-3.5" />
                    </button>
                  </div>
                ))}
              </div>
            ) : (
              <div className="mt-4 grid min-h-[180px] place-items-center rounded-xl border border-dashed border-white/8 text-center">
                <div>
                  <Backpack className="mx-auto size-6 text-slate-700" />
                  <div className="mt-2 text-sm font-semibold text-slate-400">BP ainda vazia</div>
                  <div className="mt-1 text-xs text-slate-600">Cadastre armas e equipamentos alternativos que você realmente possui.</div>
                </div>
              </div>
            )}
          </div>
        </div>

        {inventoryTarget && (
          <div className="mt-5 rounded-2xl border border-cyan-400/15 bg-[#07101b] p-4">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan-400">
                  {inventoryTarget.storageKind === "main" ? `Selecionar ${slotLabel(inventoryTarget.selectionKey || "")}` : "Adicionar item à BP"}
                </div>
                <div className="mt-1 text-xs text-slate-500">Busca no catálogo real de equipamentos e armas do HuntNexus.</div>
              </div>
              <button
                type="button"
                onClick={() => {
                  setInventoryTarget(null);
                  setInventoryQuery("");
                  setInventoryResults([]);
                }}
                className="text-xs text-slate-500 transition hover:text-slate-300"
              >
                Fechar
              </button>
            </div>

            <div className="relative mt-4">
              <input
                autoFocus
                className="hn-control"
                value={inventoryQuery}
                onChange={(e) => setInventoryQuery(e.target.value)}
                placeholder="Digite o nome do item..."
              />
              {inventorySearching && <Loader2 className="absolute right-3 top-1/2 size-4 -translate-y-1/2 animate-spin text-cyan-300" />}
            </div>

            {inventoryQuery.trim().length >= 2 && !inventorySearching && inventoryResults.length === 0 && (
              <div className="mt-3 text-xs text-slate-600">Nenhum item encontrado.</div>
            )}

            {inventoryResults.length > 0 && (
              <div className="mt-3 grid gap-2 md:grid-cols-2">
                {inventoryResults.map((item) => {
                  const blockedForMain = inventoryTarget.storageKind === "main" && !item.eligible;
                  return (
                    <button
                      key={`${item.selection_key}-${item.item_key}`}
                      type="button"
                      disabled={blockedForMain}
                      onClick={() => void putInventoryItem(item)}
                      className="flex items-center gap-3 rounded-xl border border-white/7 bg-white/[0.02] p-3 text-left transition hover:border-cyan-400/20 hover:bg-cyan-400/[0.035] disabled:cursor-not-allowed disabled:opacity-45"
                    >
                      <CanonicalSprite kind="item" name={item.name} size="sm" />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-semibold text-slate-200">{item.name}</span>
                        <span className="mt-1 block text-[10px] text-slate-600">
                          {slotLabel(item.selection_key)} · Level {item.level_required ?? "—"} · {item.item_family}
                        </span>
                        {!item.eligible && (
                          <span className="mt-1 block text-[10px] text-amber-300/80">
                            Não elegível para o level/vocação atual
                          </span>
                        )}
                      </span>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        )}
      </section>

      <section className="rounded-3xl border border-white/8 bg-slate-950/45 p-5 md:p-6">
        <SectionTitle icon={Sparkles} title="Preferências padrão" subtitle="Pré-preenchidas automaticamente no Hunt Planner." />
        <div className="mt-5 grid gap-4 sm:grid-cols-3">
          <Field label="Objetivo da hunt">
            <select className="hn-control" value={form.hunt_objective} onChange={(e) => patch("hunt_objective", e.target.value as FormState["hunt_objective"])}>
              <option value="xp">XP</option>
              <option value="profit">Profit</option>
              <option value="balanced">Balanced</option>
            </select>
          </Field>
          <Field label="Objetivo do set">
            <select className="hn-control" value={form.set_objective} onChange={(e) => patch("set_objective", e.target.value as FormState["set_objective"])}>
              <option value="offense">Offense</option>
              <option value="defense">Defense</option>
              <option value="sustain">Sustain</option>
              <option value="utility">Utility</option>
              <option value="balanced">Balanced</option>
            </select>
          </Field>
          <Field label="Party padrão">
            <select className="hn-control" value={form.party_size} onChange={(e) => patch("party_size", e.target.value)}>
              <option value="1">Solo</option>
              <option value="2">Duo</option>
              <option value="3">Trio</option>
              <option value="4">x4</option>
              <option value="5">x5+</option>
            </select>
          </Field>
        </div>
      </section>

      {message && <div className="text-sm text-emerald-300">{message}</div>}
      {error && <div className="text-sm text-red-300">{error}</div>}

      <div className="border-t border-white/8 pt-5">
        <button className="hn-primary-button" onClick={() => void save()} disabled={saving}>
          {saving ? <Loader2 className="size-4 animate-spin" /> : <Save className="size-4" />}
          Salvar perfil
        </button>
      </div>
    </div>
  );
}

function ProficiencyPerkIcon({ perk }: { perk: ProficiencyPerk }) {
  const files = proficiencyIconFiles(perk.effect_key);
  return (
    <div className="relative grid size-14 place-items-center">
      <span className="absolute inset-0 grid place-items-center text-lg font-black text-slate-600">
        {perk.perk_order}
      </span>
      {files.map((file, index) => (
        <img
          key={file}
          src={tibiaWikiFile(file)}
          alt=""
          loading="lazy"
          referrerPolicy="no-referrer"
          className={`relative z-10 max-h-12 max-w-12 object-contain [image-rendering:pixelated] ${files.length > 1 && index > 0 ? "absolute bottom-0 right-0 max-h-7 max-w-7" : ""}`}
          onError={(event) => { event.currentTarget.style.display = "none"; }}
        />
      ))}
    </div>
  );
}

function tibiaWikiFile(filename: string) {
  return `https://www.tibiawiki.com.br/wiki/Special:Redirect/file/${encodeURIComponent(filename).replace(/%20/g, "_")}`;
}

function proficiencyIconFiles(effectKey: string) {
  const exact: Record<string,string[]> = {
    critical_extra_damage: ["Proficiency Type Critical Dmg.gif"],
    critical_chance: ["Proficiency Type Critical Chance.gif"],
    magic_level_bonus: ["Proficiency Type Skill Magic.gif"],
    mana_on_kill: ["Proficiency Type Mana On Kill.gif"],
    death_magic_level_bonus: ["Proficiency Type Magic Boost Death.gif"],
    energy_magic_level_bonus: ["Proficiency Type Magic Boost Energy.gif"],
    fire_magic_level_bonus: ["Proficiency Type Magic Boost Fire.gif"],
    death_spells_runes_critical_chance: ["Proficiency Type Element Critical Chance Death.gif"],
    death_spells_runes_critical_extra_damage: ["Proficiency Type Element Critical Dmg Death.gif"],
    energy_spells_runes_critical_chance: ["Proficiency Type Element Critical Chance Energy.gif"],
    energy_spells_runes_critical_extra_damage: ["Proficiency Type Element Critical Dmg Energy.gif"],
    fire_spells_runes_critical_chance: ["Proficiency Type Element Critical Chance Fire.gif"],
    fire_spells_runes_critical_extra_damage: ["Proficiency Type Element Critical Dmg Fire.gif"],
    offensive_rune_critical_chance: ["Proficiency Type Rune Critical Chance.gif"],
    offensive_rune_critical_extra_damage: ["Proficiency Type Rune Critical Dmg.gif"],
    magic_level_spell_extra_damage_percent: ["Proficiency Type Perc Spell Dmg Magic.gif"],
    bestiary_demon_damage: ["Proficiency Type Bestiary Dmg Demon.gif"],
    bestiary_inkborn_damage: ["Proficiency Type Bestiary Dmg Inkborn.gif"],
    bestiary_magical_damage: ["Proficiency Type Bestiary Dmg Magical.gif"],
    powerful_foe_damage: ["Proficiency Type Powerful Foe Bonus.gif"],
    great_death_beam_critical_chance: ["Proficiency Spell Great Death Beam.gif","Proficiency Augment Critical Chance.gif"],
    great_death_beam_critical_extra_damage: ["Proficiency Spell Great Death Beam.gif","Proficiency Augment Critical Dmg.gif"],
    great_fire_wave_critical_extra_damage: ["Proficiency Spell Great Fire Wave.gif","Proficiency Augment Critical Dmg.gif"],
    energy_wave_base_damage: ["Proficiency Spell Energy Wave.gif","Proficiency Augment Damage.gif"],
    hells_core_base_damage: ["Proficiency Spell Hells Core.gif","Proficiency Augment Damage.gif"],
    hells_core_critical_extra_damage: ["Proficiency Spell Hells Core.gif","Proficiency Augment Critical Dmg.gif"],
    rage_of_the_skies_critical_extra_damage: ["Proficiency Spell Rage of the Skies.gif","Proficiency Augment Critical Dmg.gif"],
    rage_of_the_skies_mana_leech: ["Proficiency Spell Rage of the Skies.gif","Proficiency Augment Mana Leech.gif"],
  };
  return exact[effectKey] ?? [];
}

function CharacterMeta({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-white/7 bg-slate-950/35 px-3 py-2">
      <div className="text-[9px] uppercase tracking-wide text-slate-600">{label}</div>
      <div className="mt-1 text-sm font-bold text-slate-200">{value}</div>
    </div>
  );
}

function vocationLabel(vocation: string) {
  return ({
    EK: "Elite Knight",
    RP: "Royal Paladin",
    ED: "Elder Druid",
    MS: "Master Sorcerer",
    EM: "Exalted Monk",
  } as Record<string,string>)[vocation] || vocation || "—";
}

function vocationBackdrop(vocation: string) {
  return ({
    EK: "bg-[radial-gradient(circle_at_center,rgba(251,146,60,.14),transparent_58%)]",
    RP: "bg-[radial-gradient(circle_at_center,rgba(250,204,21,.12),transparent_58%)]",
    ED: "bg-[radial-gradient(circle_at_center,rgba(74,222,128,.12),transparent_58%)]",
    MS: "bg-[radial-gradient(circle_at_center,rgba(168,85,247,.16),transparent_58%)]",
    EM: "bg-[radial-gradient(circle_at_center,rgba(34,211,238,.12),transparent_58%)]",
  } as Record<string,string>)[vocation] || "bg-[radial-gradient(circle_at_center,rgba(34,211,238,.08),transparent_58%)]";
}

function SectionTitle({ icon: Icon, title, subtitle }: { icon: typeof Swords; title: string; subtitle: string }) {
  return (
    <div className="flex items-start gap-3">
      <div className="grid size-10 place-items-center rounded-xl bg-cyan-400/10 text-cyan-300"><Icon className="size-4" /></div>
      <div>
        <div className="font-bold text-white">{title}</div>
        <div className="mt-1 text-xs text-slate-500">{subtitle}</div>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return <label className="space-y-2 text-xs font-medium text-slate-400"><span>{label}</span>{children}</label>;
}

function NumberInput({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  return <input className="hn-control" type="number" min="0" value={value} onChange={(e) => onChange(e.target.value)} />;
}

function Summary({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-white/6 bg-white/[0.025] p-3">
      <div className="text-[10px] uppercase tracking-wide text-slate-600">{label}</div>
      <div className="mt-1 truncate text-sm font-bold text-slate-200">{value}</div>
    </div>
  );
}

function toString(value: unknown) {
  return value == null ? "" : String(value);
}

function numberOrNull(value: string) {
  const n = Number(value);
  return value.trim() && Number.isFinite(n) ? n : null;
}

function compactObject<T extends Record<string, unknown>>(input: T) {
  return Object.fromEntries(Object.entries(input).filter(([, value]) => value !== null && value !== ""));
}

function baseWeaponSkill(form: FormState) {
  if (form.weapon_family === "sword") return form.sword;
  if (form.weapon_family === "axe") return form.axe;
  if (form.weapon_family === "club") return form.club;
  if (form.weapon_family === "bow" || form.weapon_family === "crossbow") return form.distance;
  if (form.weapon_family === "fist") return form.fist;
  return "";
}

function weaponFamilyOptions(vocation: string) {
  if (vocation === "EK") return [
    { value: "sword", label: "Sword" },
    { value: "axe", label: "Axe" },
    { value: "club", label: "Club" },
  ];
  if (vocation === "RP") return [
    { value: "bow", label: "Bow" },
    { value: "crossbow", label: "Crossbow" },
  ];
  if (vocation === "ED") return [{ value: "rod", label: "Rod" }];
  if (vocation === "MS") return [{ value: "wand", label: "Wand" }];
  if (vocation === "EM") return [{ value: "fist", label: "Fist" }];
  return [];
}

function mainSetSlots(vocation: string) {
  const slots = [
    { key: "neck", label: "Amuleto" },
    { key: "head", label: "Helmet" },
    { key: "ring", label: "Ring" },
    { key: "weapon", label: "Weapon" },
    { key: "body", label: "Armor" },
    { key: "offhand", label: "Off-hand" },
    { key: "legs", label: "Legs" },
    { key: "feet", label: "Boots" },
  ];
  if (vocation === "RP") slots.push({ key: "ammunition", label: "Ammo" });
  return slots;
}

function slotLabel(selectionKey: string) {
  const labels: Record<string, string> = {
    head: "Helmet",
    body: "Armor",
    legs: "Legs",
    feet: "Boots",
    neck: "Amuleto",
    ring: "Ring",
    weapon: "Weapon",
    offhand: "Off-hand",
    ammunition: "Ammo",
  };
  return labels[selectionKey] || selectionKey || "Item";
}

function compareFinalStat(label: string, baseRaw: string, finalRaw: string) {
  const base = Number(baseRaw);
  const finalValue = Number(finalRaw);
  if (!baseRaw.trim() || !finalRaw.trim() || !Number.isFinite(base) || !Number.isFinite(finalValue)) return null;
  if (finalValue >= base) return null;
  return `${label} final (${finalValue}) está abaixo do valor base (${base}).`;
}
