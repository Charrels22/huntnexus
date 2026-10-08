/* eslint-disable @typescript-eslint/no-explicit-any -- API returns untyped jsonb previews */
import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { AlertTriangle, Loader2, ShieldAlert } from "lucide-react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "HuntNexus — Hunts e Bosses explicáveis" },
      { name: "description", content: "Recomendações explicáveis de hunts e bosses com dados factuais, sessões observadas e regras versionadas do RubinOT." },
      { property: "og:title", content: "HuntNexus — Hunts e Bosses explicáveis" },
      { property: "og:description", content: "Recomendações explicáveis de hunts e bosses com dados factuais, sessões observadas e regras versionadas do RubinOT." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: HomePage,
});

const VOCATIONS = [
  { v: "EK", label: "Elite Knight (EK)" },
  { v: "RP", label: "Royal Paladin (RP)" },
  { v: "ED", label: "Elder Druid (ED)" },
  { v: "MS", label: "Master Sorcerer (MS)" },
];
const PARTY = [
  { v: "1", label: "Solo" }, { v: "2", label: "Duo" }, { v: "3", label: "Trio" },
  { v: "4", label: "x4" }, { v: "5", label: "x5+" },
];
const BLOCKED_TEXT = "O HuntNexus não apresenta uma build final enquanto a mecânica atual da sala não estiver reconciliada.";

async function callApi(body: Record<string, unknown>): Promise<any> {
  const res = await fetch("/api/huntnexus", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.detail ?? data?.error ?? `HTTP ${res.status}`);
  return data;
}

const fmt = (n: unknown, digits = 0) =>
  typeof n === "number" ? n.toLocaleString("pt-BR", { maximumFractionDigits: digits }) : "—";
const arr = (x: unknown): any[] => (Array.isArray(x) ? x : []);

