import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

const Vocation = z.enum(["EK", "RP", "ED", "MS", "EM"]);
const Level = z.coerce.number().int().min(1).max(5000);
const PerkOrders = z.array(z.coerce.number().int().min(1).max(100)).max(20);
const ProficiencySelections = z.record(
  z.string().regex(/^[a-z0-9-]+$/).max(200),
  PerkOrders,
).refine((x) => Object.keys(x).length <= 30, "Máximo de 30 armas por requisição.");
const CharacterProfile = z.object({
  weapon_family: z.enum(["sword", "axe", "club"]),
  effective_weapon_skill: z.coerce.number().int().min(1).max(1000).optional(),
  effective_magic_level: z.coerce.number().int().min(0).max(1000).optional(),
  effective_shielding: z.coerce.number().int().min(0).max(1000).optional(),
}).strict();

const UniversalCharacterProfile = z.object({
  weapon_family: z.string().max(40).optional(),
  effective_weapon_skill: z.coerce.number().int().min(1).max(1000).optional(),
  effective_magic_level: z.coerce.number().int().min(0).max(1000).optional(),
  effective_shielding: z.coerce.number().int().min(0).max(1000).optional(),
  effective_distance_skill: z.coerce.number().int().min(0).max(1000).optional(),
  effective_fist_skill: z.coerce.number().int().min(0).max(1000).optional(),
}).passthrough();

