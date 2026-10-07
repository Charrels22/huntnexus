import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "HuntNexus" },
      {
        name: "description",
        content: "Hunt recommendations, evidence, builds and boss-room guidance.",
      },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: HuntNexusHome,
});

type Vocation = "EK" | "RP" | "ED" | "MS";
type Objective = "xp" | "profit" | "balanced";

function fmt(n: unknown) {
  if (typeof n !== "number") return "—";
  return new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 0 }).format(n);
}

async function callApi<T>(body: Record<string, unknown>) {
  const { data, error } = await supabase.functions.invoke("huntnexus-api", { body });
  if (error) throw error;
  if (data?.error) throw new Error(data.detail || data.error);
  return data as { data: T; warnings?: unknown[] };
}

function HuntNexusHome() {
  const [health, setHealth] = useState<any>(null);
  const [tab, setTab] = useState("hunts");

  useEffect(() => {
    callApi<any>({ action: "health" })
      .then((x) => setHealth(x.data))
      .catch(() => setHealth(null));
  }, []);

  return (
    <main className="mx-auto min-h-screen max-w-7xl space-y-6 p-4 md:p-8">
      <header className="flex flex-col gap-3 border-b pb-6 md:flex-row md:items-end md:justify-between">
        <div>
          <p className="text-xs font-medium uppercase tracking-[0.2em] text-muted-foreground">
            HuntNexus
          </p>
          <h1 className="text-3xl font-semibold tracking-tight">Hunt intelligence</h1>
          <p className="mt-1 max-w-2xl text-sm text-muted-foreground">
            Recomendações explicáveis usando dados factuais, sessões observadas e regras versionadas do RubinOT.
          </p>
        </div>
        <div className="flex flex-wrap gap-2 text-xs">
          {health?.versions?.latest_rubinot_server && (
            <Badge variant="secondary">RubinOT {health.versions.latest_rubinot_server}</Badge>
          )}
          {health?.counts?.hunts != null && (
            <Badge variant="outline">{fmt(health.counts.hunts)} hunts</Badge>
          )}
          {health?.counts?.bosses != null && (
            <Badge variant="outline">{fmt(health.counts.bosses)} bosses</Badge>
          )}
        </div>
      </header>

      <Tabs value={tab} onValueChange={setTab}>
        <TabsList>
          <TabsTrigger value="hunts">Hunts</TabsTrigger>
          <TabsTrigger value="bosses">Bosses</TabsTrigger>
        </TabsList>
        <TabsContent value="hunts" className="mt-6">
          <HuntPanel />
        </TabsContent>
        <TabsContent value="bosses" className="mt-6">
          <BossPanel />
        </TabsContent>
      </Tabs>
    </main>
  );
}

