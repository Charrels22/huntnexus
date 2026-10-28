import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import { evaluateAuthGate, extractRequestAccessToken, jwtSessionId, type AuthGateState } from "@/lib/auth-security";

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
    action: z.literal("account_resolve"),
    access_token: z.string().min(20).max(8192).optional(),
    local_client_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("account_status"),
    access_token: z.string().min(20).max(8192).optional(),
  }),
  z.object({
    action: z.literal("account_unbind"),
    access_token: z.string().min(20).max(8192).optional(),
  }),
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
    action: z.literal("hunt_detail_setup"),
    hunt_key: z.string().min(1).max(200),
    vocation: Vocation,
    level: Level,
    set_objective: z.enum(["offense", "defense", "sustain", "utility", "balanced"]).default("balanced"),
    proficiency_selections: ProficiencySelections.default({}),
    character_profile: UniversalCharacterProfile.default({}),
  }),
  z.object({
    action: z.literal("hunt_detail_spells"),
    hunt_key: z.string().min(1).max(200),
    vocation: Vocation,
    level: Level,
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
      setupMode: z.enum(["auto", "main", "hunt", "none"]).default("auto"),
      observation: z.string().max(1000).default(""),
      tags: z.array(z.string().max(60)).max(20).default([]),
      type: z.enum(["normal", "bounty"]).default("normal"),
      favorite: z.boolean().default(false),
      publishHighscores: z.boolean().default(false),
      rareDrops: z.string().max(5000).default(""),
    }),
  }),
  z.object({
    action: z.literal("player_session_build_performance"),
    client_id: z.string().uuid(),
    hunt_key: z.string().min(1).max(200),
    vocation: z.string().max(20).nullable().optional(),
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
    action: z.literal("player_session_integrity_review"),
    client_id: z.string().uuid(),
    session_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_session_delete"),
    client_id: z.string().uuid(),
    session_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_session_reparse_preview"),
    client_id: z.string().uuid(),
    session_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_session_reparse_apply"),
    client_id: z.string().uuid(),
    session_id: z.string().uuid(),
    expected_fingerprint: z.string().regex(/^[a-f0-9]{32}$/),
    confirm: z.literal(true),
  }),
  z.object({
    action: z.literal("player_session_revision_list"),
    client_id: z.string().uuid(),
    session_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_session_restore_preview"),
    client_id: z.string().uuid(),
    session_id: z.string().uuid(),
    revision_id: z.string().uuid(),
  }),
  z.object({
    action: z.literal("player_session_restore_apply"),
    client_id: z.string().uuid(),
    session_id: z.string().uuid(),
    revision_id: z.string().uuid(),
    expected_fingerprint: z.string().regex(/^[a-f0-9]{32}$/),
    confirm: z.literal(true),
    accept_regressions: z.boolean().default(false),
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
    action: z.literal("search_creatures"),
    query: z.string().max(100).default(""),
    limit: z.coerce.number().int().min(1).max(50).default(30),
  }),
  z.object({
    action: z.literal("creature_detail"),
    creature_key: z.string().trim().min(1).max(160),
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
    action: z.literal("planner_personalized"),
    client_id: z.string().uuid().nullable().optional(),
    vocation: Vocation,
    level: Level,
    objective: z.enum(["xp", "profit", "balanced"]).default("balanced"),
    party_size: z.coerce.number().int().min(1).max(10).default(1),
    limit: z.coerce.number().int().min(1).max(5).default(3),
    proficiency_selections: ProficiencySelections.default({}),
    character_profile: UniversalCharacterProfile.default({}),
  }),
  z.object({
    action: z.literal("final_optimizer"),
    client_id: z.string().uuid().nullable().optional(),
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
  z.object({
    action: z.literal("loadout_preview"),
    hunt_key: z.string().min(1).max(200),
    vocation: Vocation,
    level: Level,
    objective: z.enum(["offense","defense","sustain","utility","balanced"]).default("balanced"),
    per_dimension: z.coerce.number().int().min(1).max(5).default(2),
    character_profile: UniversalCharacterProfile.default({}),
  }),
]);