const Body = z.discriminatedUnion("action", [
  z.object({ action: z.literal("health") }),
  z.object({
    action: z.literal("player_profile_get"),
    client_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_profile_proficiency_catalog"),
    vocation: z.string().max(20),
    level: z.coerce.number().int().min(1).max(5000),
    weapon_family: z.string().max(40).nullable().optional(),
  }),
  z.object({
    action: z.literal("player_profile_delete"),
    client_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_inventory_get"),
    client_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_inventory_search"),
    vocation: z.string().max(20),
    level: z.coerce.number().int().min(1).max(5000),
    query: z.string().trim().min(2).max(120),
    selection_key: z.string().max(40).nullable().optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  }),
  z.object({
    action: z.literal("player_inventory_put"),
    client_id: z.string().uuid(),
    storage_kind: z.enum(["main","backpack"]),
    item_key: z.string().max(200),
    quantity: z.coerce.number().int().min(1).max(9999).default(1),
  }),
  z.object({
    action: z.literal("player_inventory_remove"),
    client_id: z.string().uuid(),
    inventory_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_inventory_hunt_review"),
    client_id: z.string().uuid(),
    hunt_key: z.string().min(1).max(200),
    vocation: z.string().max(20),
    level: z.coerce.number().int().min(1).max(5000),
    proficiency_selections: z.record(z.string(), z.array(z.number().int().min(1).max(100))).default({}),
    frontier_limit: z.coerce.number().int().min(1).max(30).default(12),
  }),
  z.object({
    action: z.literal("player_hunt_build_choice_get"),
    client_id: z.string().uuid(),
    hunt_key: z.string().min(1).max(200),
    vocation: z.string().max(20),
  }),
  z.object({
    action: z.literal("player_hunt_build_choice_save"),
    client_id: z.string().uuid(),
    hunt_key: z.string().min(1).max(200),
    vocation: z.string().max(20),
    level: z.coerce.number().int().min(1).max(5000),
    selection: z.record(z.string(), z.string()).default({}),
    option_type: z.enum(["main","owned_variant"]),
    replacements: z.array(z.record(z.string(), z.unknown())).default([]),
  }),
  z.object({
    action: z.literal("player_hunt_build_choice_delete"),
    client_id: z.string().uuid(),
    hunt_key: z.string().min(1).max(200),
    vocation: z.string().max(20),
  }),
  z.object({
    action: z.literal("player_owned_build_options"),
    client_id: z.string().uuid(),
    hunt_key: z.string().min(1).max(200),
    vocation: z.string().max(20),
    level: z.coerce.number().int().min(1).max(5000),
    proficiency_selections: z.record(z.string(), z.array(z.number().int().min(1).max(100))).default({}),
    character_profile: z.record(z.string(), z.unknown()).default({}),
    option_limit: z.coerce.number().int().min(1).max(3).default(3),
  }),
  z.object({
    action: z.literal("player_profile_save"),
    client_id: z.string().uuid(),
    profile: z.object({
      character_name: z.string().max(120).default(""),
      world_name: z.string().max(120).default(""),
      vocation: z.string().max(20).default(""),
      level: z.union([z.string(), z.number()]).optional(),
      online: z.boolean().nullable().optional(),
      former_names: z.array(z.string().max(120)).max(20).default([]),
      official_lookup_at: z.string().max(80).nullable().optional(),
      official_lookup_status: z.string().max(40).nullable().optional(),
      manual_stats: z.record(z.string(), z.union([z.string(), z.number(), z.null()])).default({}),
      proficiency_selections: z.record(z.string(), z.array(z.number().int().min(1).max(100))).default({}),
      defaults: z.object({
        hunt_objective: z.enum(["xp","profit","balanced"]).default("balanced"),
        set_objective: z.enum(["offense","defense","sustain","utility","balanced"]).default("balanced"),
        party_size: z.coerce.number().int().min(1).max(10).default(1),
      }).default({ hunt_objective:"balanced", set_objective:"balanced", party_size:1 }),
    }),
  }),
  z.object({
    action: z.literal("profile_contract"),
    vocation: Vocation,
  }),
  z.object({
    action: z.literal("proficiency_preview"),
    weapon_family: z.enum(["sword", "axe", "club"]),
    one_hand_active_perk_orders: PerkOrders.default([]),
    two_hand_active_perk_orders: PerkOrders.default([]),
    effective_weapon_skill: z.coerce.number().int().min(1).max(1000).optional(),
    effective_magic_level: z.coerce.number().int().min(0).max(1000).optional(),
  }),
  z.object({
    action: z.literal("hand_context_batch"),
    hunt_keys: z.array(z.string().min(1).max(200)).min(1).max(10),
    level: Level,
    character_profile: CharacterProfile,
    one_hand_active_perk_orders: PerkOrders.default([]),
    two_hand_active_perk_orders: PerkOrders.default([]),
  }),
  z.object({
    action: z.literal("featured_hunts"),
    limit: z.coerce.number().int().min(1).max(20).default(8),
  }),
  z.object({
    action: z.literal("hunt_detail"),
    hunt_key: z.string().min(1).max(200),
    vocation: Vocation,
    level: Level,
    set_objective: z.enum(["offense", "defense", "sustain", "utility", "balanced"]).default("balanced"),
    proficiency_selections: ProficiencySelections.default({}),
    character_profile: UniversalCharacterProfile.default({}),
  }),
  z.object({
    action: z.literal("session_import_save"),
    client_id: z.string().uuid(),
    blocks: z.object({
      hunt: z.string().max(120000).default(""),
      party: z.string().max(120000).default(""),
      input: z.string().max(120000).default(""),
      misc: z.string().max(120000).default(""),
    }),
    metadata: z.object({
      character: z.string().max(120).default(""),
      server: z.string().max(120).default(""),
      vocation: z.string().max(20).default(""),
      level: z.string().max(10).default(""),
      location: z.string().max(200).default(""),
      hunt_key: z.string().max(200).default(""),
      observation: z.string().max(1000).default(""),
      tags: z.array(z.string().max(60)).max(20).default([]),
      type: z.enum(["normal", "bounty"]).default("normal"),
      favorite: z.boolean().default(false),
      publishHighscores: z.boolean().default(false),
      rareDrops: z.string().max(5000).default(""),
    }),
  }),
  z.object({
    action: z.literal("player_session_list"),
    client_id: z.string().uuid(),
    limit: z.coerce.number().int().min(1).max(100).default(30),
  }),
  z.object({
    action: z.literal("player_session_detail"),
    client_id: z.string().uuid(),
    session_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_session_delete"),
    client_id: z.string().uuid(),
    session_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("session_list"),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    hunt_key: z.string().min(1).max(200).nullable().optional(),
  }),
  z.object({
    action: z.literal("session_detail"),
    session_id: z.string().uuid(),
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
    one_hand_active_perk_orders: PerkOrders.default([]),
    two_hand_active_perk_orders: PerkOrders.default([]),
    proficiency_selections: ProficiencySelections.default({}),
  }),
  z.object({
    action: z.literal("final_optimizer"),
    vocation: Vocation,
    level: Level,
    hunt_objective: z.enum(["xp", "profit", "balanced"]).default("balanced"),
    set_objective: z.enum(["offense", "defense", "sustain", "utility", "balanced"]).default("balanced"),
    party_size: z.coerce.number().int().min(1).max(10).default(1),
    hunt_limit: z.coerce.number().int().min(1).max(5).default(3),
    hand_per_source: z.coerce.number().int().min(1).max(10).default(3),
    per_body_slot: z.coerce.number().int().min(1).max(5).default(2),
    set_limit: z.coerce.number().int().min(1).max(200).default(100),
    frontier_limit: z.coerce.number().int().min(1).max(200).default(100),
    selection_limit: z.coerce.number().int().min(1).max(50).default(20),
    unlocked_requirement_keys: z.array(z.string().min(1).max(200)).max(100).default([]),
    proficiency_selections: ProficiencySelections.default({}),
    character_profile: UniversalCharacterProfile.default({}),
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
            case "player_profile_get":
              return json({
                data: await rpc("huntnexus_player_profile_get", {
                  p_client_id: b.client_id,
                }),
              });
            case "player_profile_proficiency_catalog":
              return json({
                data: await rpc("huntnexus_player_profile_proficiency_catalog", {
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_weapon_family: b.weapon_family ?? null,
                }),
              });
            case "player_profile_delete":
              return json({
                data: await rpc("huntnexus_player_profile_delete", {
                  p_client_id: b.client_id,
                }),
              });
            case "player_inventory_get":
              return json({
                data: await rpc("huntnexus_player_inventory_get", {
                  p_client_id: b.client_id,
                }),
              });
            case "player_inventory_search":
              return json({
                data: await rpc("huntnexus_player_inventory_search", {
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_query: b.query,
                  p_selection_key: b.selection_key ?? null,
                  p_limit: b.limit,
                }),
              });
            case "player_inventory_put":
              return json({
                data: await rpc("huntnexus_player_inventory_put", {
                  p_client_id: b.client_id,
                  p_storage_kind: b.storage_kind,
                  p_item_key: b.item_key,
                  p_quantity: b.quantity,
                }),
              });
            case "player_inventory_remove":
              return json({
                data: await rpc("huntnexus_player_inventory_remove", {
                  p_client_id: b.client_id,
                  p_inventory_id: b.inventory_id,
                }),
              });
            case "player_inventory_hunt_review":
              return json({
                data: await rpc("huntnexus_player_inventory_hunt_review", {
                  p_client_id: b.client_id,
                  p_hunt_key: b.hunt_key,
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_proficiency_selections: b.proficiency_selections,
                  p_frontier_limit: b.frontier_limit,
                }),
              });
            case "player_hunt_build_choice_get":
              return json({
                data: await rpc("huntnexus_player_hunt_build_choice_get", {
                  p_client_id: b.client_id,
                  p_hunt_key: b.hunt_key,
                  p_vocation: b.vocation,
                }),
              });
            case "player_hunt_build_choice_save":
              return json({
                data: await rpc("huntnexus_player_hunt_build_choice_save", {
                  p_client_id: b.client_id,
                  p_hunt_key: b.hunt_key,
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_selection: b.selection,
                  p_option_type: b.option_type,
                  p_replacements: b.replacements,
                }),
              });
            case "player_hunt_build_choice_delete":
              return json({
                data: await rpc("huntnexus_player_hunt_build_choice_delete", {
                  p_client_id: b.client_id,
                  p_hunt_key: b.hunt_key,
                  p_vocation: b.vocation,
                }),
              });
            case "player_owned_build_options":
              return json({
                data: await rpc("huntnexus_player_owned_build_options_v2", {
                  p_client_id: b.client_id,
                  p_hunt_key: b.hunt_key,
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_proficiency_selections: b.proficiency_selections,
                  p_character_profile: b.character_profile,
                  p_option_limit: b.option_limit,
                }),
              });
            case "player_profile_save":
              return json({
                data: await rpc("huntnexus_player_profile_save", {
                  p_client_id: b.client_id,
                  p_profile: b.profile,
                }),
              });
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
            case "featured_hunts":
              return json({
                data: await rpc("huntnexus_frontend_featured_hunts", {
                  p_limit: b.limit,
                }),
              });
            case "hunt_detail": {
              const [factual, observed, defensive, imbuements, setSelection, composition, spells, media] = await Promise.all([
                rpc("huntnexus_hunt_factual_profile", { p_hunt_key: b.hunt_key }),
                rpc("huntnexus_hunt_observed_profile", { p_hunt_key: b.hunt_key }),
                rpc("huntnexus_hunt_defensive_profile", { p_hunt_key: b.hunt_key, p_vocation: b.vocation }),
                rpc("huntnexus_imbuement_hunt_context_universal", { p_hunt_key: b.hunt_key, p_vocation: b.vocation }),
                rpc("huntnexus_optimizer_set_selection_universal", {
                  p_hunt_key: b.hunt_key,
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_set_objective: b.set_objective,
                  p_hand_per_source: 3,
                  p_per_body_slot: 2,
                  p_set_limit: 100,
                  p_frontier_limit: 100,
                  p_selection_limit: 20,
                  p_proficiency_selections: b.proficiency_selections,
                  p_character_profile: b.character_profile,
                }),
                rpc("huntnexus_vocation_composition_universal", {
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_unlocked_requirement_keys: [],
                  p_hunt_key: b.hunt_key,
                }),
                rpc("huntnexus_spell_candidates_with_unlocks_universal", {
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_unlocked_requirement_keys: [],
                  p_attack_type: null,
                  p_element: null,
                  p_limit: 250,
                }),
                rpc("huntnexus_hunt_media_context", { p_hunt_key: b.hunt_key }),
              ]);
              return json({
                data: {
                  factual,
                  observed,
                  defensive,
                  imbuements,
                  set_selection: setSelection,
                  vocation_composition: composition,
                  spells,
                  media,
                },
              });
            }
            case "session_import_save": {
              const { parseSessionImport } = await import("@/lib/session-parser");
              const parsedImport = parseSessionImport(b.blocks);
              const data = await rpc("huntnexus_player_session_save", {
                p_client_id: b.client_id,
                p_raw_blocks: b.blocks,
                p_parsed_data: {
                  ...parsedImport,
                  metadata: {
                    rare_drops_raw: b.metadata.rareDrops || null,
                  },
                },
                p_metadata: b.metadata,
              });
              return json({ data, parsed: parsedImport });
            }
            case "player_session_list":
              return json({
                data: await rpc("huntnexus_player_session_list", {
                  p_client_id: b.client_id,
                  p_limit: b.limit,
                }),
              });
            case "player_session_detail":
              return json({
                data: await rpc("huntnexus_player_session_detail", {
                  p_client_id: b.client_id,
                  p_session_id: b.session_id,
                }),
              });
            case "player_session_delete":
              return json({
                data: await rpc("huntnexus_player_session_delete", {
                  p_client_id: b.client_id,
                  p_session_id: b.session_id,
                }),
              });
            case "session_list":
              return json({
                data: await rpc("huntnexus_session_analyzer_list", {
                  p_limit: b.limit,
                  p_hunt_key: b.hunt_key ?? null,
                }),
              });
            case "session_detail":
              return json({
                data: await rpc("huntnexus_session_analyzer_detail", {
                  p_session_id: b.session_id,
                }),
              });
            case "search_hunts":
              return json({ data: await rpc("huntnexus_search_hunts", { p_query: b.query, p_limit: b.limit }) });
            case "search_bosses":
              return json({ data: await rpc("huntnexus_search_bosses", { p_query: b.query, p_limit: b.limit }) });
            case "recommend": {
              const recommendationFn = b.character_profile
                ? "huntnexus_recommendation_preview_contextual_items"
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
                recommendationParams.p_proficiency_selections = b.proficiency_selections;
              }
              const [data, warnings] = await Promise.all([
                rpc(recommendationFn, recommendationParams),
                rpc("huntnexus_rubinot_spell_warnings", { p_vocation: b.vocation, p_level: b.level }),
              ]);
              return json({ data, warnings: Array.isArray(warnings) ? warnings : [] });
            }
            case "final_optimizer":
              return json({
                data: await rpc("huntnexus_optimizer_final_universal", {
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_hunt_objective: b.hunt_objective,
                  p_set_objective: b.set_objective,
                  p_party_size: b.party_size,
                  p_hunt_limit: b.hunt_limit,
                  p_hand_per_source: b.hand_per_source,
                  p_per_body_slot: b.per_body_slot,
                  p_set_limit: b.set_limit,
                  p_frontier_limit: b.frontier_limit,
                  p_selection_limit: b.selection_limit,
                  p_unlocked_requirement_keys: b.unlocked_requirement_keys,
                  p_proficiency_selections: b.proficiency_selections,
                  p_character_profile: b.character_profile,
                }),
              });
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