function HuntPanel() {
  const [vocation, setVocation] = useState<Vocation>("EK");
  const [level, setLevel] = useState(700);
  const [objective, setObjective] = useState<Objective>("balanced");
  const [partySize, setPartySize] = useState(1);
  const [loading, setLoading] = useState(false);
  const [payload, setPayload] = useState<any>(null);
  const [warnings, setWarnings] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    setLoading(true);
    setError(null);
    try {
      const r = await callApi<any>({
        action: "recommend",
        vocation,
        level,
        objective,
        party_size: partySize,
        limit: 5,
        defensive_items_per_slot: 3,
      });
      setPayload(r.data);
      setWarnings((r.warnings as any[]) ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Falha ao gerar recomendação.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[320px_1fr]">
      <Card className="h-fit">
        <CardHeader>
          <CardTitle>Encontrar hunt</CardTitle>
          <CardDescription>Informe o perfil usado no ranking.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <Field label="Vocação">
            <Select value={vocation} onValueChange={(v) => setVocation(v as Vocation)}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="EK">Elite Knight</SelectItem>
                <SelectItem value="RP">Royal Paladin</SelectItem>
                <SelectItem value="ED">Elder Druid</SelectItem>
                <SelectItem value="MS">Master Sorcerer</SelectItem>
              </SelectContent>
            </Select>
          </Field>

          <Field label="Level">
            <Input
              type="number"
              min={1}
              value={level}
              onChange={(e) => setLevel(Math.max(1, Number(e.target.value) || 1))}
            />
          </Field>

          <Field label="Objetivo">
            <Select value={objective} onValueChange={(v) => setObjective(v as Objective)}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="xp">XP</SelectItem>
                <SelectItem value="profit">Profit</SelectItem>
                <SelectItem value="balanced">Balanced</SelectItem>
              </SelectContent>
            </Select>
          </Field>

          <Field label="Party size">
            <Select value={String(partySize)} onValueChange={(v) => setPartySize(Number(v))}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="1">Solo</SelectItem>
                <SelectItem value="2">Duo</SelectItem>
                <SelectItem value="3">Trio</SelectItem>
                <SelectItem value="4">x4</SelectItem>
                <SelectItem value="5">x5+</SelectItem>
              </SelectContent>
            </Select>
          </Field>

          <Button className="w-full" onClick={run} disabled={loading}>
            {loading ? "Analisando…" : "Analisar hunts"}
          </Button>
        </CardContent>
      </Card>

      <div className="space-y-4">
        {error && <ErrorAlert text={error} />}

        {warnings.length > 0 && (
          <Alert>
            <AlertTitle>Alterações RubinOT pendentes</AlertTitle>
            <AlertDescription>
              Há {warnings.length} alteração(ões) recente(s) relacionada(s) à sua vocação ainda em reconciliação.
            </AlertDescription>
          </Alert>
        )}

        {!payload && !error && (
          <EmptyState title="Pronto para analisar" text="Preencha seu perfil e execute uma análise." />
        )}

        {payload?.results?.map((result: any, index: number) => (
          <HuntResult key={result.ranking?.hunt_key ?? index} result={result} rank={index + 1} />
        ))}
      </div>
    </div>
  );
}

function HuntResult({ result, rank }: { result: any; rank: number }) {
  const ranking = result.ranking ?? {};
  const observed = result.observed_profile?.performance ?? {};
  const defenses = result.defensive_candidates?.incoming_damage ?? [];
  const items = result.defensive_candidates?.candidates ?? [];
  const spells = result.spell_candidates ?? {};
  const imbuements = result.imbuement_candidates?.defensive_priority ?? [];

  const topItems = useMemo(() => items.slice(0, 6), [items]);

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle className="text-xl">#{rank} {ranking.hunt_name}</CardTitle>
            <CardDescription>
              {ranking.session_count ?? 0} sessão(ões) usadas no ranking · confiança {ranking.confidence_score ?? "—"}
            </CardDescription>
          </div>
          <div className="flex gap-2">
            <Badge>score {ranking.ranking_score ?? "—"}</Badge>
            {ranking.level_evidence_label && (
              <Badge variant="outline">{ranking.level_evidence_label}</Badge>
            )}
          </div>
        </div>
      </CardHeader>

      <CardContent className="space-y-5">
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <Metric label="Raw XP/h mediano" value={fmt(ranking.median_raw_xp_per_hour)} />
          <Metric label="XP/h mediano" value={fmt(ranking.median_xp_per_hour)} />
          <Metric label="Balance/h mediano" value={fmt(ranking.median_balance_per_hour)} />
          <Metric
            label="Melhor elemento observado"
            value={ranking.strongest_observed_element ?? "—"}
          />
        </div>

        {defenses.length > 0 && (
          <Block title="Dano recebido observado">
            <div className="flex flex-wrap gap-2">
              {defenses.slice(0, 6).map((d: any) => (
                <Badge key={d.element} variant="secondary">
                  {d.element}: {Math.round((d.weight ?? 0) * 100)}%
                </Badge>
              ))}
            </div>
          </Block>
        )}

        {topItems.length > 0 && (
          <Block title="Candidatos defensivos">
            <div className="grid gap-2 md:grid-cols-2">
              {topItems.map((item: any) => (
                <div key={item.item_key} className="rounded-md border p-3">
                  <div className="font-medium">{item.name}</div>
                  <div className="text-xs text-muted-foreground">
                    {item.slot ?? item.category} · proteção ponderada {item.weighted_protection_score ?? "—"}
                  </div>
                </div>
              ))}
            </div>
          </Block>
        )}

        {imbuements.length > 0 && (
          <Block title="Imbuements defensivos prioritários">
            <div className="flex flex-wrap gap-2">
              {imbuements.slice(0, 5).map((x: any) => (
                <Badge key={x.imbuement_key} variant="outline">
                  {x.name} · {x.element}
                </Badge>
              ))}
            </div>
          </Block>
        )}

        {(spells.single_target_attacks?.length > 0 || spells.multi_target_attacks?.length > 0) && (
          <Block title="Magias candidatas">
            <div className="grid gap-2 md:grid-cols-2">
              {[...(spells.single_target_attacks ?? []), ...(spells.multi_target_attacks ?? [])]
                .slice(0, 6)
                .map((s: any) => (
                  <div key={s.spell_key} className="rounded-md border p-3">
                    <div className="font-medium">{s.name}</div>
                    <div className="text-xs text-muted-foreground">
                      {s.words} · {s.element ?? "weapon"} · CD {s.cooldown_seconds ?? "—"}s
                    </div>
                  </div>
                ))}
            </div>
          </Block>
        )}

        {observed?.session_count != null && (
          <p className="text-xs text-muted-foreground">
            Métricas observadas são evidência comunitária e não garantia de performance.
          </p>
        )}
      </CardContent>
    </Card>
  );
}