// Cloudflare overwrites cf-connecting-ip at the edge; never trust an arbitrary
// caller-supplied client_id or x-forwarded-for for expensive admission.
async function optimizerCallerHash(request: Request): Promise<string> {
  const secret = process.env["SUPABASE_SERVICE_ROLE_KEY"];
  if (!secret) throw new Error("optimizer_identity_secret_missing");
  const remoteIp = request.headers.get("cf-connecting-ip")?.trim();
  const subject = remoteIp && remoteIp.length <= 64 ? remoteIp : "unattributed";
  const bytes = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", bytes.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, bytes.encode(`huntnexus-optimizer-v1:${subject}`));
  return Array.from(new Uint8Array(signature), (value) => value.toString(16).padStart(2, "0")).join("");
}

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
        const rawRecord = raw && typeof raw === "object" ? raw as Record<string, unknown> : {};
        const requestAuth = extractRequestAccessToken(
          request.headers.get("authorization"),
          rawRecord["access_token"],
        );
        if (requestAuth.error) {
          return json(
            { error: requestAuth.error },
            requestAuth.error === "conflicting_auth_tokens" ? 400 : 401,
          );
        }
        const requestAccessToken = requestAuth.token;

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
        const strongAuthContext = async (accessToken: string) => {
          const { data, error } = await supabaseAdmin.auth.getUser(accessToken);
          if (error || !data?.user?.id) return null;
          const sessionId = jwtSessionId(accessToken);
          if (!sessionId) return null;

          const [{ data: assurance, error: assuranceError }, sessionGate] = await Promise.all([
            supabaseAdmin.auth.mfa.getAuthenticatorAssuranceLevel(accessToken),
            rpc("huntnexus_auth_session_gate", {
              p_auth_user_id: data.user.id,
              p_session_id: sessionId,
            }),
          ]);
          if (assuranceError || !assurance) return null;

          const state = evaluateAuthGate({
            currentLevel: assurance.currentLevel,
            nextLevel: assurance.nextLevel,
            verifiedFactorCount: Number(sessionGate?.verified_factor_count ?? 0),
            activeSession: sessionGate?.active_session === true,
          });
          return {
            userId: data.user.id,
            sessionId,
            state,
          };
        };
        const authGateError = (state: AuthGateState) => {
          if (state === "invalid_session") {
            return json({ error: "auth_session_inactive" }, 401);
          }
          if (state === "mfa_enrollment_required") {
            return json({ error: "mfa_enrollment_required" }, 403);
          }
          return json({ error: "mfa_challenge_required" }, 403);
        };

        const withAdvancedOptimizerSlot = async (perform: () => Promise<Response>): Promise<Response> => {
          const subjectHash = await optimizerCallerHash(request);
          const admission = await rpc("huntnexus_optimizer_admit", {
            p_subject_hash: subjectHash,
          });
          if (admission?.allowed !== true) {
            const retryAfter = Math.max(1, Math.min(600, Number(admission?.retry_after) || 10));
            const detail = admission?.reason === "rate_limit"
              ? "Limite temporário de cálculos avançados atingido. Tente novamente mais tarde."
              : "Outro cálculo avançado está em execução. Aguarde alguns segundos e tente novamente.";
            return Response.json({
              error: "optimizer_admission_denied",
              reason: admission?.reason || "unavailable",
              detail,
              retry_after_seconds: retryAfter,
            }, {
              status: 429,
              headers: { "cache-control": "no-store", "retry-after": String(retryAfter) },
            });
          }
          if (typeof admission.lease_id !== "string") {
            throw new Error("optimizer_lease_missing");
          }
          try {
            return await perform();
          } finally {
            try {
              await rpc("huntnexus_optimizer_release", {
                p_lease_id: admission.lease_id,
                p_subject_hash: subjectHash,
              });
            } catch {
              console.error("[huntnexus-api] optimizer lease release failed");
            }
          }
        };

        const b = parsed.data;

        const scopedClientId =
          "client_id" in b && typeof b.client_id === "string"
            ? b.client_id
            : null;

        if (scopedClientId) {
          const { data: binding, error: bindingError } = await supabaseAdmin
            .from("player_account_bindings")
            .select("auth_user_id")
            .eq("client_id", scopedClientId)
            .maybeSingle();

          if (bindingError) {
            console.error("[huntnexus-api] account scope lookup failed:", bindingError.message);
            return json({ error: "account_scope_lookup_failed" }, 500);
          }

          if (binding?.auth_user_id) {
            if (!requestAccessToken) {
              return json({ error: "authentication_required_for_bound_client" }, 401);
            }

            const auth = await strongAuthContext(requestAccessToken);
            if (!auth) {
              return json({ error: "invalid_auth_token" }, 401);
            }

            if (auth.userId !== binding.auth_user_id) {
              return json({ error: "forbidden_client_scope" }, 403);
            }
            if (auth.state !== "ready") return authGateError(auth.state);
          }
        }

        try {
          switch (b.action) {
            case "health":
              return json({ data: await rpc("huntnexus_api_health") });
            case "account_resolve": {
              if (!requestAccessToken) return json({ error: "authentication_required" }, 401);
              const auth = await strongAuthContext(requestAccessToken);
              if (!auth) return json({ error: "invalid_auth_token" }, 401);
              if (auth.state !== "ready") return authGateError(auth.state);
              return json({
                data: await rpc("huntnexus_account_resolve", {
                  p_auth_user_id: auth.userId,
                  p_local_client_id: b.local_client_id,
                }),
              });
            }
            case "account_status": {
              if (!requestAccessToken) return json({ error: "authentication_required" }, 401);
              const auth = await strongAuthContext(requestAccessToken);
              if (!auth) return json({ error: "invalid_auth_token" }, 401);
              if (auth.state !== "ready") return authGateError(auth.state);
              return json({
                data: await rpc("huntnexus_account_binding_status", {
                  p_auth_user_id: auth.userId,
                }),
              });
            }
            case "account_unbind": {
              if (!requestAccessToken) return json({ error: "authentication_required" }, 401);
              const auth = await strongAuthContext(requestAccessToken);
              if (!auth) return json({ error: "invalid_auth_token" }, 401);
              if (auth.state !== "ready") return authGateError(auth.state);
              const result = await rpc("huntnexus_account_unbind", {
                p_auth_user_id: auth.userId,
              });
              // An account containing Profile, Main/BP, builds or sessions must
              // not turn into an unprotected guest UUID after unlinking.
              if (result?.error === "private_data_present_unbind_blocked") {
                return json({
                  error: "private_data_present_unbind_blocked",
                  private_data_deleted: false,
                }, 409);
              }
              return json({ data: result });
            }
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
              const [factual, observed, vocationObserved, defensive, imbuements, media, evidence] = await Promise.all([
                rpc("huntnexus_hunt_factual_profile", { p_hunt_key: b.hunt_key }),
                rpc("huntnexus_hunt_observed_profile", { p_hunt_key: b.hunt_key }),
                rpc("huntnexus_hunt_vocation_observation_sample", { p_hunt_key: b.hunt_key, p_vocation: b.vocation }),
                rpc("huntnexus_hunt_defensive_profile", { p_hunt_key: b.hunt_key, p_vocation: b.vocation }),
                rpc("huntnexus_imbuement_hunt_context_universal", { p_hunt_key: b.hunt_key, p_vocation: b.vocation }),
                rpc("huntnexus_hunt_media_context", { p_hunt_key: b.hunt_key }),
                // Scoped to a single hunt; optional if the provenance RPC is
                // temporarily unavailable during deployment. Never infer it.
                rpc("huntnexus_hunt_evidence_context", { p_hunt_key: b.hunt_key })
                  .catch(() => null),
              ]);
              return json({
                data: {
                  factual,
                  observed,
                  vocation_observed: vocationObserved,
                  defensive,
                  imbuements,
                  media,
                  evidence: evidence && typeof evidence === "object" && !evidence.error ? evidence : null,
                  methodology: {
                    stage: "hunt_detail_lazy_heavy_v1",
                    setup_loaded_on_demand: true,
                    spells_loaded_on_demand: true,
                    factual_separate_from_observed: true,
                    factual_source_provenance_explicit: true,
                    source_timestamp_is_not_live_verification: true,
                    optional_coverage_not_equivalent_to_observed_performance: true,
                  },
                },
              });
            }
            case "hunt_detail_setup": {
              return withAdvancedOptimizerSlot(async () => {
                const setSelection = await rpc("huntnexus_optimizer_set_selection_universal", {
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
                });
                return json({
                  data: {
                    ...setSelection,
                    execution: {
                      enumeration_set_limit: 100,
                      frontier_limit: 100,
                      returned_set_limit: 20,
                      exhaustive_all_possible_combinations: false,
                      candidate_scope: "bounded_concrete_enumeration",
                      admission_stage: "distributed_optimizer_admission_v1",
                    },
                  },
                });
              });
            }
            case "hunt_detail_spells": {
              const spells = await rpc("huntnexus_spell_candidates_with_unlocks_universal", {
                p_vocation: b.vocation,
                p_level: b.level,
                p_unlocked_requirement_keys: [],
                p_spell_group: null,
                p_element: null,
                p_limit: 250,
              });
              let composition: unknown = null;
              let compositionStatus = "available";
              try {
                composition = await rpc("huntnexus_vocation_composition_universal", {
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_unlocked_requirement_keys: [],
                  p_hunt_key: b.hunt_key,
                });
              } catch {
                compositionStatus = "unavailable";
              }
              return json({
                data: {
                  vocation_composition: composition,
                  spells,
                  availability: { spells: true, vocation_composition: compositionStatus },
                  methodology: { stage: "hunt_detail_spells_resilient_v1", missing_composition_not_inferred: true },
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
              // The DB rejects explicitly requested setups that are no longer
              // owned/saved. Fail without inserting a misleading snapshot.
              if (data && typeof data === "object" && "error" in data && data.error) {
                return json({ error: String(data.error) }, 409);
              }
              return json({ data, parsed: parsedImport });
            }
            case "player_session_build_performance":
              return json({
                data: await rpc("huntnexus_player_session_build_performance", {
                  p_client_id: b.client_id,
                  p_hunt_key: b.hunt_key,
                  p_vocation: b.vocation ?? null,
                }),
              });
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
            case "player_session_integrity_review": {
              const [saved, detail] = await Promise.all([
                rpc("huntnexus_player_session_reparse_source",{
                  p_client_id:b.client_id,p_session_id:b.session_id,
                }),
                rpc("huntnexus_player_session_detail",{
                  p_client_id:b.client_id,p_session_id:b.session_id,
                }),
              ]);
              if (!saved || saved.error || !detail || detail.error) {
                return json({error:"session_not_found"},404);
              }
              const raw=saved.raw_blocks;
              if (!raw || typeof raw!=="object" || Array.isArray(raw)) {
                return json({error:"session_raw_blocks_missing"},422);
              }
              for (const key of ["hunt","party","input","misc"]) {
                if (raw[key]!==undefined && typeof raw[key]!=="string") {
                  return json({error:"session_raw_blocks_invalid"},422);
                }
              }
              const {buildSessionIntegrityReport}=await import("@/lib/session-integrity");
              const report=buildSessionIntegrityReport({
                rawBlocks:{
                  hunt:raw.hunt||"",input:raw.input||"",
                  misc:raw.misc||"",party:raw.party||"",
                },
                storedParsedData:saved.parsed_data && typeof saved.parsed_data==="object"
                  ? saved.parsed_data:{},
                sessionDetail:detail,
                parserVersion:String(saved.parser_version??""),
              });
              return json({data:{session_id:b.session_id,...report}});
            }
            case "player_session_delete":
              return json({
                data: await rpc("huntnexus_player_session_delete", {
                  p_client_id: b.client_id,
                  p_session_id: b.session_id,
                }),
              });
            case "player_session_revision_list": {
              const result = await rpc("huntnexus_player_session_revision_list",{
                p_client_id:b.client_id,p_session_id:b.session_id,
              });
              if (result?.error) return json({error:String(result.error)},404);
              return json({data:result});
            }
            case "player_session_restore_preview":
            case "player_session_restore_apply": {
              const saved=await rpc("huntnexus_player_session_revision_restore_source",{
                p_client_id:b.client_id,p_session_id:b.session_id,
                p_revision_id:b.revision_id,
              });
              if (!saved || typeof saved!=="object" || saved.error) {
                return json({error:"revision_not_found"},404);
              }
              const current=saved.current_parsed_data;
              const previous=saved.target_parsed_data;
              if (!current || typeof current!=="object" ||
                  !previous || typeof previous!=="object") {
                return json({error:"restore_revision_invalid"},422);
              }
              const {buildSessionReparseReview}=
                await import("@/lib/session-reparse-review");
              // Restore only from the DB's saved historical revision, never
              // accept a parsed_data object provided by the browser.
              const review=buildSessionReparseReview(
                current,previous,String(saved.current_parser_version??""),
              );
              const preview={
                session_id:b.session_id,
                revision_id:b.revision_id,
                current_parser_version:saved.current_parser_version,
                target_parser_version:saved.target_parser_version,
                revised_at:saved.revised_at,
                snapshot_source:saved.snapshot_source??"not_available",
                raw_blocks_preserved:true,
                loadout_snapshot_preserved:true,
                expected_fingerprint:saved.fingerprint,
                review,
                data_loss_warning:review.regression_reasons.length>0,
              };
              if (b.action==="player_session_restore_preview") {
                return json({data:preview});
              }
              if (saved.fingerprint!==b.expected_fingerprint) {
                return json({error:"restore_preview_stale"},409);
              }
              if (!review.changed) return json({error:"restore_no_changes"},409);
              if (review.regression_reasons.length>0 && !b.accept_regressions) {
                return json({error:"restore_accept_data_loss_required",
                  reasons:review.regression_reasons},409);
              }
              const result=await rpc("huntnexus_player_session_revision_restore",{
                p_client_id:b.client_id,p_session_id:b.session_id,
                p_revision_id:b.revision_id,
                p_expected_fingerprint:b.expected_fingerprint,
                p_confirm:true,
                p_accept_regressions:true,
              });
              if (result?.error) return json({error:String(result.error)},
                result.error==="session_not_found"||result.error==="revision_not_found"?404:409);
              return json({data:{...result,review:{
                ...review,raw_blocks_preserved:true,loadout_snapshot_preserved:true,
              }}});
            }
            case "player_session_reparse_preview":
            case "player_session_reparse_apply": {
              const saved = await rpc("huntnexus_player_session_reparse_source", {
                p_client_id: b.client_id,
                p_session_id: b.session_id,
              });
              if (!saved || typeof saved !== "object" || saved.error) {
                return json({ error: "session_not_found" }, 404);
              }
              const raw = saved.raw_blocks;
              if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
                return json({ error: "session_raw_blocks_missing" }, 422);
              }
              for (const key of ["hunt","party","input","misc"]) {
                if (raw[key] !== undefined && typeof raw[key] !== "string") {
                  return json({ error: "session_raw_blocks_invalid" }, 422);
                }
              }
              const { parseSessionImport } = await import("@/lib/session-parser");
              const { buildSessionReparseReview } =
                await import("@/lib/session-reparse-review");
              const reparsed = parseSessionImport({
                hunt: raw.hunt || "", party: raw.party || "",
                input: raw.input || "", misc: raw.misc || "",
              });
              const prior = saved.parsed_data && typeof saved.parsed_data === "object"
                && !Array.isArray(saved.parsed_data) ? saved.parsed_data : {};
              const candidate = { ...prior, ...reparsed };
              const review = buildSessionReparseReview(
                prior, reparsed, String(saved.parser_version ?? ""),
              );
              // Recheck parser metrics at both layers: never overwrite old
              // numeric observations with a less complete parse.
              const preview = {
                session_id: b.session_id,
                previous_parser_version: saved.parser_version,
                proposed_parser_version: reparsed.methodology.stage,
                snapshot_source: saved.snapshot_source ?? "not_available",
                raw_blocks_preserved: true,
                loadout_snapshot_preserved: true,
                review,
                expected_fingerprint: saved.fingerprint,
              };
              if (b.action === "player_session_reparse_preview") {
                return json({ data: preview });
              }
              if (saved.fingerprint !== b.expected_fingerprint) {
                return json({ error: "reparse_preview_stale" }, 409);
              }
              if (!review.changed) return json({ error: "reparse_no_changes" }, 409);
              if (!review.safe_to_apply) {
                return json({
                  error: "reparse_regression_blocked",
                  reasons: review.regression_reasons,
                }, 409);
              }
              const applied = await rpc("huntnexus_player_session_reparse_apply", {
                p_client_id: b.client_id,
                p_session_id: b.session_id,
                p_expected_fingerprint: b.expected_fingerprint,
                p_parsed_data: candidate,
                p_confirm: true,
              });
              if (applied?.error) {
                return json({ error: String(applied.error) },
                  applied.error === "session_not_found" ? 404 : 409);
              }
              return json({ data: {
                ...applied,
                review,
                original_raw_blocks_preserved: true,
                original_loadout_snapshot_preserved: true,
              } });
            }
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
            case "search_creatures":
              return json({ data: await rpc("huntnexus_search_creatures", { p_query: b.query, p_limit: b.limit }) });
            case "creature_detail":
              return json({ data: await rpc("huntnexus_creature_detail", { p_creature_key: b.creature_key }) });
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
            case "planner_personalized": {
              const plannerEvidence = (hunt: any, method: any) => {
                const count = Math.max(0, Number(hunt?.session_count) || 0);
                return {
                  source_layer: method?.source_layer ?? "unknown",
                  observed_session_count: count,
                  limited_sample: count < 3,
                  confidence_index_is_statistical_probability: false,
                  ranking_is_experimental: method?.final_recommendation !== true,
                  private_sessions_do_not_change_rank: true,
                };
              };
              const ranking = await rpc("huntnexus_rank_observed_hunts", {
                p_vocation: b.vocation,
                p_level: b.level,
                p_objective: b.objective,
                p_party_size: b.party_size,
                p_limit: b.limit,
              });

              const ranked = Array.isArray(ranking?.results) ? ranking.results : [];
              const results = await Promise.all(
                ranked.map(async (hunt: any, index: number) => {
                  if (!b.client_id || !hunt?.hunt_key) {
                    return {
                      hunt,
                      hunt_rank_order: index + 1,
                      evidence: plannerEvidence(hunt, ranking?.methodology),
                      owned_builds: null,
                      saved_owned_choice: { exists: false, choice: null },
                    };
                  }

                  const [ownedBuilds, savedChoice, personalPerformance] = await Promise.all([
                    rpc("huntnexus_player_owned_build_options_v2", {
                      p_client_id: b.client_id,
                      p_hunt_key: hunt.hunt_key,
                      p_vocation: b.vocation,
                      p_level: b.level,
                      p_proficiency_selections: b.proficiency_selections,
                      p_character_profile: b.character_profile,
                      p_option_limit: 3,
                    }),
                    rpc("huntnexus_player_hunt_build_choice_get", {
                      p_client_id: b.client_id,
                      p_hunt_key: hunt.hunt_key,
                      p_vocation: b.vocation,
                    }),
                    rpc("huntnexus_player_session_build_performance", {
                      p_client_id: b.client_id,
                      p_hunt_key: hunt.hunt_key,
                      p_vocation: b.vocation,
                    }),
                  ]);

                  return {
                    hunt,
                    hunt_rank_order: index + 1,
                    evidence: plannerEvidence(hunt, ranking?.methodology),
                    owned_builds: ownedBuilds,
                    saved_owned_choice: savedChoice,
                    personal_performance: personalPerformance,
                  };
                }),
              );

              return json({
                data: {
                  query: ranking?.query ?? {
                    vocation: b.vocation,
                    level: b.level,
                    objective: b.objective,
                    party_size: b.party_size,
                  },
                  results,
                  summary: {
                    ranked_hunts: results.length,
                    hunts_with_registered_main_set: results.filter(
                      (row: any) => Number(row?.owned_builds?.summary?.main_items ?? 0) > 0,
                    ).length,
                    hunts_with_saved_build_choice: results.filter(
                      (row: any) => row?.saved_owned_choice?.exists === true,
                    ).length,
                    observed_sessions_in_displayed_hunts: results.reduce(
                      (sum: number, row: any) => sum + Number(row?.evidence?.observed_session_count ?? 0), 0,
                    ),
                    hunts_with_limited_sample: results.filter(
                      (row: any) => row?.evidence?.limited_sample === true,
                    ).length,
                  },
                  methodology: {
                    stage: "planner_personalized_api_v1",
                    source_hunt_ranking_stage: ranking?.methodology?.stage ?? null,
                    hunt_ranking_reordered_by_inventory: false,
                    ownership_affects_hunt_rank: false,
                    universal_set_frontier_deferred_to_hunt_detail: true,
                    owned_builds_enrich_results_only: true,
                    main_set_is_baseline: true,
                    external_items_used_in_owned_options: false,
                    experimental_observational_ranking: ranking?.methodology?.final_recommendation !== true,
                    performance_values_are_observed_not_guaranteed: true,
                    confidence_index_is_not_a_statistical_probability: true,
                    no_results_does_not_mean_no_hunts_exist: true,
                  },
                },
              });
            }
            case "final_optimizer": {
              return withAdvancedOptimizerSlot(async () => {
              const params = {
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
              };

              const base = await rpc("huntnexus_optimizer_final_universal", params);

              if (!b.client_id) {
                return json({ data: base });
              }

              const baseResults = Array.isArray(base?.results) ? base.results : [];
              const enrichedResults = await Promise.all(
                baseResults.map(async (row: any) => {
                  const huntKey = row?.hunt?.hunt_key;
                  if (!huntKey) {
                    return {
                      ...row,
                      owned_builds: null,
                      saved_owned_choice: { exists: false, choice: null },
                    };
                  }

                  const [ownedBuilds, savedChoice] = await Promise.all([
                    rpc("huntnexus_player_owned_build_options_v2", {
                      p_client_id: b.client_id,
                      p_hunt_key: huntKey,
                      p_vocation: b.vocation,
                      p_level: b.level,
                      p_proficiency_selections: b.proficiency_selections,
                      p_character_profile: b.character_profile,
                      p_option_limit: 3,
                    }),
                    rpc("huntnexus_player_hunt_build_choice_get", {
                      p_client_id: b.client_id,
                      p_hunt_key: huntKey,
                      p_vocation: b.vocation,
                    }),
                  ]);

                  return {
                    ...row,
                    owned_builds: ownedBuilds,
                    saved_owned_choice: savedChoice,
                  };
                }),
              );

              return json({
                data: {
                  ...base,
                  results: enrichedResults,
                  personalization_summary: {
                    client_scope_available: true,
                    ranked_hunts: enrichedResults.length,
                    hunts_with_registered_main_set: enrichedResults.filter(
                      (row: any) => Number(row?.owned_builds?.summary?.main_items ?? 0) > 0,
                    ).length,
                    hunts_with_saved_build_choice: enrichedResults.filter(
                      (row: any) => row?.saved_owned_choice?.exists === true,
                    ).length,
                  },
                  methodology: {
                    ...(base?.methodology ?? {}),
                    stage: "optimizer_final_personalized_api_v1",
                    hunt_ranking_reordered_by_inventory: false,
                    ownership_affects_hunt_rank: false,
                    owned_builds_enrich_results_only: true,
                    external_items_used_in_owned_options: false,
                    personal_session_history_affects_hunt_rank: false,
                    main_set_is_baseline: true,
                  },
                },
              });
              });
            }
            case "boss_build": {
              const [data, warnings] = await Promise.all([
                rpc("huntnexus_boss_build_preview", { p_boss_key: b.boss_key, p_vocation: b.vocation, p_level: b.level }),
                rpc("huntnexus_global_boss_warnings"),
              ]);
              return json({ data, warnings: Array.isArray(warnings) ? warnings : [] });
            }
            case "loadout_preview":
              return json({
                data: await rpc("huntnexus_loadout_set_preview_profiled", {
                  p_hunt_key: b.hunt_key,
                  p_vocation: b.vocation,
                  p_level: b.level,
                  p_objective: b.objective,
                  p_per_dimension: b.per_dimension,
                  p_character_profile: b.character_profile,
                }),
              });
          }
        } catch {
          return json({ error: "upstream_error", detail: "A consulta ao banco falhou." }, 502);
        }
      },
    },
  },
});
