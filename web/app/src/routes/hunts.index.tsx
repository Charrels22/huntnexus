import { createFileRoute, Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { BookOpen, Loader2, Search } from "lucide-react";
import { callHuntNexusApi } from "@/lib/api/huntnexus";

export const Route = createFileRoute("/hunts/")({
  validateSearch: (search: Record<string, unknown>) => ({
    q: typeof search.q === "string" ? search.q.slice(0, 100) : "",
  }),
  component: HuntCatalogPage,
});

type CatalogHunt = {
  hunt_key: string;
  name: string;
  city?: string | null;
  level_knights?: string | number | null;
  level_paladins?: string | number | null;
  level_mages?: string | number | null;
  observed_sessions?: number | null;
  planner_eligible?: boolean;
};

function HuntCatalogPage() {
  const { q } = Route.useSearch();
  const navigate = Route.useNavigate();
  const [query, setQuery] = useState(q);
  const [retry, setRetry] = useState(0);
  const [state, setState] = useState<{
    query: string; loading: boolean; error: boolean; hunts: CatalogHunt[];
  }>({ query: q, loading: true, error: false, hunts: [] });

  useEffect(() => { setQuery(q); }, [q]);

  useEffect(() => {
    let active = true;
    setState({ query, loading: true, error: false, hunts: [] });
    const timer = window.setTimeout(() => {
      callHuntNexusApi<{ data?: CatalogHunt[] }>({ action: "search_hunts", query: query.trim(), limit: 50 })
        .then((response) => {
          if (!Array.isArray(response.data)) throw new Error("Invalid catalog response");
          if (active) setState({ query, loading: false, error: false,
            hunts: response.data.filter((hunt) => hunt.planner_eligible !== false && typeof hunt.hunt_key === "string" && typeof hunt.name === "string") });
        })
        .catch(() => {
          if (active) setState({ query, loading: false, error: true, hunts: [] });
        });
    }, 300);
    return () => { active = false; window.clearTimeout(timer); };
  }, [query, retry]);

  const loading = state.loading || state.query !== query;
  const hunts = loading ? [] : state.hunts;
  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <section className="hn-hero rounded-3xl border border-white/8 p-5 md:p-7">
        <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-widest text-cyan-300"><BookOpen className="size-4" /> Catálogo factual · Tibia</div>
        <h1 className="mt-3 text-3xl font-black text-white">Catálogo de hunts</h1>
        <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-400">Explore hunts mesmo sem sessões da comunidade. Os dados de referência de Tibia (fonte B) são separados da performance observada (Tier C); não garantem XP, profit ou validade para um patch RubinOT.</p>
        <Link to="/planner" className="hn-secondary-button mt-4">Abrir Hunt Planner</Link>
      </section>

      <form role="search" className="space-y-2" onSubmit={(event) => {
        event.preventDefault();
        void navigate({ search: { q: query }, replace: true });
      }}>
        <label htmlFor="hunt-catalog-query" className="block text-sm font-medium text-slate-200">Buscar por hunt, cidade ou slug</label>
        <div className="flex gap-2">
          <div className="relative min-w-0 flex-1">
            <Search aria-hidden="true" className="absolute left-3 top-3 size-4 text-slate-500" />
            <input id="hunt-catalog-query" type="search" maxLength={100} value={query}
              onChange={(event) => setQuery(event.target.value)} aria-describedby="hunt-catalog-help"
              className="hn-search w-full rounded-xl border border-white/10 bg-white/5 py-2.5 pl-10 pr-3 text-sm text-white outline-none focus:border-cyan-300"
              placeholder="Ex.: Forest of Life, Ankrahmun..." />
          </div>
          <button type="submit" className="hn-primary-button">Buscar</button>
        </div>
        <p id="hunt-catalog-help" className="text-xs leading-5 text-slate-400">Até 50 resultados por busca. Refine o nome ou cidade para encontrar outras hunts. A busca respeita a elegibilidade do catálogo; bosses e spawns não fixos excluídos pela API ficam fora desta lista.</p>
      </form>

      <section aria-label="Resultados do catálogo" aria-busy={loading} className="space-y-4">
        <p role="status" aria-live="polite" className="text-sm text-slate-300">
          {loading ? <span className="flex items-center gap-2"><Loader2 aria-hidden="true" className="size-4 animate-spin" /> Buscando hunts...</span>
            : state.error ? "Busca indisponível." : `${hunts.length} hunts nesta busca${hunts.length === 50 ? " · limite atingido, refine a busca" : ""}.`}
        </p>
        {!loading && state.error && <div role="alert" className="rounded-2xl border border-red-400/20 bg-red-400/5 p-5 text-red-200">
          <p>Não foi possível carregar o catálogo. Tente novamente.</p>
          <button type="button" className="hn-secondary-button mt-3" onClick={() => setRetry((value) => value + 1)}>Tentar novamente</button>
        </div>}
        {!loading && !state.error && hunts.length === 0 && <div className="rounded-2xl border border-dashed border-white/15 p-6 text-slate-300">Nenhuma hunt encontrada. Tente outro nome, cidade ou slug.</div>}
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {hunts.map((hunt) => <article key={hunt.hunt_key} className="hn-hunt-card space-y-4 p-5">
            <div>
              <span className="text-xs text-cyan-300">Catálogo factual · fonte B</span>
              <h2 className="mt-2 text-xl font-bold text-white"><Link to="/hunts/$huntKey" params={{ huntKey: hunt.hunt_key }} search={{ vocation: "EK", level: 700, setObjective: "balanced", catalogQuery: query }} className="hover:text-cyan-200 focus-visible:outline-2 focus-visible:outline-cyan-300">{hunt.name}</Link></h2>
              <p className="mt-1 text-sm text-slate-400">{hunt.city || "Cidade não informada"}</p>
            </div>
            <dl className="grid grid-cols-3 gap-2 text-xs text-slate-300">
              {([["EK", hunt.level_knights], ["RP", hunt.level_paladins], ["Mages", hunt.level_mages]] as const).map(([label, value]) => <div key={label}><dt className="text-slate-500">Nível {label}</dt><dd className="mt-1">{value ?? "Não informado"}</dd></div>)}
            </dl>
            <p className="text-xs leading-5 text-slate-400">{hunt.observed_sessions === 0 ? "Sem sessões de desempenho observadas. A hunt continua disponível no catálogo." : typeof hunt.observed_sessions === "number" ? `${hunt.observed_sessions} sessões observadas · Tier C, sem garantia de performance.` : "Sessões observadas: não informado."}</p>
            <Link to="/hunts/$huntKey" params={{ huntKey: hunt.hunt_key }} search={{ vocation: "EK", level: 700, setObjective: "balanced", catalogQuery: query }} className="hn-secondary-button">Ver detalhes de {hunt.name}</Link>
          </article>)}
        </div>
      </section>
    </div>
  );
}