function BossPanel() {
  const [query, setQuery] = useState("Magma Bubble");
  const [bosses, setBosses] = useState<any[]>([]);
  const [bossKey, setBossKey] = useState("magma-bubble");
  const [vocation, setVocation] = useState<Vocation>("EK");
  const [level, setLevel] = useState(700);
  const [payload, setPayload] = useState<any>(null);
  const [warnings, setWarnings] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function search() {
    setLoading(true);
    setError(null);
    try {
      const r = await callApi<any[]>({ action: "search_bosses", query, limit: 15 });
      setBosses(r.data ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Falha na busca.");
    } finally {
      setLoading(false);
    }
  }

  async function build(key = bossKey) {
    setLoading(true);
    setError(null);
    try {
      const r = await callApi<any>({
        action: "boss_build",
        boss_key: key,
        vocation,
        level,
      });
      setBossKey(key);
      setPayload(r.data);
      setWarnings((r.warnings as any[]) ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Falha ao analisar boss.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[360px_1fr]">
      <Card className="h-fit">
        <CardHeader>
          <CardTitle>Boss Room</CardTitle>
          <CardDescription>Busque um boss e consulte a prontidão da build.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <Field label="Buscar boss">
            <div className="flex gap-2">
              <Input value={query} onChange={(e) => setQuery(e.target.value)} />
              <Button variant="secondary" onClick={search} disabled={loading}>Buscar</Button>
            </div>
          </Field>

          {bosses.length > 0 && (
            <div className="max-h-60 space-y-1 overflow-auto rounded-md border p-2">
              {bosses.map((b) => (
                <button
                  key={b.boss_key}
                  className="flex w-full items-center justify-between rounded px-2 py-2 text-left text-sm hover:bg-muted"
                  onClick={() => build(b.boss_key)}
                >
                  <span>{b.name}</span>
                  {b.final_build_blocked && <Badge variant="destructive">guard</Badge>}
                </button>
              ))}
            </div>
          )}

          <Field label="Vocação">
            <Select value={vocation} onValueChange={(v) => setVocation(v as Vocation)}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="EK">Elite Knight</SelectItem>
                <SelectItem value="RP">Royal Paladin</SelectItem>
                <SelectItem value="ED">Elder Druid</SelectItem>
                <SelectItem value="MS">Master Sorcerer</SelectItem>
              </SelectContent>
            </Select>
          </Field>

          <Field label="Level">
            <Input type="number" value={level} onChange={(e) => setLevel(Number(e.target.value) || 1)} />
          </Field>

          <Button className="w-full" onClick={() => build()} disabled={loading || !bossKey}>
            {loading ? "Analisando…" : "Analisar boss"}
          </Button>
        </CardContent>
      </Card>

      <div className="space-y-4">
        {error && <ErrorAlert text={error} />}
        {!payload && !error && (
          <EmptyState title="Boss Room" text="Busque e selecione um boss para ver evidências e guards." />
        )}
        {payload && <BossResult payload={payload} warnings={warnings} />}
      </div>
    </div>
  );
}

function BossResult({ payload, warnings }: { payload: any; warnings: any[] }) {
  const boss = payload.boss_profile?.boss ?? {};
  const readiness = payload.readiness ?? {};
  const spells = payload.spell_evidence ?? {};

  return (
    <Card>
      <CardHeader>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle className="text-xl">{boss.name ?? payload.query?.boss_key}</CardTitle>
            <CardDescription>
              {readiness.readiness_status ?? "unknown"}
            </CardDescription>
          </div>
          {readiness.final_build_blocked ? (
            <Badge variant="destructive">Build final bloqueada</Badge>
          ) : (
            <Badge>Base disponível</Badge>
          )}
        </div>
      </CardHeader>
      <CardContent className="space-y-5">
        {readiness.guards?.map((g: any) => (
          <Alert key={g.guard_key}>
            <AlertTitle>{g.patch_version} · Reconciliação RubinOT</AlertTitle>
            <AlertDescription>{g.reason}</AlertDescription>
          </Alert>
        ))}

        {warnings.length > 0 && (
          <Alert>
            <AlertTitle>Aviso global de boss</AlertTitle>
            <AlertDescription>
              Existem {warnings.length} alteração(ões) RubinOT de sistema de boss ainda pendentes de detalhamento.
            </AlertDescription>
          </Alert>
        )}

        <Block title="Elementos do boss">
          <div className="flex flex-wrap gap-2">
            {(payload.boss_profile?.element_profile ?? []).slice(0, 10).map((e: any) => (
              <Badge key={e.element} variant="secondary">
                {e.element}: {e.avg_modifier_percent}%
              </Badge>
            ))}
          </div>
        </Block>

        <Block title="Magias">
          <div className="grid gap-2 md:grid-cols-2">
            {[...(spells.single_target_attacks ?? []), ...(spells.multi_target_attacks ?? [])]
              .slice(0, 8)
              .map((s: any) => (
                <div key={s.spell_key} className="rounded-md border p-3">
                  <div className="font-medium">{s.name}</div>
                  <div className="text-xs text-muted-foreground">
                    {s.words} · {s.element ?? "weapon"}
                  </div>
                </div>
              ))}
          </div>
        </Block>

        {(spells.boss_restricted_spells ?? []).length > 0 && (
          <Block title="Restritas nesta categoria de boss">
            <div className="flex flex-wrap gap-2">
              {spells.boss_restricted_spells.map((s: any) => (
                <Badge key={s.spell_key} variant="destructive">
                  {s.name}
                </Badge>
              ))}
            </div>
          </Block>
        )}

        {!payload.final_build_available && (
          <p className="text-xs text-muted-foreground">
            O HuntNexus não apresenta uma build final enquanto a mecânica atual da sala não estiver reconciliada.
          </p>
        )}
      </CardContent>
    </Card>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      {children}
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border p-3">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="mt-1 font-semibold">{value}</div>
    </div>
  );
}

function Block({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-2">
      <h3 className="text-sm font-semibold">{title}</h3>
      {children}
    </section>
  );
}

function EmptyState({ title, text }: { title: string; text: string }) {
  return (
    <Card>
      <CardContent className="py-12 text-center">
        <div className="font-medium">{title}</div>
        <div className="mt-1 text-sm text-muted-foreground">{text}</div>
      </CardContent>
    </Card>
  );
}

function ErrorAlert({ text }: { text: string }) {
  return (
    <Alert variant="destructive">
      <AlertTitle>Erro</AlertTitle>
      <AlertDescription>{text}</AlertDescription>
    </Alert>
  );
}
