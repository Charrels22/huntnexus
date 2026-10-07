import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type RecommendBody = {
  action: "recommend";
  vocation: string;
  level: number;
  objective?: "xp" | "profit" | "balanced";
  party_size?: number;
  limit?: number;
  defensive_items_per_slot?: number;
};

type BossBody = {
  action: "boss_build";
  boss_key: string;
  vocation: string;
  level: number;
};

type SearchHuntsBody = {
  action: "search_hunts";
  query?: string;
  limit?: number;
};

type SearchBossesBody = {
  action: "search_bosses";
  query?: string;
  limit?: number;
};

type HealthBody = { action: "health" };

type RequestBody =
  | RecommendBody
  | BossBody
  | SearchHuntsBody
  | SearchBossesBody
  | HealthBody;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json({ error: "server_not_configured" }, 500);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const db = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (body.action === "health") {
    const { data, error } = await db.rpc("huntnexus_api_health");
    if (error) return json({ error: "health_failed", detail: error.message }, 500);
    return json({ data });
  }

  if (body.action === "search_hunts") {
    const { data, error } = await db.rpc("huntnexus_search_hunts", {
      p_query: body.query ?? "",
      p_limit: Math.min(50, Math.max(1, Math.trunc(body.limit ?? 20))),
    });
    if (error) return json({ error: "hunt_search_failed", detail: error.message }, 500);
    return json({ data });
  }

  if (body.action === "search_bosses") {
    const { data, error } = await db.rpc("huntnexus_search_bosses", {
      p_query: body.query ?? "",
      p_limit: Math.min(50, Math.max(1, Math.trunc(body.limit ?? 20))),
    });
    if (error) return json({ error: "boss_search_failed", detail: error.message }, 500);
    return json({ data });
  }

  if (body.action === "recommend") {
    if (!body.vocation || !Number.isFinite(body.level) || body.level < 1) {
      return json({ error: "invalid_recommendation_input" }, 400);
    }

    const [recommendation, warnings] = await Promise.all([
      db.rpc("huntnexus_recommendation_preview", {
        p_vocation: body.vocation,
        p_level: Math.trunc(body.level),
        p_objective: body.objective ?? "balanced",
        p_party_size: Math.max(1, Math.trunc(body.party_size ?? 1)),
        p_limit: Math.min(10, Math.max(1, Math.trunc(body.limit ?? 5))),
        p_defensive_items_per_slot: Math.min(
          5,
          Math.max(1, Math.trunc(body.defensive_items_per_slot ?? 3)),
        ),
      }),
      db.rpc("huntnexus_rubinot_spell_warnings", {
        p_vocation: body.vocation,
        p_level: Math.trunc(body.level),
      }),
    ]);

    if (recommendation.error) {
      return json({ error: "recommendation_failed", detail: recommendation.error.message }, 500);
    }

    return json({
      data: recommendation.data,
      warnings: warnings.error ? [] : warnings.data,
    });
  }

  if (body.action === "boss_build") {
    if (!body.boss_key || !body.vocation || !Number.isFinite(body.level) || body.level < 1) {
      return json({ error: "invalid_boss_input" }, 400);
    }

    const [build, warnings] = await Promise.all([
      db.rpc("huntnexus_boss_build_preview", {
        p_boss_key: body.boss_key,
        p_vocation: body.vocation,
        p_level: Math.trunc(body.level),
      }),
      db.rpc("huntnexus_global_boss_warnings"),
    ]);

    if (build.error) {
      return json({ error: "boss_build_failed", detail: build.error.message }, 500);
    }

    return json({
      data: build.data,
      warnings: warnings.error ? [] : warnings.data,
    });
  }

  return json({ error: "unknown_action" }, 400);
});