function HomePage() {
  return (
    <main className="mx-auto max-w-5xl space-y-6 px-4 py-10">
      <header className="space-y-1">
        <h1 className="text-3xl font-semibold tracking-tight">HuntNexus</h1>
        <p className="text-muted-foreground">
          Recomendações explicáveis usando dados factuais, sessões observadas e regras versionadas do RubinOT.
        </p>
      </header>
      <Tabs defaultValue="hunts">
        <TabsList>
          <TabsTrigger value="hunts">Hunts</TabsTrigger>
          <TabsTrigger value="bosses">Bosses</TabsTrigger>
        </TabsList>
        <TabsContent value="hunts" className="mt-4"><HuntsTab /></TabsContent>
        <TabsContent value="bosses" className="mt-4"><BossesTab /></TabsContent>
      </Tabs>
    </main>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return <div className="space-y-1.5"><Label>{label}</Label>{children}</div>;
}

function VocationSelect({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger><SelectValue /></SelectTrigger>
      <SelectContent>{VOCATIONS.map((o) => <SelectItem key={o.v} value={o.v}>{o.label}</SelectItem>)}</SelectContent>
    </Select>
  );
}

function Stat({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="rounded-md border px-3 py-2">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="font-medium tabular-nums">{value}</div>
    </div>
  );
}

function SpellList({ title, spells }: { title: string; spells: any[] }) {
  if (!spells.length) return null;
  return (
    <div className="space-y-1">
      <div className="text-sm font-medium">{title}</div>
      <ul className="space-y-1 text-sm">
        {spells.map((s, i) => (
          <li key={s.spell_key ?? i} className="flex flex-wrap items-baseline gap-x-2">
            <span>{s.name}</span>
            {s.words && <code className="text-xs text-muted-foreground">{s.words}</code>}
            {s.element && <Badge variant="outline">{s.element}</Badge>}
            {s.cooldown_seconds != null && <span className="text-xs text-muted-foreground">cd {s.cooldown_seconds}s</span>}
          </li>
        ))}
      </ul>
    </div>
  );
}

function ImbueSummary({ label, data }: { label: string; data: any }) {
  if (!data || Number(data.imbue_slots ?? 0) < 1) return null;
  const candidates = [
    ...arr(data.protection_candidates),
    ...arr(data.skill_candidates),
    ...arr(data.core_offense_sustain_candidates),
  ];
  const names = Array.from(new Set(candidates.map((x) => x.name).filter(Boolean)));
  return (
    <li className="text-sm">
      <span className="text-muted-foreground">{label}:</span>{" "}
      <span className="font-medium">{data.name}</span>{" "}
      <Badge variant="outline">{data.imbue_slots} slot{Number(data.imbue_slots) === 1 ? "" : "s"}</Badge>
      {names.length > 0 && (
        <span className="ml-2 text-xs text-muted-foreground">
          {names.slice(0, 5).join(", ")}{names.length > 5 ? ` +${names.length - 5}` : ""}
        </span>
      )}
    </li>
  );
}

function ErrorBox({ msg }: { msg: string }) {
  return (
    <Alert variant="destructive"><AlertTriangle className="h-4 w-4" /><AlertTitle>Erro</AlertTitle><AlertDescription>{msg}</AlertDescription></Alert>
  );
}

/* ---------------- HUNTS ---------------- */

function HuntsTab() {
  const [vocation, setVocation] = useState("EK");
  const [level, setLevel] = useState("300");
  const [objective, setObjective] = useState("balanced");
  const [party, setParty] = useState("1");
  const [profileContract, setProfileContract] = useState<any>(null);
  const [weaponFamily, setWeaponFamily] = useState("none");
  const [weaponSkill, setWeaponSkill] = useState("");
  const [shielding, setShielding] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<any>(null);

  useEffect(() => {
    let active = true;
    callApi({ action: "profile_contract", vocation })
      .then((r) => { if (active) setProfileContract(r.data); })
      .catch(() => { if (active) setProfileContract(null); });
    if (vocation !== "EK") {
      setWeaponFamily("none");
      setWeaponSkill("");
      setShielding("");
    }
    return () => { active = false; };
  }, [vocation]);

  async function run() {
    setLoading(true); setError(null);
    try {
      const characterProfile = vocation === "EK" && weaponFamily !== "none"
        ? {
            weapon_family: weaponFamily,
            ...(Number(weaponSkill) > 0 ? { effective_weapon_skill: Number(weaponSkill) } : {}),
            ...(shielding !== "" && Number(shielding) >= 0 ? { effective_shielding: Number(shielding) } : {}),
          }
        : undefined;
      setResult(await callApi({
        action: "recommend",
        vocation,
        level: Number(level),
        objective,
        party_size: Number(party),
        ...(characterProfile ? { character_profile: characterProfile } : {}),
      }));
    } catch (e) { setError((e as Error).message); setResult(null); }
    finally { setLoading(false); }
  }

  const results = arr(result?.data?.results);
  const warnings = arr(result?.warnings);

  return (
    <div className="space-y-4">
      <Card>
        <CardContent className="space-y-4 pt-6">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            <Field label="Vocação"><VocationSelect value={vocation} onChange={setVocation} /></Field>
            <Field label="Level"><Input type="number" min={1} value={level} onChange={(e) => setLevel(e.target.value)} /></Field>
            <Field label="Objetivo">
              <Select value={objective} onValueChange={setObjective}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="xp">XP</SelectItem><SelectItem value="profit">Profit</SelectItem><SelectItem value="balanced">Balanced</SelectItem>
                </SelectContent>
              </Select>
            </Field>
            <Field label="Party size">
              <Select value={party} onValueChange={setParty}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{PARTY.map((p) => <SelectItem key={p.v} value={p.v}>{p.label}</SelectItem>)}</SelectContent>
              </Select>
            </Field>
            <div className="flex items-end">
              <Button className="w-full" onClick={run} disabled={loading || Number(level) < 1}>
                {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Analisar hunts
              </Button>
            </div>
          </div>

          {vocation === "EK" && (
            <div className="space-y-3 rounded-md border bg-muted/20 p-3">
              <div className="flex flex-wrap items-center gap-2">
                <div className="text-sm font-medium">Perfil de combate EK</div>
                <Badge variant="outline">opcional</Badge>
              </div>
              <div className="grid gap-3 sm:grid-cols-3">
                <Field label="Família de arma">
                  <Select value={weaponFamily} onValueChange={setWeaponFamily}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="none">Não informar</SelectItem>
                      {arr(profileContract?.vocation_specific?.weapon_family?.values).map((family) => (
                        <SelectItem key={family} value={family}>
                          {family === "sword" ? "Sword" : family === "axe" ? "Axe" : family === "club" ? "Club" : family}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Field label="Skill efetivo">
                  <Input
                    type="number"
                    min={1}
                    max={1000}
                    placeholder="ex.: 120"
                    value={weaponSkill}
                    disabled={weaponFamily === "none"}
                    onChange={(e) => setWeaponSkill(e.target.value)}
                  />
                </Field>
                <Field label="Shielding efetivo">
                  <Input
                    type="number"
                    min={0}
                    max={1000}
                    placeholder="opcional"
                    value={shielding}
                    disabled={weaponFamily === "none"}
                    onChange={(e) => setShielding(e.target.value)}
                  />
                </Field>
              </div>
              <p className="text-xs text-muted-foreground">
                {profileContract?.input_principle ??
                  "Use os valores efetivos mostrados pelo cliente. O perfil não é obrigatório."}
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      {error && <ErrorBox msg={error} />}

      {warnings.length > 0 && (
        <Alert><AlertTriangle className="h-4 w-4" /><AlertTitle>Alterações RubinOT pendentes ({warnings.length})</AlertTitle>
          <AlertDescription>
            <ul className="list-disc pl-4">{warnings.map((w, i) => <li key={i}>{w.summary ?? w.notes ?? JSON.stringify(w)}{w.patch_version ? ` (${w.patch_version})` : ""}</li>)}</ul>
          </AlertDescription>
        </Alert>
      )}

      {result && (
        <p className="text-xs text-muted-foreground">
          Dados observados são evidência comunitária, não garantia.
        </p>
      )}

      {result && results.length === 0 && (
        <p className="text-sm text-muted-foreground">Nenhuma hunt com sessões observadas para esses filtros.</p>
      )}

      {results.map((r, i) => <HuntResult key={r.ranking?.hunt_key ?? i} rank={i + 1} r={r} />)}
    </div>
  );
}

function HuntResult({ rank, r }: { rank: number; r: any }) {
  const k = r.ranking ?? {};
  const incoming = arr(r.defensive_candidates?.incoming_damage);
  const defensive = arr(r.defensive_candidates?.candidates);
  const imbues = arr(r.imbuement_candidates?.defensive_priority);
  const sp = r.spell_candidates ?? {};
  const setPreview = r.loadout_set_preview ?? {};
  const selectedSlots = Object.entries(setPreview.selected_slots ?? {}) as Array<[string, any]>;
  const oneHand = setPreview.hand_options?.one_handed;
  const twoHand = setPreview.hand_options?.two_handed;
  const handAnalysis = setPreview.hand_analysis ?? {};
  const oneAnalysis = arr(handAnalysis.one_handed?.offense_options)[0] ?? {};
  const twoAnalysis = arr(handAnalysis.two_handed?.offense_options)[0] ?? {};
  const excludedWeapons = arr(handAnalysis.excluded_from_sustained_hunt);
  const imbuePreview = setPreview.imbuement_preview ?? {};
  const fixedImbues = Object.entries(imbuePreview.fixed_slots ?? {}) as Array<[string, any]>;
  const characterProfile = setPreview.character_profile ?? {};
  const characterProfileAnalysis = setPreview.character_profile_analysis ?? {};
  return (
    <Card>
      <CardHeader className="pb-3">
        <CardTitle className="flex flex-wrap items-center gap-2 text-lg">
          <span className="text-muted-foreground">#{rank}</span>{k.hunt_name}
        </CardTitle>
        <CardDescription className="flex flex-wrap gap-2">
          <Badge variant="secondary">score {fmt(k.ranking_score, 3)}</Badge>
          <Badge variant="outline">confiança {fmt(k.confidence_score, 3)}</Badge>
          <Badge variant="outline">{k.session_count ?? 0} sessões</Badge>
          {k.level_evidence_label && <Badge variant="outline">{k.level_evidence_label}</Badge>}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
          <Stat label="Raw XP/h (mediana)" value={fmt(k.median_raw_xp_per_hour)} />
          <Stat label="XP/h (mediana)" value={fmt(k.median_xp_per_hour)} />
          <Stat label="Balance/h (mediana)" value={fmt(k.median_balance_per_hour)} />
          <Stat label="Elemento mais forte observado" value={k.strongest_observed_element ?? "—"} />
        </div>

        {selectedSlots.length > 0 && (
          <div className="space-y-2 rounded-md border p-3">
            <div className="flex flex-wrap items-center gap-2">
              <div className="text-sm font-medium">Set sugerido (preview)</div>
              <Badge variant="outline">não final</Badge>
              {characterProfileAnalysis.applied && characterProfile.weapon_family && (
                <Badge variant="secondary">
                  perfil {characterProfile.weapon_family}
                  {characterProfile.effective_weapon_skill ? ` · skill ${characterProfile.effective_weapon_skill}` : ""}
                </Badge>
              )}
            </div>
            <p className="text-xs text-muted-foreground">
              {setPreview.methodology?.objective_policy ?? "Seleção por evidência, mantendo as dimensões separadas."}
            </p>
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {selectedSlots.map(([slot, item]) => (
                <div key={slot} className="rounded-md bg-muted/40 px-3 py-2 text-sm">
                  <div className="text-xs text-muted-foreground">{slot}</div>
                  <div className="font-medium">{item.name}</div>
                  <div className="mt-1 flex flex-wrap gap-1">
                    {Number(item.defensive_score) > 0 && <Badge variant="outline">def {fmt(item.defensive_score, 2)}</Badge>}
                    {Number(item.offensive_skill_total) > 0 && <Badge variant="outline">off {fmt(item.offensive_skill_total, 0)}</Badge>}
                    {Number(item.imbue_slots) > 0 && <Badge variant="outline">{item.imbue_slots} imbue</Badge>}
                  </div>
                </div>
              ))}
            </div>

            {(oneHand?.available || twoHand?.available) && (
              <div className="space-y-2 pt-1">
                <div className="flex flex-wrap items-center gap-2 text-sm font-medium">
                  Configuração de mãos
                  {setPreview.recommended_hand_configuration ? (
                    <Badge variant="secondary">
                      dominância: {setPreview.recommended_hand_configuration === "two_handed" ? "2 mãos" : "1 mão + off-hand"}
                    </Badge>
                  ) : (
                    <Badge variant="secondary">trade-off aberto</Badge>
                  )}
                </div>
                <div className="grid gap-2 sm:grid-cols-2">
                  {oneHand?.available && (
                    <div className="rounded-md border px-3 py-2 text-sm">
                      <div className="text-xs text-muted-foreground">1 mão + off-hand</div>
                      <div className="font-medium">{oneHand.main_hand?.name ?? "—"}</div>
                      <div className="text-xs text-muted-foreground">
                        {oneHand.off_hand?.name ? `Off-hand: ${oneHand.off_hand.name}` : "Sem off-hand candidato"}
                      </div>
                      {oneAnalysis.weapon && (
                        <div className="mt-2 flex flex-wrap gap-1">
                          <Badge variant="outline">atk proxy {fmt(oneAnalysis.weapon.effective_attack_proxy, 2)}</Badge>
                          <Badge variant="outline">skill +{fmt(oneAnalysis.matching_weapon_skill_bonus, 0)}</Badge>
                          {oneAnalysis.effective_weapon_skill_with_items != null && (
                            <Badge variant="outline">skill efetivo {fmt(oneAnalysis.effective_weapon_skill_with_items, 0)}</Badge>
                          )}
                          {oneAnalysis.effective_shielding_with_offhand != null && (
                            <Badge variant="outline">shield {fmt(oneAnalysis.effective_shielding_with_offhand, 0)}</Badge>
                          )}
                          <Badge variant="outline">prot {fmt(oneAnalysis.weighted_protection, 2)}</Badge>
                          <Badge variant="outline">{oneAnalysis.imbue_capacity ?? 0} imbue</Badge>
                        </div>
                      )}
                    </div>
                  )}
                  {twoHand?.available && (
                    <div className="rounded-md border px-3 py-2 text-sm">
                      <div className="text-xs text-muted-foreground">2 mãos</div>
                      <div className="font-medium">{twoHand.item?.name ?? "—"}</div>
                      {twoAnalysis.item_key && (
                        <div className="mt-2 flex flex-wrap gap-1">
                          <Badge variant="outline">atk proxy {fmt(twoAnalysis.effective_attack_proxy, 2)}</Badge>
                          <Badge variant="outline">skill +{fmt(twoAnalysis.weapon_skill_bonus, 0)}</Badge>
                          {twoAnalysis.effective_weapon_skill_with_item != null && (
                            <Badge variant="outline">skill efetivo {fmt(twoAnalysis.effective_weapon_skill_with_item, 0)}</Badge>
                          )}
                          <Badge variant="outline">prot {fmt(twoAnalysis.weighted_protection, 2)}</Badge>
                          <Badge variant="outline">{twoAnalysis.imbue_capacity ?? 0} imbue</Badge>
                        </div>
                      )}
                    </div>
                  )}
                </div>

                {!setPreview.recommended_hand_configuration && (
                  <p className="text-xs text-muted-foreground">
                    Nenhuma configuração domina a outra em ataque efetivo, skill compatível, proteção observada e capacidade de imbue; o HuntNexus mantém o trade-off explícito.
                  </p>
                )}
                {characterProfileAnalysis.applied && (
                  <p className="text-xs text-muted-foreground">
                    O perfil restringe armas à família treinada. Skill e shielding efetivos entram como contexto; ainda não são convertidos em DPS/mitigação final.
                  </p>
                )}

                {excludedWeapons.length > 0 && (
                  <p className="text-xs text-muted-foreground">
                    Fora da hunt sustentada: {excludedWeapons.map((x) => `${x.name} (${x.reason})`).join(", ")}.
                  </p>
                )}
              </div>
            )}

            {imbuePreview.methodology?.stage && (
              <div className="space-y-2 border-t pt-3">
                <div className="flex flex-wrap items-center gap-2">
                  <div className="text-sm font-medium">Imbuements compatíveis (preview)</div>
                  <Badge variant="outline">sem prioridade entre categorias</Badge>
                </div>
                <ul className="space-y-1">
                  {fixedImbues.map(([slot, data]) => (
                    <ImbueSummary key={slot} label={slot} data={data} />
                  ))}
                  <ImbueSummary
                    label="1 mão"
                    data={imbuePreview.hand_options?.one_handed?.main_hand}
                  />
                  <ImbueSummary
                    label="Off-hand"
                    data={imbuePreview.hand_options?.one_handed?.off_hand}
                  />
                  <ImbueSummary
                    label="2 mãos"
                    data={imbuePreview.hand_options?.two_handed}
                  />
                </ul>
                <p className="text-xs text-muted-foreground">
                  Compatibilidade respeita categoria e quantidade de slots. Proteções elementais são ordenadas pelo dano recebido observado; Strike, leech e skill continuam sem peso artificial entre si.
                </p>
              </div>
            )}
          </div>
        )}

        {incoming.length > 0 && (
          <div className="space-y-1">
            <div className="text-sm font-medium">Dano recebido observado por elemento</div>
            <div className="flex flex-wrap gap-2">
              {incoming.map((d, i) => (
                <Badge key={i} variant="outline">
                  {d.element}: {typeof d.weight === "number" ? `${Math.round(d.weight * 100)}%` : fmt(d.share ?? d.damage_share ?? d.total_damage ?? d.median_damage ?? d.damage, 3)}
                </Badge>
              ))}
            </div>
          </div>
        )}

        {defensive.length > 0 && (
          <div className="space-y-1">
            <div className="text-sm font-medium">Candidatos defensivos</div>
            <ul className="grid gap-1 text-sm sm:grid-cols-2">
              {defensive.map((d, i) => (
                <li key={d.item_key ?? i}><span className="text-muted-foreground">{d.slot}:</span> {d.name} <span className="text-xs text-muted-foreground">({fmt(d.weighted_protection_score, 2)})</span></li>
              ))}
            </ul>
          </div>
        )}

        {imbues.length > 0 && (
          <div className="space-y-1">
            <div className="text-sm font-medium">Imbuements defensivos prioritários</div>
            <div className="flex flex-wrap gap-2">{imbues.map((m, i) => <Badge key={m.imbuement_key ?? i} variant="secondary">{m.name}{m.element ? ` · ${m.element}` : ""}</Badge>)}</div>
          </div>
        )}

        <div className="grid gap-4 sm:grid-cols-2">
          <SpellList title="Magias candidatas — alvo único" spells={arr(sp.single_target_attacks)} />
          <SpellList title="Magias candidatas — múltiplos alvos" spells={arr(sp.multi_target_attacks)} />
        </div>
      </CardContent>
    </Card>
  );
}

/* ---------------- BOSSES ---------------- */

function BossesTab() {
  const [query, setQuery] = useState("");
  const [bosses, setBosses] = useState<any[]>([]);
  const [searching, setSearching] = useState(false);
  const [selected, setSelected] = useState<any>(null);
  const [vocation, setVocation] = useState("MS");
  const [level, setLevel] = useState("300");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<any>(null);

  useEffect(() => {
    const t = setTimeout(async () => {
      setSearching(true);
      try { setBosses(arr((await callApi({ action: "search_bosses", query, limit: 20 })).data)); }
      catch (e) { setError((e as Error).message); }
      finally { setSearching(false); }
    }, 300);
    return () => clearTimeout(t);
  }, [query]);

  async function run() {
    if (!selected) return;
    setLoading(true); setError(null);
    try { setResult(await callApi({ action: "boss_build", boss_key: selected.boss_key, vocation, level: Number(level) })); }
    catch (e) { setError((e as Error).message); setResult(null); }
    finally { setLoading(false); }
  }

  return (
    <div className="space-y-4">
      <Card>
        <CardContent className="space-y-4 pt-6">
          <Field label="Buscar boss">
            <Input placeholder="ex.: Magma Bubble, Soul War…" value={query} onChange={(e) => setQuery(e.target.value)} />
          </Field>
          <div className="max-h-56 overflow-y-auto rounded-md border">
            {searching && <div className="p-3 text-sm text-muted-foreground">Buscando…</div>}
            {!searching && bosses.length === 0 && <div className="p-3 text-sm text-muted-foreground">Nenhum boss encontrado.</div>}
            {bosses.map((b) => (
              <button
                key={b.boss_key}
                type="button"
                onClick={() => { setSelected(b); setResult(null); }}
                className={`flex w-full items-center justify-between gap-2 border-b px-3 py-2 text-left text-sm last:border-b-0 hover:bg-accent ${selected?.boss_key === b.boss_key ? "bg-accent" : ""}`}
              >
                <span>{b.name}</span>
                {b.final_build_blocked && <Badge variant="destructive">bloqueado</Badge>}
              </button>
            ))}
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Vocação"><VocationSelect value={vocation} onChange={setVocation} /></Field>
            <Field label="Level"><Input type="number" min={1} value={level} onChange={(e) => setLevel(e.target.value)} /></Field>
            <div className="flex items-end">
              <Button className="w-full" onClick={run} disabled={!selected || loading || Number(level) < 1}>
                {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Analisar boss
              </Button>
            </div>
          </div>
          {selected && <p className="text-xs text-muted-foreground">Selecionado: {selected.name}</p>}
        </CardContent>
      </Card>

      {error && <ErrorBox msg={error} />}
      {result && <BossResult data={result.data} warnings={arr(result.warnings)} />}
    </div>
  );
}

function BossResult({ data, warnings }: { data: any; warnings: any[] }) {
  const rd = data?.readiness ?? {};
  const blocked = rd.final_build_blocked === true;
  const finalAvailable = data?.final_build_available === true && !blocked;
  const guards = arr(rd.guards);
  const elements = arr(data?.boss_profile?.element_profile);
  const sp = data?.spell_evidence ?? {};
  const restricted = arr(sp.boss_restricted_spells);

  return (
    <Card>
      <CardHeader className="pb-3">
        <CardTitle className="flex flex-wrap items-center gap-2 text-lg">
          {rd.name ?? data?.boss_profile?.boss?.name}
          {blocked && (
            <Badge variant="destructive" className="gap-1 text-sm"><ShieldAlert className="h-4 w-4" />Build final bloqueada</Badge>
          )}
        </CardTitle>
        <CardDescription><Badge variant="outline">{rd.readiness_status ?? "—"}</Badge></CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {!finalAvailable && (
          <Alert variant={blocked ? "destructive" : "default"}>
            <ShieldAlert className="h-4 w-4" />
            <AlertTitle>Sem build final</AlertTitle>
            <AlertDescription>{BLOCKED_TEXT}</AlertDescription>
          </Alert>
        )}

        {guards.length > 0 && (
          <div className="space-y-1">
            <div className="text-sm font-medium">Guards</div>
            <ul className="space-y-1 text-sm">
              {guards.map((g, i) => (
                <li key={g.guard_key ?? i}><Badge variant="outline" className="mr-2">{g.patch_version ?? "—"}</Badge>{g.reason}</li>
              ))}
            </ul>
          </div>
        )}

        {elements.length > 0 && (
          <div className="space-y-1">
            <div className="text-sm font-medium">Perfil elemental do boss</div>
            <div className="flex flex-wrap gap-2">
              {elements.map((e) => <Badge key={e.element} variant="outline">{e.element}: {fmt(e.avg_modifier_percent)}%</Badge>)}
            </div>
          </div>
        )}

        <div className="space-y-2">
          <div className="text-xs text-muted-foreground">Evidência de magias — não é uma build nem rotação final.</div>
          <div className="grid gap-4 sm:grid-cols-2">
            <SpellList title="Magias candidatas — alvo único" spells={arr(sp.single_target_attacks)} />
            <SpellList title="Magias candidatas — múltiplos alvos" spells={arr(sp.multi_target_attacks)} />
          </div>
        </div>

        {restricted.length > 0 && (
          <Alert variant="destructive">
            <AlertTriangle className="h-4 w-4" />
            <AlertTitle>Magias restritas neste boss</AlertTitle>
            <AlertDescription>
              <ul className="list-disc pl-4">{restricted.map((s, i) => <li key={s.spell_key ?? i}>{s.name}{s.words ? ` (${s.words})` : ""}{s.reason ? ` — ${s.reason}` : ""}</li>)}</ul>
            </AlertDescription>
          </Alert>
        )}

        {warnings.length > 0 && (
          <Alert>
            <AlertTriangle className="h-4 w-4" />
            <AlertTitle>Avisos globais de boss do RubinOT ({warnings.length})</AlertTitle>
            <AlertDescription>
              <ul className="list-disc pl-4">
                {warnings.map((w, i) => <li key={i}>{w.summary}{w.patch_version ? ` (${w.patch_version})` : ""}{w.reconciliation_status ? ` — ${w.reconciliation_status}` : ""}</li>)}
              </ul>
            </AlertDescription>
          </Alert>
        )}
      </CardContent>
    </Card>
  );
}