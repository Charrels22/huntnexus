import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

const Vocation = z.enum(["EK", "RP", "ED", "MS"]);
const Level = z.coerce.number().int().min(1).max(5000);
const CharacterProfile = z.object({
  weapon_family: z.enum(["sword", "axe", "club"]),
  effective_weapon_skill: z.coerce.number().int().min(1).max(1000).optional(),
  effective_magic_level: z.coerce.number().int().min(0).max(1000).optional(),
  effective_shielding: z.coerce.number().int().min(0).max(1000).optional(),
}).strict();

const Body = z.discriminatedUnion("action", [
  z.object({ action: z.literal("health") }),
  z.object({
    action: z.literal("profile_contract"),
    vocation: Vocation,
  }),
  z.object({
    action: z.literal("proficiency_preview"),
    weapon_family: z.enum(["sword", "axe", "club"]),
    one_hand_active_perk_orders: z.array(z.coerce.number().int().min(1).max(100)).max(20).default([]),
    two_hand_active_perk_orders: z.array(z.coerce.number().int().min(1).max(100)).max(20).default([]),
    effective_weapon_skill: z.coerce.number().int().min(1).max(1000).optional(),
    effective_magic_level: z.coerce.number().int().min(0).max(1000).optional(),
  }),
  z.object({
    action: z.literal("hand_context_batch"),
    hunt_keys: z.array(z.string().min(1).max(200)).min(1).max(10),
    level: Level,
    character_profile: CharacterProfile,
    one_hand_active_perk_orders: z.array(z.coerce.number().int().min(1).max(100)).max(20).default([]),
    two_hand_active_perk_orders: z.array(z.coerce.number().int().min(1).max(100)).max(20).default([]),
  }),
  z.object({
    action: z.literal("search_hunts"),
    query: z.string().max(100).default(""),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  }),
  z.object({
    action: z.literal("search_bosses"),
    query: z.string().max(100).default(""),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  }),
  z.object({
    action: z.literal("recommend"),
    vocation: Vocation,
    level: Level,
    objective: z.enum(["xp", "profit", "balanced"]).default("balanced"),
    party_size: z.coerce.number().int().min(1).max(10).default(1),
    limit: z.coerce.number().int().min(1).max(10).default(5),
    defensive_items_per_slot: z.coerce.number().int().min(1).max(5).default(3),
    character_profile: CharacterProfile.optional(),
    one_hand_active_perk_orders: z.array(z.coerce.number().int().min(1).max(100)).max(20).default([]),
    two_hand_active_perk_orders: z.array(z.coerce.number().int().min(1).max(100)).max(20).default([]),
  }),
  z.object({
    action: z.literal("boss_build"),
    boss_key: z.string().min(1).max(200),
    vocation: Vocation,
    level: Level,
  }),
]);

const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: { "cache-control": "no-store" } });

const notAllowed = () =>
  new Response(JSON.stringify({ error: "method_not_allowed" }), {
    status: 405,
    headers: { "content-type": "application/json", allow: "POST" },
  });

export const Route = createFileRoute("/api/huntnexus")({
  server: {
    handlers: {
      GET: notAllowed,
      PUT: notAllowed,
      PATCH: notAllowed,
      DELETE: notAllowed,
      POST: async ({ request }) => {
        let raw: unknown;
        try {
          raw = await request.json();
        } catch {
          return json({ error: "invalid_json" }, 400);
        }
        const parsed = Body.safeParse(raw);
        if (!parsed.success) {
          return json({ error: "invalid_input", detail: parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ") }, 400);
        }
        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
        // eslint-disable-next-line @typescript-eslint/no-explicit-any -- RPCs return untyped jsonb
        const rpc = async (fn: string, params?: Record<string, unknown>): Promise<any> => {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const { data, error } = await (supabaseAdmin.rpc as any)(fn, params ?? {});
          if (error) {
            console.error(`[huntnexus-api] ${fn} failed:`, error.message);
            throw new Error("rpc_failed");
          }
          return data;
        };
        const b = parsed.data;
        try {
          switch (b.action) {
            case "health":
              return json({ data: await rpc("huntnexus_api_health") });
            case "profile_contract":
              return json({
                data: await rpc("huntnexus_character_combat_profile_contract", {
                  p_vocation: b.vocation,
                }),
              });
            case "proficiency_preview": {
              const [reference, impact] = await Promise.all([
                rpc("huntnexus_ek_proficiency_comparison", {
                  p_weapon_family: b.weapon_family,
                  p_one_hand_active_perk_orders: b.one_hand_active_perk_orders,
                  p_two_hand_active_perk_orders: b.two_hand_active_perk_orders,
                }),
                rpc("huntnexus_ek_proficiency_impact_comparison", {
                  p_weapon_family: b.weapon_family,
                  p_one_hand_active_perk_orders: b.one_hand_active_perk_orders,
                  p_two_hand_active_perk_orders: b.two_hand_active_perk_orders,
                  p_effective_weapon_skill: b.effective_weapon_skill,
                  p_effective_magic_level: b.effective_magic_level,
                }),
              ]);
              return json({ data: { ...reference, impact } });
            }
            case "hand_context_batch":
              return json({
                data: await rpc("huntnexus_ek_hand_context_batch", {
                  p_hunt_keys: b.hunt_keys,
                  p_level: b.level,
                  p_character_profile: b.character_profile,
                  p_one_hand_active_perk_orders: b.one_hand_active_perk_orders,
                  p_two_hand_active_perk_orders: b.two_hand_active_perk_orders,
                  p_effective_magic_level: b.character_profile.effective_magic_level,
                }),
              });
            case "search_hunts":
              return json({ data: await rpc("huntnexus_search_hunts", { p_query: b.query, p_limit: b.limit }) });
            case "search_bosses":
              return json({ data: await rpc("huntnexus_search_bosses", { p_query: b.query, p_limit: b.limit }) });
            case "recommend": {
              const recommendationFn = b.character_profile
                ? "huntnexus_recommendation_preview_contextual"
                : "huntnexus_recommendation_preview";
              const recommendationParams: Record<string, unknown> = {
                p_vocation: b.vocation,
                p_level: b.level,
                p_objective: b.objective,
                p_party_size: b.party_size,
                p_limit: b.limit,
                p_defensive_items_per_slot: b.defensive_items_per_slot,
              };
              if (b.character_profile) {
                recommendationParams.p_character_profile = b.character_profile;
                recommendationParams.p_one_hand_active_perk_orders = b.one_hand_active_perk_orders;
                recommendationParams.p_two_hand_active_perk_orders = b.two_hand_active_perk_orders;
              }
              const [data, warnings] = await Promise.all([
                rpc(recommendationFn, recommendationParams),
                rpc("huntnexus_rubinot_spell_warnings", { p_vocation: b.vocation, p_level: b.level }),
              ]);
              return json({ data, warnings: Array.isArray(warnings) ? warnings : [] });
            }
            case "boss_build": {
              const [data, warnings] = await Promise.all([
                rpc("huntnexus_boss_build_preview", { p_boss_key: b.boss_key, p_vocation: b.vocation, p_level: b.level }),
                rpc("huntnexus_global_boss_warnings"),
              ]);
              return json({ data, warnings: Array.isArray(warnings) ? warnings : [] });
            }
          }
        } catch {
          return json({ error: "upstream_error", detail: "A consulta ao banco falhou." }, 502);
        }
      },
    },
  },
});